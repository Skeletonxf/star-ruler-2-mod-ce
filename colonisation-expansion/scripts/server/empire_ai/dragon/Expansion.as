import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Development;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Creeping;
import empire_ai.weasel.Construction;

import planet_levels;
import buildings;
import systems;

import ai.consider;
from ai.buildings import Buildings, BuildingAI, BuildingUse, AsCreatedResource, EnergyMaintenance;
from ai.resources import AIResources, ResourceAI, DistributeToImportantPlanet, DistributeToHighPopulationPlanet, DistributeToLaborUsing, DistributeAsLocalPressureBoost;
from ai.constructions import ConstructionAI, AsConstructedResource, ShortTermIncomeLoss;

// It is very important we don't just import the entire resources definition
// because it defines a Resource class which conflicts with the Resources
// class for the AI Resources component
from resources import ResourceType;
import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;
from empire_ai.dragon.expansion.resource_value import RaceResourceValuation, ResourceValuationOwner, DefaultRaceResourceValuation, ResourceValuator, PlanetValuables;
import empire_ai.dragon.expansion.expand_logic;
import empire_ai.dragon.expansion.terrestrial_colonization;
import empire_ai.dragon.expansion.planet_management;
import empire_ai.dragon.expansion.region_linking;
import empire_ai.dragon.expansion.development;
import empire_ai.dragon.expansion.buildings;
import empire_ai.dragon.expansion.constructions;
import empire_ai.dragon.expansion.ftl;
import empire_ai.dragon.expansion.potentials;
import empire_ai.dragon.logs;

from statuses import getStatusID;
from traits import getTraitID;

// Data class for what actions development and colonization can take, ie
// if we can do certain things or not due to our race.
class Actions {
	// Do we need to manage pressure on our planets
	bool managePressure = true;
	// Can we colonize or do we need the race component to handle this for us
	bool performColonization = true;
	// Can we manually pick targets to colonize
	bool queueColonization = true;
}

class Limits {
	//Maximum colonizations that can still be done this turn
	uint remainingColonizations = 0;
	//Amount of colonizations that have happened so far this budget cycle
	uint currentColonizations = 0;
	//Amount of colonizations that happened the previous budget cycle
	uint previousColonizations = 0;

	void save(SaveFile& file) {
		file << remainingColonizations;
		file << currentColonizations;
		file << previousColonizations;
	}

	void load(SaveFile& file) {
		file >> remainingColonizations;
		file >> currentColonizations;
		file >> previousColonizations;
	}
}

/**
 * Subclass of DevelopmentFocus, with save/load methods for use here
 */
class DevelopmentFocus2 : DevelopmentFocus {
	/* Object@ obj;
	PlanetAI@ plAI;
	int targetLevel = 0;
	int requestedLevel = 0;
	int maximumLevel = INT_MAX;
	array<ExportData@> managedPressure;
	double weight = 1.0; */

	void tick(AI& ai, Expansion& dev, double time) {
		if(targetLevel != requestedLevel) {
			if(targetLevel > requestedLevel) {
				int nextLevel = min(targetLevel, min(obj.resourceLevel, requestedLevel)+1);
				if(nextLevel != requestedLevel) {
					for(int i = requestedLevel+1; i <= nextLevel; ++i)
						dev.resources.organizeImports(obj, i);
					requestedLevel = nextLevel;
				}
			}
			else {
				dev.resources.organizeImports(obj, targetLevel);
				requestedLevel = targetLevel;
			}
		}

		//Remove managed pressure resources that are no longer valid
		for(uint i = 0, cnt = managedPressure.length; i < cnt; ++i) {
			ExportData@ res = managedPressure[i];
			if(res.request !is null || res.obj is null || !res.obj.valid || res.obj.owner !is ai.empire || !res.usable || res.developUse !is obj) {
				if(res.developUse is obj)
					@res.developUse = null;
				managedPressure.removeAt(i);
				--i; --cnt;
			}
		}

		//Make sure we're not exporting our resource
		if(plAI !is null && plAI.resources !is null && plAI.resources.length != 0) {
			auto@ res = plAI.resources[0];
			res.localOnly = true;
			if(res.request !is null && res.request.obj !is res.obj)
				dev.resources.breakImport(res);
		}

		//TODO: We should be able to bump managed pressure resources back to Development for
		//redistribution if we run out of pressure capacity.
	}

	void save(Expansion& development, SaveFile& file) {
		file << obj;
		development.planets.saveAI(file, plAI);
		file << targetLevel;
		file << requestedLevel;
		file << maximumLevel;
		file << weight;

		uint cnt = managedPressure.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			development.resources.saveExport(file, managedPressure[i]);
	}

	void load(Expansion& development, SaveFile& file) {
		file >> obj;
		@plAI = development.planets.loadAI(file);
		file >> targetLevel;
		file >> requestedLevel;
		file >> maximumLevel;
		file >> weight;

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = development.resources.loadExport(file);
			managedPressure.insertLast(data);
		}
	}

	// Rough heuristic for how far we want to level something
	int maximumDesireableLevel(Expansion& expansion) {
		const ResourceType@ resource = getResource(obj.primaryResourceType);
		if (resource is null) {
			return min(3, maximumLevel);
		}
		if (resource.cls is expansion.scalableClass) {
			return maximumLevel;
		}
		if (resource.limitlessLevel) {
			// Pretty much anything which is not scalable, but still limitlessLevel
			// is likely to have some reason the AI wants to develop it as this
			// is mainly Ringworlds, and Unobtanium
			return max(3, maximumLevel);
		}
		return min(3, maximumLevel);
	}

	void takeManagedPressureResource(ExportData@ res, AI& ai, Expansion& expansion) {
		if (res.obj !is obj) {
			res.obj.exportResourceByID(res.resourceId, obj);
		} else {
			res.obj.exportResourceByID(res.resourceId, null);
		}
		@res.developUse = obj;

		// Assign to us
		managedPressure.insertLast(res);

		if (false)
			ai.print("Take "+res.resource.name+" from "+res.obj.name+" for pressure", obj);
	}

	// TODO: Use to yield pressure back to development if we go over pressure cap
	void yieldManagedPressureResource(ExportData@ res, AI& ai, Expansion& expansion) {
		@res.developUse = null;

		// Assign to development
		expansion.managedPressure.insertLast(res);

		if (false)
			ai.print("Yield "+res.resource.name+" from "+res.obj.name+" for pressure", obj);
	}
}

// This was originally intended as a tree of a particular planet we want to
// colonise, and nodes for the other planets that we would then be colonising
// to get this one up to its resource level (so if colonising this failed we
// could cancel or reassign the children). The AI seems to colonise just fine
// waiting for itself to claim a planet and then ordering colonisations for the
// dependencies, so this will probably stay as a single node 'tree' for now.
class ColonizeTree {
	Planet@ target;
	// Nullable import data that might be associated with our node
	ImportData@ request;

	ColonizeTree(Planet@ target) {
		@this.target = target;
	}

	ColonizeTree(Planet@ target, ImportData@ request) {
		@this.target = target;
		@this.request = request;
	}

	void save(Expansion& expansion, SaveFile& file) {
		file << target;
		if (request !is null) {
			file.write1();
			expansion.resources.saveImport(file, request);
		} else {
			file.write0();
		}
	}

	// only for deserialisation
	ColonizeTree() {}

	void load(Expansion& expansion, SaveFile& file) {
		Planet@ target;
		file >> target;
		@this.target = target;
		if (file.readBit()) {
			@this.request = expansion.resources.loadImport(file);
		}
	}
}

// A collection of ColonizeTrees, forming a queue of resources we are planning
// to colonise in the short term, but haven't actually started to colonise yet.
class ColonizeForest {
	array<ColonizeTree@> queue;
	double nextCheckForPotentialColonizeTargets = 0;

	ResourceValuator@ resourceValuator;
	const ConstructionType@ build_moon_base;

	double lastOutpostExpandCheck = 0;

	const ResourceType@ light;

	ColonizeForest(RaceResourceValuation@ race) {
		@resourceValuator = ResourceValuator(race);
		@build_moon_base = getConstructionType("MoonBase");
		@light = getResource("Starlight");
	}

	void save(Expansion& expansion, SaveFile& file) {
		uint cnt = queue.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			queue[i].save(expansion, file);
		file << nextCheckForPotentialColonizeTargets;
		file << lastOutpostExpandCheck;
	}

	void load(Expansion& expansion, SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		queue.length = cnt;
		for (uint i = 0; i < cnt; ++i) {
			ColonizeTree@ tree = ColonizeTree();
			tree.load(expansion, file);
			@queue[i] = tree;
		}
		file >> nextCheckForPotentialColonizeTargets;
		file >> lastOutpostExpandCheck;
	}

	void tick(Expansion& expansion, AI& ai) {
		if (nextCheckForPotentialColonizeTargets > gameTime) {
			checkBorderSystems(expansion, ai);
		}

		if (expansion.potentialColonizations.length == 0 && gameTime < 60.0) {
			nextCheckForPotentialColonizeTargets = gameTime + 1.0;
		} else {
			nextCheckForPotentialColonizeTargets = gameTime + randomd(10.0, 40.0);
		}
	}

	// Updates the expansion potentials list, including potentials for
	// all nearby planets we might want to colonise that we haven't already
	// queued.
	//
	// Can also tell the Exapansion component to build an outpost to advance
	// through a system that we're never going to colonise.
	void checkBorderSystems(Expansion& expansion, AI& ai) {
		// reset list of potential colonise targets
		expansion.potentialColonizations.reset();

		// check systems inside border
		for (uint i = 0, cnt = expansion.systems.owned.length; i < cnt; ++i) {
			checkSystem(expansion.systems.owned[i], expansion, ai);
		}
		// check systems 1 hop away
		for (uint i = 0, cnt = expansion.systems.outsideBorder.length; i < cnt; ++i) {
			SystemAI@ sys = expansion.systems.outsideBorder[i];
			uint valuablePlanets = checkSystem(sys, expansion, ai);
			if (valuablePlanets == 0 && gameTime > lastOutpostExpandCheck + 90) {
				// we should consider making an outpost to claim this, we're not
				// going to be colonising any planets in it any time soon
				if (false) {
					ai.print("Found no available valuable planets in "+sys.obj.name);
				}
				expansion.regionLinking.considerMakingLinkAt(sys.obj, ai.empire);
				lastOutpostExpandCheck = gameTime;
			}
		}

		// check home system or all systems we can see if no owned systems
		if (expansion.systems.owned.length == 0) {
			// FIXME: We should just check all systems around our units, since
			// only star children can come back from the dead at this stage
			Region@ homeSys = ai.empire.HomeSystem;
			if (homeSys !is null) {
				auto@ homeAI = expansion.systems.getAI(homeSys);
				if (homeAI !is null) {
					checkSystem(homeAI, expansion, ai);
				}
			} else {
				for (uint i = 0, cnt = expansion.systems.all.length; i < cnt; ++i) {
					if (expansion.systems.all[i].visible) {
						checkSystem(expansion.systems.all[i], expansion, ai);
					}
				}
			}
		}

		// TODO: Check planets we found in deep space
	}

	uint checkSystem(SystemAI@ sys, Expansion& expansion, AI& ai) {
		// seenPresent is a cache of the PlanetsMask of this system
		uint presentMask = sys.seenPresent;
		bool isOwned = presentMask & ai.mask != 0;
		bool safeToColonize = expansion.colonyManagement.canSafelyColonize(sys);
		// if we abort, return 1 because we don't want to bridge our way
		// through this
		if(!safeToColonize) {
			return 1;
		}

		if (ai.empire.ForbidStellarColonization > 0 && regionHasStars(sys.obj)) {
			// we can't colonise this yet, so don't add the planets to our
			// potentials because we don't want to try and fail to colonise and
			// then penalty set them
			return 1;
		}

		// Add weighting to planets in systems we don't have any planets in,
		// as they will expand our borders
		double sysWeight = 1.0;
		if (!isOwned)
			sysWeight *= ai.behavior.weightOutwardExpand;

		// track how many planets in this system are already owned by us,
		// or we would like to colonise them
		uint valuablePlanets = 0;

		uint plCnt = sys.planets.length;

		if (plCnt == 0 && !sys.explored) {
			// there's probably something here, we just don't know it yet
			return 1;
		}

		for (uint n = 0; n < plCnt; ++n) {
			Planet@ pl = sys.planets[n];
			Empire@ visOwner = pl.visibleOwnerToEmp(ai.empire);
			if(!pl.valid || visOwner.valid) {
				if (visOwner is ai.empire) {
					valuablePlanets += 1;
				}
				continue;
			}
			if (expansion.isColonizing(pl)) {
				valuablePlanets += 1;
				continue;
			}
			if(expansion.penaltySet.contains(pl.id)) // probably a remnant in the way
				continue;
			if(pl.quarantined)
				continue;

			/* int resId = pl.primaryResourceType;
			if(resId == -1)
				continue; */

			PotentialColonizeSource@ p = PotentialColonizeSource(pl, resourceValuator);
			if (p.weight >= 1) {
				valuablePlanets += 1;
			}
			p.weight *= sysWeight;
			//TODO: this should be weighted according to the position of the planet,
			//we should try to colonize things in favorable positions
			expansion.potentialColonizations.add(p);
		}

		return valuablePlanets;
	}

	// Checks if a planet is in the queue
	bool isQueuedForColonizing(Planet& pl) {
		for(uint i = 0, cnt = queue.length; i < cnt; ++i) {
			if(queue[i].target is pl)
				return true;
		}
		return false;
	}

	// Checks if any planet in a region is in the queue
	bool isQueuedForColonizing(Region& region) {
		for(uint i = 0, cnt = queue.length; i < cnt; ++i) {
			if(queue[i].target !is null && queue[i].target.region is region)
				return true;
		}
		return false;
	}

	void fillQueueFromRequests(Expansion& expansion, AI& ai) {
		// look through the requests made to the Resources component
		// and try to colonise to fill them
		// this loop can manipulate the list it loops through, so do NOT cache
		// the length of the list
		for(uint i = 0; i < expansion.resources.requested.length; ++i) {
			ImportData@ req = expansion.resources.requested[i];
			if(!req.isOpen)
				continue;
			if(!req.cycled)
				continue;
			if(req.claimedFor)
				continue;
			if(req.isColonizing)
				continue;
			if(req.buildingFor)
				continue;

			queueColonizeForRequest(req, expansion, ai);
		}
	}

	/**
	 * Tries to construct a project on the planet requesting an import to meet the request.
	 * Returns true if it found and queued a construction that meets the request.
	 */
	bool queueConstructionForRequest(ImportData@ request, Expansion& expansion, AI& ai) {
		// If we're looking for any resources that we could find in the universe don't
		// resort to projects if we haven't even scouted the systems on our border yet.
		if (!expansion.hasScoutedBorders()) {
			//bool canMeetArtificialOnly = request.spec.meets(light, fromObj=request.obj, toObj=request.obj);
			//if (!canMeetArtificialOnly) {
			return false;
			//}
		}

		// Get the PlanetAI for the object making this request
		Planet@ planet = cast<Planet>(request.obj);
		if (planet is null)
			return false;

		PlanetAI@ plAI = expansion.planets.getAI(planet);

		if (plAI is null || plAI.obj is null)
			return false;

		for (uint i = 0, cnt = getConstructionTypeCount(); i < cnt; ++i) {
			auto@ type = getConstructionType(i);
			if (type.ai.length == 0)
				continue;

			if (!type.canBuild(plAI.obj))
				continue;

			if (expansion.planets.isConstructing(plAI.obj, type)) {
				// don't try to make two of the same type on the same planet at once
				continue;
			}

			// check all the hooks on this construction type
			for (uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
				auto@ hook = cast<ConstructionAI>(type.ai[n]);
				if (hook is null) {
					continue;
				}
				// Not sure if we want to let the AI spend aggressively for constructions to meet
				// import requests or not. Don't want the AI having just enough budget but
				// not doing a project because it doesn't have the development budget especially
				// if that project is a bottleneck for level chaining that would increase income
				// overall.
				/* if (!expansion.budget.canSpend(BT_Development, type.buildCost, type.maintainCost)) {
					continue;
				} */
				auto@ incomeLoss = cast<ShortTermIncomeLoss>(hook);
				if (incomeLoss !is null) {
					// check our net budget first
					if (!expansion.budget.canSpend(BT_Development, incomeLoss.spare_budget.decimal, incomeLoss.spare_budget.decimal)) {
						continue;
					}
				}
				auto@ resourceConstruction = cast<AsConstructedResource>(hook);
				if (resourceConstruction !is null) {
					if (request.spec.meets(getResource(resourceConstruction.resource.integer), fromObj=request.obj, toObj=request.obj)) {
						auto@ req = expansion.planets.requestConstruction(plAI, plAI.obj, type, priority=2, expire=ai.behavior.genericBuildExpire);
						if (req !is null) {
							// got match, close request
							if (LOG)
								ai.print("constructing project "+type.name+" to meet requested resource: "+request.spec.dump(), plAI.obj);
							// for ease and not making requests even more complicated, use buildingFor with constructions
							// as well as buildings
							request.buildingFor = true;
							auto@ tracker = ConstructionTracker(req);
							@tracker.importRequestReason = request;
							expansion.trackConstruction(tracker);
						}
						// all done here, met the resource
						return true;
					}
				}
			}
		}

		return false;
	}

	/**
	 * Tries to build on the planet requesting an import to meet the request.
	 * Returns true if it found and queued a building that meets the request.
	 */
	bool queueBuildingForRequest(ImportData@ request, Expansion& expansion, AI& ai) {
		// If we're looking for any resources that we could find in the universe don't
		// resort to buildings if we haven't even scouted the systems on our border yet.
		if (!expansion.hasScoutedBorders()) {
			bool canMeetArtificialOnly = request.spec.meets(light, fromObj=request.obj, toObj=request.obj);
			if (!canMeetArtificialOnly) {
				return false;
			}
		}
		// Get the PlanetAI for the object making this request
		Planet@ planet = cast<Planet>(request.obj);
		if (planet is null)
			return false;
		PlanetAI@ plAI = expansion.planets.getAI(planet);

		if (plAI is null || plAI.obj is null)
			return false;

		/* bool alreadyConstructingMoonBase = expansion.planets.isConstructing(plAI.obj, build_moon_base);
		if (alreadyConstructingMoonBase || plAI.failedToPlaceBuilding) {
			// we're working on it, no point trying again
			return;
		} */

		// try checking the next building type out of the list on
		// this tick to see if we can meet the request with a building
		for (uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
			auto@ type = getBuildingType(i);
			if (type.ai.length == 0)
				continue;

			if (!type.canBuildOn(plAI.obj))
				continue;

			// FIXME: This only checks if we have queued a desire to make a building
			// This will return false while the building is actually being built
			if (expansion.planets.isBuilding(plAI.obj, type)) {
				// don't try to make two of the same type on the same planet at once
				continue;
			}

			// check all the hooks on this building type
			for (uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
				auto@ hook = cast<BuildingAI>(type.ai[n]);
				if (hook is null) {
					continue;
				}
				auto@ energyMaint = cast<EnergyMaintenance>(hook);
				if (energyMaint !is null) {
					double energyCost = energyMaint.energy_maintenance.decimal;
					//int minLevel = energyMaint.min_level.integer;
					// this building costs energy, we should check we can afford
					// it before construction
					// TODO: Abandon stuff we can't afford
					double weight = resourceValuator.devalueEnergyCosts(energyCost, 1.0);
					if (weight <= 0.0) {
						// try for a different building to meet this request
						continue;
					}
				}

				auto@ resourceBuilding = cast<AsCreatedResource>(hook);
				if (resourceBuilding !is null) {
					// our hook is an AsCreatedResource, check if this resource
					// is what we need to meet the spec (this completely bypasses
					// most of the logic to how these hooks work in vanilla, but will
					// also stop the AI waiting for chunks of time when a building is
					// the only way to meet a resource, so this is intended hackery)
					if (request.spec.meets(getResource(resourceBuilding.resource.integer), fromObj=request.obj, toObj=request.obj)) {
						auto@ req = expansion.planets.requestBuilding(plAI, type, priority=2, expire=ai.behavior.genericBuildExpire);
						if (req !is null) {
							// got match, close request
							if (LOG)
								ai.print("building "+type.name+" to meet requested resource: "+request.spec.dump(), plAI.obj);
							request.buildingFor = true;
							auto@ tracker = BuildTracker(req);
							@tracker.importRequestReason = request;
							expansion.trackBuilding(tracker);
						}
						// all done here, met the resource
						return true;
					}
				}
			}
		}
		if (false && LOG && request.spec.isForImport) {
			ai.print("failed to find target for requested resource: "+request.spec.dump(), request.obj);
		}
		return false;
	}

	/**
	 * Enqueues actions to meet resource specs. Primarily colonising planets,
	 * but also tries to meet requests that can't be met by any known planets
	 * via buildings. This assumes planets are always cheaper than buildings.
	 *
	 * It also has the benefit of taking full advantage of the fact that we
	 * can know if we can colonise for a resource, so we can immediately request
	 * a building when we can't colonise for it, rather than the vanilla method
	 * where Development would rely on having waited for a resource for a while
	 * before building to meet it, hoping that the Colonisation component would
	 * have sorted out the problem first (and thus waiting unnecessarily when
	 * there was never going to be a way to provide the resource via
	 * colonisiation).
	 */
	void queueColonizeForRequest(ImportData@ request, Expansion& expansion, AI& ai) {
		if (false) {
			ai.print("colonize for requested resource: "+request.spec.dump(), request.obj);
		}
		ResourceSpec@ spec = request.spec;

		// try constructions first since they typically cost nothing in upkeep
		if (queueConstructionForRequest(request, expansion, ai)) {
			return;
		}

		Planet@ newColony;
		double bestWeight = 0.0;

		// evaluate each potential source against the spec to pick one to colonise
		for (uint i = 0, cnt = expansion.potentialColonizations.length; i < cnt; ++i) {
			PotentialColonizeSource@ p = expansion.potentialColonizations.get(i);
			// can't use as a source if it doesn't meet the spec
			if (!p.canMeet(request.spec)) {
				continue;
			}
			Region@ region = p.pl.region;
			if (region is null) {
				// TODO: Will need to handle this eventually
				continue;
			}
			if (expansion.isColonizing(p.pl)) {
				continue;
			}
			// TODO: Work out how to check the planet isn't being colonised
			// without cheating vision
			/* if (p.pl.isBeingColonized) {
				continue;
			} */
			// TODO: Check this planet is actually still unowned

			auto@ sys = expansion.systems.getAI(region);
			bool regionIsOccupiedByOthers = sys.obj.PlanetsMask & ~ai.mask != 0;

			double weight = p.weight;
			if (regionIsOccupiedByOthers) {
				weight *= 0.25;
			}

			// TODO: Weight slightly by proximity to our colonise sources,
			// ie, if we can colonise one of two food planets we probably
			// want to favor the one that will colonise faster
			// This might not be needed as we will colonize from the faster
			// location when looking to meet this colonize request

			if (weight > bestWeight) {
				@newColony = p.pl;
				bestWeight = weight;
			}
		}

		if (newColony !is null) {
			if (LOG)
				ai.print("found colonize target for requested resource: "+request.spec.dump(), newColony);
			queue.insertLast(ColonizeTree(newColony, request));
			request.isColonizing = true;
		} else {
			queueBuildingForRequest(request, expansion, ai);
		}
	}

	/**
	 * Colonizes for a resource spec
	 *
	 * The assumption is that if we're colonising for a resource we need a planet,
	 * so does not try to meet the spec via any other means.
	 */
	ColonizeTree@ queueColonizeForResourceSpec(ResourceSpec@ spec, Expansion& expansion, AI& ai) {
		if (false) {
			ai.print("colonize for resource spec: "+spec.dump());
		}

		Planet@ newColony;
		double bestWeight = 0.0;

		// evaluate each potential source against the spec to pick one to colonise
		for (uint i = 0, cnt = expansion.potentialColonizations.length; i < cnt; ++i) {
			PotentialColonizeSource@ p = expansion.potentialColonizations.get(i);
			// can't use as a source if it doesn't meet the spec
			if (!p.canMeet(spec)) {
				continue;
			}
			Region@ region = p.pl.region;
			if (region is null) {
				// TODO: Will need to handle this eventually
				continue;
			}
			if (expansion.isColonizing(p.pl)) {
				continue;
			}
			// TODO: Work out how to check the planet isn't being colonised
			// without cheating vision
			/* if (p.pl.isBeingColonized) {
				continue;
			} */
			// TODO: Check this planet is actually still unowned

			auto@ sys = expansion.systems.getAI(region);
			bool regionIsOccupiedByOthers = sys.obj.PlanetsMask & ~ai.mask != 0;

			double weight = p.weight;
			if (regionIsOccupiedByOthers) {
				weight *= 0.25;
			}

			if (weight > bestWeight) {
				@newColony = p.pl;
				bestWeight = weight;
			}
		}

		if (newColony !is null) {
			if (LOG)
				ai.print("found colonize target for spec: "+spec.dump(), newColony);
			ColonizeTree@ node = ColonizeTree(newColony);
			queue.insertLast(node);
			return node;
		}
		return null;
	}

	/**
	 * Colonizes to occupy a region, to allow for a trade link to be established
	 *
	 * Will always return null and not queue a colonize if the region already has
	 * planets owned by the empire.
	 */
	ColonizeTree@ queueColonizeForOccupyRegion(Region@ region, Expansion& expansion, AI& ai) {
		if (region is null) {
			return null;
		}

		SystemAI@ sys = expansion.systems.getAI(region);
		if (sys is null) {
			return null;
		}
		if (!sys.explored) {
			return null;
		}
		uint presentMask = sys.seenPresent;
		bool isOwned = presentMask & ai.mask != 0;
		bool safeToColonize = expansion.colonyManagement.canSafelyColonize(sys);
		if (isOwned || !safeToColonize) {
			return null;
		}

		array<PotentialColonizeSource@> potentialColonies;
		uint plCnt = sys.planets.length;
		for (uint n = 0; n < plCnt; ++n) {
			Planet@ pl = sys.planets[n];
			Empire@ visOwner = pl.visibleOwnerToEmp(ai.empire);
			if(!pl.valid || visOwner.valid) {
				if (visOwner is ai.empire) {
					return null;
				}
				continue;
			}
			if (expansion.isColonizing(pl)) {
				continue;
			}
			if(expansion.penaltySet.contains(pl.id)) // probably a remnant in the way
				continue;
			if(pl.quarantined)
				continue;

			PotentialColonizeSource@ p = PotentialColonizeSource(pl, resourceValuator);
			potentialColonies.insertLast(p);
		}

		Planet@ newColony;
		// for occupying a region, we are willing to colonise a planet that is
		// otherwise worthless, but we still have a limit to how negative the
		// weight may be.
		double bestWeight = -1.0;

		for (uint i = 0, cnt = potentialColonies.length; i < cnt; ++i) {
			PotentialColonizeSource@ p = potentialColonies[i];
			if (p.weight > bestWeight) {
				@newColony = p.pl;
				bestWeight = p.weight;
			}
		}

		if (newColony !is null) {
			if (LOG)
				ai.print("found colonize target for region: "+region.name, newColony);
			ColonizeTree@ node = ColonizeTree(newColony);
			queue.insertLast(node);
			return node;
		}
		return null;
	}

	/**
	 * Pops the oldest planet off the queue
	 */
	ColonizeTree@ pop() {
		if (queue.length == 0) {
			return null;
		}
		ColonizeTree@ node = queue[0];
		queue.removeAt(0);
		return node;
	}
}

/**
 * A combined and rewritten AIComponent which is responsible for colonization
 * and development, and as such will hopefully do the two together in a way
 * which doesn't sit on unused resources or colonise resources not needed for
 * levelling.
 */
class Expansion : AIComponent, Buildings, ConsiderFilter, AIResources, IDevelopment, IColonization, ColonizeBudgeting, ColonizationAbilityOwner, DevelopmentFocuses, ResourceValuationOwner, BuildingTracker, ConstructionsTracker, FTLRequirements {
	Resources@ resources;
	Planets@ planets;
	Systems@ systems;
	Budget@ budget;
	Creeping@ creeping;
	Construction@ construction;

	array<DevelopmentFocus@> focuses;

	// Building hook state
	array<BuildTracker@> genericBuilds;
	const BuildingType@ filterType;
	array<ConstructionTracker@> genericConstructions;

	Actions actions;
	FTLResourceIncomes ftlIncomeTargets;
	Limits limits;

	// Colonization state
	int nextColonizeId = 0;

	// Things we might want to colonize to expand (ie, within 1 hop to the border)
	// Used by the Ancient component, at least for now.
	// Long term would like to make this flexible enough to play Ancient well
	PotentialColonizationsSummary@ potentialColonizations;

	// Things in the queue for colonizing
	ColonizeForest@ queue;
	// Things we need a colonize source to colonize with
	array<ColonizeData@> awaitingSource;
	// Things we are colonizing, includes things that are also in awaitingSource
	array<ColonizeData@> colonizing;

	array<ColonizeData@> loadIds;

	// list of penalties that will stop us colonising planets we recently
	// failed at colonising
	array<AvoidColonizeMarker@> penalties;
	// a set of the ids in penalties
	set_int penaltySet;

	ExpandType expandType;

	ColonizationAbility@ colonyManagement;
	PlanetManagement@ planetManagement;

	RegionLinking@ regionLinking;

	const ResourceClass@ scalableClass;

	bool bordersScouted = false;

	double lastLevelChainCheck = 0;
	double lastPressureCheck = 0;

	// Pressure resources that aren't for levelling that we haven't assigned
	// to a focus yet
	array<ExportData@> managedPressure;
	uint pressureIndex = 0;

	// A secondary 'queue' of resource specs we will persistently try to
	// colonise for. This is not targeted at level chaining, or colonising, but
	// instead for ad hoc 'please colonise this type of planet' requests that
	// other AI components may make.
	array<ResourceSpec@> extraRequests;

	// A very special queue of resource specs we will always attempt to meet,
	// no matter how many times we have met already. Use with extreme caution,
	// this is intended for high value high scarcity resources like FTL Crystals.
	array<ResourceSpec@> colonizeOnSight;

	void create() {
		@resources = cast<Resources>(ai.resources);
		@planets = cast<Planets>(ai.planets);
		@systems = cast<Systems>(ai.systems);
		@budget = cast<Budget>(ai.budget);
		@creeping = cast<Creeping>(ai.creeping);
		@construction = cast<Construction>(ai.construction);
		@ftlIncomeTargets.ftl = cast<FTLGeneric>(ai.ftl);

		@queue = ColonizeForest(DefaultRaceResourceValuation(ai));
		RaceColonization@ race;
		@race = cast<RaceColonization>(ai.race);
		@colonyManagement = TerrestrialColonization(planets, ai);
		@planetManagement = PlanetManagement(planets, budget, this, this, this, this, ai, log);
		@regionLinking = RegionLinking(planets, construction, resources, systems, budget, this);

		@scalableClass = getResourceClass("Scalable");

		@potentialColonizations = PotentialColonizationsSummary(ai);
	}

	void save(SaveFile& file) {
		file << nextColonizeId;
		limits.save(file);

		uint cnt = colonizing.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			saveColonize(file, colonizing[i]);
			cast<ColonizeData2>(colonizing[i]).save(resources, colonyManagement, file);
		}

		potentialColonizations.save(file);

		queue.save(this, file);

		cnt = penalties.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			penalties[i].save(file);

		cnt = focuses.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ focus = focuses[i];
			cast<DevelopmentFocus2>(focus).save(this, file);
		}

		file << uint(expandType);

		colonyManagement.saveManager(file);

		cnt = genericBuilds.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			genericBuilds[i].save(planets, resources, file);

		cnt = genericConstructions.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			genericConstructions[i].save(planets, resources, file);

		planetManagement.save(file);
		regionLinking.save(file);

		file << bordersScouted;
		file << lastLevelChainCheck;
		file << lastPressureCheck;

		cnt = managedPressure.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			resources.saveExport(file, managedPressure[i]);
		file << pressureIndex;

		ftlIncomeTargets.save(file);

		cnt = extraRequests.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			extraRequests[i].save(file);
		}

		cnt = colonizeOnSight.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			colonizeOnSight[i].save(file);
		}
	}

	void load(SaveFile& file) {
		file >> nextColonizeId;
		limits.load(file);

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = loadColonize(file);
			if(data !is null) {
				cast<ColonizeData2>(data).load(resources, colonyManagement, file);
				if (data.target !is null) {
					colonizing.insertLast(data);
					if (cast<ColonizeData2>(data).colonizeUnit is null)
						awaitingSource.insertLast(data);
				}
				else {
					data.canceled = true;
				}
			}
			else {
				ColonizeData2().load(resources, colonyManagement, file);
			}
		}

		potentialColonizations.load(file);

		queue.load(this, file);

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			AvoidColonizeMarker@ penalty = AvoidColonizeMarker();
			penalty.load(file);
			if(penalty.planet !is null) {
				penalties.insertLast(penalty);
				penaltySet.insert(penalty.planet.id);
			}
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ focus = DevelopmentFocus2();
			cast<DevelopmentFocus2>(focus).load(this, file);

			if(focus.obj !is null)
				focuses.insertLast(focus);
		}

		uint expandTypeID = 0;
		file >> expandTypeID;
		expandType = convertToExpandType(expandTypeID);

		colonyManagement.loadManager(file);

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			auto@ data = BuildTracker(planets, resources, file);
			if (data !is null)
				genericBuilds.insertLast(data);
		}

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			auto@ data = ConstructionTracker(planets, resources, file);
			if (data !is null)
				genericConstructions.insertLast(data);
		}

		planetManagement.load(file);
		regionLinking.load(file);

		file >> bordersScouted;
		file >> lastLevelChainCheck;
		file >> lastPressureCheck;

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = resources.loadExport(file);
			if(data !is null)
				managedPressure.insertLast(data);
		}
		file >> pressureIndex;

		ftlIncomeTargets.load(file);

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			ResourceSpec@ spec = ResourceSpec();
			spec.load(file);
			extraRequests.insertLast(spec);
		}

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			ResourceSpec@ spec = ResourceSpec();
			spec.load(file);
			colonizeOnSight.insertLast(spec);
		}
	}

	void tick(double time) override {
		for (uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			cast<DevelopmentFocus2>(focuses[i]).tick(ai, this, time);
		}

		queue.tick(this, ai);
	}

	void focusTick(double time) override {
		// Colonize and Develop bookeeping
		if (expandType == LevelingHomeworld) {
			// level chaining starts when we have a homeworld
			doLevelChaining();
		}
		if (expandType == LookingForHomeworld) {
			// TODO: We should scout for a scalable and pick that as our first
			// focus instead

			// grab the first tier 1 we see
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 1;
			spec.isForImport = false;
			spec.isLevelRequirement = false;
			if (queue.queueColonizeForResourceSpec(spec, this, ai) !is null) {
				if (log) {
					ai.print("Enqueued starting tier 1");
				}
				expandType = WaitingForHomeworld;
			}
		}
		if (expandType == WaitingForHomeworld) {
			// Level up 'homeworld' to level 3 to start
			if (ai.empire.planetCount > 0) {
				for (uint i = 0, cnt = ai.empire.planetCount; i < cnt; ++i) {
					Planet@ planet = ai.empire.planetList[i];
					if (planet !is null && planet.valid) {
						auto@ focus = addFocus(planets.register(planet));
						focus.targetLevel = 3;
						expandType = LevelingHomeworld;
						break;
					}
				}
			}
		}

		// Look for resource requests made to resources that we can
		// colonize for to meet
		if (limits.remainingColonizations > 0) {
			// Fill the queue with planets we shall colonize to meet
			// requested resources
			// We tick the Resources component first to ensure it has matched
			// all match open requests to planets we already have, so this
			// should only colonise for things we actually don't have available
			resources.focusTick(0.0);
			queue.fillQueueFromRequests(this, ai);
			fillQueueFromExtraRequests();
			// Pull planets off the queue for colonising
			drainQueue();
		}

		clearAlreadyMetColonizations();

		// Try to colonise any planets we are waiting on a source for
		doColonizations();

		checkBuildingsInProgress();
		checkConstructionsInProgress();
		checkColonizationsInProgress();
		updatePenalties();

		// Manage our owned planets
		planetManagement.focusTick(ai);

		// Keep our regions linked
		regionLinking.focusTick(ai);

		checkIfBordersScouted();

		managePressure();
	}

	/**
	 * In rare circumstances we also need to maintain a secondary queue of
	 * resource specs that we should colonise (primarily for the Parasite AI).
	 * Unlike in Weasel's Colonisation code, our primary queue doesn't rememeber
	 * things we ask it to colonise for unless it finds a valid target, so we
	 * need to maintain a seperate list and keep trying to match the items in it
	 * till they are found, at which point it's as if the request was like any
	 * normal one.
	 */
	void fillQueueFromExtraRequests() {
		for (uint i = 0; i < extraRequests.length; ++i) {
			ResourceSpec@ spec = extraRequests[i];
			if (queue.queueColonizeForResourceSpec(spec, this, ai) !is null) {
				extraRequests.removeAt(i);
				--i; // --cnt;
			}
		}
		for (uint i = 0; i < colonizeOnSight.length; ++i) {
			ResourceSpec@ spec = colonizeOnSight[i];
			queue.queueColonizeForResourceSpec(spec, this, ai);
		}
	}

	void drainQueue() {
		// Try to drain the queue whenever we don't have many things we
		// decided to colonise waiting on a source to colonise with
		while (awaitingSource.length < 3) {
			// Try to pull off the queue
			ColonizeTree@ node = queue.pop();
			if (node is null || node.target is null) {
				// we fully drained the queue, no more work to do here
				return;
			}
			Planet@ planet = node.target;

			// mark the planet as awaiting a source and in our colonising list
			colonize(planet, node.request);
		}
	}

	void clearAlreadyMetColonizations() {
		for (uint i = 0, cnt = awaitingSource.length; i < cnt; ++i) {
			ColonizeData2@ colonizeData = cast<ColonizeData2>(awaitingSource[i]);
			if (colonizeData.target is null) {
				continue;
			}
			if (colonizeData.target.owner is ai.empire) {
				// are we playing heralds?
				// Looks like we colonised this without ever ordering it
				double population = colonizeData.target.population;
				if (population >= 1.0) {
					if (log) {
						ai.print("Unordered awaiting colonisation detected", colonizeData.target);
					}
					// finished colonising successfully
					finishColonize(colonizeData);
					--i; --cnt;
					continue;
				}
			}
		}
	}

	/**
	 * Finds colony units to colonise other planets that are awaiting a source.
	 */
	void doColonizations() {
		if (!actions.performColonization) {
			return;
		}
		// Potentially refresh the units we can use as colonise sources
		colonyManagement.colonizeTick();
		// Try to move things out of awaiting source
		for (uint i = 0, cnt = awaitingSource.length; i < cnt; ++i) {
			if (!canAffordColonize()) {
				return;
			}
			ColonizeData2@ colonizeData = cast<ColonizeData2>(awaitingSource[i]);
			ColonizationSource@ source = colonyManagement.getFastestSource(colonizeData.target);
			if (source !is null) {
				if (LOG)
					ai.print("start colonizing "+colonizeData.target.name+" from "+source.toString());
				colonyManagement.orderColonization(colonizeData, source);
				payColonize();
				awaitingSource.remove(colonizeData);
				colonizeData.startColonizeTime = gameTime;
				--i; --cnt;
			}
		}
	}

	/**
	 * Checks if we finished or failed any colonizations.
	 */
	void checkColonizationsInProgress() {
		for (uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			ColonizeData2@ colonizeData = cast<ColonizeData2>(colonizing[i]);
			// TODO: Should we check that the planet we're colonising still exists?

			Empire@ visOwner = colonizeData.target.visibleOwnerToEmp(ai.empire);
			bool canSeeOwnedByOtherEmpire = visOwner !is ai.empire && (visOwner is null || visOwner.valid);
			if (canSeeOwnedByOtherEmpire) {
				abortColonize(colonizeData, avoidRetry=false);
				--i; --cnt;
				continue;
			}

			bool owned = visOwner is ai.empire;
			if (owned) {
				double population = colonizeData.target.population;
				if (population >= 1.0) {
					// finished colonising successfully
					finishColonize(colonizeData);
					--i; --cnt;
					continue;
				} else {
					// either we're in progress or we failed due to some
					// colony ships being shot down
					if (colonizeData.checkTime == -1.0) {
						colonizeData.checkTime = gameTime;
					} else {
						double gracePeriod = ai.behavior.colonizeFailGraceTime;
						if (population > 0.9) {
							gracePeriod *= 2.0;
						}
						if (gameTime > colonizeData.checkTime + gracePeriod) {
							// Give up on colonise and try to clear the system
							// Penalise the target so we don't try to colonise
							// it again too soon
							creeping.requestClear(systems.getAI(colonizeData.target.region));
							abortColonize(colonizeData, avoidRetry=true);
							--i; --cnt;
							continue;
						}
					}
				}
			}

			// Check that the planet we're colonising this from is valid
			// to use, ie owned and sufficient pop if we're playing a terrestrial race
			// if it isn't try to find a different awaitingSource
			if (colonizeData.colonizeUnit !is null) {
				// have a little bit of leeway in allowing colonisations to
				// contine from planets that dropped levels for a brief
				// period before stopping them
				bool hasTakenTooLong = colonizeData.hasTakenTooLong(ai.behavior.colonizePenalizeTime * 0.5);
				if (hasTakenTooLong) {
					bool stillValid = colonizeData.colonizeUnit.valid(ai);
					if (stillValid && colonizeData.colonizeFrom !is null) {
						PlanetAI@ plAI = planets.getAI(colonizeData.colonizeFrom);
						bool stillValid = plAI !is null
							&& plAI.obj !is null
							&& plAI.obj.valid
							&& plAI.abstractColonizeWeight >= 0;
					}
					if (!stillValid) {
						if (LOG)
							ai.print("aborting colonise, source invalid");
						// did we lose our source planet?
						abortColonize(colonizeData, avoidRetry=false);
						--i; --cnt;
						continue;
					}
				}
			}
		}
	}

	void start() {
		// Level up homeworld to level 3 to start
		for (uint i = 0, cnt = ai.empire.planetCount; i < cnt; ++i) {
			Planet@ homeworld = ai.empire.planetList[i];
			if(homeworld !is null && homeworld.valid) {
				auto@ hwFocus = addFocus(planets.register(homeworld));
				if(homeworld.nativeResourceCount >= 2 || homeworld.primaryResourceLimitLevel >= 3 || cnt == 1)
					hwFocus.targetLevel = 3;
			}
		}
		expandType = LevelingHomeworld;
		if (ai.empire.planetCount == 0) {
			if (log) {
				ai.print("Spawned with no planets, need to find a new homeworld");
			}
			expandType = LookingForHomeworld;
		}
		// TODO: Ancient should skip to Expanding

		// Hardcode AI to always grab FTL Crystals on sight.
		// Even if the AI is sublight, grabbing FTL Crystals prevents another
		// empire from getting them easily.
		{
			const ResourceType@ crystals = getResource("FTL");
			ResourceSpec spec;
			if (crystals !is null) {
				spec.type = RST_Specific;
				@spec.resource = crystals;
				spec.isLevelRequirement = false;
				spec.isForImport = false;
				spec.allowUniversal = false;
				colonizeOnSight.insertLast(spec);
			}
		}
	}

	void turn() {
		// Update limits on colonizations for new budget cycle
		limits.previousColonizations = limits.currentColonizations;
		limits.remainingColonizations = ai.behavior.maxColonizations;
		limits.currentColonizations = 0;

		if (log) {
			resources.dumpRequests();
			resources.dumpAvailable();
		}
	}

	bool requestColonyInRegion(Region@ region) {
		if (region is null)
			return true;
		SystemAI@ sys = systems.getAI(region);
		if (sys is null || !sys.explored)
			return true;
		uint presentMask = sys.seenPresent;
		bool isOwned = presentMask & ai.mask != 0;
		if (isOwned)
			return true;
		if (isColonizing(region))
			return true;
		if (!colonyManagement.canSafelyColonize(sys))
			return false;

		return queue.queueColonizeForOccupyRegion(region, this, ai) !is null;
	}

	// Checks we have obtained vision of all the systems 1 hop from our border
	// ie, we know which planets are in the systems we can immediately expand
	// into.
	void checkIfBordersScouted() {
		for (uint i = 0, cnt = systems.outsideBorder.length; i < cnt; ++i) {
			SystemAI@ sys = systems.outsideBorder[i];
			if (!sys.explored) {
				bordersScouted = false;
				return;
			}
		}
		bordersScouted = true;
	}

	bool hasScoutedBorders() {
		return bordersScouted;
	}

	// development component tick essentially
	void doLevelChaining() {
		// only run this every 10 seconds as we don't need to be very responsive
		// on level chain management compared to other things
		if (gameTime < lastLevelChainCheck + 10) {
			return;
		}
		lastLevelChainCheck = gameTime + randomd(-0.5, 0.5);

		// if we lost all our focuses, pick a new one
		if (focuses.length == 0) {
			findNewFocus();
		}

		// if we have only one focus, get that to at least level 3
		if (focuses.length == 1) {
			if (focuses[0].targetLevel < 3) {
				focuses[0].targetLevel = 3;
			}
			if (focuses[0].obj.resourceLevel >= 2) {
				findNewFocus();
			}
		}

		// We should pick which focus we most want to level up next
		DevelopmentFocus@ priorityFocus;
		uint levelsAway = 0;
		for (uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			uint levelTargetGap = max(focuses[i].targetLevel - focuses[i].obj.level, 0);
			levelsAway += levelTargetGap;
			if (levelTargetGap > 0) {
				array<ImportData@> requestedUnmet = resources.getRequestedResources(focuses[i].obj);
				// de deplicate requests into one per spec type
				array<ResourceSpec@> neededSpecs;
				array<uint> neededSpecsCount;
				for (uint j = 0, jcnt = requestedUnmet.length; j < jcnt; ++j) {
					if (neededSpecs.find(requestedUnmet[j].spec) != -1) {
						neededSpecsCount[j] += 1;
						continue;
					}
					neededSpecs.insertLast(requestedUnmet[j].spec);
					neededSpecsCount.insertLast(1);
				}
				for (uint j = 0, jcnt = neededSpecs.length; j < jcnt; ++j) {
					uint availablePotentials = potentialColonizations.hasPotentialsForSpec(neededSpecs[j]);
					bool sufficientPotentials = neededSpecsCount[j] <= availablePotentials;
					// TODO: Determine if this is a fatal problem or if we can use a building
					// TODO: Act on this being a problem
				}
			}
		}
		if (levelsAway > 5) {
			// TODO: If we have a lot of unmet focuses we should potentially
			// cull our empire and reorganise to meet some of them
		}

		// for now, try to bump up the target levels to keep us with something
		// to do at all times, TODO: we should really be checking if the resources
		// for the level chain we need to bump here are actually available
		uint parallelLevelling = 1 + uint(double(planets.planets.length) * 0.05);
		for (uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if (levelsAway > parallelLevelling) {
				continue;
			}
			DevelopmentFocus2@ focus = cast<DevelopmentFocus2>(focuses[i]);
			int desired = focus.maximumDesireableLevel(this);
			if(focus.targetLevel >= desired)
				continue;
			parallelLevelling -= 1;
			focus.targetLevel += 1;
		}

		// pick a new focus if we run out of existing focuses to raise the
		// level for
		if (levelsAway <= parallelLevelling) {
			findNewFocus();
		}

		// As a way to recover from getting stuck and also make use of tier 0 planets,
		// always look to see if we have any borders we could/should expand into
		expandBorders();
	}

	/**
	 * Creates a new focus from a planet we already own or tries to colonise
	 * for one if we aren't colonising for one already.
	 */
	void findNewFocus() {
		// check if we're colonising for any potentially good focuses
		for (uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			if (isGoodFocus(colonizing[i].target, ai)) {
				return;
			}
		}
		// check if we already queued a potentially good focus
		for (uint i = 0, cnt = queue.queue.length; i < cnt; ++i) {
			if (isGoodFocus(queue.queue[i].target, ai)) {
				return;
			}
		}

		// now we need something else to do
		array<PlanetAI@> possibleFocuses = planetManagement.getGoodNextFocuses(ai);
		if (possibleFocuses.length == 0) {
			// now that we also know we're not colonising for any, we
			// should pick one to colonise for
			ResourceSpec spec;
			spec.type = RST_Level_Minimum_Or_Class;
			spec.level = 3;
			@spec.cls = scalableClass;
			spec.isLevelRequirement = false;
			spec.isForImport = false;

			if (queue.queueColonizeForResourceSpec(spec, this, ai) !is null) {
				// found one
				return;
			}

			// TODO: we've had some bad luck, and have no bordering scalables
			// or tier 3s, plus we ran out of planets to colonise for
			// our only focus.
		} else {
			// Create a new dev focus from the first in the list
			// TODO: Should probably be choosing the best focus from
			// this list
			PlanetAI@ newFocus = possibleFocuses[0];
			DevelopmentFocus@ focus = addFocus(newFocus);
			focus.targetLevel = 3;
			return;
		}
	}

	/**
	 * Tries to expand over our borders when we have capacity for colonising but
	 * not requests to fill.
	 */
	void expandBorders() {
		if (!actions.performColonization) {
			return;
		}
		if (!canAffordColonize()) {
			return;
		}
		if (awaitingSource.length > 2) {
			return;
		}
		/* if (colonizing.length > 2) {
			return;
		} */
		if (systems.outsideBorder.length > 0) {
			SystemAI@ sys = systems.outsideBorder[randomi(0, systems.outsideBorder.length-1)];
			if (sys.obj !is null && sys.timeSpentOutsideBorder > 4 * 60) {
				if (LOG)
					ai.print("Trying to expand border to "+sys.obj.name+" to find requests");
				regionLinking.considerMakingLinkAt(sys.obj, ai.empire);
			}
		}
	}

	void managePressure() {
		// Remove any resources we're managing that got used
		for (uint i = 0, cnt = managedPressure.length; i < cnt; ++i) {
			ExportData@ res = managedPressure[i];
			bool invalid = res.request !is null || res.obj is null || !res.obj.valid || res.obj.owner !is ai.empire || !res.usable;
			if (invalid) {
				managedPressure.removeAt(i);
				--i; --cnt;
			}
		}

		// only run this every second or so as we don't need to be very
		// responsive on pressure management compared to other things
		if (gameTime < lastPressureCheck + 1) {
			return;
		}
		lastPressureCheck = gameTime + randomd(-0.2, 0.2);

		//Find new resources that we can put in our pressure manager
		uint availableResources = resources.available.length;
		if (availableResources != 0) {
			uint index = randomi(0, availableResources-1);
			uint checks = min(availableResources, 3);
			for (uint i = 0; i < checks; ++i) {
				// loop through a subset of the available resources, so we don't
				// loop through too many in one tick but see them all eventually
				uint resInd = (index + i) % availableResources;
				ExportData@ res = resources.available[resInd];
				if(res.usable && res.request is null && res.obj !is null && res.obj.valid && res.obj.owner is ai.empire && res.developUse is null) {
					if (res.resource.ai.length != 0 || (res.resource.totalPressure > 0 && res.resource.exportable)) {
						if(!isManaging(res))
							managedPressure.insertLast(res);
					}
				}
			}
		}

		// Distribute the next managed pressure resource
		if(managedPressure.length != 0) {
			pressureIndex = (pressureIndex+1) % managedPressure.length;
			ExportData@ res = managedPressure[pressureIndex];

			int pressure = res.resource.totalPressure;

			DevelopmentFocus@ onFocus;
			double bestWeight = 0;
			bool havePressure = ai.empire.HasPressure != 0.0;

			bool favorPopulation = false;
			bool restrictToFactoryPlanets = false;
			bool restrictToMoneyPlanets = false;

			// 'loop' through all hooks on this resource to adjust our heuristics,
			// in practise there will most likely be zero or one.
			for (uint i = 0, cnt = res.resource.ai.length; i < cnt; ++i) {
				auto@ hook = cast<ResourceAI>(res.resource.ai[i]);
				if (hook is null)
					continue;

				// try casting the hook type to see if it's one we know about
				auto@ importantPlanet = cast<DistributeToImportantPlanet>(hook);
				if (importantPlanet !is null) {
					// no special consideration needed, important planets are our focuses
				}
				auto@ highPopulationPlanet = cast<DistributeToHighPopulationPlanet>(hook);
				if (highPopulationPlanet !is null) {
					favorPopulation = true;
				}
				auto@ factoryPlanet = cast<DistributeToLaborUsing>(hook);
				if (factoryPlanet !is null) {
					restrictToFactoryPlanets = true;
				}
				// this is a bit of a hack, but for now if our resource boosts local pressure
				// assume we want to boost money pressure, we might want to allow for
				// boosting research pressure in the future and base the decision on which
				// resource we need more of
				auto@ moneyPlanet = cast<DistributeAsLocalPressureBoost>(hook);
				if (moneyPlanet !is null) {
					restrictToMoneyPlanets = true;
				}
			}

			bool restrictToPrimaryFactory = restrictToFactoryPlanets;
			Factory@ factory = construction.primaryFactory;
			// FIXME: Beacons should count as a planet for this
			if (restrictToPrimaryFactory && (factory is null || factory.obj is null || !factory.obj.isPlanet)) {
				restrictToPrimaryFactory = false;
			}

			for (uint i = 0, cnt = focuses.length; i < cnt; ++i) {
				auto@ f = focuses[i];

				int cap = f.obj.pressureCap;
				if (!havePressure)
					cap = 10000;
				int cur = f.obj.totalPressure;

				if (cur + pressure > 2 * cap)
					continue;

				double w = 1.0;
				if (cur + pressure > cap)
					w *= 0.1;

				if (restrictToPrimaryFactory) {
					if (factory.obj is f.obj) {
						// stack labor on the primary factory
						w += 10;
					} else {
						w -= 10;
					}
				} else if (restrictToFactoryPlanets) {
					if (f.obj.laborIncome > 0) {
						// favor stacking labor on the current best source
						w *= f.obj.laborIncome;
					} else {
						w -= 1;
					}
				}

				if (favorPopulation) {
					w *= f.obj.population;
				}

				if (restrictToMoneyPlanets) {
					const ResourceType@ resource = getResource(f.obj.primaryResourceType);
					if (resource.tilePressure[TR_Money] > 0) {
						w += 5;
					} else {
						w -= 5;
					}
				}

				if (w > bestWeight) {
					bestWeight = w;
					@onFocus = f;
				}

				// TODO: Favor the development focus with synergistic pressure
				// multipliers and penalise the ones with antisynergistic pressure
				// multipliers
			}

			if (onFocus !is null) {
				managedPressure.removeAt(pressureIndex);
				cast<DevelopmentFocus2>(onFocus).takeManagedPressureResource(res, ai, this);
			}

			// TODO: If restrictToMoneyPlanets is true and we didn't find a focus
			// we should promote a non focus which has spare pressure cap and a
			// money primary resource to be a focus
		}
	}

	/**
	 * Checks if we are managing the pressure of a resource in any way
	 */
	bool isManaging(ExportData@ res) {
		for(uint i = 0, cnt = managedPressure.length; i < cnt; ++i) {
			if(managedPressure[i] is res)
				return true;
		}
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			DevelopmentFocus@ focus = focuses[i];
			if(focus.obj is res.obj)
				return true;
			for(uint j = 0, jcnt = focus.managedPressure.length; j < jcnt; ++j) {
				if(focus.managedPressure[j] is res)
					return true;
			}
		}
		return false;
	}

	bool isDevelopingIn(Region@ reg) {
		if (reg is null) {
			return false; // TODO
		}
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj.region is reg)
				return true;
		}
		return false;
	}

	/**
	 * Keeps the genericBuilds list up to date, removing items from it
	 * as we finish or cancel building them.
	 */
	void checkBuildingsInProgress() {
		for (uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			bool removeTracker = genericBuilds[i].buildingRequest is null;
			bool aborted = removeTracker;
			if (!removeTracker) {
				auto@ build = genericBuilds[i].buildingRequest;
				if (build.canceled) {
					removeTracker = true;
					aborted = true;
				} else if (build.built) {
					if (build.getProgress() >= 1.f) {
						if(build.expires < gameTime) {
							removeTracker = true;
						}
					} else {
						build.expires = gameTime + 60.0;
					}
				}
			}
			if (aborted) {
				if (genericBuilds[i].importRequestReason !is null) {
					if (genericBuilds[i].importRequestReason.obj !is null)
						if (LOG) {
							ai.print("Failed build on "+genericBuilds[i].importRequestReason.obj.name);
						}
					// reset buildingFor flag so we try to meet this resource
					// potentially by colonisation again
					genericBuilds[i].importRequestReason.buildingFor = false;
				}
				// Check if we failed and we were trying to build on a Gas Giant
				auto@ build = genericBuilds[i].buildingRequest;
				// our build failed on this planet, probably because we ran out
				// of space
				// if this is a gas giant there are probably moons we can start a moon
				// base with here. Set a flag so we can consider building another
				// moon base on this planet from the Improvement.as focus phase
				if (build !is null && build.couldNotFindLocation) {
					if (LOG) {
						ai.print("Marking as failed place on "+build.plAI.obj.name);
					}
					build.plAI.failedToPlaceBuilding = true;
				}
				// [[ MODIFY BASE GAME END ]]
			}
			if (removeTracker) {
				genericBuilds.removeAt(i);
				--i; --cnt;
			}
		}
	}

	/**
	 * Keeps the genericConstructions list up to date, removing items from it
	 * as we finish or cancel building them.
	 */
	void checkConstructionsInProgress() {
		for (uint i = 0, cnt = genericConstructions.length; i < cnt; ++i) {
			bool removeTracker = genericConstructions[i].constructionRequest is null;
			bool aborted = removeTracker;
			if (!removeTracker) {
				auto@ build = genericConstructions[i].constructionRequest;
				if (build.canceled) {
					removeTracker = true;
					aborted = true;
				} else if (build.built) {
					if (build.getProgress() >= 1.f) {
						if(build.expires < gameTime) {
							removeTracker = true;
						}
					} else {
						build.expires = gameTime + 60.0;
					}
				}
			}
			if (aborted) {
				if (genericConstructions[i].importRequestReason !is null) {
					if (genericConstructions[i].importRequestReason.obj !is null)
						if (LOG) {
							ai.print("Failed construction project on "+genericConstructions[i].importRequestReason.obj.name);
						}
					// reset buildingFor flag so we try to meet this resource
					// potentially by colonisation again
					genericConstructions[i].importRequestReason.buildingFor = false;
				}
			}
			if (removeTracker) {
				genericConstructions.removeAt(i);
				--i; --cnt;
			}
		}
	}

	// Methods for the Buildings interface and AIResources interface
	void registerUse(BuildingUse use, const BuildingType& type) {
		switch(use) {
			case BU_Factory:
			@ai.defs.Factory = type;
			break;
			case BU_LaborStorage:
			@ai.defs.LaborStorage = type;
			break;
		}
	}

	Considerer@ get_consider() {
		return cast<Considerer>(ai.consider);
	}

	bool requestsFTLStorage() {
		return ftlIncomeTargets.requestsFTLStorage(ai);
	}

	bool requestsFTLIncome() {
		return ftlIncomeTargets.requestsFTLIncome(ai);
	}

	Empire@ get_empire() {
		return ai.empire;
	}

	bool isBuilding(const BuildingType& type) {
		for(uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			if(genericBuilds[i].buildingType() is type)
				return true;
		}
		return false;
	}

	void trackBuilding(BuildTracker@ tracker) {
		genericBuilds.insertLast(tracker);
	}

	bool isConstructing(const ConstructionType& type) {
		for(uint i = 0, cnt = genericConstructions.length; i < cnt; ++i) {
			if(genericConstructions[i].constructionType() is type)
				return true;
		}
		return false;
	}

	void trackConstruction(ConstructionTracker@ tracker) {
		genericConstructions.insertLast(tracker);
	}

	DevelopmentFocus@ getFocus(Planet& pl) {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj is pl)
				return focuses[i];
		}
		return null;
	}

	array<DevelopmentFocus@> getFocuses() {
		return focuses;
	}

	bool isFocus(Object@ obj) {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj is obj)
				return true;
		}
		return false;
	}

	DevelopmentFocus@ addFocus(PlanetAI@ plAI) {
		// don't add a focus twice!
		DevelopmentFocus@ existingFocus = getFocus(plAI.obj);
		if (existingFocus !is null) {
			return existingFocus;
		}

		DevelopmentFocus2 focus;
		@focus.obj = plAI.obj;
		@focus.plAI = plAI;
		focus.maximumLevel = getMaxPlanetLevel(plAI.obj);

		focuses.insertLast(focus);
		return focus;
	}

	// Method for the ConsiderFilter interface
	bool filter(Object@ obj) {
		for(uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			auto@ build = genericBuilds[i];
			if(build.buildingType() is filterType && build.buildingRequest.plAI.obj is obj)
				return false;
		}
		return true;
	}

	// Puts a resource spec into the colonise queue
	void queueColonizeLowPriority(ResourceSpec& spec, bool place = true) {
		extraRequests.insertLast(spec);
	}

	// Places a resource spec into the colonize queue
	void queueColonizeHighPriority(ResourceSpec& spec, bool place = true) {
		extraRequests.insertAt(0, spec);
	}

	// Loads colonize data from a file
	ColonizeData@ loadColonize(SaveFile& file) {
		int id = -1;
		file >> id;
		if(id == -1)
			return null;
		else
			return loadColonize(id);
	}
	ColonizeData@ loadColonize(int id) {
		if(id == -1)
			return null;
		for(uint i = 0, cnt = loadIds.length; i < cnt; ++i) {
			if(loadIds[i].id == id)
				return loadIds[i];
		}
		ColonizeData2 data;
		data.id = id;
		loadIds.insertLast(data);
		return data;
	}
	// Saves colonize data to a file
	void saveColonize(SaveFile& file, ColonizeData@ data) {
		int id = -1;
		if(data !is null)
			id = data.id;
		file << id;
	}

	// Colonizes a planet, marking the ColonizeData as colonizing and awaitingSource
	ColonizeData@ colonize(Planet& pl) {
		if(log)
			ai.print("queue colonization", pl);

		ColonizeData2 data;
		data.id = nextColonizeId++;
		@data.target = pl;

		colonizing.insertLast(data);
		awaitingSource.insertLast(data);
		return data;
	}

	// Colonizes a planet, with an associated ImportData, marking the
	// ColonizeData as colonizing and awaitingSource
	ColonizeData@ colonize(Planet& pl, ImportData@ request) {
		if(log)
			ai.print("queue colonization", pl);

		ColonizeData2 data;
		data.id = nextColonizeId++;
		@data.target = pl;
		@data.request = request;

		colonizing.insertLast(data);
		awaitingSource.insertLast(data);
		return data;
	}

	// Colonizes the best planet in the potentials matching the resource spec
	ColonizeData@ colonize(ResourceSpec@ spec) {
		// Not used in Expansion, only used by replaced Development component
		return null;
	}

	// Checks if a planet is being colonized or is in the queue
	bool isColonizing(Planet& pl) {
		for(uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			if(colonizing[i].target is pl)
				return true;
		}
		return queue.isQueuedForColonizing(pl);
	}

	// Checks if any planet in a region is being colonized or is in the queue
	bool isColonizing(Region& region) {
		for(uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			if(colonizing[i].target !is null && colonizing[i].target.region is region)
				return true;
		}
		return queue.isQueuedForColonizing(region);
	}

	void abortColonize(ColonizeData2@ data, bool avoidRetry=false) {
		data.completed = false;
		data.canceled = true;
		if(data.colonizeFrom !is null && data.colonizeFrom.owner is ai.empire)
			data.colonizeFrom.stopColonizing(data.target);
		if (data.target !is null) {
			if(data.target.owner is ai.empire)
				data.target.forceAbandon();
		}
		awaitingSource.remove(data);
		colonizing.remove(data);
		ImportData@ request = data.request;
		if (request !is null) {
			// unset the isColonizing flag because we failed to colonise for
			// this
			request.isColonizing = false;
		}

		if (avoidRetry) {
			double nextAllowedColonizeTime = gameTime + ai.behavior.colonizePenalizeTime;
			if (data.target !is null) {
				AvoidColonizeMarker@ penalty = AvoidColonizeMarker(data.target, nextAllowedColonizeTime);
				penalties.insertLast(penalty);
				penaltySet.insert(penalty.planet.id);
			}
		}
	}

	/**
	 * Responds to any colonisation failuires we get told about by aborting
	 * the colonise.
	 */
	void onColonizeFailed(Planet@ target) {
		for (uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			if (colonizing[i].target is target) {
				ColonizeData2@ data = cast<ColonizeData2>(colonizing[i]);
				abortColonize(data);
				return;
			}
		}
	}

	void finishColonize(ColonizeData2@ data) {
		data.completed = true;
		data.canceled = false;
		awaitingSource.remove(data);
		colonizing.remove(data);
		if (data.target !is null) {
			PlanetAI@ plAI = planets.register(data.target);
			if (log) {
				ai.print("Colonised "+data.target.name);
			}
		}
	}

	void updatePenalties() {
		for (uint i = 0, cnt = penalties.length; i < cnt; ++i) {
			AvoidColonizeMarker@ penalty = penalties[i];
			if (penalty.planet is null || gameTime > penalty.until) {
				penalties.removeAt(i);
				if (penalty.planet !is null) {
					penaltySet.erase(penalty.planet.id);
				}
				--i; --cnt;
			}
		}
	}

	// Check how recently we colonized something matching the spec
	double timeSinceMatchingColonize(ResourceSpec& spec) {
		return 181.0; // This is no longer used
	}

	// Methods for ColonizeBudgeting
	void payColonize() {
		limits.remainingColonizations -= 1;
		limits.currentColonizations += 1;
		// Only spend upon paying for colonization, the Colonization component
		// would eagerly spend on colonizations it hasn't started yet
		budget.spend(BT_Colonization, 0, ai.behavior.colonizeBudgetCost);
	}
	bool canAffordColonize() {
		return limits.remainingColonizations > 0;
	}

	// This method is only used in the Colonization and Development components,
	// which means we don't need it as Expansion replaces both components.
	bool shouldQueueFor(const ResourceSpec@ spec, ColonizeQueue@ inside = null) {
		return false;
	}

	// This method is only used in the Colonization and Development components,
	// which means we don't need it as Expansion replaces both components.
	bool isResolved(ImportData@ req, ColonizeQueue@ inside = null) {
		return false;
	}

	// Getters and setters for the Development and Colonization interfaces
	// we need to implement for other components to interact with us

	// Returns the AwaitingSource list
	array<ColonizeData@> get_AwaitingSource() {
		return awaitingSource;
	}

	// Returns the PotentialColonize list
	array<PotentialColonize@>@ getPotentialColonize() {
		return potentialColonizations.potentialColonizations;
	}

	// Potentials is the same as getPotentialColonize()
	array<PotentialColonize@> get_Potentials() {
		return getPotentialColonize();
	}

	// This flag is set to false when the heralds race component is present
	// We don't use it, but weasel colonisation does
	void set_QueueColonization(bool value) { actions.queueColonization = value; }
	// This is used to modify the weight of potential colonisations based on
	// distance, except it quickly becomes useless once Star Children have
	// more than one mothership, so we will manage this a different way
	void set_ColonizeWeightObj(Object@ colonizeWeightObj) { }

	array<DevelopmentFocus@> get_Focuses() { return focuses; }

	double get_AimFTLStorage() { return ftlIncomeTargets.FTLStorage; }
	void set_AimFTLStorage(double value) { ftlIncomeTargets.FTLStorage = value; }
	double get_AimFTLIncome() { return ftlIncomeTargets.FTLIncome; }
	void set_AimFTLIncome(double value) { ftlIncomeTargets.FTLIncome = value; }
	bool get_ManagePlanetPressure() { return actions.managePressure; }
	void set_ManagePlanetPressure(bool value) { actions.managePressure = value; }
	bool get_BuildBuildings() { return true; }
	// We just check if we are able to build per building type and planet, no
	// need for an empire wide flag anymore (Star Children are allowed to build
	// on uplifted planets now)
	void set_BuildBuildings(bool value) { }

	// This flag is set to false when the race is Ancient, which stops the
	// Development component from colonizing to develop resources. This is just
	// ignored here because performColonization will be set to false anyway.
	bool get_ColonizeResources() { return actions.performColonization; }
	void set_ColonizeResources(bool value) { }

	// This flag is set to false when a race component is responsible for picking
	// a source to colonize with
	// The Ancient component doesn't pickup awaitingSource's like Star Children
	// do?
	void set_PerformColonization(bool value) { actions.performColonization = value; }

	// ColonyManagement interface hook
	void setColonyManagement(ColonizationAbility@ colonyManagement) {
		@this.colonyManagement = colonyManagement;
	}

	// Race resource valuation interface hook
	void setResourceValuation(RaceResourceValuation@ race) {
		@this.queue.resourceValuator.race = race;
	}
}

AIComponent@ createExpansion() {
	return Expansion();
}
