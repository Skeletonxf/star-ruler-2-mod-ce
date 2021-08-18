import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.race.Race;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Development;
import empire_ai.weasel.Fleets;
import empire_ai.weasel.Movement;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Designs;
import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;
import empire_ai.dragon.expansion.resource_value;
import empire_ai.dragon.logs;

import oddity_navigation;
from abilities import getAbilityID;
from statuses import getStatusID;

// TODO: star killer mission
// TODO: star killer ship type
// TODO: frostkin AI component

double HEALTH_ABORT_THRESHOLD = 0.9;
double HEALTH_MISSION_THRESHOLD = 0.95;

class FreezeMission : Mission {
	Star@ target;
	Region@ region;
	MoveOrder@ move;
	uint retries = 0;

	void save(Fleets& fleets, SaveFile& file) override {
		file << target;
		file << region;
		fleets.movement.saveMoveOrder(file, move);
		file << retries;
	}

	void load(Fleets& fleets, SaveFile& file) override {
		file >> target;
		file >> region;
		@move = fleets.movement.loadMoveOrder(file);
		file >> retries;
	}

	void start(AI& ai, FleetAI& fleet) override {
		uint priority = MP_Normal;
		if (gameTime < 30.0 * 60.0) // TODO: This should not be hardcoded to game time
			priority = MP_Critical;
		@move = cast<Movement>(ai.movement).move(fleet.obj, target, priority);
	}

	void tick(AI& ai, FleetAI& fleet, double time) override {
		if (fleet.flagshipHealth < HEALTH_ABORT_THRESHOLD) {
			if (LOG) {
				ai.print("Aborted freeze mission, took too much damage", fleet.obj);
			}
			onCancel(ai);
			cast<Fleets>(ai.fleets).returnToBase(fleet, MP_Critical);
			return;
		}
		if (move !is null) {
			if (move.failed || move.completed) {
				retries += 1;
				@move = cast<Movement>(ai.movement).move(fleet.obj, target, priority);
				if (retries > 2 || move.completed) {
					int ablId = cast<Frostkin>(ai.race).freezeAbilityID;
					fleet.obj.activateAbilityTypeFor(ai.empire, ablId, target);

					@move = null;
					retries = 0;
				}
			}
		}
		else {
			if (target is null || !target.valid) {
				// TODO: Move onto next star in region
			}
		}
	}

	void onCancel(AI& ai) {
		canceled = true;
		if (target !is null && target.valid) {
			if (LOG) {
				ai.print("Freeze failed at "+region.name);
			}
			// TODO
		}
	}
}

class Frostkin : Race {
	Construction@ construction;
	Movement@ movement;
	Systems@ systems;
	Fleets@ fleets;
	Designs@ designs;

	int freezeAbilityID = -1;

	uint systemCheckIndex = 0;
	uint borderCheckIndex = 0;

	array<FleetAI@> starEaters;

	void save(SaveFile& file) override {
		file << systemCheckIndex;
		file << borderCheckIndex;
		fleets.saveFleetList(file, starEaters);
	}

	void load(SaveFile& file) override {
		file >> systemCheckIndex;
		file >> borderCheckIndex;
		starEaters = fleets.loadFleetList(file);
	}

	void create() override {
		@construction = cast<Construction>(ai.construction);
		@movement = cast<Movement>(ai.movement);
		@systems = cast<Systems>(ai.systems);
		@fleets = cast<Fleets>(ai.fleets);
		@designs = cast<Designs>(ai.designs);

		freezeAbilityID = getAbilityID("StarEater");
	}

	void start() override {
		// TODO: Design and build another star eater?
	}

	void turn() {
		//lookToBuildNewStarEaters();
	}

	uint chkInd = 0;
	void focusTick(double time) override {
		checkStarEaters();
		clearRegions();
	}

	void checkStarEaters() {
		// Detect star eaters
		for (uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if (flAI.fleetClass != FC_StarEater)
				continue;

			if (starEaters.find(flAI) == -1) {
				// Add to our tracking list
				starEaters.insertLast(flAI);
			}
		}

		// Stop tracking invalid star eaters
		for (uint i = 0, cnt = starEaters.length; i < cnt; ++i) {
			Object@ obj = starEaters[i].obj;
			if (obj is null || !obj.valid || obj.owner !is ai.empire) {
				starEaters.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void clearRegions() {
		if (systems.owned.length == 0) {
			return;
		}
		systemCheckIndex = (systemCheckIndex+1) % systems.owned.length;
		checkSystem(systems.owned[systemCheckIndex]);

		if (systems.border.length == 0) {
			return;
		}
		borderCheckIndex = (borderCheckIndex+1) % systems.border.length;
		SystemAI@ borderAI = systems.border[borderCheckIndex];
		checkSystem(systems.border[systemCheckIndex]);
	}

	void checkSystem(SystemAI@ systemAI) {
		if (systemAI.obj is null || systemAI.totalTemperature() == 0) {
			return;
		}
		tryClear(systemAI);
	}

	void tryClear(SystemAI@ systemAI) {
		// TODO
	}
}

AIComponent@ createFrostkin() {
	return Frostkin();
}