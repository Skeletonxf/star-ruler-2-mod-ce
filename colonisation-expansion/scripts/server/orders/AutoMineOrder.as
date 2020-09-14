import orders.Order;
import cargo;
import saving;
from statuses import getStatusID;

tidy class AutoMineOrder : Order {
	/**
	 * The dropoff target we are supplying. This is where we will transfer
	 * all our cargo each time it gets full.
	 */
	Object@ dropoffTarget;
	/**
	 * The current mining target. This will switch to the next closest each
	 * time an asteroid is depleted, and will auto cast to the nearest asteroid
	 * when starting the order, to allow players to fly a mining ship to the
	 * desired asteroid belt before starting auto mining to pick the mining
	 * location.
	 */
	Object@ miningTarget;
	int moveId = -1;

	AutoMineOrder(Object@ dropoffTarget) {
		@this.dropoffTarget = dropoffTarget;
	}

	AutoMineOrder(SaveFile& file) {
		Order::load(file);
		file >> dropoffTarget;
		file >> miningTarget;
		file >> moveId;
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << dropoffTarget;
		file << miningTarget;
		file << moveId;
	}

	string get_name() {
		string targetName = "";
		if (dropoffTarget !is null) {
			targetName = dropoffTarget.name;
		}
		return "AutoMine to supply " + targetName;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if (dropoffTarget !is null) {
			return dropoffTarget.position;
		}
		return vec3d();
	}

	OrderType get_type() {
		return OT_AutoMine;
	}

	OrderStatus tick(Object& obj, double time) {
		if (!obj.hasMover || !obj.hasCargo || dropoffTarget is null || !dropoffTarget.hasCargo || dropoffTarget.owner !is obj.owner) {
			return OS_COMPLETED;
		}

		// NYI
		return OS_COMPLETED;
	}
}
