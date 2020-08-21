#section server
import object_creation;
import influence;
import scenario;
import systems;
import map_loader;
import campaign;
import traits;
from traits import getTraitID;
import empire_ai.weasel.WeaselAI;
import empire_ai.EmpireAI;
import empire_ai.weasel.War;
import victory;
import settings.game_settings;
#section all

#section server
/**
 * Utility class for creating campaign scenario subclasses from that
 * contains a number of useful helpers for scripting campaigns.
 */
class CampaignScenarioState {
	array<SystemDesc@> systems;
	array<Empire@> empires;

	CampaignScenarioState(array<SystemDesc@> systems, array<Empire@> empires) {
		this.systems = systems;
		this.empires = empires;
	}

	/**
	 * Gets the i'th planet of a j'th system in this scenario.
	 */
	Planet@ planet(uint systemID, uint planetID) {
		if (systemID >= systems.length) {
			return null;
		}
		Region@ region = systems[systemID].object;
		if (region is null) {
			return null;
		}
		if (planetID < region.planetCount)  {
			return region.planets[planetID];
		}
		return null;
	}

	/**
	 * Puts population on a planet.
	 */
	void populate(Planet@ pl, Empire@ owner, double pop = 1.0, Object@ exportTo = null, double defense = 0.0) {
		@pl.owner = owner;
		pl.addPopulation(pop);
		if(exportTo !is null)
			pl.exportResource(owner, 0, exportTo);
		if(defense > 0)
			pl.spawnDefenseShips(defense);
	}

	/**
	 * Spawns a flagship at a given position, with supports.
	 */
	Ship@ spawnFleet(Empire@ emp, const vec3d& pos, const string& design = "Titan", uint support = 25) {
		auto@ flagshipDesign = emp.getDesign(design);
		auto@ sup3Dsg = emp.getDesign("Missile Boat");
		auto@ sup1Dsg = emp.getDesign("Beamship");
		auto@ sup2Dsg = emp.getDesign("Heavy Gunship");

		Ship@ flagship = createShip(pos, flagshipDesign, emp, free=true);
		for(uint i = 0; i < support / 2; ++i)
			createShip(pos, sup1Dsg, emp, flagship);
		for(uint i = 0; i < support / 4; ++i)
			createShip(pos, sup2Dsg, emp, flagship);
		for(uint i = 0; i < support / 8; ++i)
			createShip(pos, sup3Dsg, emp, flagship);
		flagship.setHoldPosition(true);
		return flagship;
	}

	/**
	 * Removes the influence, energy and research incomes added by
	 * various sources to drop them back to 0.
	 */
	void removeStartingIncomes() {
		for (uint i = 0; i < empires.length; i++) {
			empires[i].modInfluenceIncome(-100);
			empires[i].modInfluence(-5);
			empires[i].modEnergyIncome(-3);
			empires[i].modResearchRate(-1);
		}
	}

	void triggerVictory() {
		declareVictor(empires[0]);
	}

	bool getEmpireFleetHasShip(Empire@ empire, Ship@ test) {
		DataList@ objs = empire.getFlagships();
		Object@ obj;
		while (receive(objs, obj)) {
			Ship@ ship = cast<Ship>(obj);
			if (ship !is null && ship is test) {
				return true;
			}
		}
		return false;
	}

	uint getEmpirePlanetCount(Empire@ empire) {
		DataList@ objs = empire.getPlanets();
		Object@ obj;
		uint count = 0;
		while (receive(objs, obj)) {
			Planet@ planet = cast<Planet>(obj);
			if (planet !is null) {
				count += 1;
			}
		}
		return count;
	}
}

class OrObjectiveCheck : CEObjectiveCheck {
	CEObjectiveCheck@ predicate1;
	CEObjectiveCheck@ predicate2;

	bool check() {
		return predicate1.check() || predicate2.check();
	}

	OrObjectiveCheck(CEObjectiveCheck@ predicate1, CEObjectiveCheck@ predicate2) {
		@this.predicate1 = predicate1;
		@this.predicate2 = predicate2;
	}
}

class CEObjectiveCheck : ObjectiveCheck {

	CEObjectiveCheck@ _or_(CEObjectiveCheck@ other) {
		return OrObjectiveCheck(this, other);
	}
}
#section all
