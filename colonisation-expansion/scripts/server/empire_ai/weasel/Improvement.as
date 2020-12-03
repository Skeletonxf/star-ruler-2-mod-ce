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

/**
 * Component responsible for minor tweaks and actions to take that improve
 * the AI's existing infrastructure and planets.
 *
 * Mostly reactive actions in response to problems that occur from other
 * components.
 */
class Improvement : AIComponent {
	Planets@ planets;
	Resources@ resources;
	IDevelopment@ development;
	Orbitals@ orbitals;
	Construction@ construction;
	Systems@ systems;
	Budget@ budget;
	IMilitary@ military;
	Intelligence@ intelligence;
	Relations@ relations;

	uint atmosphere = 0;
	int moon_base = -1;
	const ConstructionType@ build_moon_base;
	bool no_build_moon_bases = false;

	const OrbitalModule@ ftlExtractor;
	bool ftlExtractorsUnlocked = false;
	bool immuneToCarpetBombs = false;
	bool isMechanoid = false;
	// an index for checking planets in need of carpet bomb protection
	uint carpetBombCheck = 0;

	AllocateConstruction@ extractorBuild = null;

	const BuildingType@ defenseGrid;
	const BuildingType@ largeDefenseGrid;
	int ringworldStatusID = -1;
	int artificialPlanetoidStatusID = -1;
	int hasDefensesStatusID = -1;
	int nonCombatDefensesOrdered = 0;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@resources = cast<Resources>(ai.resources);
		@development = cast<IDevelopment>(ai.development);
		@orbitals = cast<Orbitals>(ai.orbitals);
	    @construction = cast<Construction>(ai.construction);
		@systems = cast<Systems>(ai.systems);
	    @budget = cast<Budget>(ai.budget);
		@military = cast<IMilitary>(ai.military);
		@intelligence = cast<Intelligence>(ai.intelligence);
		@relations = cast<Relations>(ai.relations);

		// cache lookups
		atmosphere = getBiomeID("Atmosphere");
		moon_base = getStatusID("MoonBase");
		@build_moon_base = getConstructionType("MoonBase");
		no_build_moon_bases = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		@ftlExtractor = getOrbitalModule("FTLExtractor");
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;

		immuneToCarpetBombs = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		@defenseGrid = getBuildingType("DefenseGrid");
		@largeDefenseGrid = getBuildingType("LargeDefenseGrid");
		ringworldStatusID = getStatusID("Ringworld");
		artificialPlanetoidStatusID = getStatusID("ArtificialPlanetoid");
		isMechanoid = ai.empire.hasTrait(getTraitID("Mechanoid"));
		hasDefensesStatusID = getStatusID("HasDefenses");
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
		lookToBuildMoonBases();

		// check again to see if we unlocked FTL Extractors
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;
		lookToBuildFTLExtractors();

		lookToBuildDefenses();
	}

	/**
	 * Tries to place moon bases on planets we logged as failing to build on
	 * in Development/Expansion. Mostly aimed at building a moon base for
	 * Gas Giants that need space for a Megafarm/Hydrogenator but may also
	 * help with AI with development focuses running out of room.
	 */
	void lookToBuildMoonBases() {
		// don't build moon bases as Star Children or Ancient
		// star children don't need them as they don't build
		// and Ancient bypasses biome cost/build time mods
		// so can just build on planet surfaces as normal and
		// thus doesn't need them
		if (no_build_moon_bases) {
			return;
		}
		// check for any planets we have no moon bases on
		if (budget.canSpend(BT_Development, build_moon_base.buildCost)) {
			for(uint i = 0, cnt = planets.planets.length; i < cnt; ++i) {
				auto@ plAI = planets.planets[i];
				auto@ planet = plAI.obj;
				if (planet.moonCount == 0) {
					continue;
				}
				// We could try to check here if the planet actually needs a moon base.
				// There's a high chance we get the gas giant to level 1 via importing
				// food and water, in which case we shouldn't waste money on a moon base
				// we don't use. Instead we'll only act reactively, and build another
				// moon base following a failed attempt to build on this planet
				if (!plAI.failedToPlaceBuilding) {
					continue;
				}
				// Loosening up restrictions so the AI can consider building
				// moons on non gas giants if it runs out of space there too
				/* if (planet.get_Biome0() != atmosphere) {
					continue;
				} */
				if (planet.getStatusStackCountAny(moon_base) >= planet.moonCount) {
					// can't build more moon bases
					continue;
				}
				bool alreadyConstructingMoonBase = planets.isConstructing(planet, build_moon_base);
				if (!alreadyConstructingMoonBase) {
					// TODO: Check for how many spare tiles we have on the planet
					// so we can allow building multiple moon bases but ensure the
					// AI doesn't waste money on moon bases for buildings its already
					// making
					if (true && planet.getStatusStackCountAny(moon_base) > 0) {
						//ai.print("Building additional moon base at " + planet.name);
						// FIXME: Why does the AI think it needs to make 2 moon
						// bases the moment a build request fails when we are
						// clearly checking that we've not already queued one
						// and why does the AI think it needs to make a third moon
						// base once we actually finish building the first two, all
						// for a single megafarm?
						return;
					}
					if (log && planet.getStatusStackCountAny(moon_base) == 0) {
						ai.print("Building moon base at " + planet.name);
					}
					// Set the flag back
					plAI.failedToPlaceBuilding = false;
					// This is always highish priority because we only try
					// to make a moon base after finding out a building failed
					// to be placed.
					planets.requestConstruction(
						plAI, planet, build_moon_base, priority=2, expire=gameTime + 600, moneyType=BT_Development);
						// only build max of one moon base thing each tick so the empire
						// does other things than improvements
						return;
				}
			}
		}
	}

	void lookToBuildFTLExtractors() {
		if (ftlExtractor is null) {
			return;
		}

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
		if (!budget.canSpend(BT_Military, ftlExtractor.buildCost, ftlExtractor.maintenance)) {
			return;
		}

		// Try to find a staging base to build this orbital at as they are
		// easily shot down if not protected
		for (uint i = 0, cnt = military.StagingBases.length; i < cnt; ++i) {
			auto@ base = military.StagingBases[i];
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

			BuildOrbital@ buildPlan = construction.buildLocalOrbital(ftlExtractor);
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
			if (planet is null) {
				return;
			}
			if (planet.level < 2 || planet.population <= 5) {
				// nothing to protect from carpet bombs
				return;
			}
			if (planet.hasStatusEffect(hasDefensesStatusID)) {
				return;
			}
			// Mechanoid are particularly vulnurable to carpet bomb
			// attacks, but most of their planets are level 2 because a tier
			// 1 resource gets level 2 by default. Mechanoid also really need
			// to avoid spending money they need for pop.
			// A comprimise here is to avoid spending money on defending
			// level 2 planets if the net budget isn't 4M or higher, to
			// avoid crushing the Mono AI's eco even more in the early game.
			if (isMechanoid && planet.level == 2 && ai.empire.EstNextBudget < 4000) {
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
					if (budget.canSpend(BT_Development, 300, 100)) {
						planets.requestBuilding(plAI, largeDefenseGrid, priority=buildPriority);
						if (!planetUnderSiege) {
							nonCombatDefensesOrdered += 1;
						}
						if (log) {
							ai.print("Building defense grid at "+planet.name);
						}
					}
				}
			} else {
				if (!planets.isBuilding(planet, defenseGrid)) {
					if (budget.canSpend(BT_Development, 300, 100)) {
						planets.requestBuilding(plAI, defenseGrid, priority=buildPriority);
						if (!planetUnderSiege) {
							nonCombatDefensesOrdered += 1;
						}
						if (log) {
							ai.print("Building defense grid at "+planet.name);
						}
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
