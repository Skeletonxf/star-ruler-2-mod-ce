#priority init 1501
import maps;

#section game
import dialogue;
#section all

#section server
import object_creation;
import influence;
import tile_resources;
import scenario;
import systems;
import map_loader;
import campaign;
#include "include/resource_constants.as"
import traits;
from traits import getTraitID;
import empire_ai.weasel.WeaselAI;
import empire_ai.EmpireAI;
import empire_ai.weasel.War;
import victory;
#section all

// TODO: Prevent the AI from offering to surrender
// TODO: Disable artifact spawning
// TODO: Modify all empires research income into defense, and prohibit building
// research complexes
// TODO: Give the human player a flagship which is considered to have them on it
// with bonus efficiency but game over if it gets destroyed
// TODO: Disable all conditions on spawned planets, ie native life, vanilla ones

#section server

enum ScenarioSystem {
	SCS_Main,
	SCS_Other1,
	SCS_Other2,
	SCS_Other3,
	SCS_Other4,
	SCS_Other5
};

/**
 * Scenario state for running post map generation. Of particular note is that
 * SystemData persists only for map generation, so cannot be used if the game
 * is saved and reloaded, which is what this class is for.
 */
class MiningColonyScenario {
	Empire@ player;
	Empire@ ally;
	Empire@ enemy;
	const SystemDesc@ mainSystem;
	const SystemDesc@ otherSystem1;
	const SystemDesc@ otherSystem2;
	const SystemDesc@ otherSystem3;
	const SystemDesc@ otherSystem4;
	const SystemDesc@ otherSystem5;

	MiningColonyScenario() {
		@player = getEmpire(0);
		@ally = getEmpire(1);
		@enemy = getEmpire(2);
		@mainSystem = getSystem(0);
		@otherSystem1 = getSystem(1);
		@otherSystem2 = getSystem(2);
		@otherSystem3 = getSystem(3);
		@otherSystem4 = getSystem(4);
		@otherSystem5 = getSystem(5);
	}

	/**
	 * Gets the i'th planet of a system in this scenario.
	 */
	Planet@ planet(ScenarioSystem systemID, uint id) {
		Region@ region;
		if (systemID == SCS_Main) {
			@region = mainSystem.object;
		}
		if (systemID == SCS_Other1) {
			@region = otherSystem1.object;
		}
		if (systemID == SCS_Other2) {
			@region = otherSystem2.object;
		}
		if (systemID == SCS_Other3) {
			@region = otherSystem3.object;
		}
		if (systemID == SCS_Other4) {
			@region = otherSystem4.object;
		}
		if (systemID == SCS_Other5) {
			@region = otherSystem5.object;
		}
		if (region is null) {
			return null;
		}
		if (id < region.planetCount)  {
			return region.planets[id];
		}
		return null;
	}

	void tick() {
		if (gameTime > 5) {
			if (false) {
				completeCampaignScenario("MiningColony");
				triggerVictory();
			}
		}
	}

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
	 * Post map generation initialisation, only to run once per scenario
	 * (ie not again after reloading).
	 */
	void postInit() {
		populate(planet(SCS_Main, 0), ally, 1.0, exportTo=planet(SCS_Main, 2));
		populate(planet(SCS_Main, 1), ally, 1.0, exportTo=planet(SCS_Main, 2));
		populate(planet(SCS_Main, 2), ally, 3.0);
		populate(planet(SCS_Main, 3), player, 1.0);
		populate(planet(SCS_Other1, 0), enemy, 10.0);

		player.modFTLStored(+250);
		enemy.modFTLStored(+250);
		player.modInfluenceIncome(-100);
		enemy.modInfluenceIncome(-100);
		player.modInfluence(-5);
		enemy.modInfluence(-5);
		player.modEnergyIncome(-3);
		enemy.modEnergyIncome(-3);
		player.modResearchRate(-1);
		enemy.modResearchRate(-1);
		player.modTotalBudget(-700);
		enemy.modTotalBudget(-700);
	}

	void triggerVictory() {
		declareVictor(player);
	}

	void triggerDefeat() {
		declareVictor(enemy);
	}
}
#section all

Scenario _map;
class Scenario : Map {
	Scenario() {
		super();

		isListed = false;
		isScenario = true;
	}

#section server
	void prepareSystem(SystemData@ data, SystemDesc@ desc) {
		@data.homeworlds = null;
		Map::prepareSystem(data, desc);
	}

	bool canHaveHomeworld(SystemData@ data, Empire@ emp) {
		return false;
	}

	void placeSystems() {
		loadMap("maps/TerraCampaign/mining_colony.txt").generate(this);
	}

	void preGenerate() {
		Map::preGenerate();
		radius = 400000;
	}

	void modSettings(GameSettings& settings) {
		settings.empires.length = 3;

		settings.empires[0].name = locale::MINING_COLONY_PLAYER_EMP;
		settings.empires[0].shipset = "Gevron";
		settings.empires[0].portrait = "emp_portrait_harrian";
		settings.empires[0].team = 1;

		settings.empires[1].name = locale::MINING_COLONY_ALLY_EMP;
		settings.empires[1].shipset = "Volkur";
		settings.empires[1].type = ET_NoAI;
		settings.empires[1].portrait = "emp_portrait_harrian";
		settings.empires[1].team = 1;
		settings.empires[1].color = colors::Blue;

		settings.empires[2].name = locale::MINING_COLONY_ENEMY_EMP;
		settings.empires[2].shipset = "Mechanica";
		settings.empires[2].type = ET_WeaselAI;
		settings.empires[2].portrait = "emp_portrait_mono";
		settings.empires[2].color = colors::Red;

		config::ENABLE_UNIQUE_SPREADS = 0.0;
		config::DISABLE_STARTING_FLEETS = 1.0;
		config::ENABLE_DREAD_PIRATE = 0.0;
		config::ENABLE_INFLUENCE_EVENTS = 0.0;
		config::START_EXPLORED_MAP = 1.0;
	}

	MiningColonyScenario@ state;

	void init() {
		Empire@ ally = getEmpire(1);
		Empire@ enemy = getEmpire(2);

		playerEmpire.setHostile(enemy, true);
		enemy.setHostile(playerEmpire, true);
		ally.setHostile(enemy, true);
		enemy.setHostile(ally, true);
		playerEmpire.Victory = -3;
		enemy.Victory = -3;
		ally.Victory = -3;

		initDialogue();
	}

	bool initialized = false;

	void tick(double time) {
		if(!initialized && !isLoadedSave) {
			initialized = true;
			postInit();
		}

		state.tick();
	}

	void postInit() {
		@state = MiningColonyScenario();
		state.postInit();
	}

	void save(SaveFile& file) {
		saveDialoguePosition(file);
	}

	void load(SaveFile& file) {
		@state = MiningColonyScenario();

		initDialogue();
		loadDialoguePosition(file);
	}

	void initDialogue() {
		// FIXME doesn't display
		Dialogue("DOGFIGHT_TRAINING_INTRO")
			.setSpeaker(Sprite(material::emp_portrait_harrian), "General Nova");
		Dialogue("DOGFIGHT_TRAINING_INTRO2")
			.newObjective.checker(1, CheckDestroyFleet());
		Dialogue("DOGFIGHT_TRAINING_PROGRESS");
		Dialogue("DOGFIGHT_TRAINING_PROGRESS2")
			.newObjective.checker(1, CheckDestroyAllFleets());
		Dialogue("DOGFIGHT_TRAINING_COMPLETE")
			.onStart(EndCinematic(this)); // doesn't work?????
	}

#section all
};

#section server
uint getEnemyFleetCount() {
	DataList@ objs = getEmpire(1).getFlagships();
	Object@ obj;
	uint index = 0;
	while(receive(objs, obj)) {
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null) {
			++index;
		}
	}
	return index;
}

uint getPlayerFleetCount() {
	DataList@ objs = getEmpire(0).getFlagships();
	Object@ obj;
	uint index = 0;
	while(receive(objs, obj)) {
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null) {
			++index;
		}
	}
	return index;
}

class CheckDestroyFleet : ObjectiveCheck {
	bool check() {
		return getEnemyFleetCount() < 3;
	}
};

class CheckDestroySecondFleet : ObjectiveCheck {
	bool check() {
		return getEnemyFleetCount() < 2;
	}
};

class CheckDestroyAllFleets : ObjectiveCheck {
	bool check() {
		return getEnemyFleetCount() == 0;
	}
};

class CheckLostAllFleets : ObjectiveCheck {
	bool check() {
		return getPlayerFleetCount() == 0;
	}
};

class EndCinematic : DialogueAction {
	Scenario@ scen;
	EndCinematic(Scenario@ _scen) { @scen = _scen; }
	bool start() {
		// this code never gets called despite the API for dialogue.as
		// claiming otherwise, the text still shows though?????
		completeCampaignScenario("MiningColonyScenario");
		return true;
	}
};
#section all
