import ftl;
import resources;

tidy class ColonizationEvent : Serializable {
	Object@ from;
	Object@ to;

	void write(Message& msg) {
		msg << from;
		msg << to;
	}

	void read(Message& msg) {
		msg >> from;
		msg >> to;
	}
};

tidy class ObjectManager : Component_ObjectManager {
	ReadWriteMutex plMutex;
	Planet@[] planets;
	Asteroid@[] asteroids;
	Orbital@[] Orbitals;

	Mutex flingMutex;
	Object@[] flingBeacons;

	// [[ MODIFY BASE GAME START ]]
	// Also track all fling beacons we can use, rather than just ones
	// we own.
	Mutex friendlyFlingMutex;
	Object@[] friendlyFlingBeacons;
	// [[ MODIFY BASE GAME END ]]

	Mutex gateMutex;
	Object@[] gates;

	// [[ MODIFY BASE GAME START ]]
	// Also track all (star)gates we can use, rather than just ones
	// we own.
	Mutex friendlyGateMutex;
	Object@[] friendlyGates;
	// [[ MODIFY BASE GAME END ]]

	Mutex artifMutex;
	Artifact@[] artifacts;

	ColonizationEvent@[] colonizations;
	ColonizationEvent@[] queuedAutoColonizations;

	AutoImportDesc[] autoImports;

	ReadWriteMutex defenseMtx;
	array<Object@> defenseObjects;
	set_int defenseSet;

	double defenseRate = 0;
	double defenseStorage = 0;
	double defenseStored = 0;
	double localDefenseRate = 0;

	void getPlanets() {
		ReadLock lock(plMutex);
		for(uint i = 0, cnt = planets.length; i < cnt; ++i)
			yield(planets[i]);
	}

	// [[ MODIFY BASE GAME START ]]
	Planet@ getClosestPlanet(const vec3d& position) {
		ReadLock lock(plMutex);
		Planet@ closest;
		double closestDist = INFINITY;
		for(uint i = 0, cnt = planets.length; i < cnt; ++i) {
			Planet@ planet = planets[i];
			double d = planet.position.distanceToSQ(position);
			if(d < closestDist) {
				closestDist = d;
				@closest = planet;
			}
		}
		return closest;
	}
	// [[ MODIFY BASE GAME END ]]

	void getAutoImports() {
		ReadLock lock(plMutex);
		for(uint i = 0, cnt = autoImports.length; i < cnt; ++i) {
			if(!autoImports[i].handled)
				yield(autoImports[i]);
		}
	}

	uint get_planetCount() {
		return planets.length;
	}

	Planet@ get_planetList(uint index) {
		ReadLock lock(plMutex);
		if(index >= planets.length)
			return null;
		return planets[index];
	}

	uint get_orbitalCount() {
		return Orbitals.length;
	}

	Orbital@ get_orbitals(uint index) {
		ReadLock lock(plMutex);
		if(index >= Orbitals.length)
			return null;
		return Orbitals[index];
	}

	Orbital@ getClosestOrbital(uint type, const vec3d& position) {
		ReadLock lock(plMutex);
		Orbital@ closest;
		double closestDist = INFINITY;
		for(uint i = 0, cnt = Orbitals.length; i < cnt; ++i) {
			Orbital@ orb = Orbitals[i];
			if(orb.coreModule == type) {
				double d = orb.position.distanceToSQ(position);
				if(d < closestDist) {
					closestDist = d;
					@closest = orb;
				}
			}
		}
		return closest;
	}

	bool isFlingBeacon(Object@ obj) {
		Lock lock(flingMutex);
		for(uint i = 0, cnt = flingBeacons.length; i < cnt; ++i)
			if(flingBeacons[i] is obj)
				return true;
		return false;
	}

	// [[ MODIFY BASE GAME START ]]
	bool isFriendlyFlingBeacon(Object@ obj) {
		Lock lock(friendlyFlingMutex);
		for(uint i = 0, cnt = friendlyFlingBeacons.length; i < cnt; ++i)
			if(friendlyFlingBeacons[i] is obj)
				return true;
		return false;
	}
	// [[ MODIFY BASE GAME END ]]

	void getAsteroids() {
		ReadLock lock(plMutex);
		for(uint i = 0, cnt = asteroids.length; i < cnt; ++i)
			yield(asteroids[i]);
	}

	void getFlingBeacons() {
		Lock lock(flingMutex);
		for(uint i = 0, cnt = flingBeacons.length; i < cnt; ++i)
			yield(flingBeacons[i]);
	}

	// [[ MODIFY BASE GAME START ]]
	void getFriendlyFlingBeacons() {
		Lock lock(friendlyFlingMutex);
		for(uint i = 0, cnt = friendlyFlingBeacons.length; i < cnt; ++i)
			yield(friendlyFlingBeacons[i]);
	}
	// [[ MODIFY BASE GAME END ]]

	void getStargates() {
		Lock lock(gateMutex);
		for(uint i = 0, cnt = gates.length; i < cnt; ++i)
			yield(gates[i]);
	}

	// [[ MODIFY BASE GAME START ]]
	void getFriendlyStargates() {
		Lock lock(friendlyGateMutex);
		for(uint i = 0, cnt = friendlyGates.length; i < cnt; ++i)
			yield(friendlyGates[i]);
	}
	// [[ MODIFY BASE GAME END ]]

	void getArtifacts() {
		Lock lock(artifMutex);
		for(uint i = 0, cnt = artifacts.length; i < cnt; ++i)
			yield(artifacts[i]);
	}

	void getOrbitals() {
		ReadLock lock(plMutex);
		for(uint i = 0, cnt = Orbitals.length; i < cnt; ++i)
			yield(Orbitals[i]);
	}

	void getQueuedColonizations(Empire& emp) {
		ReadLock lock(plMutex);
		for(uint i = 0, cnt = queuedAutoColonizations.length; i < cnt; ++i) {
			auto@ q = queuedAutoColonizations[i];
			if(q.to.owner !is emp && q.from is null)
				yield(q.to);
		}
		for(uint i = 0, cnt = colonizations.length; i < cnt; ++i) {
			if(colonizations[i].to.owner !is emp)
				yield(colonizations[i].to);
		}
	}

	bool get_hasFlingBeacons() {
		return friendlyFlingBeacons.length != 0; // [[ MODIFY BASE GAME ]]
	}

	Object@ getFlingBeacon(vec3d position) {
		Lock lock(flingMutex);
		for(uint i = 0, cnt = flingBeacons.length; i < cnt; ++i) {
			if(flingBeacons[i].position.distanceToSQ(position) < FLING_BEACON_RANGE_SQ)
				return flingBeacons[i];
		}
		return null;
	}

	// [[ MODIFY BASE GAME START ]]
	Object@ getFriendlyFlingBeacon(vec3d position) {
		Lock lock(friendlyFlingMutex);
		for(uint i = 0, cnt = friendlyFlingBeacons.length; i < cnt; ++i) {
			if(friendlyFlingBeacons[i].position.distanceToSQ(position) < FLING_BEACON_RANGE_SQ)
				return friendlyFlingBeacons[i];
		}
		return null;
	}
	// [[ MODIFY BASE GAME END ]]

	Object@ getClosestFlingBeacon(vec3d position) {
		Lock lock(flingMutex);
		Object@ nearest;
		double dist = 0;
		for(uint i = 0, cnt = flingBeacons.length; i < cnt; ++i) {
			Object@ beacon = flingBeacons[i];
			double d = beacon.position.distanceToSQ(position);
			if(nearest is null || d < dist) {
				@nearest = beacon;
				dist = d;
			}
		}
		return nearest;
	}

	// [[ MODIFY BASE GAME START ]]
	Object@ getClosestFriendlyFlingBeacon(vec3d position) {
		Lock lock(friendlyFlingMutex);
		Object@ nearest;
		double dist = 0;
		for(uint i = 0, cnt = friendlyFlingBeacons.length; i < cnt; ++i) {
			Object@ beacon = friendlyFlingBeacons[i];
			double d = beacon.position.distanceToSQ(position);
			if(nearest is null || d < dist) {
				@nearest = beacon;
				dist = d;
			}
		}
		return nearest;
	}
	// [[ MODIFY BASE GAME END ]]

	Object@ getClosestFlingBeacon(Object& obj) {
		Lock lock(flingMutex);
		Object@ nearest;
		double dist = 0;
		for(uint i = 0, cnt = flingBeacons.length; i < cnt; ++i) {
			Object@ beacon = flingBeacons[i];
			if(beacon is obj)
				continue;
			double d = beacon.position.distanceToSQ(obj.position);
			if(nearest is null || d < dist) {
				@nearest = beacon;
				dist = d;
			}
		}
		return nearest;
	}

	// [[ MODIFY BASE GAME START ]]
	Object@ getClosestFriendlyFlingBeacon(Object& obj) {
		Lock lock(friendlyFlingMutex);
		Object@ nearest;
		double dist = 0;
		for(uint i = 0, cnt = friendlyFlingBeacons.length; i < cnt; ++i) {
			Object@ beacon = friendlyFlingBeacons[i];
			if(beacon is obj)
				continue;
			double d = beacon.position.distanceToSQ(obj.position);
			if(nearest is null || d < dist) {
				@nearest = beacon;
				dist = d;
			}
		}
		return nearest;
	}
	// [[ MODIFY BASE GAME END ]]

	bool hasStargates() {
		return friendlyGates.length != 0; // [[ MODIFY BASE GAME ]]
	}

	Object@ getStargate(vec3d position) {
		Lock lock(gateMutex);
		Object@ best;
		double bestDist = INFINITY;
		for(uint i = 0, cnt = gates.length; i < cnt; ++i) {
			Object@ gate = gates[i];
			double d = gate.position.distanceToSQ(position);
			if(d < bestDist) {
				bestDist = d;
				@best = gate;
			}
		}
		return best;
	}

	// [[ MODIFY BASE GAME START ]]
	Object@ getFriendlyStargate(vec3d position) {
		Lock lock(friendlyGateMutex);
		Object@ best;
		double bestDist = INFINITY;
		for(uint i = 0, cnt = friendlyGates.length; i < cnt; ++i) {
			Object@ gate = friendlyGates[i];
			double d = gate.position.distanceToSQ(position);
			if(d < bestDist) {
				bestDist = d;
				@best = gate;
			}
		}
		return best;
	}
	// [[ MODIFY BASE GAME END ]]

	bool isDefending(Object@ obj) {
		if(obj is null)
			return false;
		ReadLock lck(defenseMtx);
		return defenseSet.contains(obj.id);
	}

	bool get_hasDefending() {
		return defenseObjects.length > 0;
	}

	void getDefending() {
		ReadLock lck(defenseMtx);
		for(uint i = 0, cnt = defenseObjects.length; i < cnt; ++i)
			yield(defenseObjects[i]);
	}

	void setDefending(Object@ obj, bool value) {
		if(obj is null)
			return;
		WriteLock lck(defenseMtx);
		if(value) {
			if(defenseSet.contains(obj.id))
				return;

			defenseSet.insert(obj.id);
			defenseObjects.insertLast(obj);
		}
		else {
			if(!defenseSet.contains(obj.id))
				return;

			defenseSet.erase(obj.id);
			defenseObjects.remove(obj);
		}
	}

	double get_globalDefenseRate() {
		return defenseRate + localDefenseRate;
	}

	double get_globalDefenseStorage() {
		return defenseStorage;
	}

	double get_globalDefenseStored() {
		return defenseStored;
	}

	void readObjects(Message& msg) {
		WriteLock wlock(plMutex);

		if(msg.readBit()) {
			msg >> defenseRate;
			msg >> localDefenseRate;
			msg >> defenseStorage;
			msg >> defenseStored;
		}

		if(msg.readBit()) {
			uint cnt = 0;
			msg >> cnt;
			planets.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> planets[i];

			msg >> cnt;
			asteroids.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> asteroids[i];

			msg >> cnt;
			Orbitals.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> Orbitals[i];

			{
				Lock lock(flingMutex);
				msg >> cnt;
				flingBeacons.length = cnt;
				for(uint i = 0; i < cnt; ++i)
					msg >> flingBeacons[i];
			}

			// [[ MODIFY BASE GAME START ]]
			{
				Lock lock(friendlyFlingMutex);
				msg >> cnt;
				friendlyFlingBeacons.length = cnt;
				for(uint i = 0; i < cnt; ++i)
					msg >> friendlyFlingBeacons[i];
			}
			// [[ MODIFY BASE GAME END ]]

			{
				Lock lock(gateMutex);
				msg >> cnt;
				gates.length = cnt;
				for(uint i = 0; i < cnt; ++i)
					msg >> gates[i];
			}

			// [[ MODIFY BASE GAME START ]]
			{
				Lock lock(friendlyGateMutex);
				msg >> cnt;
				friendlyGates.length = cnt;
				for(uint i = 0; i < cnt; ++i)
					msg >> friendlyGates[i];
			}
			// [[ MODIFY BASE GAME END ]]

			{
				Lock lock(artifMutex);
				msg >> cnt;
				artifacts.length = cnt;
				for(uint i = 0; i < cnt; ++i)
					msg >> artifacts[i];
			}

			{
				ReadLock lock(defenseMtx);
				msg >> cnt;
				defenseObjects.length = cnt;
				defenseSet.clear();
				for(uint i = 0; i < cnt; ++i) {
					msg >> defenseObjects[i];
					if(defenseObjects[i] !is null)
						defenseSet.insert(defenseObjects[i].id);
				}
			}
		}

		if(msg.readBit()) {
			uint cnt = 0;
			msg >> cnt;
			colonizations.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				if(colonizations[i] is null)
					@colonizations[i] = ColonizationEvent();
				msg >> colonizations[i];
			}

			msg >> cnt;
			queuedAutoColonizations.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				if(queuedAutoColonizations[i] is null)
					@queuedAutoColonizations[i] = ColonizationEvent();
				msg >> queuedAutoColonizations[i];
			}
		}

		if(msg.readBit()) {
			uint cnt = 0;
			msg >> cnt;
			autoImports.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> autoImports[i];
		}
	}
};
