import orders.Order;
import cargo;
import saving;
from statuses import getStatusID;

// Credit to Dalo Lorn for providing the starting point of this cargo order
// system

tidy class CargoOrder : Order {
	Object@ target;
	// cargoId must be either a valid cargo id, in which case this cargo order
	// is for a single type of cargo, or -1, in which case this order transfers
	// all types of cargo from source to destination
	int cargoId = -1;
	bool pickup;
	int moveId = -1;
	int canGiveCargoStatusID = -1;
	int canTakeCargoStatusID = -1;
	// If non zero, a limit on how much cargo we want to transfer, which
	// may be less than our actual cargo capacity
	double capacityLimit = 0;

	CargoOrder(Object@ targ, int id, bool pickup, double capacityLimit = 0) {
		@target = targ;
		cargoId = id;
		this.pickup = pickup;
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
		this.capacityLimit = capacityLimit;
	}

	CargoOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> cargoId;
		file >> pickup;
		file >> moveId;
		file >> capacityLimit;
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << cargoId;
		file << pickup;
		file << moveId;
		file << capacityLimit;
	}

	string get_name() {
		const CargoType@ type = getCargoType(cargoId);
		string cargoName = "";
		if (cargoId == -1) {
			cargoName = "all";
		}
		if (type !is null) {
			cargoName = type.name;
		}
		string targetName = "";
		if (target !is null) {
			targetName = target.name;
		}
		if (pickup) {
			return "Pickup " + cargoName + " from " + targetName;
		} else {
			return "Dropoff " + cargoName + " at " + targetName;
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

	// Override the extra info to send to client about this order
	int getCargoId() { return cargoId; }
	bool getIsPickup() { return pickup; }
	bool getIsDropoff() { return !pickup; }

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

		// Interpret -1 cargo id as transfer/pickup all cargo types, to
		// avoid duplicating 99% of this file as a seperate order
		if (cargoId == -1) {
			if (!((dest.cargoCapacity - dest.cargoStored) > 0
				&& src.cargoStored > 0)) {
				return OS_COMPLETED;
			}
		} else {
			if (!(type !is null
				&& (dest.cargoCapacity - dest.cargoStored) > 0
				&& src.getCargoStored(cargoId) > 0)) {
					return OS_COMPLETED;
				}
		}

		double range = 100 + obj.radius + target.radius;
		double distance = obj.position.distanceToSQ(target.position);
		if (distance >= range*range) {
			obj.moveTo(target, moveId, range * 0.95, enterOrbit = false);
		} else {
			if (capacityLimit > 0.0) {
				if (cargoId == -1) {
					src.transferAllCargoToFixed(dest, capacityLimit);
				} else {
					src.transferCargoToFixed(cargoId, dest, capacityLimit);
				}
			} else {
				if (cargoId == -1) {
					src.transferAllCargoTo(dest);
				} else {
					src.transferCargoTo(cargoId, dest);
				}
			}
			if (moveId != -1) {
				moveId = -1;
				obj.stopMoving(false, false);
			}
			return OS_COMPLETED;
		}
		return OS_BLOCKING;
	}
}
