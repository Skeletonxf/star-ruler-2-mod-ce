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
from statuses import getStatusID;
from abilities import getAbilityID;
#section all

// TODO: Disable artifact spawning
// TOOD: Add pressure capacity to AI's and player's main planets
// TODO: Either fix the Mechanoid AI wasting all its money on Labor storage
// on planets that don't need to build anything, or hack it a way to keep
// it producing ships and/or money income at least before its eco gets
// destroyed by economy attacks via the player

#section server

/**
 * Scenario state for running post map generation. Of particular note is that
 * SystemData persists only for map generation, so cannot be used if the game
 * is saved and reloaded, which is what this class is for.
 */
class MiningColonyScenario : CampaignScenarioState {
	Empire@ player;
	Empire@ ally;
	Empire@ enemy;
	Ship@ playerShip;
	bool playerDead = false;
	bool lostColonies = false;
	bool won = false;
	double lastTickedMiningShips = 0;

	MiningColonyScenario() {
		@player = getEmpire(0);
		@ally = getEmpire(1);
		@enemy = getEmpire(2);
		array<Empire@> empires = {player, ally, enemy};
		array<SystemDesc@> systems = {
			getSystem(0), getSystem(1), getSystem(2),
			getSystem(3), getSystem(4), getSystem(5)
		};
		super(systems, empires);
	}

	void tick() {
		if (gameTime > 5) {
			if (getEmpirePlanetCount(enemy) == 0) {
				completeCampaignScenario("MiningColony");
				won = true;
				triggerVictory();
			}

			if (!getEmpireFleetHasShip(player, playerShip)) {
				playerDead = true;
				triggerDefeat();
			}

			if (getEmpirePlanetCount(ally) == 0) {
				lostColonies = true;
				triggerDefeat();
			}
		}

		if (gameTime > lastTickedMiningShips + 60) {
			lastTickedMiningShips = gameTime;

			Planet@ dropOffPlanet;
			DataList@ objs = ally.getPlanets();
			Object@ obj;
			uint count = 0;
			while (receive(objs, obj)) {
				Planet@ planet = cast<Planet>(obj);
				if (planet !is null && dropOffPlanet is null) {
					@dropOffPlanet = planet;
				}
			}

			if (dropOffPlanet !is null) {
				DataList@ objs = ally.getFlagships();
				Object@ obj;
				int dropOffAbility = getAbilityID("DropoffPoint");
				uint miningShips = 0;
				while (receive(objs, obj)) {
					Ship@ ship = cast<Ship>(obj);
					if (ship !is null) {
						ship.activateAbilityTypeFor(ally, dropOffAbility, dropOffPlanet);
						miningShips += 1;
					}
				}

				if (miningShips < 6) {
					spawnFleet(ally, dropOffPlanet.position + vec3d(-40.0,0.0,-40.0), "Miner", 0);
				}
			}
		}
	}

	/**
	 * Post map generation initialisation, only to run once per scenario
	 * (ie not again after reloading).
	 */
	void postInit() {
		populate(planet(0, 0), ally, 1.0, exportTo=planet(0, 2));
		populate(planet(0, 1), ally, 1.0, exportTo=planet(0, 2));
		populate(planet(0, 2), ally, 3.0);
		spawnBuilding(planet(0, 2), vec2i(2, 3), "Factory");
		spawnBuilding(planet(0, 2), vec2i(5, 4), "Factory");
		populate(planet(0, 3), player, 3.0);
		populate(planet(0, 4), enemy, 5.0);
		populate(planet(0, 5), player, 1.0, exportTo=planet(0, 3));
		spawnBuilding(planet(0, 3), vec2i(1, 1), "Hydrogenator");
		spawnBuilding(planet(0, 3), vec2i(5, 1), "Factory");
		spawnBuilding(planet(0, 3), vec2i(5, 5), "Factory");
		for (uint i = 1; i < systems.length; i++) {
			uint j = 0;
			Planet@ pl = planet(i, j);
			while (pl !is null) {
				populate(pl, enemy, 3.0);
				j += 1;
				@pl = planet(i, j);
			}
		}

		// setup some exports for vultri to get them going
		// oil and titanium to uranium
		planet(3, 0).exportResource(enemy, 0, planet(3, 1));
		planet(1, 1).exportResource(enemy, 0, planet(3, 1));
		populate(planet(3, 1), enemy, 5.0);
		// natural gas and rate metals to supercarbons
		planet(4, 0).exportResource(enemy, 0, planet(4, 1));
		planet(4, 2).exportResource(enemy, 0, planet(4, 1));
		populate(planet(4, 1), enemy, 5.0);
		// get their hydroconductors to level 3
		planet(1, 4).exportResource(enemy, 0, planet(1, 3));
		planet(2, 4).exportResource(enemy, 0, planet(2, 3));
		populate(planet(2, 3), enemy, 5.0);
		planet(2, 3).exportResource(enemy, 0, planet(1, 3));
		planet(3, 0).exportResource(enemy, 0, planet(1, 3));
		populate(planet(1, 3), enemy, 7.0);
		// for some reason the AI just doesn't setup exports
		planet(3, 3).exportResource(enemy, 0, planet(3, 1));
		planet(5, 1).exportResource(enemy, 0, planet(5, 2));
		planet(5, 4).exportResource(enemy, 0, planet(5, 2));
        planet(0, 4).exportResource(enemy, 0, planet(1, 3));
        planet(2, 1).exportResource(enemy, 0, planet(1, 3));
        planet(2, 2).exportResource(enemy, 0, planet(1, 3));
        planet(5, 3).exportResource(enemy, 0, planet(1, 3));
        planet(1, 0).exportResource(enemy, 0, planet(1, 3));
        planet(1, 2).exportResource(enemy, 0, planet(1, 3));

		// setup defense for some planets because the AI is
		// quite slow to do this automatically
		enemy.setDefending(planet(0, 4), true);
		enemy.setDefending(planet(1, 3), true);
		enemy.setDefending(planet(2, 3), true);
		enemy.setDefending(planet(3, 1), true);
		enemy.setDefending(planet(4, 0), true);
		enemy.setDefending(planet(5, 4), true);

		removeStartingIncomes();
		for (uint i = 0; i < empires.length; i++) {
			empires[i].modFTLStored(+250);
			empires[i].modTotalBudget(+200);
		}
		// equipping the player with eco busting carpet bombs means the vultri's
		// eco will take a big hit, so give the AI some leeway to stay able to
		// buy countermeasures over time
		empires[2].modTotalBudget(+500);

		@playerShip = spawnFleet(player, planet(0,3).position + vec3d(180.0,0.0,0.0), "Heavy Carrier Bomber", 100);
		spawnFleet(player, planet(0,3).position + vec3d(-40.0,0.0,40.0), "Heavy Carrier Bomber", 50);
		spawnFleet(player, planet(0,3).position + vec3d(40.0,0.0,40.0), "Heavy Carrier Bomber", 50);
		spawnFleet(player, planet(0,3).position + vec3d(40.0,0.0,-40.0), "Heavy Carrier Bomber", 50);
		spawnFleet(player, planet(0,3).position + vec3d(-40.0,0.0,-40.0), "Heavy Carrier Bomber", 50);
		playerShip.addStatus(getStatusID("Leader"));
		spawnOrbital(player, vec3d(440.0,0.0,440.0), "TradeOutpost");

		spawnFleet(enemy, planet(1,1).position + vec3d(-40.0,0.0,40.0), "Dreadnaught", 50);
		spawnFleet(enemy, planet(2,1).position + vec3d(-40.0,0.0,-40.0), "Dreadnaught", 50);
		spawnFleet(enemy, planet(3,0).position + vec3d(80.0,0.0,0.0), "Dreadnaught", 50);
		spawnFleet(enemy, planet(4,0).position + vec3d(120.0,0.0,120.0), "Armored Heavy Carrier", 50);
		spawnFleet(enemy, planet(5,1).position + vec3d(-120.0,0.0,-120.0), "Armored Heavy Carrier", 50);

		spawnOrbital(ally, vec3d(-440.0,0.0,-440.0), "TradeOutpost");
		spawnFleet(ally, planet(0,2).position + vec3d(120.0,0.0,-120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(-120.0,0.0,120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(-120.0,0.0,-120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(120.0,0.0,120.0), "Miner", 0);
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
		settings.empires[1].color = 0x9765caff;

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
		config::INFLUENCE_CONTACT_BONUS = 0.0;

		array<const Trait@> vultriTraits;
		vultriTraits.insertLast(getTrait("Theocracy"));
		vultriTraits.insertLast(getTrait("Mechanoid"));
		vultriTraits.insertLast(getTrait("Sublight"));
		vultriTraits.insertLast(getTrait("NoResearch"));
		vultriTraits.insertLast(getTrait("Invaders"));
		settings.empires[2].traits = vultriTraits;

		array<const Trait@> terraTraits;
		terraTraits.insertLast(getTrait("Empire"));
		terraTraits.insertLast(getTrait("Terrestial"));
		terraTraits.insertLast(getTrait("Hyperdrive"));
		terraTraits.insertLast(getTrait("NoResearch"));
		terraTraits.insertLast(getTrait("MiningColony"));
		settings.empires[0].traits = terraTraits;
		settings.empires[1].traits = terraTraits;

		// hostile stops the mining colony from being subjugated by the vultri
		uint flags = 0;
		flags |= AIF_Hostile;
		// enable smarter components
		flags |= AIF_Dragon;
		settings.empires[1].aiFlags = flags;
		// hostile stops the vultri from trying to surrender
		settings.empires[2].aiFlags = flags;
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
		// MINING_COLONY_INTRO -> MINING_COLONY_INTRO2
		// |
		// |--> MINING_COLONY_VICTORY if win game
		// |
		// |--> MINING_COLONY_LOST if ally dies
		// |
		// |--> MINING_COLONY_PLAYER_DEAD if player dies
		Dialogue("MINING_COLONY_INTRO")
			.newObjective
			// skippable means the player can click through this dialogue
			// onto the next one before passing any of the checks which,
			// combined with the objective passing skipping this dialogue
			// automatically, creates divergent dialogue pathing
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this))), skippable = true);
		Dialogue("MINING_COLONY_INTRO2")
			.newObjective
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this))));
		Dialogue("MINING_COLONY_VICTORY")
			.newObjective
			.checker(1, CheckPlayerDead(this)._or_(CheckLostColonies(this)));
		Dialogue("MINING_COLONY_LOST")
			.newObjective
			.checker(1, CheckPlayerDead(this));
		Dialogue("MINING_COLONY_PLAYER_DEAD");
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
