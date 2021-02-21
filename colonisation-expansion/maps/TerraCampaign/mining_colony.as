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
// TOOD: Add pressure capacity to AI's and player's main planets
// TODO: Either fix the Mechanoid AI wasting all its money on Labor storage
// on planets that don't need to build anything, or hack it a way to keep
// it producing ships and/or money income at least before its eco gets
// destroyed by economy attacks via the player
// TODO: Give player starting ships 3 times the supply storage and no supply
// leakage so they don't run out of resources way too fast to see the effects
// of bombing

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
	bool suppliedDyson = false;
	bool selectedMiner = false;
	bool won = false;
	double lastTickedMiningShips = -55;
	// avoid computing some things when we immediately reopen a save because
	// not everything is initialised instantly
	double gameTimeAtLastSave = 0;
	double enemyKickstarted = 0;
	double enemyLastEffort = 0;

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

			if (getEmpireFleetCount(enemy) == 0 && enemyKickstarted != 0 && gameTime > enemyKickstarted + 10) {
				if (enemyLastEffort != 0 && gameTime > enemyLastEffort + 10) {
					completeCampaignScenario("MiningColony");
					won = true;
					triggerVictory();
				} else {
					// spawn in an armored heavy carrier as a 'last ditch effort'
					// onto any tier 2 or 3 world of the AI's so the player doesn't
					// autowin after taking out the Dreadnaughts.
					// If the player is doing awfully at this campaign, the AI will
					// also start making its own ships as it is coded to in normal games,
					// and the eco difference will likely mean the player loses a drawn
					// out game.
					Planet@ spawnPlanet;
					DataList@ objs = enemy.getPlanets();
					Object@ obj;
					while (receive(objs, obj)) {
						Planet@ planet = cast<Planet>(obj);
						if (planet !is null && spawnPlanet is null && planet.level >= 2) {
							@spawnPlanet = planet;
						}
					}
					if (spawnPlanet is null) {
						completeCampaignScenario("MiningColony");
						won = true;
						triggerVictory();
					} else {
						spawnFleet(enemy, spawnPlanet.position + vec3d(60.0,0.0,60.0), "Armored Heavy Carrier", 300);
						spawnFleet(enemy, spawnPlanet.position + vec3d(-60.0,0.0,-60.0), "Armored Heavy Carrier", 300);
						spawnFleet(enemy, spawnPlanet.position + vec3d(60.0,0.0,-60.0), "Armored Heavy Carrier", 300);
						enemyLastEffort = gameTime;
					}
				}
			}

			if (!suppliedDyson) {
				auto@ ore = getCargoType("Ore");
				Planet@ dyson = planet(0, 6);
				if (dyson !is null && ore !is null) {
					suppliedDyson = dyson.getCargoStored(ore.id) > 0;
				}
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
				uint miningShips = 0;
				while (receive(objs, obj)) {
					Ship@ ship = cast<Ship>(obj);
					if (ship !is null) {
						ship.addAutoMineOrder(dropOffPlanet);
						miningShips += 1;
					}
				}

				if (miningShips < 6) {
					spawnFleet(ally, dropOffPlanet.position + vec3d(-40.0,0.0,-40.0), "Miner", 0);
				}
			}
		}

		if (enemyKickstarted == 0 && (suppliedDyson || gameTime > 3 * 60)) {
			for (uint i = 0; i < 3; ++i) {
				spawnFleet(enemy, planet(1,1).position + vec3d(-40.0,0.0,40.0), "Dreadnaught", 0);
				spawnFleet(enemy, planet(2,1).position + vec3d(-40.0,0.0,-40.0), "Dreadnaught", 0);
				spawnFleet(enemy, planet(3,0).position + vec3d(80.0,0.0,0.0), "Dreadnaught", 0);
			}
			enemyKickstarted = gameTime;
		}
	}

	/**
	 * Post map generation initialisation, only to run once per scenario
	 * (ie not again after reloading).
	 */
	void postInit() {
		auto@ ore = getCargoType("Ore");
		populate(planet(0, 0), ally, 1.0, exportTo=planet(0, 2));
		populate(planet(0, 1), ally, 1.0, exportTo=planet(0, 2));
		populate(planet(0, 2), ally, 3.0);
		if (ore !is null) {
			// asesthetics, make it looks like the ally was mining for a while
			planet(0, 0).addCargo(ore.id, 5321);
			planet(0, 1).addCargo(ore.id, 7819);
			planet(0, 2).addCargo(ore.id, 3786);
			planet(0, 3).addCargo(ore.id, 9355);
		}
		// spawn some comets for the player to use
		spawnArtifact(planet(0,1).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnArtifact(planet(0,0).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnArtifact(planet(0,2).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnArtifact(planet(0,3).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnArtifact(planet(0,0).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnArtifact(planet(0,1).position + vec3d(randomd(-40, 40),0.0,randomd(-40, 40)), "Comet");
		spawnBuilding(planet(0, 2), vec2i(2, 3), "Factory");
		spawnBuilding(planet(0, 2), vec2i(5, 4), "Factory");
		populate(planet(0, 3), player, 3.0);
		populate(planet(0, 5), player, 1.0, exportTo=planet(0, 3));
		spawnBuilding(planet(0, 3), vec2i(1, 1), "Hydrogenator");
		spawnBuilding(planet(0, 3), vec2i(4, 1), "Factory");
		spawnBuilding(planet(0, 3), vec2i(7, 1), "Factory");
		// start player close to next food resource
		auto@ forestation = getCargoType("Forestation");
		if (forestation !is null) {
			planet(0, 3).addCargo(forestation.id, 90);
		}
		populate(planet(1, 3), enemy, 12.0);
		spawnBuilding(planet(1, 3), vec2i(2, 3), "FTLStorage");
		spawnBuilding(planet(1, 3), vec2i(6, 4), "FTLBreeder");
		populate(planet(3, 1), enemy, 12.0);
		spawnBuilding(planet(3, 1), vec2i(2, 3), "FTLStorage");
		spawnBuilding(planet(3, 1), vec2i(5, 5), "FTLBreeder");

		removeStartingIncomes();
		for (uint i = 0; i < empires.length; i++) {
			empires[i].modFTLStored(+250);
			empires[i].modTotalBudget(+200);
		}
		enemy.modFTLIncome(+0.1);
		enemy.modTotalBudget(+500);
		player.modTotalBudget(+500);

		@playerShip = spawnFleet(player, planet(0,3).position + vec3d(180.0,0.0,0.0), "Heavy Carrier Bomber", 0);
		spawnFleet(player, planet(0,3).position + vec3d(-40.0,0.0,40.0), "Heavy Carrier Bomber", 0);
		spawnFleet(player, vec3d(400.0,0.0,400.0), "Miner", 0);
		spawnFleet(player, vec3d(400.0,0.0,-300.0), "Miner", 0);
		spawnFleet(player, vec3d(-400.0,0.0,-400.0), "Miner", 0);
		playerShip.addStatus(getStatusID("Leader"));
		spawnOrbital(player, vec3d(640.0,0.0,740.0), "TradeOutpost");
		spawnOrbital(player, vec3d(0.0,0.0,0.0), "DysonSphere");

		spawnOrbital(ally, vec3d(-740.0,0.0,-840.0), "TradeOutpost");
		spawnFleet(ally, planet(0,2).position + vec3d(120.0,0.0,-120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(-120.0,0.0,120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(-120.0,0.0,-120.0), "Miner", 0);
		spawnFleet(ally, planet(0,2).position + vec3d(120.0,0.0,120.0), "Miner", 0);
	}

	void triggerDefeat() {
		declareVictor(enemy);
	}

	void save(SaveFile& file) {
		file << playerShip;
		file << lastTickedMiningShips;
		file << enemyLastEffort;
		file << suppliedDyson;
		file << enemyKickstarted;
	}

	void load(SaveFile& file) {
		file >> playerShip;
		file >> lastTickedMiningShips;
		file >> enemyLastEffort;
		file >> suppliedDyson;
		file >> enemyKickstarted;
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
		state.save(file);
	}

	void load(SaveFile& file) {
		@state = MiningColonyScenario();

		initDialogue();
		loadDialoguePosition(file);
		state.load(file);
	}

	void initDialogue() {
		// MINING_COLONY_INTRO ->
		// |
		// |--> MINING_COLONY_INTRO2 when select mining ship
		// |
		// |--> MINING_COLONY_INTRO3 when follow instructions to supply dyson
		// |---> MINING_COLONY_INTRO4 when click through
		// |
		// |--> MINING_COLONY_VICTORY if win game
		// |
		// |--> MINING_COLONY_LOST if ally dies
		// |
		// |--> MINING_COLONY_PLAYER_DEAD if player dies
		Dialogue("MINING_COLONY_INTRO")
			.newObjective
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this)))._or_(CheckMiningShipSelected()));
		Dialogue("MINING_COLONY_INTRO2")
			.newObjective
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this))._or_(CheckDysonSupplied(this))._or_(CheckMiningShipOrdered())));
		// skippable means the player can click through this dialogue
		// onto the next one before passing any of the checks which
		Dialogue("MINING_COLONY_INTRO3")
			.newObjective
			.checker(1, CheckVictory(this)._or_(CheckPlayerDead(this)._or_(CheckLostColonies(this))), skippable = true);
		Dialogue("MINING_COLONY_INTRO4")
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

class CheckDysonSupplied : CEObjectiveCheck {
	Scenario@ scenario;
	CheckDysonSupplied(Scenario@ scenario) { @this.scenario = scenario; }

	bool check() {
		if (scenario.state is null) {
			return false;
		}
		return scenario.state.suppliedDyson;
	}
};

class CheckMiningShipSelected : CEObjectiveCheck {
	CheckMiningShipSelected() {}

	bool check() {
		for (uint i = 0, cnt = playerEmpire.fleetCount; i < cnt; ++i) {
			if (playerEmpire.fleets[i].selected) {
				Ship@ ship = cast<Ship>(playerEmpire.fleets[i]);
				if (ship is null) {
					continue;
				}
				const Design@ dsg = ship.blueprint.design;
				if (dsg.name == "Miner") {
					return true;
				}
			}
		}
		return false;
	}
};

class CheckMiningShipOrdered : CEObjectiveCheck {
	CheckMiningShipOrdered() {}

	bool check() {
		auto@ ore = getCargoType("Ore");
		if (ore is null) {
			return false;
		}
		for (uint i = 0, cnt = playerEmpire.fleetCount; i < cnt; ++i) {
			Ship@ ship = cast<Ship>(playerEmpire.fleets[i]);
			if (ship is null) {
				continue;
			}
			const Design@ dsg = ship.blueprint.design;
			if (dsg.name == "Miner") {
				if (ship.isLoopingOrders() && ship.hasCargoPickupOrder(ore.id, checkQueued = true) && ship.hasAnyCargoDropoffOrder(checkQueued = true)) {
					return true;
				}
			}
		}
		return false;
	}
};
#section all
