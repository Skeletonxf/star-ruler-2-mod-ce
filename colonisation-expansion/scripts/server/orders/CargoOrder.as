import orders.Order;
import cargo;
import saving;
from statuses import getStatusID;

// Credit to Dalo Lorn for providing the starting point of this cargo order
// system

tidy class CargoOrder : Order {
	Object@ target;
	int cargoId = -1;
	bool pickup;
	int moveId = -1;
	int canGiveCargoStatusID = -1;
	int canTakeCargoStatusID = -1;

	CargoOrder(Object@ targ, int id, bool pickup) {
		@target = targ;
		cargoId = id;
		this.pickup = pickup;
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
	}

	CargoOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> cargoId;
		file >> pickup;
		file >> moveId;
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << cargoId;
		file << pickup;
		file << moveId;
	}

	string get_name() {
		string cargoName = getCargoType(cargoId).name;
		if (pickup) {
			return "Pickup " + cargoName + " from " + target.name;
		} else {
			return "Dropoff " + cargoName + " at " + target.name;
		}
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
		return OT_Cargo;
	}

	OrderStatus tick(Object& obj, double time) {
		if (!obj.hasMover || !obj.hasCargo || target is null || !target.hasCargo || target.owner !is obj.owner) {
			return OS_COMPLETED;
		}

		// Check obj still has CanGiveCargo/CanTakeCargo statuses as needed
		if (pickup && !obj.hasStatusEffect(canTakeCargoStatusID)) {
			return OS_COMPLETED;
		}
		if (!pickup && !obj.hasStatusEffect(canGiveCargoStatusID)) {
			return OS_COMPLETED;
		}

		const CargoType@ type = getCargoType(cargoId);

		Object@ src;
		Object@ dest;
		if (pickup) {
			@src = target;
			@dest = obj;
		} else {
			@src = obj;
			@dest = target;
		}

		if (!(type !is null
				&& (dest.cargoCapacity - dest.cargoStored) > 0
				&& src.getCargoStored(cargoId) > 0)) {
			return OS_COMPLETED;
		}

		double range = 100 + obj.radius + target.radius;
		double distance = obj.position.distanceToSQ(target.position);
		if (distance >= range*range) {
			obj.moveTo(target, moveId, range * 0.95, enterOrbit = false);
		} else {
			src.transferCargoTo(cargoId, dest);
			if (moveId != -1) {
				moveId = -1;
				obj.stopMoving(false, false);
			}
			return OS_COMPLETED;
		}
		return OS_BLOCKING;
	}
}
