import empire_ai.weasel.Planets;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Resources;
import empire_ai.dragon.expansion.development;
import empire_ai.dragon.expansion.buildings;
import empire_ai.dragon.expansion.constructions;
import empire_ai.dragon.expansion.ftl;

import buildings;
// cannot import constructions because the Construction class name clashes
from constructions import ConstructionType, getConstructionTypeCount, getConstructionType;
from ai.buildings import Buildings, BuildingAI, BuildingUse, BuildForPressureCap, AsFTLIncome, AsFTLStorage;
from ai.resources import AIResources, ResourceAI, MorphUnobtaniumTo;
from ai.constructions import ConstructionAI, AsCreatedPopulationIncome;

from abilities import getAbilityID;
from statuses import getStatusID;
from traits import getTraitID;

import empire_ai.dragon.logs;

class PlanetManagement: PlanetEventListener {
	Planets@ planets;
	Budget@ budget;
	DevelopmentFocuses@ focuses;
	FTLRequirements@ ftlRequirements;
	BuildingTracker@ builds;
	ConstructionsTracker@ projects;
	bool log;

	uint nativeLifeStatus = 0;
	const ConstructionType@ uplift_planet;
	const ConstructionType@ genocide_planet;
	bool no_uplift = false;
	double uplift_cost = 800;
	const ResourceClass@ scalableClass;

	uint planetCheckIndex = 0;

	array<PlanetAI@> goodNextFocuses;

	int unobtaniumAbility = -1;
	const ResourceType@ unobtanium;
	array<PlanetAI@> unobtaniumCandidatePlanets;

	int razing = -1;
	int razed = -1;

	void onConstructionRequestActioned(ConstructionRequest@ request) {}
	void onRemovedPlanetAI(PlanetAI@ plAI) {
		for (uint i = 0, cnt = goodNextFocuses.length; i < cnt; ++i) {
			if (goodNextFocuses[i] is plAI) {
				goodNextFocuses.removeAt(i);
				--i; --cnt;
			}
		}
		for (uint i = 0, cnt = unobtaniumCandidatePlanets.length; i < cnt; ++i) {
			if (unobtaniumCandidatePlanets[i] is plAI) {
				unobtaniumCandidatePlanets.removeAt(i);
				--i; --cnt;
			}
		}
	}

	PlanetManagement(Planets@ planets, Budget@ budget, DevelopmentFocuses@ focuses, BuildingTracker@ builds, ConstructionsTracker@ projects, FTLRequirements@ ftlRequirements, AI& ai, bool log) {
		@this.planets = planets;
		@this.budget = budget;
		@this.focuses = focuses;
		@this.builds = builds;
		@this.projects = projects;
		@this.ftlRequirements = ftlRequirements;
		this.log = log;

		// cache lookups
		nativeLifeStatus = getStatusID("NativeLife");
		@uplift_planet = getConstructionType("SharePlanet");
		@genocide_planet = getConstructionType("TakePlanet");
		// ancient empire has automatic, free, genocide effect, and cannot
		// uplift
		no_uplift = ai.empire.hasTrait(getTraitID("Ancient"));
		// mono empire has a cheaper uplift option
		if (ai.empire.hasTrait(getTraitID("Mechanoid"))) {
			@uplift_planet = getConstructionType("SharePlanetMono");
		}
		if (uplift_planet !is null) {
			uplift_cost = uplift_planet.buildCost;
		}
		@scalableClass = getResourceClass("Scalable");
		unobtaniumAbility = getAbilityID("UnobtaniumMorph");
		@unobtanium = getResource("Unobtanium");
		razing = getStatusID("ParasiteRaze");
		razed = getStatusID("ParasiteRazeDone");

		planets.listeners.insertLast(this);
	}

	/**
	 * Checks one of the planets we own, acting as necessary to fix problems
	 * or act on things we might want to do.
	 */
	void focusTick(AI& ai) {
		if (planets.planets.length == 0) {
			return;
		}

		planetCheckIndex = (planetCheckIndex+1) % planets.planets.length;
		PlanetAI@ plAI = planets.planets[planetCheckIndex];

		if (plAI.obj is null) {
			return;
		}

		manageUplift(plAI, ai);
		// TODO: Respond to primitive life statuses
		managePressureCapacity(plAI, ai);
		manageFTLBuildings(plAI, ai);
		considerUnobtaniumMorph(plAI, ai);
		// TODO: Long term this should all be generic hook based responses
		considerPopulationIncomeConstruction(plAI, ai);
		checkNextFocus(plAI, ai);
	}

	// TODO: Track the construction requests we make in a ConstructionTracker
	// so we can prompt other parts of the AI to do things when they complete
	// or fail.
	// Should also open a new colonise to makeup for lost resource
	// this would ideally be done by unsetting the import request the planet
	// was matched to but this info isn't tracked yet

	/**
	 * Deals with native life status on planets
	 */
	void manageUplift(PlanetAI@ plAI, AI& ai) {
		if (!plAI.obj.hasStatusEffect(nativeLifeStatus)) {
			return;
		}
		if ((!planets.isConstructing(plAI.obj, uplift_planet))
				&& (!planets.isConstructing(plAI.obj, genocide_planet))
				&& !no_uplift) {
			// check if we can afford to uplift this planet
			// Uplift costs 800k, 5 influence, 500 energy
			// 500 energy is pretty cheap to save up for so isn't
			// factored in here for evaluating
			if (ai.empire.Influence >= 8 && budget.canSpend(BT_Development, uplift_cost)) {
				if (log) {
					ai.print("found native life planet to uplift");
				}
				planets.requestConstruction(
					plAI, plAI.obj, uplift_planet, priority=1, expire=gameTime + 600, moneyType=BT_Development);
				// register as a focus and set target to 3
				DevelopmentFocus@ focus = focuses.addFocus(plAI);
				focus.targetLevel = max(3, focus.targetLevel);
			} else {
				if (log) {
					ai.print("can't afford uplift, taking over planet");
				}
				// this is high priority because until the NativeLife status is removed the
				// AI may think it can use this planet as an export and get very confused or
				// cripple its resource chains which would be very bad.
				planets.requestConstruction(
					plAI, plAI.obj, genocide_planet, priority=3, expire=gameTime + 600, moneyType=BT_Development);
			}
		}
	}

	void managePressureCapacity(PlanetAI@ plAI, AI& ai) {
		if (plAI.obj is null)
			return;

		if (plAI.obj.hasStatusEffect(razing) || plAI.obj.hasStatusEffect(razed))
			return;

		bool havePressure = ai.empire.HasPressure != 0.0;
		int cap = plAI.obj.pressureCap;
		if (!havePressure)
			cap = 10000;
		bool needsPressureCap = plAI.obj.totalPressure > cap + 7;

		if (!needsPressureCap)
			return;

		for (uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
			auto@ type = getBuildingType(i);
			if (type.ai.length == 0)
				continue;

			if (!type.canBuildOn(plAI.obj))
				continue;

			if (planets.isBuilding(plAI.obj, type)) {
				// don't try to make two of the same type on the same planet at once
				continue;
			}

			// Check we can actually afford this building
			if (!budget.canSpend(BT_Development, type.baseBuildCost * 2, type.baseMaintainCost)) {
				continue;
			}

			// check all the hooks on this building type
			for (uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
				auto@ hook = cast<BuildingAI>(type.ai[n]);
				if (hook is null) {
					continue;
				}
				auto@ pressureBuilding = cast<BuildForPressureCap>(hook);
				if (pressureBuilding !is null) {
					// TODO: Decide which pressure building to use
					if (log) {
						ai.print("building "+type.name+" to meet pressure cap");
					}
					auto@ req = planets.requestBuilding(plAI, type, priority=0.5, expire=ai.behavior.genericBuildExpire);
					if (req !is null) {
						auto@ tracker = BuildTracker(req);
						builds.trackBuilding(tracker);
					}
					return;
				}
			}
		}
	}

	void manageFTLBuildings(PlanetAI@ plAI, AI& ai) {
		if (plAI.obj is null)
			return;

		if (plAI.obj.level < 1)
			return;

		if (!ftlRequirements.requestsFTLStorage() && !ftlRequirements.requestsFTLIncome()) {
			return;
		}

		for (uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
			auto@ type = getBuildingType(i);
			if (type.ai.length == 0)
				continue;

			if (!type.canBuildOn(plAI.obj))
				continue;

			if (planets.isBuilding(plAI.obj, type)) {
				// don't try to make two of the same type on the same planet at once
				continue;
			}

			// Check we can actually afford this building
			if (!budget.canSpend(BT_Development, type.baseBuildCost * 2, type.baseMaintainCost)) {
				continue;
			}

			// check all the hooks on this building type
			for (uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
				auto@ hook = cast<BuildingAI>(type.ai[n]);
				if (hook is null) {
					continue;
				}
				bool shouldBuild = false;
				auto@ ftlStorage = cast<AsFTLStorage>(hook);
				if (ftlStorage !is null && ftlRequirements.requestsFTLStorage()) {
					// TODO: Should ideally pass the FTL Crystals affinity info to the AI
					shouldBuild = true;
				}
				auto@ ftlIncome = cast<AsFTLIncome>(hook);
				if (ftlIncome !is null && ftlRequirements.requestsFTLIncome()) {
					shouldBuild = true;
				}

				if (shouldBuild) {
					if (LOG)
						ai.print("building "+type.name+" to meet FTL request at", plAI.obj);
					auto@ req = planets.requestBuilding(plAI, type, priority=0.5, expire=ai.behavior.genericBuildExpire);
					if (req !is null) {
						auto@ tracker = BuildTracker(req);
						builds.trackBuilding(tracker);
					}
					return;
				}
			}
		}
	}

	double unobtaniumMorphWeight(const ResourceType@ resource) {
		if (resource is null)
			return -1.0;
		for (uint i = 0, cnt = resource.ai.length; i < cnt; ++i) {
			auto@ hook = cast<ResourceAI>(resource.ai[i]);
			if (hook is null)
				continue;
			auto@ unobtaniumCandidate = cast<MorphUnobtaniumTo>(hook);
			if (unobtaniumCandidate !is null) {
				return unobtaniumCandidate.weight.decimal;
			}
		}
		return 0.0;
	}

	void considerUnobtaniumMorph(PlanetAI@ plAI, AI& ai) {
		if (plAI.obj is null)
			return;
		if (plAI.resources is null)
			return;

		if (unobtaniumCandidatePlanets.find(plAI) != -1)
			return;

		// Check to see if this planet is a candidate for morphing unobtanium to
		const ResourceType@ resource = getResource(plAI.obj.primaryResourceType);
		if (unobtaniumMorphWeight(resource) > 0.0) {
			unobtaniumCandidatePlanets.insertLast(plAI);
		}

		// Check to see if this planet has unobtanium
		for (uint r = 0, rcnt = plAI.resources.length; r < rcnt; ++r) {
			if (plAI.resources[r].resource is null || plAI.resources[r].resource.id != unobtanium.id) {
				continue;
			}

			PlanetAI@ choice;
			// use roulette wheel selection so we can often choose the highest weight
			// but don't get stuck only choosing it
			double totalWeights = 0;
			for (uint i = 0, cnt = unobtaniumCandidatePlanets.length; i < cnt; ++i) {
				PlanetAI@ candidate = unobtaniumCandidatePlanets[i];
				double weight = unobtaniumMorphWeight(getResource(candidate.obj.primaryResourceType));
				if (candidate is null || candidate.obj is null || !candidate.obj.valid || candidate.obj.owner !is ai.empire || weight <= 0.0) {
					unobtaniumCandidatePlanets.removeAt(i);
					--i; --cnt;
					continue;
				}
				totalWeights += weight;
				if (randomd() < weight / totalWeights) {
					@choice = candidate;
				}
			}
			if (choice is null)
				return;

			const ResourceType@ res = getResource(choice.obj.primaryResourceType);
			if (res is null)
				return;
			if (LOG)
				ai.print("Morph planet to "+res.name+" from "+choice.obj.name, plAI.obj);
			plAI.obj.activateAbilityTypeFor(ai.empire, unobtaniumAbility, choice.obj);
			return;
		}
	}

	void considerPopulationIncomeConstruction(PlanetAI@ plAI, AI& ai) {
		if (plAI.obj is null)
			return;

		if (plAI.obj.hasStatusEffect(razing) || plAI.obj.hasStatusEffect(razed))
			return;

		for (uint i = 0, cnt = getConstructionTypeCount(); i < cnt; ++i) {
			const ConstructionType@ type = getConstructionType(i);
			if (type.ai.length == 0) {
				continue;
			}
			if (!type.canBuild(plAI.obj, ignoreCost=true)) {
				continue;
			}

			// don't try to make two of the same thing on the same planet at once
			if (planets.isConstructing(plAI.obj, type)) {
				continue;
			}
			// Check we can actually afford this
			if (!budget.canSpend(BT_Development, type.buildCost * 2, type.maintainCost)) {
				continue;
			}

			for (uint j = 0, jcnt = type.ai.length; j < jcnt; ++j) {
				auto@ hook = cast<ConstructionAI>(type.ai[j]);
				if (hook is null) {
					continue;
				}
				auto@ populationIncome = cast<AsCreatedPopulationIncome>(hook);
				if (populationIncome !is null) {
					// check we're already level 1 as a heuristic for if adding
					// max pop will actually increase our income (since it
					// doesn't if a planet is net negative due to level)
					if (plAI.obj.level < 1) {
						continue;
					}

					if (LOG)
						ai.print("constructing project "+type.name+" to improve income at", plAI.obj);
					auto@ req = planets.requestConstruction(plAI, plAI.obj, type, priority=0.5, expire=ai.behavior.genericBuildExpire);
					if (req !is null) {
						auto@ tracker = ConstructionTracker(req);
						projects.trackConstruction(tracker);
					}
					return;
				}
			}
		}
	}

	void checkNextFocus(PlanetAI@ plAI, AI& ai) {
		if (focuses.isFocus(plAI.obj)) {
			// we're tracking good next focuses, if a planet is already a
			// focus we stop tracking it
			goodNextFocuses.remove(plAI);
			return;
		}
		if (goodNextFocuses.find(plAI) != -1) {
			return;
		}

		if (isGoodFocus(plAI.obj, ai)) {
			goodNextFocuses.insertLast(plAI);
		}
	}

	/**
	 * Planets we've found that we already own and might want to promote
	 * to focuses
	 */
	array<PlanetAI@> getGoodNextFocuses(AI& ai) {
		// Cull the list to ensure we only return valid focuses
		for (uint i = 0, cnt = goodNextFocuses.length; i < cnt; ++i) {
			if (goodNextFocuses[i] is null || goodNextFocuses[i].obj is null || !goodNextFocuses[i].obj.valid || goodNextFocuses[i].obj.owner !is ai.empire) {
				goodNextFocuses.removeAt(i);
				--i; --cnt;
			}
		}
		return goodNextFocuses;
	}

	void save(SaveFile& file) {
		file << planetCheckIndex;
		uint cnt = goodNextFocuses.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			planets.saveAI(file, goodNextFocuses[i]);
		}
		cnt = unobtaniumCandidatePlanets.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			planets.saveAI(file, unobtaniumCandidatePlanets[i]);
		}
	}

	void load(SaveFile& file) {
		file >> planetCheckIndex;
		uint cnt = 0;
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			PlanetAI plAI =  planets.loadAI(file);
			if (plAI !is null) {
				goodNextFocuses.insertLast(plAI);
			}
		}
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			PlanetAI plAI = planets.loadAI(file);
			if (plAI !is null) {
				unobtaniumCandidatePlanets.insertLast(plAI);
			}
		}
	}
}
