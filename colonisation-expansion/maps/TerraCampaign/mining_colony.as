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
#section all

// TODO: Disable artifact spawning
// TODO: Prohibit building research complexes as part of NoResearch trait
// TODO: Give the human player a flagship which is considered to have them on it
// with bonus efficiency but game over if it gets destroyed
// TODO: Disable all conditions on spawned planets, ie native life, vanilla ones
// TODO: Move common scenario code into a parent class
// TODO: Remove instant 'discover' influence effect

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

		// TODO: Create mining ships over time for mining colony empire
		// and set all to automine and dropoff at whichever planets the
		// empire still controls

		// TODO: Player loses if the mining colony runs out of planets
		// or if their commander fleet gets destroyed

		// TODO: Player wins if they take out the mono entirely
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
		populate(planet(SCS_Main, 4), enemy, 10.0);
		array<ScenarioSystem> others = {
			SCS_Other1, SCS_Other2, SCS_Other3, SCS_Other4, SCS_Other5
		};
		for (uint i = 0; i < others.length; i++) {
			uint j = 0;
			Planet@ pl = planet(others[i], j);
			while (pl !is null) {
				populate(pl, enemy, 8.0);
				j += 1;
				@pl = planet(others[i], j);
			}
		}

		// setup some exports for vultri to get them going
		// oil and titanium to uranium
		planet(SCS_Other3, 0).exportResource(enemy, 0, planet(SCS_Other3, 1));
		planet(SCS_Other1, 1).exportResource(enemy, 0, planet(SCS_Other3, 1));
		// natural gas and rate metals to supercarbons
		planet(SCS_Other4, 0).exportResource(enemy, 0, planet(SCS_Other4, 1));
		planet(SCS_Other4, 2).exportResource(enemy, 0, planet(SCS_Other4, 1));

		array<Empire@> empires = {player, ally, enemy};
		for (uint i = 0; i < empires.length; i++) {
			empires[i].modFTLStored(+250);
			empires[i].modInfluenceIncome(-100);
			empires[i].modInfluence(-5);
			empires[i].modEnergyIncome(-3);
			empires[i].modResearchRate(-1);
			empires[i].modTotalBudget(-500);
		}

		// TODO: Build factories on each empire's main planet
		// TODO: Make a custom design for the player to give them prototype
		// hyperdrives and spawn in custom fleets
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

		array<const Trait@> vultriTraits;
		vultriTraits.insertLast(getTrait("Theocracy"));
		vultriTraits.insertLast(getTrait("Mechanoid"));
		vultriTraits.insertLast(getTrait("Sublight"));
		vultriTraits.insertLast(getTrait("NoResearch"));
		settings.empires[2].traits = vultriTraits;

		array<const Trait@> terraTraits;
		terraTraits.insertLast(getTrait("Empire"));
		terraTraits.insertLast(getTrait("Terrestial"));
		terraTraits.insertLast(getTrait("Hyperdrive")); // TODO: Create prototype hyperdrive trait
		terraTraits.insertLast(getTrait("NoResearch"));
		settings.empires[0].traits = terraTraits;
		settings.empires[1].traits = terraTraits;

		// hostile stops the mining colony from being subjugated by the vultri
		uint flags = 0;
		flags |= AIF_Hostile;
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
		Dialogue("MINING_COLONY_INTRO");
		Dialogue("MINING_COLONY_INTRO2");
			/* .newObjective.checker(1, CheckDestroyFleet());
		Dialogue("DOGFIGHT_TRAINING_PROGRESS");
		Dialogue("DOGFIGHT_TRAINING_PROGRESS2")
			.newObjective.checker(1, CheckDestroyAllFleets());
		Dialogue("DOGFIGHT_TRAINING_COMPLETE")
			.onStart(EndCinematic(this)); // doesn't work????? */
	}

#section all
};

#section server
// TODO: hooks for game end detection and dialogue
#section all
