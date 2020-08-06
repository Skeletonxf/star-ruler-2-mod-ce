import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Development;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Military;
import empire_ai.weasel.Intelligence;
import empire_ai.weasel.Relations;

import biomes;

from traits import getTraitID;
from orbitals import getOrbitalModuleID;
from statuses import getStatusID;
from buildings import getBuildingType, BuildingType;

const double FTL_EXTRACTOR_MIN_HELD_BASE_TIMER = 3 * 60.0;

class Improvement : AIComponent {
	Planets@ planets;
	Resources@ resources;
	Colonization@ colonization;
	Development@ development;
	Orbitals@ orbitals;
	Construction@ construction;
	Systems@ systems;
	Budget@ budget;
	Military@ military;
	Intelligence@ intelligence;
	Relations@ relations;

	uint atmosphere = 0;
	int moon_base = -1;
	const ConstructionType@ build_moon_base;
	bool no_build_moon_bases = false;

	int ftlExtractorModuleID = -1;
	bool ftlExtractorsUnlocked = false;
	bool immuneToCarpetBombs = false;
	// an index for checking planets in need of carpet bomb protection
	uint carpetBombCheck = 0;

	AllocateConstruction@ extractorBuild = null;

	const BuildingType@ defenseGrid;
	const BuildingType@ largeDefenseGrid;
	int ringworldStatusID = -1;
	int artificialPlanetoidStatusID = -1;
	int nonCombatDefensesOrdered = 0;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@resources = cast<Resources>(ai.resources);
		@colonization = cast<Colonization>(ai.colonization);
		@development = cast<Development>(ai.development);
		@orbitals = cast<Orbitals>(ai.orbitals);
	    @construction = cast<Construction>(ai.construction);
		@systems = cast<Systems>(ai.systems);
	    @budget = cast<Budget>(ai.budget);
		@military = cast<Military>(ai.military);
		@intelligence = cast<Intelligence>(ai.intelligence);
		@relations = cast<Relations>(ai.relations);

		// cache lookups
		atmosphere = getBiomeID("Atmosphere");
		moon_base = getStatusID("MoonBase");
		@build_moon_base = getConstructionType("MoonBase");
		no_build_moon_bases = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		ftlExtractorModuleID = getOrbitalModuleID("FTLExtractor");
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;

		immuneToCarpetBombs = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		@defenseGrid = getBuildingType("DefenseGrid");
		@largeDefenseGrid = getBuildingType("LargeDefenseGrid");
		ringworldStatusID = getStatusID("Ringworld");
		artificialPlanetoidStatusID = getStatusID("ArtificialPlanetoid");
	}

	void save(SaveFile& file) {
		construction.saveConstruction(file, extractorBuild);
		file << carpetBombCheck;
		file << nonCombatDefensesOrdered;
	}

	void load(SaveFile& file) {
		@extractorBuild = construction.loadConstruction(file);
		file >> carpetBombCheck;
		file >> nonCombatDefensesOrdered;
	}

	void start() {
		// TODO
	}

	void focusTick(double time) override {
		lookToBuildGasGiants();

		// check again to see if we unlocked FTL Extractors
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;
		lookToBuildFTLExtractors();

		lookToBuildDefenses();
	}

	void lookToBuildGasGiants() {
		// check for any gas giants we have no moon bases on
		if (budget.canSpend(BT_Development, 500)) {
			for(uint i = 0, cnt = planets.planets.length; i < cnt; ++i) {
				auto@ plAI = planets.planets[i];
				auto@ planet = plAI.obj;
				if (no_build_moon_bases) {
					// don't build moon bases as Star Children or Ancient
					// star children don't need them as they don't build
					// and Ancient bypasses biome cost/build time mods
					// so can just build on planet surfaces as normal and
					// thus doesn't need them
					continue;
				}
				if (planet.moonCount == 0) {
					continue;
				}
				if (planet.get_Biome0() != atmosphere) {
					continue;
				}
				if (planet.getStatusStackCountAny(moon_base) > 0 && !plAI.failedGasGiantBuild) {
					// If we already have a moon base and haven't attempted
					// and failed to build anything on this planet we don't need
					// more
					continue;
				}
				if (planet.moonCount >= planet.getStatusStackCountAny(moon_base)) {
					// can't build more moon bases
					continue;
				}
				if (!plAI.failedGasGiantBuild) {
					// don't need a moon base if this planet has all its
					// food and water imported
					continue;
				}
				if (!planets.isConstructing(planet, build_moon_base)) {
					// This is always high priority because we either have no
					// moon base in which case we can't build anything
					// or we already tried to build something and don't have
					// enough moon bases
					if (log && planet.getStatusStackCountAny(moon_base) > 1) {
						ai.print("Building additional moon base at " + planet.name);
					}
					// Set the flag back
					plAI.failedGasGiantBuild = false;
					planets.requestConstruction(
						plAI, planet, build_moon_base, priority=3, expire=gameTime + 600, moneyType=BT_Development);
						// only build one thing each tick so the empire
						// does other things than improvements
						return;
				}
			}
		}
	}

	void lookToBuildFTLExtractors() {
		if (!development.requestsFTLIncome()) {
			return;
		}

		if (!ftlExtractorsUnlocked) {
			// TODO: Queue up the research for Extractors
			return;
		}

		if (extractorBuild !is null) {
			// Don't try to build a second extractor while first is in progress
			return;
		}

		if (!budget.canSpend(BT_Military, 300, 50)) {
			// TODO: Pull these values from the orbital module rather than
			// hardcoding
			return;
		}

		// Try to find a staging base to build this orbital at as they are
		// easily shot down if not protected
		for (uint i = 0, cnt = military.stagingBases.length; i < cnt; ++i) {
			auto@ base = military.stagingBases[i];
			if (base.occupiedTime < FTL_EXTRACTOR_MIN_HELD_BASE_TIMER) {
				continue;
			}

			auto@ factory = construction.getFactory(base.region);
			if (factory is null) {
				continue;
			}

			if (factory.busy) {
				continue;
			}

			if (!factory.obj.canBuildOrbitals) {
				continue;
			}

			// TODO: Should this be military money?
			BuildOrbital@ buildPlan = construction.buildLocalOrbital(getOrbitalModule(ftlExtractorModuleID));

			@extractorBuild = construction.buildNow(buildPlan, factory);
			if (log) {
				ai.print("Creating FTL Extractor", base.region);
			}
			return;
		}
	}

	bool needCarpetBombCounterMeasures() {
		if (immuneToCarpetBombs) {
			return false;
		}
		for (uint i = 0, cnt = intelligence.intel.length; i < cnt; ++i) {
			Intel@ intel = intelligence.intel[i];
			if (intel !is null && intel.hasMadeCarpetBombs && relations.isAtWar(intel.empire)) {
				// no need to counter carpet bombs made by teammates, perhaps
				// this is a little naive because a player could take advantage
				// of the at war requirement, but the AI doesn't have a concept
				// of how much another empire wants to attack it
				return true;
			}
		}
		return false;
	}

	void lookToBuildDefenses() {
		if (!needCarpetBombCounterMeasures()) {
			return;
		}

		// identify the high level planets we have that
		// are not well defended, and build defenses on them to
		// counter carpet bomb raids
		if (carpetBombCheck < planets.planets.length) {
			PlanetAI@ plAI = planets.planets[carpetBombCheck];
			carpetBombCheck += 1;
			if (plAI is null) {
				return;
			}
			Planet@ planet = plAI.obj;
			if (planet.level < 2 || planet.population <= 5) {
				// nothing to protect from carpet bombs
				return;
			}

			Empire@ captEmp = planet.captureEmpire;
			bool planetUnderSiege = !(captEmp is null || captEmp is playerEmpire);

			if (budget.Progress < 0.4 && !planetUnderSiege) {
				// don't build defenses early into the budget cycle as
				// we need to be able to do military spending first
				return;
			}

			if (nonCombatDefensesOrdered >= 2 && !planetUnderSiege) {
				// avoid spending too much money on defense grids in a
				// short period of time
				return;
			}

			double buildPriority = 0.5;
			if (planetUnderSiege) {
				buildPriority = 2;
			}

			if (planet.hasStatusEffect(ringworldStatusID) || planet.hasStatusEffect(artificialPlanetoidStatusID)) {
				if (!planets.isBuilding(planet, largeDefenseGrid)) {
					if (budget.canSpend(BT_Development, 300, 50)) {
						planets.requestBuilding(plAI, largeDefenseGrid, priority=buildPriority);
						if (!planetUnderSiege) {
							nonCombatDefensesOrdered += 1;
						}
						ai.print("building defense grid at "+planet.name);
					}
				}
			} else {
				if (!planets.isBuilding(planet, defenseGrid)) {
					if (budget.canSpend(BT_Development, 300, 50)) {
						planets.requestBuilding(plAI, defenseGrid, priority=buildPriority);
						if (!planetUnderSiege) {
							nonCombatDefensesOrdered += 1;
						}
						ai.print("building defense grid at "+planet.name);
					}
				}
			}
		} else {
			carpetBombCheck = 0;
		}
	}

	void tick(double time) override {
		// TODO
	}

	void turn() override {
		// Check the progress of building FTL Extractors once per budget cycle
		if (extractorBuild !is null) {
			if (extractorBuild.completed) {
				@extractorBuild = null;
			} else {
				if (!extractorBuild.started) {
					// assume it failed
					construction.cancel(extractorBuild);
					@extractorBuild = null;
				}
			}
		}
		// reset counter for how many defenses we've ordered each cycle
		nonCombatDefensesOrdered = 0;
	}
}

AIComponent@ createImprovement() {
	return Improvement();
}
