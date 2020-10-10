import orders.Order;
import cargo;
import saving;
import resources;
import regions.regions;
import systems;
from statuses import getStatusID;

tidy class ConsumePlanetOrder : Order {
	Object@ target;
	int moveId = -1;
	// appliedBeam is not saved to file, as beam effects are lost on reload
	bool appliedBeam = false;
	int canConsumePlanetsStatusID = -1;

	ConsumePlanetOrder(Object@ target) {
		@this.target = target;
		canConsumePlanetsStatusID = getStatusID("CanConsumePlanets");
	}

	ConsumePlanetOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> moveId;
		canConsumePlanetsStatusID = getStatusID("CanConsumePlanets");
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << moveId;
	}

	string get_name() {
		string targetName = "";
		if (target !is null) {
			targetName = target.name;
		}
		return "Consume Planet " + targetName;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if (target !is null) {
			return target.position;
		}
		return vec3d();
	}

	OrderType get_type() {
		return OT_ConsumePlanet;
	}

	void removeAppliedBeam(Object& obj) {
		if (appliedBeam) {
			int64 beam = (obj.id << 32) | (0x2 << 24);
			removeGfxEffect(ALL_PLAYERS, beam);
			appliedBeam = false;
		}
	}

	OrderStatus tick(Object& obj, double time) {
		if (!obj.hasMover || target is null || obj.owner is null) {
			removeAppliedBeam(obj);
			return OS_COMPLETED;
		}

		if (!obj.hasStatusEffect(canConsumePlanetsStatusID)) {
			removeAppliedBeam(obj);
			return OS_COMPLETED;
		}

		if (!target.isPlanet) {
			removeAppliedBeam(obj);
			return OS_COMPLETED;
		}

		bool needsWar = target.owner !is null && target.owner.valid;
		bool isProtected = target.isProtected(obj.owner);
		bool hostile = obj.owner.isHostile(target.owner);
		bool canConsume = !isProtected && ((needsWar && hostile) || (!needsWar));

		if (!canConsume) {
			removeAppliedBeam(obj);
			return OS_COMPLETED;
		}

		double distance = obj.position.distanceToSQ(target.position);
		double range = 50 + obj.radius + target.radius;
		if (distance >= range*range) {
			obj.moveTo(target, moveId, range * 0.95, enterOrbit = false);
			removeAppliedBeam(obj);
		} else {
			// apply beam effect
			if (!appliedBeam) {
				// compute the beam id we will use for consume graphics
				int64 beam = (obj.id << 32) | (0x2 << 24);
				makeBeamEffect(ALL_PLAYERS, beam, obj, target, 0xe45500ff, obj.radius, "Tractor", -1.0);
				appliedBeam = true;
			}
			if (moveId != -1) {
				moveId = -1;
				obj.stopMoving(false, enterOrbit = true);
			}

			Ship@ ship = cast<Ship>(obj);
			double damageRate = 0;
			if (ship !is null) {
				damageRate = ship.blueprint.design.total(SV_ConsumeDamage);
			}
			Planet@ planet = cast<Planet>(target);
			if (planet !is null) {
				planet.dealPlanetDamage(damageRate * time);
			} else {
				// we did it, probably
				// TODO: Apply living space benefits only when planet destroyed
				removeAppliedBeam(obj);
				return OS_COMPLETED;
			}
		}

		return OS_BLOCKING;
	}

	/**
	 * Remove beam when cancelled
	 */
	bool cancel(Object& obj) override {
		removeAppliedBeam(obj);
		return true;
	}
}
