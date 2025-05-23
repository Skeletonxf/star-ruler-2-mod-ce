// Fleets
// ------
// Manages data about fleets and missions, as well as making sure fleets
// return to their station after a mission.
//

import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Systems;
import empire_ai.weasel.Designs;
import empire_ai.weasel.Movement;

// [[ MODIFY BASE GAME START ]]
import empire_ai.dragon.AbilityAI;
// [[ MODIFY BASE GAME END ]]

enum FleetClass {
	FC_Scout,
	FC_Combat,
	FC_Slipstream,
	FC_Mothership,
	// [[ MODIFY BASE GAME START ]]
	// A frostkin star eater ship
	FC_StarEater,
	// [[ MODIFY BASE GAME END ]]

	FC_ALL
};

enum MissionPriority {
	MiP_Background,
	MiP_Normal,
	MiP_High,
	MiP_Critical,
}

class Mission {
	int id = -1;
	bool completed = false;
	bool canceled = false;
	uint priority = MiP_Normal;

	void _save(Fleets& fleets, SaveFile& file) {
		file << completed;
		file << canceled;
		file << priority;
		save(fleets, file);
	}

	void _load(Fleets& fleets, SaveFile& file) {
		file >> completed;
		file >> canceled;
		file >> priority;
		load(fleets, file);
	}

	void save(Fleets& fleets, SaveFile& file) {
	}

	void load(Fleets& fleets, SaveFile& file) {
	}

	bool get_isActive() {
		return true;
	}

	double getPerformWeight(AI& ai, FleetAI& fleet) {
		return 1.0;
	}

	void start(AI& ai, FleetAI& fleet) {
	}

	void cancel(AI& ai, FleetAI& fleet) {
	}

	void tick(AI& ai, FleetAI& fleet, double time) {
	}
};

// [[ MODIFY BASE GAME START ]]
/**
 * An interface for other components to register themselves as listeners onto
 * the Fleets component so they can respond to fleet changes without having
 * to go though all the effort of tracking each fleet they care about
 * along its entire lifetime.
 */
interface FleetEventListener {
	/**
	 * A FleetAI that was previously tracked is no longer valid for tracking
	 */
	void onRemovedFleetAI(FleetAI@ flAI);
}
// [[ MODIFY BASE GAME END ]]

final class FleetAI {
	uint fleetClass;
	Object@ obj;
	Mission@ mission;

	Region@ stationed;
	bool stationedFactory = true;

	double filled = 0.0;
	double idleSince = 0.0;
	double fillStaticSince = 0.0;
	// [[ MODIFY BASE START ]]
	AbilityAI@ abilities;
	// [[ MODIFY BASE GAME END ]]

	void save(Fleets& fleets, SaveFile& file) {
		file << fleetClass;
		file << stationed;
		file << filled;
		file << idleSince;
		file << fillStaticSince;
		file << stationedFactory;

		fleets.saveMission(file, mission);
		// [[ MODIFY BASE GAME START ]]
		bool hasAbilities = abilities !is null;
		file << hasAbilities;
		// [[ MODIFY BASE GAME END ]]
	}

	void load(Fleets& fleets, SaveFile& file) {
		file >> fleetClass;
		file >> stationed;
		file >> filled;
		file >> idleSince;
		file >> fillStaticSince;
		file >> stationedFactory;

		@mission = fleets.loadMission(file);
		// [[ MODIFY BASE GAME START ]]
		bool hasAbilities = false;
		file >> hasAbilities;
		if (hasAbilities) {
			@abilities = fleets.abilities.register(obj);
		}
		// [[ MODIFY BASE GAME END ]]
	}

	bool get_isHome() {
		if(stationed is null)
			return true;
		return obj.region is stationed;
	}

	bool get_busy() {
		return mission !is null;
	}

	double get_strength() {
		return obj.getFleetStrength();
	}

	double get_supplies() {
		Ship@ ship = cast<Ship>(obj);
		if(ship is null)
			return 1.0;
		double maxSupply = ship.MaxSupply;
		if(maxSupply <= 0)
			return 1.0;
		return ship.Supply / maxSupply;
	}

	double get_remainingSupplies() {
		Ship@ ship = cast<Ship>(obj);
		if(ship is null)
			return 0.0;
		return ship.Supply;
	}

	double get_radius() {
		return obj.getFormationRadius();
	}

	double get_fleetHealth() {
		return obj.getFleetStrength() / obj.getFleetMaxStrength();
	}

	double get_flagshipHealth() {
		Ship@ ship = cast<Ship>(obj);
		if(ship is null)
			return 1.0;
		return ship.blueprint.currentHP / ship.blueprint.design.totalHP;
	}

	bool get_actionableState() {
		if(isHome && obj.hasOrderedSupports && stationedFactory)
			return false;
		if(supplies < 0.75)
			return false;
		if(filled < 0.5)
			return false;
		if(filled < 1.0 && gameTime < fillStaticSince + 90.0)
			return false;
		return true;
	}

	bool get_readyForAction() {
		if(mission !is null)
			return false;
		if(isHome && obj.hasOrderedSupports && stationedFactory)
			return false;
		if(supplies < 0.75)
			return false;
		if(filled < 0.5)
			return false;
		if(filled < 1.0 && gameTime < fillStaticSince + 90.0)
			return false;
		if(obj.isMoving) {
			if(obj.velocity.length / obj.maxAcceleration > 16.0)
				return false;
		}
		return true;
	}

	bool tick(AI& ai, Fleets& fleets, double time) {
		//Make sure we still exist
		if(!obj.valid || obj.owner !is ai.empire) {
			if(mission !is null) {
				mission.canceled = true;
				@mission = null;
			}
			return false;
		}

		//Record data
		int supUsed = obj.SupplyUsed;
		int supCap = obj.SupplyCapacity;
		int supGhost = obj.SupplyGhost;
		int supOrdered = obj.SupplyOrdered;

		double newFill = 1.0;
		if(supCap > 0.0)
			newFill = double(supUsed - supGhost - supOrdered) / double(supCap);
		if(newFill != filled) {
			fillStaticSince = gameTime;
			filled = newFill;
		}

		//Perform our mission
		if(mission !is null) {
			if(!mission.completed && !mission.canceled)
				mission.tick(ai, this, time);
			if(mission.completed || mission.canceled) {
				@mission = null;
				idleSince = gameTime;
			}
		}

		//Return to where we're stationed if we're not doing anything
		if(mission is null && stationed !is null && fleetClass != FC_Scout) {
			if(gameTime >= idleSince + ai.behavior.fleetIdleReturnStationedTime) {
				if(obj.region !is stationed && !obj.hasOrders) {
					if(fleets.log)
						ai.print("Returning to station in "+stationed.name, obj);
					fleets.movement.move(obj, stationed, spread=true);
				}
			}
		}
		return true;
	}

	// [[ MODIFY BASE START ]]
	// TODO: Methods for firing any ion cannon abilities we have
	// [[ MODIFY BASE GAME END ]]
};

class Fleets : AIComponent {
	Systems@ systems;
	Designs@ designs;
	Movement@ movement;
	// [[ MODIFY BASE GAME START ]]
	AbilitiesComponentI@ abilities;
	// [[ MODIFY BASE GAME END ]]

	array<FleetAI@> fleets;

	int nextMissionId = 0;
	double totalStrength = 0;
	double totalMaxStrength = 0;

	// [[ MODIFY BASE GAME START ]]
	array<FleetEventListener@> listeners;
	// [[ MODIFY BASE GAME END ]]

	void create() {
		@systems = cast<Systems>(ai.systems);
		@designs = cast<Designs>(ai.designs);
		@movement = cast<Movement>(ai.movement);
		// [[ MODIFY BASE GAME START ]]
		@abilities = cast<AbilitiesComponentI>(ai.abilities);
		// [[ MODIFY BASE GAME END ]]
	}

	void save(SaveFile& file) {
		file << nextMissionId;
		file << totalStrength;
		file << totalMaxStrength;

		uint cnt = fleets.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			saveAI(file, fleets[i]);
			fleets[i].save(this, file);
		}
	}

	void load(SaveFile& file) {
		file >> nextMissionId;
		file >> totalStrength;
		file >> totalMaxStrength;

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			FleetAI@ flAI = loadAI(file);
			if(flAI !is null)
				flAI.load(this, file);
			else
				FleetAI().load(this, file);
		}
	}

	void saveAI(SaveFile& file, FleetAI@ flAI) {
		if(flAI is null) {
			file.write0();
			return;
		}
		file.write1();
		file << flAI.obj;
	}

	FleetAI@ loadAI(SaveFile& file) {
		if(!file.readBit())
			return null;

		Object@ obj;
		file >> obj;

		if(obj is null)
			return null;

		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			if(fleets[i].obj is obj)
				return fleets[i];
		}

		FleetAI flAI;
		@flAI.obj = obj;
		fleets.insertLast(flAI);
		return flAI;
	}

	array<Mission@> savedMissions;
	array<Mission@> loadedMissions;
	void postSave(AI& ai) {
		savedMissions.length = 0;
	}
	void postLoad(AI& ai) {
		loadedMissions.length = 0;
	}

	void saveMission(SaveFile& file, Mission@ mission) {
		if(mission is null) {
			file.write0();
			return;
		}

		file.write1();
		file << mission.id;
		if(mission.id == -1) {
			storeMission(file, mission);
		}
		else {
			bool found = false;
			for(uint i = 0, cnt = savedMissions.length; i < cnt; ++i) {
				if(savedMissions[i] is mission) {
					found = true;
					break;
				}
			}

			if(!found) {
				storeMission(file, mission);
				savedMissions.insertLast(mission);
			}
		}
	}

	Mission@ loadMission(SaveFile& file) {
		if(!file.readBit())
			return null;

		int id = 0;
		file >> id;
		if(id == -1) {
			Mission@ miss = createMission(file);
			miss.id = id;
			return miss;
		}
		else {
			for(uint i = 0, cnt = loadedMissions.length; i < cnt; ++i) {
				if(loadedMissions[i].id == id)
					return loadedMissions[i];
			}

			Mission@ miss = createMission(file);
			miss.id = id;
			loadedMissions.insertLast(miss);
			return miss;
		}
	}

	void storeMission(SaveFile& file, Mission@ mission) {
		auto@ cls = getClass(mission);
		auto@ mod = cls.module;

		file << mod.name;
		file << cls.name;
		mission._save(this, file);
	}

	Mission@ createMission(SaveFile& file) {
		string modName;
		string clsName;

		file >> modName;
		file >> clsName;

		auto@ mod = getScriptModule(modName);
		if(mod is null) {
			error("ERROR: AI Load could not find module for mission "+modName+"::"+clsName);
			return null;
		}

		auto@ cls = mod.getClass(clsName);
		if(cls is null) {
			error("ERROR: AI Load could not find class for mission "+modName+"::"+clsName);
			return null;
		}

		auto@ miss = cast<Mission>(cls.create());
		if(miss is null) {
			error("ERROR: AI Load could not create class instance for mission "+modName+"::"+clsName);
			return null;
		}

		miss._load(this, file);
		return miss;
	}

	void checkForFleets() {
		auto@ data = ai.empire.getFlagships();
		Object@ obj;
		while(receive(data, obj)) {
			if(obj !is null)
				register(obj);
		}
	}

	bool haveCombatReadyFleets() {
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if(flAI.fleetClass != FC_Combat)
				continue;
			if(!flAI.readyForAction)
				continue;
			return true;
		}
		return false;
	}

	uint countCombatReadyFleets() {
		uint count = 0;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if(flAI.fleetClass != FC_Combat)
				continue;
			if(!flAI.readyForAction)
				continue;
			count += 1;
		}
		return count;
	}

	bool allFleetsCombatReady() {
		bool have = false;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if(flAI.fleetClass != FC_Combat)
				continue;
			if(!flAI.readyForAction)
				return false;
			have = true;
		}
		return have;
	}

	uint prevFleetCount = 0;
	double checkTimer = 0;
	void focusTick(double time) override {
		//Check for any newly obtained fleets
		uint curFleetCount = ai.empire.fleetCount;
		checkTimer += time;
		if(curFleetCount != prevFleetCount || checkTimer > 60.0) {
			checkForFleets();
			prevFleetCount = curFleetCount;
			checkTimer = 0;
		}

		//Calculate our current strengths
		totalStrength = 0;
		totalMaxStrength = 0;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			totalStrength += sqrt(fleets[i].obj.getFleetStrength());
			totalMaxStrength += sqrt(fleets[i].obj.getFleetMaxStrength());
		}
		totalStrength = sqr(totalStrength);
		totalMaxStrength = sqr(totalMaxStrength);
	}

	double getTotalStrength(uint checkClass, bool idleOnly = false, bool readyOnly = false) {
		double str = 0.0;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if((flAI.fleetClass == checkClass || checkClass == FC_ALL)
				&& (!idleOnly || flAI.mission is null)
				&& (!readyOnly || flAI.readyForAction))
				str += sqrt(fleets[i].obj.getFleetStrength());
		}
		return str*str;
	}

	void tick(double time) override {
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			if(!fleets[i].tick(ai, this, time)) {
				// [[ MODIFY BASE GAME START ]]
				// Tell everything that is listening
				for (uint j = 0, jcnt = listeners.length; j < jcnt; ++j) {
					listeners[j].onRemovedFleetAI(fleets[i]);
				}
				// [[ MODIFY BASE GAME END ]]
				fleets.removeAt(i);
				--i; --cnt;
				continue;
			}

			Region@ reg = fleets[i].obj.region;
			if(reg !is null)
				systems.focus(reg);
		}
	}

	MoveOrder@ returnToBase(FleetAI@ fleet, uint priority = MP_Normal) {
		if(fleet.stationed !is null)
			return movement.move(fleet.obj, fleet.stationed, priority, spread=true);
		return null;
	}

	FleetAI@ register(Object@ obj) {
		FleetAI@ flAI = getAI(obj);

		if(flAI is null) {
			@flAI = FleetAI();
			@flAI.obj = obj;
			@flAI.stationed = obj.region;
			obj.setHoldPosition(true);

			uint designClass = designs.classify(obj);

			if(designClass == DP_Scout)
				flAI.fleetClass = FC_Scout;
			else if(designClass == DP_Slipstream)
				flAI.fleetClass = FC_Slipstream;
			else if(designClass == DP_Mothership)
				flAI.fleetClass = FC_Mothership;
			// [[ MODIFY BASE GAME START ]]
			else if(designClass == DP_StarEater)
				flAI.fleetClass = FC_StarEater;
			// [[ MODIFY BASE GAME END ]]
			else
				flAI.fleetClass = FC_Combat;

			fleets.insertLast(flAI);
		}

		return flAI;
	}

	void register(Mission@ mission) {
		if(mission.id == -1)
			mission.id = nextMissionId++;
	}

	FleetAI@ getAI(Object@ obj) {
		if(obj is null)
			return null;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			if(fleets[i].obj is obj)
				return fleets[i];
		}
		return null;
	}

	uint count(uint checkClass) {
		uint amount = 0;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if(flAI.fleetClass == checkClass || checkClass == FC_ALL)
				amount += 1;
		}
		return amount;
	}

	bool haveIdle(uint checkClass) {
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if((flAI.fleetClass == checkClass || checkClass == FC_ALL) && flAI.mission is null)
				return true;
		}
		return false;
	}

	double closestIdleTo(uint checkClass, const vec3d& position) {
		double closest = INFINITY;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if((flAI.fleetClass != checkClass && checkClass != FC_ALL) || flAI.mission !is null)
				continue;

			double d = flAI.obj.position.distanceTo(position);
			if(d < closest)
				closest = d;
		}
		return closest;
	}

	FleetAI@ performMission(Mission@ mission) {
		FleetAI@ perform;
		double bestWeight = 0.0;
		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets[i];
			if(flAI.mission !is null)
				continue;
			double w = mission.getPerformWeight(ai, flAI);
			if(w > bestWeight) {
				bestWeight = w;
				@perform = flAI;
			}
		}

		if(perform !is null) {
			@perform.mission = mission;
			register(mission);
			mission.start(ai, perform);
		}
		return perform;
	}

	FleetAI@ performMission(FleetAI@ fleet, Mission@ mission) {
		if(fleet.mission !is null) {
			fleet.mission.cancel(ai, fleet);
			fleet.mission.canceled = true;
		}
		@fleet.mission = mission;
		register(mission);
		mission.start(ai, fleet);
		return fleet;
	}

	// [[ MODIFY BASE GAME START ]]
	void saveFleetList(SaveFile& file, array<FleetAI@> fleetsList) {
		uint cnt = fleetsList.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			saveAI(file, fleetsList[i]);
		}
	}

	array<FleetAI@> loadFleetList(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		array<FleetAI@> fleetsList;
		for (uint i = 0; i < cnt; ++i) {
			auto@ flAI = loadAI(file);
			if (flAI !is null)
				fleetsList.insertLast(flAI);
		}
		return fleetsList;
	}
	// [[ MODIFY BASE GAME END ]]
};

AIComponent@ createFleets() {
	return Fleets();
}
