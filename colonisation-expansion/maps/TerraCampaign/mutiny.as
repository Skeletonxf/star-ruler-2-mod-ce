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
import settings.game_settings;
import CE_campaign_helpers;
import cargo;
from statuses import getStatusID;
from abilities import getAbilityID;
#section all

// TODO: Disable artifact spawning

#section server

/**
 * Scenario state for running post map generation. Of particular note is that
 * SystemData persists only for map generation, so cannot be used if the game
 * is saved and reloaded, which is what this class is for.
 */
class MutinyScenario : CampaignScenarioState {
	Empire@ player;
	Empire@ enemy;
	Ship@ playerShip;
	bool playerDead = false;
	bool lostColonies = false;
	bool won = false;
	// avoid computing some things when we immediately reopen a save because
	// not everything is initialised instantly
	double gameTimeAtLastSave = -1;

	MutinyScenario() {
		@player = getEmpire(0);
		@enemy = getEmpire(1);
		array<Empire@> empires = {player, enemy};
		array<SystemDesc@> systems = {
			getSystem(0), getSystem(1), getSystem(2), getSystem(3), getSystem(4)
		};
		super(systems, empires);
		AI@ enemyAI = getAI(enemy);
		// don't hold back one fleet
		enemyAI.behavior.battleReserveFleets = 0;
		// attack even if we're going to lose
		enemyAI.behavior.attackStrengthOverkill = 0;
		// always try to be in an aggressive war with the player
		enemyAI.behavior.aggressiveWarOverkill = 0;
		// be a little more sluggish at retreating than by default
		enemyAI.behavior.retreatThreshold = 0.35;
		// don't scout, the AI has all the vision it needs anyway
		enemyAI.behavior.scoutsActive = 0;
	}

	void tick() {
		if (gameTimeAtLastSave == -1) {
			// not loaded or postInit yet
			return;
		}
		if (gameTime <= gameTimeAtLastSave + 5) {
			// things won't be reloaded in yet!
			return;
		}

		if (gameTime > 5) {
			if (getEmpirePlanetCount(enemy) == 0) {
				completeCampaignScenario("Mutiny");
				won = true;
				triggerVictory();
			}

			if (!getEmpireFleetHasShip(player, playerShip)) {
				playerDead = true;
				triggerDefeat();
			}

			if (getEmpirePlanetCount(player) == 0) {
				lostColonies = true;
				triggerDefeat();
			}
		}
	}

	/**
	 * Post map generation initialisation, only to run once per scenario
	 * (ie not again after reloading).
	 */
	void postInit() {
		populate(planet(0, 0), player, 1.0);
		spawnBuilding(planet(0, 0), vec2i(2, 3), "Factory");

		populate(planet(4, 1), enemy, 20.0);
		spawnBuilding(planet(4, 1), vec2i(2, 3), "Factory");
		spawnBuilding(planet(4, 1), vec2i(6, 4), "Factory");
		populate(planet(4, 0), enemy, 1.0, exportTo=planet(4, 1));
		populate(planet(3, 0), enemy, 1.0, exportTo=planet(4, 1));

		removeStartingIncomes();
		for (uint i = 0; i < empires.length; i++) {
			empires[i].modFTLStored(+250);
			empires[i].modTotalBudget(+200);
		}
		@playerShip = spawnFleet(player, vec3d(0.0, 0.0, 100.0), "Heavy Carrier", 0);
		playerShip.addStatus(getStatusID("Leader"));
		spawnFleet(player, vec3d(0.0, 0.0, -200.0), "Heavy Carrier", 0);

		gameTimeAtLastSave = 0;
	}

	void triggerDefeat() {
		declareVictor(enemy);
	}

	void save(SaveFile& file) {
		file << playerShip;
		gameTimeAtLastSave = gameTime;
		file << gameTimeAtLastSave;
	}

	void load(SaveFile& file) {
		file >> playerShip;
		file >> gameTimeAtLastSave;
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
		loadMap("maps/TerraCampaign/mutiny.txt").generate(this);
	}

	void preGenerate() {
		Map::preGenerate();
		radius = 1500000;
	}

	void modSettings(GameSettings& settings) {
		settings.empires.length = 2;

		settings.empires[0].name = locale::MINING_COLONY_PLAYER_EMP;
		settings.empires[0].shipset = "Gevron";
		settings.empires[0].portrait = "emp_portrait_harrian";

		settings.empires[1].name = locale::MINING_COLONY_ALLY_EMP;
		settings.empires[1].shipset = "Volkur";
		settings.empires[1].type = ET_WeaselAI;
		settings.empires[1].portrait = "emp_portrait_harrian";
		settings.empires[1].color = colors::Red;

		config::ENABLE_UNIQUE_SPREADS = 0.0;
		config::DISABLE_STARTING_FLEETS = 1.0;
		config::ENABLE_DREAD_PIRATE = 0.0;
		config::ENABLE_INFLUENCE_EVENTS = 0.0;
		config::START_EXPLORED_MAP = 1.0;
		config::INFLUENCE_CONTACT_BONUS = 0.0;

		array<const Trait@> terraTraits;
		terraTraits.insertLast(getTrait("Empire"));
		terraTraits.insertLast(getTrait("Terrestial"));
		terraTraits.insertLast(getTrait("Hyperdrive"));
		terraTraits.insertLast(getTrait("NoResearch"));
		terraTraits.insertLast(getTrait("MiningColony"));
		settings.empires[0].traits = terraTraits;

		array<const Trait@> mutineerTraits;
		mutineerTraits.insertLast(getTrait("Empire"));
		mutineerTraits.insertLast(getTrait("Terrestial"));
		mutineerTraits.insertLast(getTrait("Hyperdrive"));
		mutineerTraits.insertLast(getTrait("NoResearch"));
		mutineerTraits.insertLast(getTrait("MiningColony"));
		mutineerTraits.insertLast(getTrait("Mutineers"));
		settings.empires[1].traits = mutineerTraits;

		// hostile stops the mining colony from surrendering
		uint flags = 0;
		flags |= AIF_Hostile;
		// enable smarter components
		flags |= AIF_Dragon;
		settings.empires[1].aiFlags = flags;
	}

	MutinyScenario@ state;

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
		@state = MutinyScenario();
		state.postInit();
	}

	void save(SaveFile& file) {
		saveDialoguePosition(file);
		state.save(file);
	}

	void load(SaveFile& file) {
		@state = MutinyScenario();

		initDialogue();
		loadDialoguePosition(file);
		state.load(file);
	}

	void initDialogue() {
		// MUTINY_INTRO ->
		// |--> MUTINY_VICTORY if win game
		// |
		// |--> MUTINY_LOST if ally dies
		// |
		// |--> MUTINY_PLAYER_DEAD if player dies
		Dialogue("MUTINY_INTRO")
			.newObjective
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this))));
		Dialogue("MUTINY_VICTORY")
			.newObjective
			.checker(1, CheckPlayerDead(this)._or_(CheckLostColonies(this)));
		Dialogue("MUTINY_LOST")
			.newObjective
			.checker(1, CheckPlayerDead(this));
		Dialogue("MUTINY_PLAYER_DEAD");
	}

#section all
};

#section server
class CheckLostColonies : CEObjectiveCheck {
	Scenario@ scenario;
	CheckLostColonies(Scenario@ scenario) { @this.scenario = scenario; }

	bool check() {
		if (scenario.state is null) {
			return false;
		}
		return scenario.state.lostColonies;
	}
};

class CheckPlayerDead : CEObjectiveCheck {
	Scenario@ scenario;
	CheckPlayerDead(Scenario@ scenario) { @this.scenario = scenario; }

	bool check() {
		if (scenario.state is null) {
			return false;
		}
		return scenario.state.playerDead;
	}
};

class CheckVictory : CEObjectiveCheck {
	Scenario@ scenario;
	CheckVictory(Scenario@ scenario) { @this.scenario = scenario; }

	bool check() {
		if (scenario.state is null) {
			return false;
		}
		return scenario.state.won;
	}
};
#section all
