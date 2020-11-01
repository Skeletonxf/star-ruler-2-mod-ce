import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Development;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Creeping;

import planet_levels;
import buildings;
import systems;

import ai.consider;
from ai.buildings import Buildings, BuildingAI, BuildingUse;
from ai.resources import AIResources, ResourceAI;

// It is very important we don't just import the entire resources definition
// because it defines a Resource class which conflicts with the Resources
// class for the AI Resources component
from resources import ResourceType;
import empire_ai.dragon.bookkeeping.resource_flows;
from empire_ai.dragon.bookkeeping.resource_value import RaceResourceValuation, ResourceValuator;
import empire_ai.dragon.expansion.expand_logic;

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
	// Can we make buildings
	bool buildBuildings = true;
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
		weight = 0; // TODO: PlanetValuables should produce a colonize weight
		@resource = getResource(planet.primaryResourceType);
		@pl = planet;
	}

	void save(SaveFile& file) {
		// TODO?
	}

	void load(SaveFile& file) {
		// TODO?
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

	void save(SaveFile& file) {
		file << target;
		file << colonizeFrom;
		file << completed;
		file << canceled;
		file << checkTime;
	}

	void load(SaveFile& file) {
		file >> target;
		file >> colonizeFrom;
		file >> completed;
		file >> canceled;
		file >> checkTime;
	}
};

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

	void save(SaveFile& file) {
		file << target;
	}

	void load(SaveFile& file) {
		file >> target;
	}
}

class ColonizeForest {
	// TODO
	//array<ColonizeTree@> urgent;
	array<ColonizeTree@> queue;
	double nextCheckForPotentialColonizeTargets = 0;

	ResourceValuator@ resourceValuator;

	ColonizeForest() {
		@resourceValuator = ResourceValuator();
	}

	void save(SaveFile& file) {
		uint cnt = queue.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			queue[i].save(file);
		file << nextCheckForPotentialColonizeTargets;
	}

	void load(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		queue.length = cnt;
		for (uint i = 0; i < cnt; ++i) {
			@queue[i] = ColonizeTree();
			queue[i].load(file);
		}
		file >> nextCheckForPotentialColonizeTargets;
	}

	void tick(Expansion& expansion, AI& ai) {
		if (gameTime > nextCheckForPotentialColonizeTargets) {
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
			/* if(penaltySet.contains(pl.id))
				continue; */
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
		for(uint i = 0, cnt = expansion.resources.requested.length; i < cnt && expansion.limits.remainingColonizations > 0; ++i) {
			ImportData@ req = expansion.resources.requested[i];
			if(!req.isOpen)
				continue;
			if(!req.cycled)
				continue;
			if(req.claimedFor)
				continue;
			if(req.isColonizing)
				continue;

			queueColonizeForResourceSpec(req, expansion, ai);
			req.isColonizing = true;
		}
	}

	void queueColonizeForResourceSpec(ImportData@ request, Expansion& expansion, AI& ai) {
		ai.print("colonize for requested resource: "+request.spec.dump(), request.obj);
	}
}

/**
 * A combined and rewritten AIComponent which is responsible for colonization
 * and development, and as such will hopefully do the two together in a way
 * which doesn't sit on unused resources or colonise resources not needed for
 * levelling.
 */
class Expansion : AIComponent, Buildings, ConsiderFilter, AIResources, IDevelopment, IColonization {
	Resources@ resources;
	Planets@ planets;
	Systems@ systems;
	Budget@ budget;
	Creeping@ creeping;

	array<DevelopmentFocus@> focuses;

	// Building hook state
	array<BuildingRequest@> genericBuilds;
	const BuildingType@ filterType;

	Actions actions;
	ResourceIncomes incomes;
	Limits limits;

	// Colonization state
	int nextColonizeId = 0;

	// Things we might want to colonize to expand (ie, within 1 hop to the border)
	// Used by the Ancient component, at least for now.
	// Long term would like to make this flexible enough to play Ancient well
	array<PotentialColonize@> potentialColonizations;

	// Things in the queue for colonizing
	ColonizeForest@ queue;
	// Things we need a colonize source to colonize with
	array<ColonizeData@> awaitingSource;
	// Things we are colonizing, includes things that are also in awaitingSource
	array<ColonizeData@> colonizing;

	array<ColonizeData@> loadIds;

	ExpandType expandType;

	void create() {
		@resources = cast<Resources>(ai.resources);
		@planets = cast<Planets>(ai.planets);
		@systems = cast<Systems>(ai.systems);
		@budget = cast<Budget>(ai.budget);
		@creeping = cast<Creeping>(ai.creeping);

		@queue = ColonizeForest();
	}

	void save(SaveFile& file) {
		file << nextColonizeId;
		limits.save(file);

		uint cnt = colonizing.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			saveColonize(file, colonizing[i]);
			cast<ColonizeData2>(colonizing[i]).save(file);
		}

		queue.save(file);

		// TODO: Save potential colonizations?

		cnt = focuses.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ focus = focuses[i];
			cast<DevelopmentFocus2>(focus).save(this, file);
		}

		file << uint(expandType);
	}

	void load(SaveFile& file) {
		file >> nextColonizeId;
		limits.load(file);

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = loadColonize(file);
			if(data !is null) {
				cast<ColonizeData2>(data).load(file);
				if(data.target !is null) {
					colonizing.insertLast(data);
					if(data.colonizeFrom is null)
						awaitingSource.insertLast(data);
				}
				else {
					data.canceled = true;
				}
			}
			else {
				ColonizeData2().load(file);
			}
		}

		queue.load(file);

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
			queue.fillQueueFromRequests(this, ai);
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
	}

	bool isDevelopingIn(Region@ reg) {
		return false;
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
			if(genericBuilds[i].type is type)
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
			if(build.type is filterType && build.plAI.obj is obj)
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

		budget.spend(BT_Colonization, 0, ai.behavior.colonizeBudgetCost);

		colonizing.insertLast(data);
		awaitingSource.insertLast(data);
		return data;
	}

	// Colonizes the best planet in the potentials matching the resource spec
	ColonizeData@ colonize(ResourceSpec@ spec) {
		// TODO: Pick best planet meeting this spec
		return null;
	}

	/* void orderColonization(ColonizeData& data, Planet& sourcePlanet) {
		if(log)
			ai.print("start colonizing "+data.target.name, sourcePlanet);

		if(race !is null) {
			if(race.orderColonization(data, sourcePlanet))
				return;
		}

		@data.colonizeFrom = sourcePlanet;
		awaitingSource.remove(data);

		sourcePlanet.colonize(data.target);
	} */

	// Checks if a planet is being colonized or is in the queue
	bool isColonizing(Planet& pl) {
		for(uint i = 0, cnt = colonizing.length; i < cnt; ++i) {
			if(colonizing[i].target is pl)
				return true;
		}
		return queue.isQueuedForColonizing(pl);
	}

	// Check how recently we colonized something matching the spec
	double timeSinceMatchingColonize(ResourceSpec& spec) {
		return 181.0; // TODO
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
	bool get_BuildBuildings() { return actions.buildBuildings; }
	void set_BuildBuildings(bool value) { actions.buildBuildings = value; }

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
