import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.race.Race;

import empire_ai.weasel.Colonization;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Development;
import empire_ai.weasel.Fleets;
import empire_ai.weasel.Movement;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Designs;

import oddity_navigation;
from abilities import getAbilityID;
from statuses import getStatusID;

class HabitatMission : Mission {
	Planet@ target;
	MoveOrder@ move;
	double timer = 0.0;

	void save(Fleets& fleets, SaveFile& file) override {
		file << target;
		file << timer;
		fleets.movement.saveMoveOrder(file, move);
	}

	void load(Fleets& fleets, SaveFile& file) override {
		file >> target;
		file >> timer;
		@move = fleets.movement.loadMoveOrder(file);
	}

	void start(AI& ai, FleetAI& fleet) override {
		uint prior = MP_Normal;
		if(gameTime < 30.0 * 60.0)
			prior = MP_Critical;
		@move = cast<Movement>(ai.movement).move(fleet.obj, target, prior);
	}

	void tick(AI& ai, FleetAI& fleet, double time) override {
		if(move !is null) {
			if(move.failed) {
				canceled = true;
				return;
			}
			if(move.completed) {
				int ablId = cast<StarChildren>(ai.race).habitatAbl;
				fleet.obj.activateAbilityTypeFor(ai.empire, ablId, target);

				@move = null;
				timer = gameTime + 60.0;
			}
		}
		else {
			if(target is null || !target.valid || target.quarantined
					|| (target.owner !is ai.empire && target.owner.valid)
					|| target.inCombat) {
				canceled = true;
				return;
			}

			double maxPop = max(double(target.maxPopulation), double(getPlanetLevel(target, target.primaryResourceLevel).population));
			double curPop = target.population;
			if(curPop >= maxPop) {
				completed = true;
				return;
			}

			if(gameTime >= timer) {
				int popStatus = cast<StarChildren>(ai.race).popStatus;
				if(target.getStatusStackCountAny(popStatus) >= 5) {
					canceled = true;
					return;
				}
			}
		}
	}
};

class LaborMission : Mission {
	Planet@ target;
	MoveOrder@ move;
	double timer = 0.0;

	void save(Fleets& fleets, SaveFile& file) override {
		file << target;
		file << timer;
		fleets.movement.saveMoveOrder(file, move);
	}

	void load(Fleets& fleets, SaveFile& file) override {
		file >> target;
		file >> timer;
		@move = fleets.movement.loadMoveOrder(file);
	}

	void start(AI& ai, FleetAI& fleet) override {
		@move = cast<Movement>(ai.movement).move(fleet.obj, target);
	}

	void tick(AI& ai, FleetAI& fleet, double time) override {
		if(move !is null) {
			if(move.failed) {
				canceled = true;
				return;
			}
			if(move.completed) {
				@move = null;
				timer = gameTime + 10.0;
			}
		}
		else {
			if(target is null || !target.valid || target.quarantined
					|| target.owner !is ai.empire) {
				canceled = true;
				return;
			}

			if(gameTime >= timer) {
				int popStatus = cast<StarChildren>(ai.race).popStatus;
				timer = gameTime + 10.0;
				if(target.getStatusStackCountAny(popStatus) >= 10) {
					completed = true;
					return;
				}
			}
		}
	}
};

class StarChildren : Race {
	IColonization@ colonization; // [[ MODIFY BASE GAME START ]]
	Construction@ construction;
	IDevelopment@ development;  // [[ MODIFY BASE GAME START ]]
	Movement@ movement;
	Planets@ planets;
	Fleets@ fleets;
	Designs@ designs;

	DesignTarget@ mothershipDesign;
	double idleSince = 0;

	array<FleetAI@> motherships;

	int habitatAbl = -1;
	int popStatus = -1;

	array<Planet@> popRequests;
	array<Planet@> laborPlanets;

	BuildFlagship@ mcBuild;
	BuildOrbital@ yardBuild;

	void save(SaveFile& file) override {
		designs.saveDesign(file, mothershipDesign);
		file << idleSince;
		construction.saveConstruction(file, mcBuild);
		construction.saveConstruction(file, yardBuild);

		uint cnt = motherships.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			fleets.saveAI(file, motherships[i]);
	}

	void load(SaveFile& file) override {
		@mothershipDesign = designs.loadDesign(file);
		file >> idleSince;
		@mcBuild = cast<BuildFlagship>(construction.loadConstruction(file));
		@yardBuild = cast<BuildOrbital>(construction.loadConstruction(file));

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ flAI = fleets.loadAI(file);
			if(flAI !is null)
				motherships.insertLast(flAI);
		}
	}

	void create() override {
		// [[ MODIFY BASE GAME START ]]
		@colonization = cast<IColonization>(ai.colonization);
		colonization.PerformColonization = false;

		@development = cast<IDevelopment>(ai.development);
		development.ManagePlanetPressure = false;
		development.BuildBuildings = false;
		// [[ MODIFY BASE GAME END ]]

		@fleets = cast<Fleets>(ai.fleets);
		@construction = cast<Construction>(ai.construction);
		@planets = cast<Planets>(ai.planets);
		@designs = cast<Designs>(ai.designs);
		@movement = cast<Movement>(ai.movement);

		@ai.defs.Factory = null;
		@ai.defs.LaborStorage = null;

		habitatAbl = getAbilityID("MothershipColonize");
		popStatus = getStatusID("MothershipPopulation");
	}

	void start() override {
		//Get the Tier 1 in our home system
		{
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 1;
			spec.isForImport = false;
			spec.isLevelRequirement = false;

			colonization.queueColonizeLowPriority(spec);
		}

		//Then find a Tier 2 to get
		{
			ResourceSpec spec;
			spec.type = RST_Level_Specific;
			spec.level = 2;
			spec.isForImport = false;
			spec.isLevelRequirement = false;

			colonization.queueColonizeLowPriority(spec);
		}

		// [[ MODIFY BASE GAME START ]]
		// Design a mothership
		// Code borrowed from Verdant to look through our default designs
		// to find the predesigned small mothership
		ReadLock lock(ai.empire.designMutex);
		for(uint i = 0, cnt = ai.empire.designCount; i < cnt; ++i) {
			const Design@ dsg = ai.empire.getDesign(i);
			if(dsg.newer !is null)
				continue;
			if(dsg.updated !is null)
				continue;

			uint goal = designs.classify(dsg, DP_Unknown);
			if(goal == DP_Unknown)
				continue;

			if (goal == DP_Mothership && dsg.size == 500) {
				@mothershipDesign = DesignTarget();
				mothershipDesign.set(dsg);
			}
		}

		// a second mothership doubles early expansion rates
		construction.buildFlagship(mothershipDesign, force=true);
		// [[ MODIFY BASE GAME END ]]
	}

	bool requiresPopulation(Planet& target) {
		double maxPop = max(double(target.maxPopulation), double(getPlanetLevel(target, target.primaryResourceLevel).population));
		double curPop = target.population;
		return curPop < maxPop;
	}

	uint chkInd = 0;
	void focusTick(double time) override {
		//Detect motherships
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if(flAI.fleetClass != FC_Mothership)
				continue;

			if(motherships.find(flAI) == -1) {
				//Add to our tracking list
				flAI.obj.autoFillSupports = false;
				flAI.obj.allowFillFrom = true;
				motherships.insertLast(flAI);

				//Add as a factory
				construction.registerFactory(flAI.obj);
			}
		}

		for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
			Object@ obj = motherships[i].obj;
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				motherships.removeAt(i);
				--i; --cnt;
			}
		}

		//Detect planets that require more population
		for(uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
			auto@ obj = popRequests[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				popRequests.removeAt(i);
				--i; --cnt;
				continue;
			}
			if(!requiresPopulation(obj)) {
				popRequests.removeAt(i);
				--i; --cnt;
				continue;
			}
		}

		for(uint i = 0, cnt = laborPlanets.length; i < cnt; ++i) {
			auto@ obj = laborPlanets[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				laborPlanets.removeAt(i);
				--i; --cnt;
				continue;
			}
			if(obj.laborIncome < 3.0/60.0) {
				laborPlanets.removeAt(i);
				--i; --cnt;
				continue;
			}
		}

		uint plCnt = planets.planets.length;
		for(uint n = 0, cnt = min(15, plCnt); n < cnt; ++n) {
			chkInd = (chkInd+1) % plCnt;
			auto@ plAI = planets.planets[chkInd];

			//Find planets that need population
			if(requiresPopulation(plAI.obj)) {
				if(popRequests.find(plAI.obj) == -1)
					popRequests.insertLast(plAI.obj);
			}

			//Find planets that have labor
			if(plAI.obj.laborIncome >= 3.0/60.0) {
				if(laborPlanets.find(plAI.obj) == -1)
					laborPlanets.insertLast(plAI.obj);
			}
		}

		//Send motherships to do colonization
		uint totalCount = popRequests.length + colonization.AwaitingSource.length; // [[ MODIFY BASE GAME ]]
		uint motherCount = idleMothershipCount();

		// [[ MODIFY BASE GAME START ]]
		// Star Children can colonise with all available motherships at once
		//ai.behavior.maxConcurrentColonizations = motherships.length;
		// [[ MODIFY BASE GAME END ]]

		/*if(motherCount > totalCount) {*/
			for(uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
				Planet@ dest = popRequests[i];
				if(isColonizing(dest))
					continue;
				if(dest.inCombat)
					continue;

				colonizeBest(dest);
			}

			// [[ MODIFY BASE GAME START ]]
			for(uint i = 0, cnt = colonization.AwaitingSource.length; i < cnt; ++i) {
				Planet@ dest = colonization.AwaitingSource[i].target;
				// [[ MODIFY BASE GAME END ]]
				if(isColonizing(dest))
					continue;

				colonizeBest(dest);
			}
		/*}*/
		/*else {*/
		/*	for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {*/
		/*		auto@ flAI = motherships[i];*/
		/*		if(flAI.mission !is null)*/
		/*			continue;*/
		/*		if(isBuildingWithLabor(flAI))*/
		/*			continue;*/

		/*		colonizeBest(flAI);*/
		/*	}*/
		/*}*/

		if(totalCount != 0)
			idleSince = gameTime;

		//See if we should build new motherships
		uint haveMC = motherships.length;
		// [[ MODIFY BASE GAME START ]]
		uint wantMC = 3;
		// [[ MODIFY BASE GAME END ]]
		if(gameTime > 20.0 * 60.0)
			wantMC += 1;
		// [[ MODIFY BASE GAME START ]]
		wantMC = max(wantMC, uint(gameTime/(30.0*60.0)));
		// [[ MODIFY BASE GAME END ]]

		if(mcBuild !is null && mcBuild.completed)
			@mcBuild = null;
		if(wantMC > haveMC && mcBuild is null)
			@mcBuild = construction.buildFlagship(mothershipDesign, force=true);

		if(yardBuild is null && haveMC > 0 && gameTime > 60 && gameTime < 180 && ai.defs.Shipyard !is null) {
			Region@ reg = motherships[0].obj.region;
			if(reg !is null) {
				vec3d pos = reg.position;
				vec2d offset = random2d(reg.radius * 0.4, reg.radius * 0.8);
				pos.x += offset.x;
				pos.z += offset.y;

				@yardBuild = construction.buildOrbital(ai.defs.Shipyard, pos);
			}
		}

		if(motherships.length == 1)
			@colonization.ColonizeWeightObj = motherships[0].obj; // [[ MODIFY BASE GAME ]]
		else
			@colonization.ColonizeWeightObj = null; // [[ MODIFY BASE GAME ]]

		//Idle motherships should be sent to go collect labor from labor planets
		if(laborPlanets.length != 0) {
			for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
				auto@ flAI = motherships[i];
				if(flAI.mission !is null)
					continue;
				if(isAtLaborPlanet(flAI))
					continue;
				if(i == 0 && idleSince < gameTime-60.0)
					continue;

				double bestDist = INFINITY;
				Planet@ best;
				for(uint n = 0, ncnt = laborPlanets.length; n < ncnt; ++n) {
					Planet@ check = laborPlanets[n];
					if(hasMothershipAt(check))
						continue;

					double d = movement.getPathDistance(flAI.obj.position, check.position);
					if(d < bestDist) {
						@best = check;
						bestDist = d;
					}
				}

				if(best !is null) {
					LaborMission miss;
					@miss.target = best;

					fleets.performMission(flAI, miss);
				}
			}
		}
	}

	bool isAtLaborPlanet(FleetAI& flAI) {
		auto@ miss = cast<LaborMission>(flAI);
		if(miss !is null)
			return true;

		for(uint i = 0, cnt = laborPlanets.length; i < cnt; ++i) {
			if(flAI.obj.isLockedOrbit(laborPlanets[i]))
				return true;
		}
		return false;
	}

	bool isBuildingWithLabor(FleetAI& flAI) {
		auto@ f = construction.get(flAI.obj);
		if(f !is null && f.active !is null)
			return false;
		if(isAtLaborPlanet(flAI))
			return true;
		return false;
	}

	bool hasMothershipAt(Planet& pl) {
		for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
			auto@ flAI = motherships[i];

			auto@ miss = cast<LaborMission>(flAI);
			if(miss !is null && miss.target is pl)
				return true;

			if(flAI.obj.isLockedOrbit(pl))
				return true;
		}
		return false;
	}

	uint idleMothershipCount() {
		uint count = 0;
		for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
			if(motherships[i].mission is null)
				count += 1;
		}
		return count;
	}

	bool isColonizing(Planet& dest) {
		for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
			auto@ flAI = motherships[i];
			auto@ miss = cast<HabitatMission>(flAI.mission);
			if(miss !is null && miss.target is dest)
				return true;
		}
		return false;
	}

	Planet@ colonizeBest(FleetAI& flAI) {
		Planet@ best;
		double bestDist = INFINITY;
		for(uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
			Planet@ dest = popRequests[i];
			if(isColonizing(dest))
				continue;
			if(dest.inCombat)
				continue;

			double d = movement.getPathDistance(flAI.obj.position, dest.position);
			if(d < bestDist) {
				@best = dest;
				bestDist = d;
			}
		}

		if(best is null) {
			// [[ MODIFY BASE GAME START ]]
			for(uint i = 0, cnt = colonization.AwaitingSource.length; i < cnt; ++i) {
				Planet@ dest = colonization.AwaitingSource[i].target;
				// [[ MODIFY BASE GAME END ]]
				if(isColonizing(dest))
					continue;

				double d = movement.getPathDistance(flAI.obj.position, dest.position);
				if(d < bestDist) {
					@best = dest;
					bestDist = d;
				}
			}
		}

		if(best !is null) {
			HabitatMission miss;
			@miss.target = best;

			fleets.performMission(flAI, miss);
		}
		return best;
	}

	FleetAI@ colonizeBest(Planet& dest) {
		FleetAI@ best;
		double bestDist = INFINITY;
		for(uint i = 0, cnt = motherships.length; i < cnt; ++i) {
			auto@ flAI = motherships[i];
			if(flAI.mission !is null)
				continue;
			if(isBuildingWithLabor(flAI))
				continue;

			double d = movement.getPathDistance(flAI.obj.position, dest.position);
			if(d < bestDist) {
				@best = flAI;
				bestDist = d;
			}
		}

		if(best !is null) {
			HabitatMission miss;
			@miss.target = dest;

			fleets.performMission(best, miss);
		}
		return best;
	}
};

AIComponent@ createStarChildren() {
	return StarChildren();
}
