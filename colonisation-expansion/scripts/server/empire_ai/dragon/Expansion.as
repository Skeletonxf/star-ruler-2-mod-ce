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
from ai.buildings import Buildings, BuildingAI, BuildingUse, AsCreatedResource;
from ai.resources import AIResources, ResourceAI;

// It is very important we don't just import the entire resources definition
// because it defines a Resource class which conflicts with the Resources
// class for the AI Resources component
from resources import ResourceType;
import empire_ai.dragon.bookkeeping.resource_flows;
from empire_ai.dragon.bookkeeping.resource_value import RaceResourceValuation, ResourceValuator, PlanetValuables;
import empire_ai.dragon.expansion.expand_logic;
import empire_ai.dragon.expansion.terrestrial_colonization;
import empire_ai.dragon.expansion.planet_management;
import empire_ai.dragon.expansion.region_linking;

from statuses import getStatusID;
from traits import getTraitID;

// Data class for incomes that we are aiming for.
class ResourceIncomes {
	double FTLIncome = 1.0;
	double FTLStorage = 0.0;
}

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

class PotentialColonizeSource : PotentialColonize {
	// Existing parent class fields, these are needed because
	// other AI components use them
	//Planet@ pl;
	//const ResourceType@ resource;
	//double weight = 0;
	PlanetValuables@ valuables;

	PotentialColonizeSource(Planet@ planet, ResourceValuator& valuation) {
		@valuables = PlanetValuables(planet);
		// weight is NOT based on resources, we will frequently loop through
		// potential colonize sources for the best choice to meet a spec,
		// and hence this is for breaking ties given a spec
		// we also scale this by distance to our border, to favor expanding
		// our border at times
		weight = valuables.getGenericValue(valuation);
		@resource = getResource(planet.primaryResourceType);
		@pl = planet;
	}

	void save(SaveFile& file) {
		file << pl;
		if (resource !is null) {
			file.write1();
			file.writeIdentifier(SI_Resource, resource.id);
		} else {
			file.write0();
		}
		file << weight;
	}

	// only for deserialisation
	PotentialColonizeSource() {}

	void load(SaveFile& file) {
		file >> pl;
		if (file.readBit())
			@resource = getResource(file.readIdentifier(SI_Resource));
		file >> weight;
		@valuables = PlanetValuables(pl);
	}

	bool canMeet(ResourceSpec@ spec) {
		return valuables.canExportToMeet(spec);
	}
}

/**
 * Subclass of ColonizeData, with save/load methods for use here.
 */
class ColonizeData2 : ColonizeData {
	/* int id = -1;
	Planet@ target;
	Planet@ colonizeFrom;
	bool completed = false;
	bool canceled = false;
	double checkTime = -1.0; */
	// Nullable import data that might be associated with our node
	ImportData@ request;
	// The time we began actually colonising for this data, or -1
	// if we didn't start yet
	double startColonizeTime = -1;

	void save(Expansion& expansion, SaveFile& file) {
		file << target;
		file << colonizeFrom;
		file << completed;
		file << canceled;
		file << checkTime;
		if (request !is null) {
			file.write1();
			expansion.resources.saveImport(file, request);
		} else {
			file.write0();
		}
		file << startColonizeTime;
	}

	void load(Expansion& expansion, SaveFile& file) {
		file >> target;
		file >> colonizeFrom;
		file >> completed;
		file >> canceled;
		file >> checkTime;
		if (file.readBit()) {
			@this.request = expansion.resources.loadImport(file);
		}
		file >> startColonizeTime;
	}

	bool hasTakenTooLong(double colonizePenalizeTime) {
		return startColonizeTime != -1 && gameTime > startColonizeTime + colonizePenalizeTime;
	}
};

/**
 * This is essentially the same as Colonization's ColonizePenalty but
 * with a different name to avoid name conflicts and potentially be
 * expanded later.
 */
class AvoidColonizeMarker {
	Planet@ planet;
	/**
	 * Minimum game time to consider colonising this planet again
	 */
	double until;

	void save(SaveFile& file) {
		file << planet;
		file << until;
	}

	void load(SaveFile& file) {
		file >> planet;
		file >> until;
	}

	AvoidColonizeMarker(Planet@ planet, double until) {
		@this.planet = planet;
		this.until = until;
	}

	// only for deserialisation
	AvoidColonizeMarker() {}
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
}

class ColonizeTree {
	// TODO, want to track what planet we are colonizing resources for here
	// so that if we lose the planet then we can stop colonizing all its
	// children, or at the very least reconsider if we need them and
	// move them to a different tree in the forest
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

class ColonizeForest {
	// TODO
	//array<ColonizeTree@> urgent;
	array<ColonizeTree@> queue;
	double nextCheckForPotentialColonizeTargets = 0;

	ResourceValuator@ resourceValuator;
	const ConstructionType@ build_moon_base;

	ColonizeForest() {
		@resourceValuator = ResourceValuator();
		@build_moon_base = getConstructionType("MoonBase");
	}

	void save(Expansion& expansion, SaveFile& file) {
		uint cnt = queue.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			queue[i].save(expansion, file);
		file << nextCheckForPotentialColonizeTargets;
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
	void checkBorderSystems(Expansion& expansion, AI& ai) {
		// reset list of potential colonise targets
		expansion.potentialColonizations.length = 0;

		// check systems inside border
		for (uint i = 0, cnt = expansion.systems.owned.length; i < cnt; ++i) {
			checkSystem(expansion.systems.owned[i], expansion, ai);
		}
		// check systems 1 hop away
		for (uint i = 0, cnt = expansion.systems.outsideBorder.length; i < cnt; ++i) {
			checkSystem(expansion.systems.outsideBorder[i], expansion, ai);
		}

		// check home system or all systems we can see if no owned systems
		if (expansion.systems.owned.length == 0) {
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

	void checkSystem(SystemAI@ sys, Expansion& expansion, AI& ai) {
		// seenPresent is a cache of the PlanetsMask of this system
		uint presentMask = sys.seenPresent;
		bool isOwned = presentMask & ai.mask != 0;
		if(!isOwned) {
			// abort if not colonising enemy systems and we think the enemy
			// has planets here
			if(!ai.behavior.colonizeEnemySystems && (presentMask & ai.enemyMask) != 0)
				return;
			// abort if not colonising neutral systems and we think there are some???
			if(!ai.behavior.colonizeNeutralOwnedSystems && (presentMask & ai.neutralMask) != 0)
				return;
			// abort if not colonising ally systems and an ally has planets here
			// (this doesn't work for heralds obviously)
			if(!ai.behavior.colonizeAllySystems && (presentMask & ai.allyMask) != 0)
				return;
		}

		// Add weighting to planets in systems we don't have any planets in,
		// as they will expand our borders
		double sysWeight = 1.0;
		if (!isOwned)
			sysWeight *= ai.behavior.weightOutwardExpand;

		uint plCnt = sys.planets.length;
		for (uint n = 0; n < plCnt; ++n) {
			Planet@ pl = sys.planets[n];
			Empire@ visOwner = pl.visibleOwnerToEmp(ai.empire);
			if(!pl.valid || visOwner.valid)
				continue;
			if(expansion.isColonizing(pl))
				continue;
			if(expansion.penaltySet.contains(pl.id)) // probably a remnant in the way
				continue;
			if(pl.quarantined)
				continue;

			/* int resId = pl.primaryResourceType;
			if(resId == -1)
				continue; */

			PotentialColonizeSource@ p = PotentialColonizeSource(pl, resourceValuator);
			p.weight *= sysWeight;
			//TODO: this should be weighted according to the position of the planet,
			//we should try to colonize things in favorable positions
			expansion.potentialColonizations.insertLast(p);
		}
	}

	// Checks if a planet is in the queue
	bool isQueuedForColonizing(Planet& pl) {
		for(uint i = 0, cnt = queue.length; i < cnt; ++i) {
			if(queue[i].target is pl)
				return true;
		}
		return false;
	}

	void fillQueueFromRequests(Expansion& expansion, AI& ai) {
		// look through the requests made to the Resources component
		// and try to colonise to fill them
		for(uint i = 0, cnt = expansion.resources.requested.length; i < cnt; ++i) {
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

			queueColonizeForResourceSpec(req, expansion, ai);
		}
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
	void queueColonizeForResourceSpec(ImportData@ request, Expansion& expansion, AI& ai) {
		ai.print("colonize for requested resource: "+request.spec.dump(), request.obj);
		ResourceSpec@ spec = request.spec;
		Object@ requestingObject = request.obj;

		Planet@ newColony;
		double bestWeight = 0.0;

		// evaluate each potential source against the spec to pick one to colonise
		for (uint i = 0, cnt = expansion.potentialColonizations.length; i < cnt; ++i) {
			PotentialColonizeSource@ p = cast<PotentialColonizeSource>(expansion.potentialColonizations[i]);
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
			ai.print("found colonize target for requested resource: "+request.spec.dump(), newColony);
			queue.insertLast(ColonizeTree(newColony, request));
			request.isColonizing = true;
		} else {
			// Perhaps check if the planet is a Gas Giant first, as we should make a moon
			// base if we need to build on them

			// Get the PlanetAI for the object making this request
			auto@ plAI = expansion.planets.getAI(cast<Planet>(request.obj));

			if (plAI.obj is null)
				return;

			bool alreadyConstructingMoonBase = expansion.planets.isConstructing(plAI.obj, build_moon_base);
			if (alreadyConstructingMoonBase && plAI.failedToPlaceBuilding) {
				// we're working on it, no point trying a third time
				return;
			}

			// try checking the next building type out of the list on
			// this tick to see if we can meet the request with a building
			for (uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
				auto@ type = getBuildingType(i);
				if (type.ai.length == 0)
					continue;

				if (!type.canBuildOn(plAI.obj))
					continue;

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

					auto@ resourceBuilding = cast<AsCreatedResource>(hook);
					if (resourceBuilding !is null) {
						// our hook is an AsCreatedResource, check if this resource
						// is what we need to meet the spec (this completely bypasses
						// most of the logic to how these hooks work in vanilla, but will
						// also stop the AI waiting for chunks of time when a building is
						// the only way to meet a resource, so this is intended hackery)
						if (request.spec.meets(getResource(resourceBuilding.resource.integer), fromObj=request.obj, toObj=request.obj)) {
							// FIXME: This is being way too eager to make megafarms when we have food resources around us
							// got match, close request
							ai.print("building "+type.name+" to meet requested resource: "+request.spec.dump());
							request.buildingFor = true;
							auto@ req = expansion.planets.requestBuilding(plAI, type, priority=2, expire=ai.behavior.genericBuildExpire);
							if (req !is null) {
								auto@ tracker = BuildTracker(req);
								@tracker.importRequestReason = request;
								expansion.genericBuilds.insertLast(tracker);
							}
							// all done here, met the resource
							return;
						}
					}
				}
			}
			ai.print("failed to find target for requested resource: "+request.spec.dump());
		}
	}

	/**
	 * Pops the oldest planet off the queue
	 *
	 * TODO: This should be much smarter once the queue is an actual forest
	 * of trees instead of a FIFO queue
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
 * Tracks a BuildingRequest AND the reason we made it, so we can respond
 * appropriately if it gets cancelled.
 */
class BuildTracker {
	// Building request we are tracking
	BuildingRequest@ buildingRequest;
	// Nullable set of reasons we made the building request:
	// - To meet an import data
	ImportData@ importRequestReason;

	BuildTracker(BuildingRequest@ buildingRequest) {
		@this.buildingRequest = buildingRequest;
	}

	void save(Expansion& expansion, SaveFile& file) {
		expansion.planets.saveBuildingRequest(file, buildingRequest);
		if (importRequestReason !is null) {
			file.write1();
			expansion.resources.saveImport(file, importRequestReason);
		} else {
			file.write0();
		}
	}

	// only for deserialisation
	BuildTracker() {}

	void load(Expansion& expansion, SaveFile& file) {
		@this.buildingRequest = expansion.planets.loadBuildingRequest(file);
		if (file.readBit()) {
			@this.importRequestReason = expansion.resources.loadImport(file);
		}
	}

	const BuildingType@ buildingType() {
		if (buildingRequest is null) {
			return null;
		}
		return buildingRequest.type;
	}
}

/**
 * A combined and rewritten AIComponent which is responsible for colonization
 * and development, and as such will hopefully do the two together in a way
 * which doesn't sit on unused resources or colonise resources not needed for
 * levelling.
 */
class Expansion : AIComponent, Buildings, ConsiderFilter, AIResources, IDevelopment, IColonization, ColonizeBudgeting {
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

	Actions actions;
	ResourceIncomes incomes;
	Limits limits;

	// Colonization state
	int nextColonizeId = 0;

	// Things we might want to colonize to expand (ie, within 1 hop to the border)
	// Used by the Ancient component, at least for now.
	// Long term would like to make this flexible enough to play Ancient well
	array<PotentialColonize@> potentialColonizations; // TODO: Move this into the queue

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

	TerrestrialColonization@ terrestrial;
	PlanetManagement@ planetManagement;

	RegionLinking@ regionLinking;

	const ResourceClass@ scalableClass;

	void create() {
		@resources = cast<Resources>(ai.resources);
		@planets = cast<Planets>(ai.planets);
		@systems = cast<Systems>(ai.systems);
		@budget = cast<Budget>(ai.budget);
		@creeping = cast<Creeping>(ai.creeping);
		@construction = cast<Construction>(ai.construction);

		@queue = ColonizeForest();
		RaceColonization@ race;
		@race = cast<RaceColonization>(ai.race);
		@terrestrial = TerrestrialColonization(planets, race, this);
		@planetManagement = PlanetManagement(planets, budget, ai, log);
		@regionLinking = RegionLinking(planets, construction, resources, systems);

		@scalableClass = getResourceClass("Scalable");
	}

	void save(SaveFile& file) {
		file << nextColonizeId;
		limits.save(file);

		uint cnt = colonizing.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			saveColonize(file, colonizing[i]);
			cast<ColonizeData2>(colonizing[i]).save(this, file);
		}

		cnt = potentialColonizations.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			(cast<PotentialColonizeSource>(potentialColonizations[i])).save(file);
		}

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

		terrestrial.save(file);

		cnt = genericBuilds.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			genericBuilds[i].save(this, file);

		planetManagement.save(file);
		regionLinking.save(file);
	}

	void load(SaveFile& file) {
		file >> nextColonizeId;
		limits.load(file);

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = loadColonize(file);
			if(data !is null) {
				cast<ColonizeData2>(data).load(this, file);
				if(data.target !is null) {
					colonizing.insertLast(data);
					// FIXME: This won't work properly with non terrestrial races
					// We need to properly track if the colonise data was in awaitingSource when saving rather
					// than try to infer it from a field which is now always null
					if(data.colonizeFrom is null)
						awaitingSource.insertLast(data);
				}
				else {
					data.canceled = true;
				}
			}
			else {
				ColonizeData2().load(this, file);
			}
		}

		file >> cnt;
		potentialColonizations.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			PotentialColonizeSource@ p = PotentialColonizeSource();
			p.load(file);
			@potentialColonizations[i] = p;
		}

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

		cnt = 0;
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

		terrestrial.load(file);

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			auto@ data = BuildTracker();
			data.load(this, file);
			if (data !is null)
				genericBuilds.insertLast(data);
		}

		planetManagement.load(file);
		regionLinking.load(file);
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
			// Look for resource requests made to resources that we can
			// colonize for to meet

			if (limits.remainingColonizations > 0) {
				// Fill the queue with planets we shall colonize to meet
				// requested resources
				// The Resources component will match open requests to planets
				// we already have for the most part, so this should only
				// colonise for things we actually don't have
				queue.fillQueueFromRequests(this, ai);
				// Pull planets off the queue for colonising
				drainQueue();
			}
		}

		// Try to colonise any planets we are waiting on a source for
		doColonizations();

		checkBuildingsInProgress();
		checkColonizationsInProgress();
		updatePenalties();

		// Manage our owned planets
		planetManagement.focusTick(ai);

		// Keep our regions linked
		regionLinking.focusTick(ai);
	}

	void drainQueue() {
		array<Resource> planetResources;
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

			if (true) {
				// mark the planet as awaiting a source and in our colonising list
				colonize(planet, node.request);
			} else {
				ai.print("Decided to not bother colonising "+planet.name);
			}
		}
	}

	/**
	 * Finds planets to colonise other planets that are awaiting a source.
	 */
	void doColonizations() {
		if (!actions.performColonization) {
			return;
		}
		// Potentially refresh the planets we can use as colonise sources
		terrestrial.tick();
		for (uint i = 0, cnt = awaitingSource.length; i < cnt; ++i) {
			ColonizeData@ colonizeData = awaitingSource[i];
			PotentialSource@ source = terrestrial.findPlanetColonizeSource(colonizeData);
			if (source !is null) {
				if (true)
					ai.print("start colonizing "+colonizeData.target.name, source.pl);
				terrestrial.orderColonization(colonizeData, source);
				awaitingSource.remove(colonizeData);
				cast<ColonizeData2>(colonizeData).startColonizeTime = gameTime;
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

			// Check that the planet we're colonising this from is still
			// owned and has sufficient pop if we're playing a terrestrial race
			// in which case try to find a different awaitingSource
			// TODO: Need to rework colonizeFrom to apply to all colonise units
			// of every race or replicate all this logic into each Race
			// component
			if (colonizeData.colonizeFrom !is null) {
				// have a little bit of leeway in allowing colonisations to
				// contine from planets that dropped levels for a brief
				// period before stopping them
				bool hasTakenTooLong = colonizeData.hasTakenTooLong(ai.behavior.colonizePenalizeTime * 0.5);
				if (hasTakenTooLong) {
					PlanetAI@ plAI = planets.getAI(colonizeData.colonizeFrom);
					bool canStillColonizeFrom = plAI !is null
						&& plAI.obj !is null
						&& plAI.obj.valid
						&& plAI.abstractColonizeWeight >= 0;
					if (!canStillColonizeFrom) {
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
		// TODO: Ancient should skip to Expanding, Star Children should start
		// at LookingForHomeworld instead
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

	bool isDevelopingIn(Region@ reg) {
		return false;
	}

	/**
	 * Keeps the genericBuilds list up to date, removing items from it
	 * as we finish or cancel building them.
	 */
	void checkBuildingsInProgress() {
		for (uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			bool removeTracker = genericBuilds[i].buildingRequest is null;
			bool aborted = false;
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
						if (log) {
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
				if (build.couldNotFindLocation) {
					if (log) {
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
		return false;
	}

	bool requestsFTLIncome() {
		return false;
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

	DevelopmentFocus@ getFocus(Planet& pl) {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj is pl)
				return focuses[i];
		}
		return null;
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
		//ColonizeQueue q;
		//@q.spec = spec;

		//if(place)
		//	queue.insertLast(q);
		//return q;
	}

	// Places a resource spec into the colonize queue
	void queueColonizeHighPriority(ResourceSpec& spec, bool place = true) {
		//ColonizeQueue q;
		//@q.spec = spec;

		//if (place) {
		//	// insertAt pushes other elements down the array
		//	queue.insertAt(0, q);
		//}
		//return q;
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
		// TODO: Pick best planet meeting this spec
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
		return 181.0; // TODO
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
		return potentialColonizations;
	}

	// Potentials is the same as getPotentialColonize()
	array<PotentialColonize@> get_Potentials() {
		return getPotentialColonize();
	}

	// This flag is set to false when the heralds race component is present
	void set_QueueColonization(bool value) { actions.queueColonization = value; }
	// This is used to modify the weight of potential colonisations based on
	// distance, except it quickly becomes useless once Star Children have
	// more than one mothership, so we will manage this a different way
	void set_ColonizeWeightObj(Object@ colonizeWeightObj) { }

	array<DevelopmentFocus@> get_Focuses() { return focuses; }

	double get_AimFTLStorage() { return incomes.FTLStorage; }
	void set_AimFTLStorage(double value) { incomes.FTLStorage = value; }
	double get_AimFTLIncome() { return incomes.FTLIncome; }
	void set_AimFTLIncome(double value) { incomes.FTLIncome = value; }
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
}

AIComponent@ createExpansion() {
	return Expansion();
}
