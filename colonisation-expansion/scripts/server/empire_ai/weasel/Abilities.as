import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Fleets;
import empire_ai.dragon.AbilityAI;

import abilities;

/**
 * CE mod code for the AI to track abilities on objects it owns.
 */

class AbilitiesComponent : AIComponent, PlanetEventListener, OrbitalEventListener, FleetEventListener, AbilitiesComponentI {
	Planets@ planets;
	Orbitals@ orbitals;
	Fleets@ fleets;

	array<AbilityAI@> abilityObjects;
	uint abilityObjectIndex = 0;

	uint planetCardCheckIndex = 0;
	uint orbitalCardCheckIndex = 0;
	uint fleetCheckIndex = 0;

	array<AbilitiesEventListener@> listeners;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@orbitals = cast<Orbitals>(ai.orbitals);
		@fleets = cast<Fleets>(ai.fleets);
		planets.listeners.insertLast(this);
		orbitals.listeners.insertLast(this);
		fleets.listeners.insertLast(this);
	}

	Empire@ get_empire() {
		return ai.empire;
	}

	void save(SaveFile& file) {
		file << planetCardCheckIndex;
		file << orbitalCardCheckIndex;
		file << fleetCheckIndex;
		uint cnt = abilityObjects.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = abilityObjects[i];
			saveAI(file, data);
			data.save(this, file);
		}
	}

	void load(SaveFile& file) {
		file >> planetCardCheckIndex;
		file >> orbitalCardCheckIndex;
		file >> fleetCheckIndex;
		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ data = loadAI(file);
			if(data !is null)
				data.load(this, file);
			else
				AbilityAI().load(this, file);
		}
	}

	AbilityAI@ loadAI(SaveFile& file) {
		Object@ obj;
		file >> obj;

		if(obj is null)
			return null;

		AbilityAI@ data = getAI(obj);
		if(data is null) {
			@data = AbilityAI();
			@data.obj = obj;
			abilityObjects.insertLast(data);
		}
		return data;
	}

	void saveAI(SaveFile& file, AbilityAI@ ai) {
		Object@ obj;
		if(ai !is null)
			@obj = ai.obj;
		file << obj;
	}

	void start() {
	}

	void tick(double time) {

	}

	void turn() {
		if (log) {
			ai.print("Tracking "+string(abilityObjects.length)+" ability objects");
		}
	}

	void focusTick(double time) override {
		// Check through our planets, orbitals and fleets one index at a time

		if (abilityObjects.length != 0) {
			abilityObjectIndex = (abilityObjectIndex + 1) % abilityObjects.length;
			AbilityAI@ data = abilityObjects[abilityObjectIndex];
			data.tick(ai, this);
		}

		uint planetCount = planets.planets.length;
		if (planetCount != 0) {
			planetCardCheckIndex = (planetCardCheckIndex + 1) % planetCount;
			PlanetAI@ plAI = planets.planets[planetCardCheckIndex];
			if (plAI !is null && plAI.obj !is null && plAI.obj.hasAbilities) {
				register(plAI.obj);
			}
		}
		uint orbitalCount = orbitals.orbitals.length;
		if (orbitalCount != 0) {
			orbitalCardCheckIndex = (orbitalCardCheckIndex + 1) % orbitalCount;
			OrbitalAI@ orbitalAI = orbitals.orbitals[orbitalCardCheckIndex];
			if (orbitalAI !is null && orbitalAI.obj !is null && orbitalAI.obj.hasAbilities) {
				register(orbitalAI.obj);
			}
		}
		uint fleetCount = fleets.fleets.length;
		if (fleetCount != 0) {
			fleetCheckIndex = (fleetCheckIndex + 1) % fleetCount;
			FleetAI@ flAI = fleets.fleets[fleetCheckIndex];
			if (flAI !is null && flAI.obj !is null && flAI.obj.hasAbilities) {
				register(flAI.obj);
			}
		}
	}

	AbilityAI@ getAI(Object& obj) {
		for (uint i = 0, cnt = abilityObjects.length; i < cnt; ++i) {
			if (abilityObjects[i].obj is obj)
				return abilityObjects[i];
		}
		return null;
	}

	AbilityAI@ register(Object& obj) {
		AbilityAI@ data = getAI(obj);
		if (data is null) {
			@data = AbilityAI();
			@data.obj = obj;
			if (data.init(ai, this)) {
				abilityObjects.insertLast(data);
			} else {
				// Object exists but we won't be making an AbilityAI for it
				return null;
			}
		}
		return data;
	}

	void remove(AbilityAI@ data) {
		data.remove(ai, this);
		abilityObjects.remove(data);
	}

	void removedAbilityAI(AbilityAI@ abilityAI) {
		// Tell everything that is listening
		for (uint i = 0, cnt = listeners.length; i < cnt; ++i) {
			listeners[i].onRemovedAbilityAI(abilityAI);
		}
	}

	void onRemovedAbilityObject(Object@ removed) {
		if (removed is null)
			return;
		for (uint i = 0, cnt = abilityObjects.length; i < cnt; ++i) {
			if (abilityObjects[i].obj is removed) {
				abilityObjects[i].remove(ai, this);
				abilityObjects.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void onRemovedPlanetAI(PlanetAI@ plAI) {
		if (plAI !is null) {
			onRemovedAbilityObject(plAI.obj);
		}
	}
	void onRemovedOrbitalAI(OrbitalAI@ orbAI) {
		if (orbAI !is null) {
			onRemovedAbilityObject(orbAI.obj);
		}
	}
	void onRemovedFleetAI(FleetAI@ flAI) {
		if (flAI !is null) {
			onRemovedAbilityObject(flAI.obj);
		}
	}

	void onConstructionRequestActioned(ConstructionRequest@ request) {}
};

AIComponent@ createAbilities() {
	return AbilitiesComponent();
}
