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

from ai.orbitals import OrbitalAIHook, IsEmpireWideSingleUse;

const double FTL_EXTRACTOR_MIN_HELD_BASE_TIMER = 3 * 60.0;

/**
 * Component responsible for minor tweaks and actions to take that improve
 * the AI's existing infrastructure and planets.
 *
 * Mostly reactive actions in response to problems that occur from other
 * components.
 */
class Improvement : AIComponent, PlanetEventListener {
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

	int moon_base = -1;
	const ConstructionType@ build_moon_base;
	bool no_build_moon_bases = false;

	const OrbitalModule@ ftlExtractor;
	bool immuneToCarpetBombs = false;
	bool isMechanoid = false;
	// an index for checking planets in need of carpet bomb protection
	uint carpetBombCheck = 0;
	bool hasFTLBreeders = false;

	const OrbitalModule@ ftlStorage; // Star Children's special alternative orbital
	bool hasFTLStorageBuilding = true;

	AllocateConstruction@ extractorBuild = null;
	AllocateConstruction@ ftlStorageBuild = null;

	const BuildingType@ defenseGrid;
	const BuildingType@ largeDefenseGrid;
	int ringworldStatusID = -1;
	int artificialPlanetoidStatusID = -1;
	int hasDefensesStatusID = -1;
	int nonCombatDefensesOrdered = 0;

	uint orbitalTypeIndex = 0;

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
		moon_base = getStatusID("MoonBase");
		@build_moon_base = getConstructionType("MoonBase");
		no_build_moon_bases = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		@ftlExtractor = getOrbitalModule("FTLExtractor");

		immuneToCarpetBombs = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		@defenseGrid = getBuildingType("DefenseGrid");
		@largeDefenseGrid = getBuildingType("LargeDefenseGrid");
		ringworldStatusID = getStatusID("Ringworld");
		artificialPlanetoidStatusID = getStatusID("ArtificialPlanetoid");
		isMechanoid = ai.empire.hasTrait(getTraitID("Mechanoid"));
		hasDefensesStatusID = getStatusID("HasDefenses");

		// TODO: Is there some way we can check which buildings/orbitals we have unlocked without
		// needing to consider a specific planet?
		hasFTLBreeders = isMechanoid;
		hasFTLStorageBuilding = !ai.empire.hasTrait(getTraitID("StarChildren"));

		@ftlStorage = getOrbitalModule("FTLStorage");

		planets.listeners.insertLast(this);
	}

	void save(SaveFile& file) {
		construction.saveConstruction(file, extractorBuild);
		construction.saveConstruction(file, ftlStorageBuild);
		file << carpetBombCheck;
		file << nonCombatDefensesOrdered;
		file << orbitalTypeIndex;
	}

	void load(SaveFile& file) {
		@extractorBuild = construction.loadConstruction(file);
		@ftlStorageBuild = construction.loadConstruction(file);
		file >> carpetBombCheck;
		file >> nonCombatDefensesOrdered;
		file >> orbitalTypeIndex;
	}

	void start() {
		// TODO
	}

	void focusTick(double time) override {
		lookToBuildMoonBases();

		lookToBuildFTLExtractors();
		lookToBuildFTLStorage();

		lookToBuildDefenses();

		lookToBuildSingleUseOrbitals();
	}

	/**
	 * Listens to events created by the Planets component, so we can clear the
	 * flags that we use for moon base construction if the moon base was paid
	 * for successfully. This also triggers if planet_management decides to
	 * make a moon base for just income.
	 */
	void onConstructionRequestActioned(ConstructionRequest@ request) {
		if (request is null)
			return;

		if (request.type !is build_moon_base)
			return;

		PlanetAI@ plAI = request.plAI;

		if (plAI is null || plAI.obj is null) {
			return;
		}

		if (request.built && !request.canceled) {
			if (log)
				ai.print("Enqueued moon base", plAI.obj);
			// clear the flag, we started the moon base
			plAI.failedToPlaceBuilding = false;
		}
	}

	void onRemovedPlanetAI(PlanetAI@ plAI) {}

	/**
	 * Tries to place moon bases on planets we logged as failing to build on
	 * in Development/Expansion. Mostly aimed at building a moon base for
	 * Gas Giants that need space for a Megafarm/Hydrogenator but may also
	 * help with AI with development focuses running out of room.
	 */
	void lookToBuildMoonBases() {
		// don't build moon bases as Star Children or Ancient.
		// Star children don't need them as they don't build
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
				// FIXME: Check the planet isn't getting razed

				// We could try to check here if the planet actually needs a moon base.
				// There's a high chance we get the gas giant to level 1 via importing
				// food and water, in which case we shouldn't waste money on a moon base
				// we don't use. Instead we'll only act reactively, and build another
				// moon base following a failed attempt to build on this planet
				if (!plAI.failedToPlaceBuilding) {
					continue;
				}
				if (planet.getStatusStackCountAny(moon_base) >= planet.moonCount) {
					// can't build more moon bases
					continue;
				}

				bool alreadyConstructingMoonBase = planets.isConstructing(planet, build_moon_base);
				if (!alreadyConstructingMoonBase) {
					if (log && planet.getStatusStackCountAny(moon_base) > 0) {
						ai.print("Building additional moon base at " + planet.name);
					}
					if (log && planet.getStatusStackCountAny(moon_base) == 0) {
						ai.print("Building moon base at " + planet.name);
					}
					// This is always highish priority because we only try
					// to make a moon base after finding out a building failed
					// to be placed.
					planets.requestConstruction(
						plAI, planet, build_moon_base, priority=2, expire=gameTime + 600, moneyType=BT_Development
					);
					// only build max of one moon base thing each tick so the empire
					// does other things than improvements
					return;
				}
			}
		}
	}

	void lookToBuildFTLExtractors() {
		if (hasFTLBreeders) {
			return;
		}

		if (ftlExtractor is null) {
			return;
		}

		if (!development.requestsFTLIncome()) {
			return;
		}

		if (!(ai.empire.FTLExtractorsUnlocked >= 1)) {
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
			if (base.occupiedTime < FTL_EXTRACTOR_MIN_HELD_BASE_TIMER || base.isUnderAttack) {
				continue;
			}

			auto@ factory = construction.getClosestFactory(base.region);
			if (factory is null || factory.busy || !factory.obj.canBuildOrbitals) {
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

	void lookToBuildFTLStorage() {
		if (hasFTLStorageBuilding) {
			return;
		}

		if (ftlStorage is null) {
			return;
		}

		if (!development.requestsFTLStorage()) {
			return;
		}

		if (ftlStorageBuild !is null) {
			// Don't try to build a second while first is in progress
			return;
		}
		if (!budget.canSpend(BT_Military, ftlStorage.buildCost, ftlStorage.maintenance)) {
			return;
		}

		// Try to find a staging base to build this orbital at as they are
		// easily shot down if not protected
		for (uint i = 0, cnt = military.StagingBases.length; i < cnt; ++i) {
			auto@ base = military.StagingBases[i];
			if (base.occupiedTime < FTL_EXTRACTOR_MIN_HELD_BASE_TIMER || base.isUnderAttack) {
				continue;
			}

			auto@ factory = construction.getClosestFactory(base.region);
			if (factory is null || factory.busy || !factory.obj.canBuildOrbitals) {
				continue;
			}
			if (!ftlStorage.canBuild(factory.obj, factory.obj.position)) {
				continue;
			}

			BuildOrbital@ buildPlan = construction.buildLocalOrbital(ftlStorage);
			@ftlStorageBuild = construction.buildNow(buildPlan, factory);
			if (log) {
				ai.print("Creating FTL Storage", base.region);
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

	void lookToBuildSingleUseOrbitals() {
		orbitalTypeIndex = (orbitalTypeIndex + 1) % getOrbitalModuleCount();
		const OrbitalModule@ type = getOrbitalModule(orbitalTypeIndex);
		for(uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
			auto@ hook = cast<OrbitalAIHook>(type.ai[n]);
			if (hook is null) {
				continue;
			}
			auto@ singleUse = cast<IsEmpireWideSingleUse>(hook);
			if (singleUse !is null) {
				if (orbitals.haveInEmpire(type))
					return;
				if (!budget.canSpend(BT_Development, type.buildCost, type.maintenance))
					return;
				array<StagingBase@> stagingBases = military.get_StagingBases();
				if (stagingBases.length == 0)
					return;
				StagingBase@ mainBase = stagingBases[0];
				if (mainBase is null)
					return;
				Region@ region = mainBase.region;
				// don't use primaryFactory because if it's a shipyard it can't build orbitals
				auto@ factory = construction.getClosestFactory(region);
				if (factory is null || factory.obj is null)
					return;
				vec3d position;
				vec2d offset = random2d(factory.obj.radius * 0.1, factory.obj.radius * 0.5);
				position.x = factory.obj.position.x + offset.x;
				position.y = factory.obj.position.y;
				position.z = factory.obj.position.z + offset.y;
				if (!type.canBuild(factory.obj, position))
					return;
				BuildOrbital@ buildPlan = construction.buildOrbital(type, position, force=false, moneyType=BT_Development);
				if (buildPlan !is null) {
					AllocateConstruction@ allocation = construction.buildNow(buildPlan, factory);
					if (allocation !is null) {
						//genericOrbitalBuilds.insertLast(GenericOrbitalBuild(allocation, region))
						if (log)
							ai.print("Making "+type.name+" at "+region.name);
					}
				}
			}
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
