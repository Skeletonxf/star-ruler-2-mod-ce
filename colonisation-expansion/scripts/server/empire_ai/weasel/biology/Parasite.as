import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Planets;
import empire_ai.weasel.Development;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
/*
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Military; */

import biomes;

from statuses import getStatusID;
from abilities import getAbilityID;

/**
 * The parasite AI component for AI usage of the Parasite trait,
 * mainly the Raze ability that comes with it, as the passive
 * pressure debuff will be handled fine by the existing planet/colonising code.
 */
class Parasite : AIComponent {
	Planets@ planets;
	Development@ development;
	Resources@ resources;
	IColonization@ colonization;
	/*
	Orbitals@ orbitals;
	Construction@ construction;
	Systems@ systems;
	Budget@ budget;
	Military@ military; */

	int foodClass = -1;
	int waterClass = -1;
	int scalableClass = -1;

	int razingStatusID = -1;
	int alreadyRazedStatusID = -1;

	int ftlType = -1;
	int supercarbonsType = -1;
	int hydroconductorsType = -1;
	int titaniumType = -1;
	int ironType = -1;
	int aluminumType = -1;

	int razeAbility = -1;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@development = cast<Development>(ai.development);
		@resources = cast<Resources>(ai.resources);
		@colonization = cast<IColonization>(ai.colonization);
		/*
		@orbitals = cast<Orbitals>(ai.orbitals);
	    @construction = cast<Construction>(ai.construction);
		@systems = cast<Systems>(ai.systems);
	    @budget = cast<Budget>(ai.budget);
		@military = cast<Military>(ai.military); */

		// cache lookups
		foodClass = getResourceClass("Food").id;
		waterClass = getResourceClass("WaterType").id;
		scalableClass = getResourceClass("Scalable").id;

		razingStatusID = getStatusID("ParasiteRaze");
		alreadyRazedStatusID = getStatusID("ParasiteRazeDone");

		ftlType = getResource("FTL").id;
		supercarbonsType = getResource("Supercarbons").id;
		hydroconductorsType = getResource("Hydroconductors").id;
		titaniumType = getResource("Titanium").id;
		ironType = getResource("Iron").id;
		aluminumType = getResource("Aluminum").id;

		razeAbility = getAbilityID("RazeAbility");
	}

	void save(SaveFile& file) {
	}

	void load(SaveFile& file) {
	}

	array<Resource> planetResources;

	/**
	 * The approx relative value of razing down a particular planet.
	 *
	 * In general food and water resources are nearly useless, but
	 * planets we've already build up have the least value to raze,
	 * whereas planets we're planing to build up but haven't yet
	 * are good candidates for razing.
	 */
	double planetRazeWeight(PlanetAI& plAI) {
		bool planetOwned = plAI.obj.owner is ai.empire;
		if (!planetOwned) {
			// cannot raze
			return -1000.0;
		}

		if (plAI.obj.hasStatusEffect(alreadyRazedStatusID) || plAI.obj.hasStatusEffect(razingStatusID)) {
			// already razing/razed
			return -1000.0;
		}

		double weight = 0.0;
		Planet@ planet = plAI.obj;
		int targetLevel = plAI.targetLevel;
		int actualLevel = planet.level;
		double planetPop = planet.population;

		// High population planets are less useful to raze because
		// the gold gain will be less
		if (planetPop <= 2.0) {
			weight += 0.5;
		}
		if (planetPop >= 8.0) {
			weight -= 5.0;
		}

		// try not to raze planets we're planning to level or in the process
		// of levelling
		if (targetLevel >= 2) {
			weight -= 10;
		}
		if (actualLevel > 0) {
			weight -= 10;
		}

		// weigh up the value of each native resource on the planet
		planetResources.syncFrom(planet.getNativeResources());
		for (uint i = 0, cnt = planetResources.length; i < cnt; i++) {
			auto planetResourceType = planetResources[i].type;
			auto planetResourceClass = planetResourceType.cls;
			bool resourceExported = planetResources[i].exportedTo !is null;
			bool foodOrWater = false;
			bool scalable = false;
			if (planetResourceClass !is null) {
				scalable = int(planetResourceClass.id) == scalableClass;
				foodOrWater = int(planetResourceClass.id) == foodClass || int(planetResourceClass.id) == waterClass;
			}

			double resourceValue = 1.0;
			if (foodOrWater) {
				// food and water resources are almost useless to raze
				resourceValue = 0.1;
			} else {
				// higher level resources are more valuable to raze, but
				// also more scarce so should not be the deciding factor
				resourceValue += planetResourceType.level;
				// level 2 planets are quite scarce and will be needed for
				// leveling
				if (planetResourceType.level == 2) {
					resourceValue -= 3.0;
				}
				// scalable resources are unlikely to be levelled all the way
				// by normal levelling so good candidates for razing
				if (scalable) {
					resourceValue += 2.0;
				}
				// unexportable resources are less useful for leveling normally
				if (planetResourceType.exportable == false) {
					resourceValue *= 2.0;
				}

				// resources we're already exporting will upset the level
				// chains established
				if (resourceExported) {
					resourceValue -= 10.0;
				}

				// handle special cases that aren't such good candidates
				int resource = planetResourceType.id;
				if (resource == ftlType) {
					// razing ftl crystals don't help in the sense that you
					// can't go above your FTL storage limit, and the AI doesn't
					// build that much FTL storage
					resourceValue = -35.0;
				}
				// labor resources also don't stockpile
				if (resource == supercarbonsType || resource == hydroconductorsType || resource == titaniumType || resource == ironType || resource == aluminumType) {
					resourceValue = -30.0;
				}
			}
			weight += resourceValue;
		}
		return weight;
	}

	/**
	 * Gets the level/tier of the resource with the highest tier/level on
	 * this planet, or 0 if there are none.
	 */
	uint getHighestPlanetResourceLevel(PlanetAI& plAI) {
		uint level = 0;
		planetResources.syncFrom(plAI.obj.getNativeResources());
		for (uint i = 0, cnt = planetResources.length; i < cnt; i++) {
			auto planetResourceType = planetResources[i].type;
			if (planetResourceType.level > level) {
				level = planetResourceType.level;
			}
		}
		return level;
	}

	void start() {
		// Grab some tier 1s as we'll need a buffer of planets to raze
		{
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 1;
			spec.isForImport = false;
			spec.isLevelRequirement = false;
			colonization.queueColonize(spec);
		}
		{
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 1;
			spec.isForImport = false;
			spec.isLevelRequirement = false;
			colonization.queueColonize(spec);
		}
	}

	void focusTick(double time) override {
		// looks like this is where we should perform actions?
		// Aim to keep 3 planets razed at minimum, as this provides a
		// good amount of bonus income regardless of the actual resources
	}

	void tick(double time) override {
		// TODO
		// If we're in debt should probably raze something
	}

	void turn() override {
		// Update book keeping for which owned planets are best to raze
		// TODO: Any sort of bookkeeping
		// TODO: do more than one target per turn?
		// TODO: This should be done just before the end of a budget cycle, not
		// at the start of one
		PlanetAI@ bestRazeTarget;
		int bestRazeValue = 0.0;
		int goodRazeTargets = 0;
		for (uint i = 0, cnt = planets.planets.length; i < cnt; i++) {
			PlanetAI@ plAI = planets.planets[i];
			int razeValue = planetRazeWeight(plAI);
			if (razeValue > bestRazeValue) {
				bestRazeValue = razeValue;
				@bestRazeTarget = plAI;
			}
			if (razeValue > 2.0) {
				goodRazeTargets += 1;
			}
		}
		if (bestRazeValue > 1.0 && bestRazeTarget !is null) {
			bestRazeTarget.obj.activateAbilityTypeFor(ai.empire, razeAbility);
			// mark the planet as no longer worth leveling
			bestRazeTarget.targetLevel = 0;
			bestRazeTarget.requestedLevel = 0;
			for (int i = development.focuses.length - 1; i >= 0; --i) {
				if (development.focuses[i].plAI is bestRazeTarget) {
					development.focuses.remove(development.focuses[i]);
				}
			}
			uint razeTargetLevel = getHighestPlanetResourceLevel(bestRazeTarget);
			if (goodRazeTargets < 3) {
				if (razeTargetLevel == 1 || razeTargetLevel == 2) {
					// queue up another colonise for a tier 1/2 planet as we're
					// using this one
					ResourceSpec spec;
					spec.type = RST_Level_Specific;
					spec.level = razeTargetLevel;
					spec.isForImport = false;
					spec.isLevelRequirement = false;
					colonization.queueColonizeHighPriority(spec);
				}
			}
			// TODO: Remove imports/exports from this planet
		}
		if (goodRazeTargets < 3) {
			// queue up a level 1 resource each turn we lack good raze targets
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 1;
			spec.isForImport = false;
			spec.isLevelRequirement = false;
			colonization.queueColonize(spec);
		}
	}

	/*
	 * A usefulness modifier similar to the race usefulness modifiers
	 * for directing colonisation towards good raze targets.
	 *
	 * This only prioritises planets we don't want to level normally, as
	 * prioritising tier 1/2 planets causes a shortage of food/water.
	 */
	double getGenericUsefulness(const ResourceType@ type) {
		if (type.exportable == false) {
			return 200.0;
		}
		if (type.level == 3) {
			return 50.0;
		}
		if (type.cls !is null) {
			if (int(type.cls.id) == scalableClass) {
				return 100.0;
			}
		}
		return 1.0;
	}
}

AIComponent@ createParasite() {
	return Parasite();
}
