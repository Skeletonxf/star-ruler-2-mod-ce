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

#section server
/**
 * Scenario state for running post map generation. Of particular note is that
 * SystemData persists only for map generation, so cannot be used if the game
 * is saved and reloaded, which is what this class is for.
 */
class DogfightScenario {
	Empire@ player;
	Empire@ enemy;
	const SystemDesc@ simulationSystem;

	DogfightScenario(Empire@ player, Empire@ enemy, SystemDesc@ simulationSystem) {
		@this.player = player;
		@this.enemy = enemy;
		@this.simulationSystem = simulationSystem;
	}

	/**
	 * Gets the AI object for the enemy empire.
	 */
	AI@ getEnemyAIObject() {
		return cast<AI>(cast<EmpireAI>(enemy.EmpireAI).ctrl);
	}

	/**
	 * Gets the i'th planet of this scenario's only system.
	 */
	Planet@ planet(uint id) {
		Region@ region = simulationSystem.object;
		if (region is null) {
			return null;
		}
		if (id < region.planetCount)  {
			return region.planets[id];
		}
		return null;
	}

	void tick() {
		// Prevent the AI from generating support ships
		enemy.setDefending(planet(0), false);
		enemy.setDefending(planet(2), false);

		if (gameTime > 5) {
			if (getEnemyFleetCount() == 0) {
				completeCampaignScenario("DogfightTraining");
				triggerVictory();
			}

			if (getPlayerFleetCount() == 0) {
				triggerDefeat();
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
		populate(planet(0), enemy, 1.0);
		populate(planet(2), enemy, 1.0);
		populate(planet(1), player, 1.0);
		populate(planet(3), player, 1.0);

		spawnFleet(enemy, planet(0).position + vec3d(50.0,0.0,0.0), "Dreadnaught", 10);
		spawnFleet(enemy, planet(2).position + vec3d(40.0,0.0,0.0), "Dreadnaught", 10);
		spawnFleet(enemy, planet(2).position + vec3d(-40.0,0.0,0.0), "Dreadnaught", 10);
		spawnFleet(player, planet(1).position + vec3d(40.0,0.0,0.0), "Dreadnaught", 10);
		spawnFleet(player, planet(3).position + vec3d(50.0,0.0,0.0), "Dreadnaught", 10);

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

		player.setDefending(planet(1), true);
		player.setDefending(planet(3), true);

		// TODO: Hijack the war / relation code to make the enemy AI have such
		// a high hate level that it will refuse all surrenders
		AI@ enemyAI = getEnemyAIObject();
		War@ enermyAIWarComponent = cast<War>(enemyAI.war);
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
		loadMap("maps/TerraCampaign/dogfight.txt").generate(this);
	}

	void preGenerate() {
		Map::preGenerate();
		radius = 40000;
	}

	void modSettings(GameSettings& settings) {
		settings.empires.length = 2;
		settings.empires[0].name = locale::DOGFIGHT_TRAINING_PLAYER_EMP;
		settings.empires[0].shipset = "Gevron";
		settings.empires[0].portrait = "emp_portrait_harrian";
		settings.empires[1].name = locale::DOGFIGHT_TRAINING_ENEMY_EMP;
		settings.empires[1].shipset = "Volkur";
		settings.empires[1].type = ET_WeaselAI;
		settings.empires[1].portrait = "emp_portrait_first";
		config::ENABLE_UNIQUE_SPREADS = 0.0;
		config::DISABLE_STARTING_FLEETS = 1.0;
		config::ENABLE_DREAD_PIRATE = 0.0;
		config::ENABLE_INFLUENCE_EVENTS = 0.0;
		config::START_EXPLORED_MAP = 1.0;
		auto@ noResourceUse = getTrait("NoResourceUse");
		settings.empires[0].addTrait(noResourceUse);
		settings.empires[1].addTrait(noResourceUse);
	}

	DogfightScenario@ state;

	void init() {
		Empire@ enemy = getEmpire(1);

		playerEmpire.setHostile(enemy, true);
		enemy.setHostile(playerEmpire, true);
		playerEmpire.Victory = -3;
		enemy.Victory = -3;

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
		@state = DogfightScenario(getEmpire(0), getEmpire(1), getSystem(0));
		state.postInit();
	}

	void save(SaveFile& file) {
		/* file << player;
		file << enemy;
		file << simulationSystem; */
		saveDialoguePosition(file);
	}

	void load(SaveFile& file) {
		/* file >> player;
		file >> enemy;
		file >> simulationSystem; */
		@state = DogfightScenario(getEmpire(0), getEmpire(1), getSystem(0));

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
		completeCampaignScenario("DogfightTraining");
		return true;
	}
};
#section all
