import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.race.Race;

import empire_ai.weasel.Colonization;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Scouting;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Budget;

from orbitals import getOrbitalModuleID;
from constructions import ConstructionType, getConstructionType;

import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;

// TODO: Teach the AI to build new beacons
// TODO: Consider making the AI not colonise tier 1 planets via beacons because they are so common

class BeaconColonizer : ColonizationSource {
	OrbitalAI@ beacon;

	BeaconColonizer(OrbitalAI@ beacon) {
		@this.beacon = beacon;
	}

	vec3d getPosition() {
		return beacon.obj.position;
	}

	bool valid(AI& ai) {
		return beacon.obj.valid && beacon.obj.owner is ai.empire;
	}

	string toString() {
		return beacon.obj.name;
	}
}

class Extragalactic : Race, ColonizationAbility {
	IColonization@ colonization;
	Construction@ construction;
	Scouting@ scouting;
	Orbitals@ orbitals;
	Resources@ resources;
	Budget@ budget;

	array<ColonizationSource@> beacons;
	OrbitalAI@ masterBeacon;

	int beaconMod = -1;

	array<ImportData@> imports;
	array<const ConstructionType@> beaconBuilds;

	const ConstructionType@ beaconColonize;
	double colonizeCost = INFINITY;

	double previousExpedition = 0;

	void create() {
		@colonization = cast<IColonization>(ai.colonization);
		//colonization.PerformColonization = false;
		//colonization.QueueColonization = false;

		@scouting = cast<Scouting>(ai.scouting);
		scouting.buildScouts = false;

		@orbitals = cast<Orbitals>(ai.orbitals);
		beaconMod = getOrbitalModuleID("Beacon");

		@construction = cast<Construction>(ai.construction);
		@resources = cast<Resources>(ai.resources);
		@budget = cast<Budget>(ai.budget);

		beaconBuilds.insertLast(getConstructionType("BeaconHealth"));
		beaconBuilds.insertLast(getConstructionType("BeaconWeapons"));
		beaconBuilds.insertLast(getConstructionType("BeaconLabor"));

		// Register ourselves as overriding the colony management
		// and resource valuation
		auto@ expansion = cast<ColonizationAbilityOwner>(ai.colonization);
		expansion.setColonyManagement(this);

		@beaconColonize = getConstructionType("BeaconTargetColonize");
		if (beaconColonize !is null) {
			colonizeCost = beaconColonize.buildCost;
		}
	}

	void save(SaveFile& file) override {
		uint cnt = beacons.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
			orbitals.saveAI(file, beacon.beacon);
		}
		orbitals.saveAI(file, masterBeacon);

		cnt = imports.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i)
			resources.saveImport(file, imports[i]);

		file << previousExpedition;
	}

	void load(SaveFile& file) override {
		uint cnt = 0;
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			OrbitalAI@ b = orbitals.loadAI(file);
			if (b !is null && b.obj !is null) {
				beacons.insertLast(BeaconColonizer(b));
			}
		}
		@masterBeacon = orbitals.loadAI(file);

		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			auto@ imp = resources.loadImport(file);
			if (imp !is null)
				imports.insertLast(imp);
		}

		file >> previousExpedition;
	}

	uint prevBeacons = 0;
	void focusTick(double time) {
		// Find our beacons
		for (uint i = 0, cnt = beacons.length; i < cnt; ++i) {
			BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
			OrbitalAI@ b = beacon.beacon;
			if(b is null || b.obj is null || !b.obj.valid || b.obj.owner !is ai.empire) {
				if(b.obj !is null)
					resources.killImportsTo(b.obj);
				beacons.removeAt(i);
				--i; --cnt;
			}
		}

		for (uint i = 0, cnt = orbitals.orbitals.length; i < cnt; ++i) {
			auto@ orb = orbitals.orbitals[i];
			Orbital@ obj = cast<Orbital>(orb.obj);
			if (obj !is null && obj.coreModule == uint(beaconMod)) {

				bool found = false;
				for (uint j = 0, jcnt = beacons.length; j < jcnt && !found; ++j) {
					BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[j]);
					if (beacon.beacon is orb) {
						found = true;
					}
				}
				if (!found) {
					beacons.insertLast(BeaconColonizer(orb));
				}
			}
		}

		//Find our master beacon
		if(masterBeacon !is null) {
			Orbital@ obj = cast<Orbital>(masterBeacon.obj);
			if(obj is null || !obj.valid || obj.owner !is ai.empire || obj.hasMaster())
				@masterBeacon = null;
		}
		else {
			for (uint i = 0, cnt = beacons.length; i < cnt; ++i) {
				BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
				OrbitalAI@ b = beacon.beacon;
				Orbital@ obj = cast<Orbital>(b.obj);
				if (!obj.hasMaster()) {
					@masterBeacon = b;
					ai.empire.setDefending(obj, true);
					break;
				}
			}
		}

		scouting.buildScouts = gameTime > 5.0 * 60.0;
		if(prevBeacons < beacons.length && masterBeacon !is null && gameTime > 10.0) {
			for(int i = beacons.length-1; i >= int(prevBeacons); --i) {
				BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
				//Make sure we order a scout at each beacon
				if(!scouting.buildScouts) {
					BuildFlagshipSourced build(scouting.scoutDesign);
					build.moneyType = BT_Military;
					@build.buildAt = masterBeacon.obj;
					if (beacon.beacon !is masterBeacon) {
						@build.buildFrom = beacon.beacon.obj;
					}
					construction.build(build, force=true);
				}

				//Set the beacon to fill up other stuff
				beacon.beacon.obj.allowFillFrom = true;
			}
			prevBeacons = beacons.length;
		}

		//Handle with importing labor and defense to our master beacon
		if(masterBeacon !is null) {
			if(imports.length == 0) {
				//Request labor and defense at our beacon
				{
					ResourceSpec spec;
					spec.type = RST_Pressure_Type;
					spec.pressureType = TR_Labor;

					imports.insertLast(resources.requestResource(masterBeacon.obj, spec));
				}
				{
					ResourceSpec spec;
					spec.type = RST_Pressure_Type;
					spec.pressureType = TR_Defense;

					imports.insertLast(resources.requestResource(masterBeacon.obj, spec));
				}
				{
					ResourceSpec spec;
					spec.type = RST_Pressure_Level0;
					spec.pressureType = TR_Research;

					imports.insertLast(resources.requestResource(masterBeacon.obj, spec));
				}
			}
			else {
				//When our requests are met, make more requests!
				for(uint i = 0, cnt = imports.length; i < cnt; ++i) {
					if(imports[i].beingMet || imports[i].obj !is masterBeacon.obj) {
						ResourceSpec spec;
						spec = imports[i].spec;
						@imports[i] = resources.requestResource(masterBeacon.obj, spec);
					}
				}
			}

			//Build stuff on our beacon if we have enough stuff
			if(budget.canSpend(BT_Development, 300)) {
				uint offset = randomi(0, beaconBuilds.length-1);
				for(uint i = 0, cnt = beaconBuilds.length; i < cnt; ++i) {
					uint ind = (i+offset) % cnt;
					auto@ type = beaconBuilds[ind];
					if(type is null)
						continue;

					if(type.canBuild(masterBeacon.obj, ignoreCost=false)) {
						masterBeacon.obj.buildConstruction(type.id);
						break;
					}
				}
			}
		}
	}

	array<ColonizationSource@> getSources() {
		return beacons;
	}

	bool canExpediteRelocation(Object@ colony) {
		// only do manual extra colonisations on hard difficulty
		if (ai.difficulty < 2) {
			return false;
		}
		// don't order too many at the same time, since this won't happen faster
		// and could crash our budget
		if (gameTime < previousExpedition + 30) {
			return false;
		}
		if (masterBeacon is null || masterBeacon.obj is null) {
			return false;
		}
		if (colony is null) {
			return beaconColonize.canBuild(masterBeacon.obj, ignoreCost=false);
		}
		Targets@ targs = Targets();
		@targs.add(TT_Object, true).obj = colony;
		return beaconColonize.canBuild(masterBeacon.obj, targs=targs, ignoreCost=false);
	}

	ColonizationSource@ getClosestSource(vec3d position) {
		bool notCheckedMilitarySpending = !budget.checkedMilitarySpending && budget.Progress < 0.33;
		if (notCheckedMilitarySpending || !budget.canSpend(BT_Colonization, colonizeCost)) {
			return null;
		}
		if (!canExpediteRelocation(null)) {
			return null;
		}
		double shortestDistance = -1;
		BeaconColonizer@ closestSource;
		for (uint i = 0, cnt = beacons.length; i < cnt; ++i) {
			BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
			if (!beacon.valid(ai))
				continue;
			double distance = beacon.beacon.obj.position.distanceTo(position);
			if (shortestDistance == -1 || distance < shortestDistance) {
				shortestDistance = distance;
				@closestSource = beacon;
			}
		}
		return closestSource;
	}

	ColonizationSource@ getFastestSource(Planet@ colony) {
		if (colony is null) {
			return null;
		}
		bool notCheckedMilitarySpending = !budget.checkedMilitarySpending && budget.Progress < 0.33;
		if (notCheckedMilitarySpending || !budget.canSpend(BT_Colonization, colonizeCost)) {
			return null;
		}
		if (!canExpediteRelocation(colony)) {
			return null;
		}
		BeaconColonizer@ closestSource;
		double shortestDistance = -1;
		for (uint i = 0, cnt = beacons.length; i < cnt; ++i) {
			BeaconColonizer@ beacon = cast<BeaconColonizer>(beacons[i]);
			if (!beacon.valid(ai))
				continue;
			double distance = getPathDistance(ai.empire, beacon.beacon.obj.position, colony.position);
			if (shortestDistance == -1 || distance < shortestDistance) {
				shortestDistance = distance;
				@closestSource = beacon;
			}
		}
		return closestSource;
	}

	void colonizeTick() {
		// Don't need to do anything here
	}

	void orderColonization(ColonizeData@ data, ColonizationSource@ source) {
		if (!canExpediteRelocation(data.target)) {
			return;
		}
		BeaconColonizer@ beacon = cast<BeaconColonizer>(source);
		ColonizeData2@ _data = cast<ColonizeData2>(data);
		if (_data !is null) {
			@_data.colonizeUnit = beacon;
		}
		if (log) {
			ai.print("Manually ordering beacon to colonise "+data.target.name);
		}
		masterBeacon.obj.buildConstruction(beaconColonize.id, objTarg=data.target);
		previousExpedition = gameTime;
	}

	void saveSource(SaveFile& file, ColonizationSource@ source) {
		if (source !is null) {
			file.write1();
			BeaconColonizer@ beacon = cast<BeaconColonizer>(source);
			orbitals.saveAI(file, beacon.beacon);
		} else {
			file.write0();
		}
	}

	ColonizationSource@ loadSource(SaveFile& file) {
		if (file.readBit()) {
			OrbitalAI@ b = orbitals.loadAI(file);
			if (b !is null && b.obj !is null) {
				return BeaconColonizer(b);
			}
		}
		return null;
	}

	// We save our state in our save and load methods
	void saveManager(SaveFile& file) {}
	void loadManager(SaveFile& file) {}

	bool canSafelyColonize(SystemAI@ sys) {
		// seenPresent is a cache of the PlanetsMask of this system
		uint presentMask = sys.seenPresent;
		bool isOwned = presentMask & ai.mask != 0;
		if (isOwned) {
			return true;
		} else {
			if(!ai.behavior.colonizeEnemySystems && (presentMask & ai.enemyMask) != 0)
				return ai.behavior.aggressive; // assume the worst, that this system is actually guarded
			if(!ai.behavior.colonizeNeutralOwnedSystems && (presentMask & ai.neutralMask) != 0)
				return ai.behavior.aggressive;
			if(!ai.behavior.colonizeAllySystems && (presentMask & ai.allyMask) != 0)
				return false; // lets be nice to our allies
			return true;
		}
	}
};

AIComponent@ createExtragalactic2() {
	return Extragalactic();
}
