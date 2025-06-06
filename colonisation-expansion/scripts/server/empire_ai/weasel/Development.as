import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Systems;

import planet_levels;
import buildings;

import ai.consider;
from ai.buildings import Buildings, BuildingAI, BuildingUse;
from ai.resources import AIResources, ResourceAI;

// [[ MODIFY BASE GAME START ]]
from statuses import getStatusID;
from traits import getTraitID;
// [[ MODIFY BASE GAME END ]]

interface RaceDevelopment {
	bool shouldBeFocus(Planet& pl, const ResourceType@ resource);
};

class DevelopmentFocus {
	Object@ obj;
	PlanetAI@ plAI;
	int targetLevel = 0;
	int requestedLevel = 0;
	int maximumLevel = INT_MAX;
	array<ExportData@> managedPressure;
	double weight = 1.0;

	void tick(AI& ai, Development& dev, double time) {
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

	void save(Development& development, SaveFile& file) {
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

	void load(Development& development, SaveFile& file) {
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
};

class Development : AIComponent, Buildings, ConsiderFilter, AIResources, IDevelopment {  // [[ MODIFY BASE GAME ]]
	RaceDevelopment@ race;
	Planets@ planets;
	Resources@ resources;
	IColonization@ colonization; // [[ MODIFY BASE GAME ]]
	Systems@ systems;
	// [[ MODIFY BASE GAME START ]]
	Budget@ budget;
	// [[ MODIFY BASE GAME END ]]

	array<DevelopmentFocus@> focuses; // [[ MODIFY BASE GAME ]]
	array<ExportData@> managedPressure;

	array<ColonizeData@> pendingFocuses;
	array<ColonizeData@> pendingResources;

	array<BuildingRequest@> genericBuilds;
	array<ExportData@> aiResources;

	// [[ MODIFY BASE GAME START ]]
	double aimFTLStorage = 0.0;
	double aimFTLIncome = 1.0;
	// [[ MODIFY BASE GAME END ]]

	bool managePlanetPressure = true;
	bool manageAsteroidPressure = true;
	bool buildBuildings = true;
	bool colonizeResources = true;

	// [[ MODIFY BASE GAME START ]]
	uint nativeLifeStatus = 0;
	const ConstructionType@ uplift_planet;
	const ConstructionType@ genocide_planet;
	bool no_uplift = false;
	uint atmosphere1 = 0;
	uint atmosphere2 = 0;
	uint atmosphere3 = 0;
	double uplift_cost = 800;
	uint currentlyStarlitStatusID = 0;
	uint razingStatusID = 0;
	const ResourceClass@ foodClass;
	const ResourceClass@ waterClass;
	const ResourceClass@ scalableClass;
	// [[ MODIFY BASE GAME END ]]

	void create() {
		@planets = cast<Planets>(ai.planets);
		@resources = cast<Resources>(ai.resources);
		@colonization = cast<IColonization>(ai.colonization); // [[ MODIFY BASE GAME ]]
		@systems = cast<Systems>(ai.systems);
		@race = cast<RaceDevelopment>(ai.race);
		// [[ MODIFY BASE GAME START ]]
		@budget = cast<Budget>(ai.budget);
		// [[ MODIFY BASE GAME END ]]

		//Register specialized building types
		for(uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
			auto@ type = getBuildingType(i);
			for(uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
				auto@ hook = cast<BuildingAI>(type.ai[n]);
				if(hook !is null)
					hook.register(this, type);
			}
		}

		// [[ MODIFY BASE GAME START ]]
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
		atmosphere1 = getBiomeID("Atmosphere1");
		atmosphere2 = getBiomeID("Atmosphere2");
		atmosphere3 = getBiomeID("Atmosphere3");
		currentlyStarlitStatusID = getStatusID("CurrentlyStarlit");
		razingStatusID = getStatusID("ParasiteRaze");
		@foodClass = getResourceClass("Food");
		@waterClass = getResourceClass("WaterType");
		@scalableClass = getResourceClass("Scalable");
		// [[ MODIFY BASE GAME END ]]
	}

	Empire@ get_empire() {
		return ai.empire;
	}

	Considerer@ get_consider() {
		return cast<Considerer>(ai.consider);
	}

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

	void save(SaveFile& file) {
		file << aimFTLStorage;
		// [[ MODIFY BASE GAME START ]]
		file << aimFTLIncome;
		// [[ MODIFY BASE GAME END ]]

		uint cnt = focuses.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ focus = focuses[i];
			focus.save(this, file);
		}

		cnt = managedPressure.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			resources.saveExport(file, managedPressure[i]);

		cnt = pendingFocuses.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			colonization.saveColonize(file, pendingFocuses[i]);

		cnt = pendingResources.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			colonization.saveColonize(file, pendingResources[i]);

		cnt = genericBuilds.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			planets.saveBuildingRequest(file, genericBuilds[i]);

		cnt = aiResources.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			resources.saveExport(file, aiResources[i]);
	}

	void load(SaveFile& file) {
		file >> aimFTLStorage;
		// [[ MODIFY BASE GAME START ]]
		file >> aimFTLIncome;
		// [[ MODIFY BASE GAME END ]]

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ focus = DevelopmentFocus();
			focus.load(this, file);

			if(focus.obj !is null)
				focuses.insertLast(focus);
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = resources.loadExport(file);
			if(data !is null)
				managedPressure.insertLast(data);
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = colonization.loadColonize(file);
			if(data !is null)
				pendingFocuses.insertLast(data);
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = colonization.loadColonize(file);
			if(data !is null)
				pendingResources.insertLast(data);
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = planets.loadBuildingRequest(file);
			if(data !is null)
				genericBuilds.insertLast(data);
		}

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = resources.loadExport(file);
			if(data !is null)
				aiResources.insertLast(data);
		}
	}

	bool requestsFTLStorage() {
		// TODO: Check we actually have an FTL method
		double capacity = ai.empire.FTLCapacity;
		if(aimFTLStorage <= capacity)
			return false;
		if(ai.empire.FTLStored < capacity * 0.5)
			return false;
		return true;
	}

	// [[ MODIFY BASE GAME START ]]
	/*
	 * Mirror the requestsFTLStorage method except this will primarily
	 * be acted on by Improvement.as rather than buildings.as as only Mechanoid
	 * has an FTL income building
	 */
	bool requestsFTLIncome() {
		// TODO: Check we actually have an FTL method
		double income = ai.empire.FTLIncome;
		double unused = income - ai.empire.FTLUse;
		if (unused < aimFTLIncome) {
			return true;
		}
		return false;
	}
	// [[ MODIFY BASE GAME END ]]

	bool isBuilding(const BuildingType& type) {
		for(uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			if(genericBuilds[i].type is type)
				return true;
		}
		return false;
	}

	bool isLeveling() {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj.resourceLevel < uint(focuses[i].targetLevel)) {
				auto@ focus = focuses[i].obj;

				//If all our requirements are resolved, then we can safely assume it will be leveled up
				bool allResolved = true;
				for(uint n = 0, ncnt = resources.requested.length; n < ncnt; ++n) {
					auto@ req = resources.requested[n];
					if(req.obj !is focus)
						continue;
					if(req.beingMet)
						continue;

					if(!req.isColonizing) {
						allResolved = false;
						break;
					}

					if(!colonization.isResolved(req)) {
						allResolved = false;
						break;
					}
				}

				if(!allResolved)
					return true;
			}
		}
		return false;
	}

	bool isBusy() {
		if(pendingFocuses.length != 0)
			return true;
		if(pendingResources.length != 0)
			return true;
		if(isLeveling())
			return true;
		return false;
	}

	bool isFocus(Object@ obj) {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj is obj)
				return true;
		}
		return false;
	}

	bool isManaging(ExportData@ res) {
		for(uint i = 0, cnt = managedPressure.length; i < cnt; ++i) {
			if(managedPressure[i] is res)
				return true;
		}
		for(uint i = 0, cnt = aiResources.length; i < cnt; ++i) {
			if(aiResources[i] is res)
				return true;
		}
		for(uint n = 0, ncnt = focuses.length; n < ncnt; ++n) {
			auto@ f = focuses[n];
			if(f.obj is res.obj)
				return true;
			for(uint i = 0, cnt = f.managedPressure.length; i < cnt; ++i) {
				if(f.managedPressure[i] is res)
					return true;
			}
		}
		return false;
	}

	bool isDevelopingIn(Region@ reg) {
		if(reg is null)
			return false;
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj.region is reg)
				return true;
		}
		return false;
	}

	void start() {
		//Level up the homeworld to level 3 to start with
		for(uint i = 0, cnt = ai.empire.planetCount; i < cnt; ++i) {
			Planet@ homeworld = ai.empire.planetList[i];
			if(homeworld !is null && homeworld.valid) {
				auto@ hwFocus = addFocus(planets.register(homeworld));
				if(homeworld.nativeResourceCount >= 2 || homeworld.primaryResourceLimitLevel >= 3 || cnt == 1)
					hwFocus.targetLevel = 3;
			}
		}
	}

	double idlePenalty = 0;
	void findSomethingToDo() {
		if(idlePenalty > gameTime)
			return;

		double totalChance =
			  ai.behavior.focusDevelopWeight
			+ ai.behavior.focusColonizeNewWeight * sqr(1.0 / double(focuses.length)) // [[ MODIFY BASE GAME START ]]
			+ ai.behavior.focusColonizeHighTierWeight;
		double roll = randomd(0.0, totalChance);

		//Level up one of our existing focuses
		roll -= ai.behavior.focusDevelopWeight;
		if(roll <= 0) {
			DevelopmentFocus@ levelup;
			double totalWeight = 0.0;
			for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
				auto@ f = focuses[i];
				if(f.weight == 0)
					continue;
				if(f.targetLevel >= f.maximumLevel)
					continue;
				totalWeight += f.weight;
				if(randomd() < f.weight / totalWeight)
					@levelup = f;
			}

			if(levelup !is null) {
				levelup.targetLevel += 1;
				if(log)
					ai.print("Develop chose to level this up to "+levelup.targetLevel, levelup.obj);
				return;
			}
			else {
				if(log)
					ai.print("Develop ran out of things to level up.");
			}
		}

		if(!colonizeResources)
			return;

		//Find a scalable or high tier resource to colonize and turn into a focus
		roll -= ai.behavior.focusColonizeNewWeight * sqr(1.0 / double(focuses.length));
		if(roll <= 0) {
			Planet@ newFocus;
			double totalWeight = 0.0;

			// [[ MODIFY BASE GAME START ]]
			for(uint i = 0, cnt = colonization.Potentials.length; i < cnt; ++i) {
				auto@ p = colonization.Potentials[i];
				// [[ MODIFY BASE GAME END ]]

				if(p.resource.level < 3 && p.resource.cls !is scalableClass)
					continue;

				Region@ reg = p.pl.region;
				if(reg is null)
					continue;

				if(colonization.isColonizing(p.pl))
					continue;

				vec2i surfaceSize = p.pl.surfaceGridSize;
				int tiles = surfaceSize.width * surfaceSize.height;
				if(tiles < 144)
					continue;

				auto@ sys = systems.getAI(reg);

				double w = 1.0;
				if(sys.border)
					w *= 0.25;
				if(sys.obj.PlanetsMask & ~ai.mask != 0)
					w *= 0.25;
				if(p.resource.cls is scalableClass)
					w *= 10.0;

				totalWeight += w;
				if(randomd() < w / totalWeight)
					@newFocus = p.pl;
			}

			if(newFocus !is null) {
				auto@ data = colonization.colonize(newFocus);
				if(data !is null)
					pendingFocuses.insertLast(data);
				if(log)
					ai.print("Colonize to become develop focus", data.target);
				return;
			}
			else {
				if(log)
					ai.print("Develop could not find a scalable or high tier resource to make a focus.");
			}
		}

		// [[ MODIFY BASE GAME START ]]
		if(focuses.length == 0)
			return;
		// [[ MODIFY BASE GAME END ]]

		//Find a high tier resource to import to one of our focuses
		roll -= ai.behavior.focusColonizeHighTierWeight;
		if(roll <= 0) {
			ResourceSpec spec;
			spec.type = RST_Level_Minimum;
			spec.level = 3;
			spec.isLevelRequirement = false;

			auto@ data = colonization.colonize(spec);
			if(data !is null) {
				if(log)
					ai.print("Colonize as free resource", data.target);
				pendingResources.insertLast(data);
				return;
			}
			else {
				if(log)
					ai.print("Develop could not find a high tier resource to colonize as free resource.");
			}
		}

		//Try to find a level 2 resource if everything else failed
		{
			ResourceSpec spec;
			spec.type = RST_Level_Minimum;
			spec.level = 2;
			spec.isLevelRequirement = false;

			if(colonization.shouldQueueFor(spec)) {
				auto@ data = colonization.colonize(spec);
				if(data !is null) {
					if(log)
						ai.print("Colonize as free resource", data.target);
					pendingResources.insertLast(data);
					return;
				}
				else {
					if(log)
						ai.print("Develop could not find a level 2 resource to colonize as free resource.");
				}
			}
		}

		idlePenalty = gameTime + randomd(10.0, 40.0);
	}

	uint bldIndex = 0;
	uint aiInd = 0;
	uint presInd = 0;
	uint chkInd = 0;
	void focusTick(double time) override {
		//Remove any resources we're managing that got used
		for(uint i = 0, cnt = managedPressure.length; i < cnt; ++i) {
			ExportData@ res = managedPressure[i];
			if(res.request !is null || res.obj is null || !res.obj.valid || res.obj.owner !is ai.empire || !res.usable) {
				managedPressure.removeAt(i);
				--i; --cnt;
			}
		}

		//Find new resources that we can put in our pressure manager
		uint avCnt = resources.available.length;
		if(avCnt != 0) {
			uint index = randomi(0, avCnt-1);
			for(uint i = 0, cnt = min(avCnt, 3); i < cnt; ++i) {
				uint resInd = (index+i) % avCnt;
				ExportData@ res = resources.available[resInd];
				if(res.usable && res.request is null && res.obj !is null && res.obj.valid && res.obj.owner is ai.empire && res.developUse is null) {
					if(res.resource.ai.length != 0) {
						if(!isManaging(res))
							aiResources.insertLast(res);
					}
					else if(res.resource.totalPressure > 0 && res.resource.exportable) {
						if(!managePlanetPressure && res.obj.isPlanet)
							continue;
						if(!manageAsteroidPressure && res.obj.isAsteroid)
							continue;
						if(!isManaging(res))
							managedPressure.insertLast(res);
					}
				}
			}
		}

		//Distribute managed pressure resources
		if(managedPressure.length != 0) {
			presInd = (presInd+1) % managedPressure.length;
			ExportData@ res = managedPressure[presInd];

			int pressure = res.resource.totalPressure;

			DevelopmentFocus@ onFocus;
			double bestWeight = 0;
			bool havePressure = ai.empire.HasPressure != 0.0;

			for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
				auto@ f = focuses[i];

				int cap = f.obj.pressureCap;
				if(!havePressure)
					cap = 10000;
				int cur = f.obj.totalPressure;

				if(cur + pressure > 2 * cap)
					continue;

				double w = 1.0;
				if(cur + pressure > cap)
					w *= 0.1;

				if(w > bestWeight) {
					bestWeight = w;
					@onFocus = f;
				}
			}

			if(onFocus !is null) {
				if(res.obj !is onFocus.obj)
					res.obj.exportResourceByID(res.resourceId, onFocus.obj);
				else
					res.obj.exportResourceByID(res.resourceId, null);
				@res.developUse = onFocus.obj;

				onFocus.managedPressure.insertLast(res);
				managedPressure.removeAt(presInd);

				if(log)
					ai.print("Take "+res.resource.name+" from "+res.obj.name+" for pressure", onFocus.obj);
			}
		}

		//Use generic AI distribution hooks
		if(aiResources.length != 0) {
			aiInd = (aiInd+1) % aiResources.length;
			ExportData@ res = aiResources[aiInd];
			if(res.request !is null || res.obj is null || !res.obj.valid || res.obj.owner !is ai.empire || !res.usable) {
				aiResources.removeAt(aiInd);
			}
			else {
				Object@ newTarget = res.developUse;
				if(newTarget !is null) {
					if(!newTarget.valid || newTarget.owner !is ai.empire)
						@newTarget = null;
				}

				for(uint i = 0, cnt = res.resource.ai.length; i < cnt; ++i) {
					auto@ hook = cast<ResourceAI>(res.resource.ai[i]);
					if(hook !is null)
						@newTarget = hook.distribute(this, res.resource, newTarget);
				}

				if(newTarget !is res.developUse) {
					if(res.obj !is newTarget)
						res.obj.exportResourceByID(res.resourceId, newTarget);
					else
						res.obj.exportResourceByID(res.resourceId, null);
					@res.developUse = newTarget;
				}
			}
		}

		//Deal with focuses we're colonizing
		for(uint i = 0, cnt = pendingFocuses.length; i < cnt; ++i) {
			auto@ data = pendingFocuses[i];
			if(data.completed) {
				auto@ focus = addFocus(planets.register(data.target));
				focus.targetLevel = 3;

				pendingFocuses.removeAt(i);
				--i; --cnt;
			}
			else if(data.canceled) {
				pendingFocuses.removeAt(i);
				--i; --cnt;
			}
		}

		for(uint i = 0, cnt = pendingResources.length; i < cnt; ++i) {
			auto@ data = pendingResources[i];
			if(data.completed) {
				planets.requestLevel(planets.register(data.target), data.target.primaryResourceLevel);
				pendingResources.removeAt(i);
				--i; --cnt;
			}
			else if(data.canceled) {
				pendingResources.removeAt(i);
				--i; --cnt;
			}
		}

		//If we're not currently leveling something up, find something else to do
		if(!isBusy())
			findSomethingToDo();

		//Deal with building AI hints
		for(uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			auto@ build = genericBuilds[i];
			if(build.canceled) {
				genericBuilds.removeAt(i);
				--i; --cnt;
				// [[ MODIFY BASE GAME START ]]
				if (
					build.plAI.obj.get_Biome0() == atmosphere1
					|| build.plAI.obj.get_Biome0() == atmosphere2
					|| build.plAI.obj.get_Biome0() == atmosphere3
				) {
					// our build failed on this gas giant,
					// probably because we ran out of space
					// and there are probably moons we can still start
					// a moon base with here
					// Set a flag so we can consider building another
					// moon base on this planet from the Improvement.as
					// focus phase
					build.plAI.failedToPlaceBuilding = true;
				}
				// [[ MODIFY BASE GAME END ]]
			}
			else if(build.built) {
				if(build.getProgress() >= 1.f) {
					if(build.expires < gameTime) {
						genericBuilds.removeAt(i);
						--i; --cnt;
					}
				}
				else
					build.expires = gameTime + 60.0;
			}
		}
		if(buildBuildings) {
			for(uint i = 0, cnt = getBuildingTypeCount(); i < cnt; ++i) {
				bldIndex = (bldIndex+1) % cnt;

				auto@ type = getBuildingType(bldIndex);
				if(type.ai.length == 0)
					continue;

				//If we're already generically building something of this type, wait
				bool existing = false;
				for(uint n = 0, ncnt = genericBuilds.length; n < ncnt; ++n) {
					auto@ build = genericBuilds[n];
					if(build.type is type && !build.built) {
						existing = true;
						break;
					}
				}

				// [[ MODIFY BASE GAME START ]]
				// Lighting Systems cannot be built by the AI wrongly because
				// of the later checks in this method, and they have no
				// money maintenance so allow multiple builds at once for them.
				if(existing && type.ident != "LightSystem")
					break;
				// [[ MODIFY BASE GAME END ]]

				@filterType = type;
				@consider.filter = this;

				//See if we should generically build something of this type
				for(uint n = 0, ncnt = type.ai.length; n < ncnt; ++n) {
					auto@ hook = cast<BuildingAI>(type.ai[n]);
					if(hook !is null) {
						Object@ buildOn = hook.considerBuild(this, type);
						if(buildOn !is null && buildOn.isPlanet) {
							auto@ plAI = planets.getAI(cast<Planet>(buildOn));
							// [[ MODIFY BASE GAME START ]]
							// Don't build on planets that are being razed down
							if(plAI !is null && !plAI.obj.hasStatusEffect(razingStatusID)) {
								// [[ MODIFY BASE GAME END ]]
								if(log)
									ai.print("AI hook generically requested building of type "+type.name, buildOn);

								// [[ MODIFY BASE GAME START ]]
								double priority = 1;
								// priorize megafarms, hydrogenerators and lighting systems
								// because these almost always level up planets
								if (type.ident == "Farm" || type.ident == "Hydrogenator" || type.ident == "LightSystem") {
									priority = 2;
								}
								bool skipBuild = false;
								/* if (type.ident == "Farm" || type.ident == "Hydrogenator") {
									// Sanity check to avoid building unneeded Megafarms
									// and Hydrogenators, this shouldn't need to trigger, as
									// the building hook code has a number of checks
									// that should ensure we didn't have any available food/water
									// planets, but none of them are actually explicit.
									// The building hook actually does sometimes try to build food/water
									// when the resource can be imported instead, which costs
									// less maintenance, so it is preferable to tell the AI
									// explicitly not to build them and import the resource instead.
									const ResourceClass@ cls;
									if (type.ident == "Farm")
										@cls = foodClass;
									if (type.ident == "Hydrogenator")
										@cls = waterClass;
									ai.print("Checking if need building "+type.name+" on "+plAI.obj.name+".");
									array<ImportData@> activeRequests = resources.getRequestedResources(plAI.obj);
									bool needFoodOrWater = false;
									for (uint i = 0, cnt = activeRequests.length; i < cnt && !needFoodOrWater; ++i) {
										ResourceSpec@ spec = activeRequests[i].spec;
										if (spec !is null && spec.cls !is null && spec.cls.id == cls.id) {
											needFoodOrWater = true;
										}
									}
									if (!needFoodOrWater) {
										ai.print("Skipped building "+type.name+" on "+plAI.obj.name+" after checking requests.");
										skipBuild = true;
									} else {
										resources.organizeImports(plAI.obj, plAI.targetLevel);
										// This is especially a bit of an ugly hack ticking a
										// component from another, but it will ensure all
										// requested resources are matched with available
										resources.focusTick(time);
										// check after organising and importing resources on this planet if we
										// really still need the building
										activeRequests = resources.getRequestedResources(plAI.obj);
										needFoodOrWater = false;
										for (uint i = 0, cnt = activeRequests.length; i < cnt && !needFoodOrWater; ++i) {
											ResourceSpec@ spec = activeRequests[i].spec;
											if (spec !is null && spec.cls !is null && spec.cls.id == cls.id) {
												needFoodOrWater = true;
											}
										}
										if (!needFoodOrWater) {
											ai.print("Skipped building "+type.name+" on "+plAI.obj.name+" after organising imports.");
											skipBuild = true;
										}
									}
									if (!skipBuild) {
										ai.print("Building "+type.name+" on "+plAI.obj.name+".");
									}
								} */
								if (type.ident == "LightSystem" && plAI.obj.hasStatusEffect(currentlyStarlitStatusID)) {
									// don't build artificial lighting on a planet with starlight
									skipBuild = true;
								}

								if (!skipBuild) {
									auto@ req = planets.requestBuilding(plAI, type, priority=priority, expire=ai.behavior.genericBuildExpire);
									if (req !is null) {
										genericBuilds.insertLast(req);
									}
								}
								// [[ MODIFY BASE GAME END ]]
								break;
							}
						}
					}
				}
				break;
			}
		}

		//Find planets we've acquired 'somehow' that have scalable resources and should be development focuses
		if(planets.planets.length != 0) {
			chkInd = (chkInd+1) % planets.planets.length;
			auto@ plAI = planets.planets[chkInd];

			// [[ MODIFY BASE GAME START ]]
			// handle native life status on planets
			if (plAI.obj.hasStatusEffect(nativeLifeStatus)) {
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
							auto@ focus = addFocus(plAI);
							focus.targetLevel = 3;
						// the existing development code will handle levelling the planet up further
						// as it will see a tier 2 resource planet (and see that it
						// just needs food and water to reach level 3)
						// from testing the AI is capable of providing water/food to these planets
						// and will also sometimes take them to level 4 so they must be recognised
						// correctly
					} else {
						if (log) {
							ai.print("cant afford uplift, taking over planet");
						}
						// this is high priority because until the NativeLife status is removed the
						// AI may think it can use this planet as an export and get very confused or
						// cripple its resource chains which would be very bad.
						planets.requestConstruction(
							plAI, plAI.obj, genocide_planet, priority=3, expire=gameTime + 600, moneyType=BT_Development);
					}
				}
			}
			// [[ MODIFY BASE GAME END ]]

			if(plAI.resources.length != 0) {
				auto@ res = plAI.resources[0];
				if(res.resource.cls is scalableClass
					|| focuses.length == 0 && res.resource.level >= 2
					|| (race !is null && race.shouldBeFocus(plAI.obj, res.resource))) {
					if(!isFocus(plAI.obj)) {
						auto@ focus = addFocus(plAI);
						focus.targetLevel = max(1, res.resource.level);
					}
				}
			}
		}
	}

	DevelopmentFocus@ addFocus(PlanetAI@ plAI) {
		DevelopmentFocus focus;
		@focus.obj = plAI.obj;
		@focus.plAI = plAI;
		focus.maximumLevel = getMaxPlanetLevel(plAI.obj);

		focuses.insertLast(focus);
		return focus;
	}

	DevelopmentFocus@ getFocus(Planet& pl) {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i) {
			if(focuses[i].obj is pl)
				return focuses[i];
		}
		return null;
	}

	void tick(double time) override {
		for(uint i = 0, cnt = focuses.length; i < cnt; ++i)
			focuses[i].tick(ai, this, time);
	}

	const BuildingType@ filterType;
	bool filter(Object@ obj) {
		for(uint i = 0, cnt = genericBuilds.length; i < cnt; ++i) {
			auto@ build = genericBuilds[i];
			if(build.type is filterType && build.plAI.obj is obj)
				return false;
		}
		return true;
	}

	// [[ MODIFY BASE GAME START ]]
	array<DevelopmentFocus@> get_Focuses() {
		return focuses;
	}

	double get_AimFTLStorage() { return aimFTLStorage; }
	void set_AimFTLStorage(double value) { aimFTLStorage = value; }
	double get_AimFTLIncome() { return aimFTLIncome; }
	void set_AimFTLIncome(double value) { aimFTLIncome = value; }
	bool get_ManagePlanetPressure() { return managePlanetPressure; }
	void set_ManagePlanetPressure(bool value) { managePlanetPressure = value; }
	bool get_BuildBuildings() { return buildBuildings; }
	void set_BuildBuildings(bool value) { buildBuildings = value; }
	bool get_ColonizeResources() { return colonizeResources; }
	void set_ColonizeResources(bool value) { colonizeResources = value; }
	// [[ MODIFY BASE GAME END ]]
};

AIComponent@ createDevelopment() {
	return Development();
}

// [[ MODIFY BASE GAME START ]]
// Define the interface that other AI components use to interact with this one,
// so this component can be swapped out.
interface IDevelopment {
	// Gets the development focus list, other components use this to decide
	// where to build other things like FTL
	array<DevelopmentFocus@> get_Focuses();
	// Checks if we have any development focuses in this region
	bool isDevelopingIn(Region@ reg);
	// gets the development focus for a planet if it exists
	DevelopmentFocus@ getFocus(Planet& pl);
	// Checks if we need more FTL storage
	bool requestsFTLStorage();
	// Checks if we need more FTL income
	bool requestsFTLIncome();
	double get_AimFTLStorage();
	void set_AimFTLStorage(double value);
	double get_AimFTLIncome();
	void set_AimFTLIncome(double value);
	void set_ManagePlanetPressure(bool value);
	void set_ColonizeResources(bool value);
	void set_BuildBuildings(bool value);
}
// [[ MODIFY BASE GAME END ]]
