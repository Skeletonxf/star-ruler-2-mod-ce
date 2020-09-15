import orders.Order;
import cargo;
import saving;
import resources;
import regions.regions;
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
	vec3d miningPosition;
	bool startedOrder;
	bool mining = true;
	// appliedBeam is not saved to file, as beam effects are lost on reload
	bool appliedBeam = false;
	int moveId = -1;
	int canMineAsteroidsStatusID = -1;

	AutoMineOrder(Object@ dropoffTarget) {
		@this.dropoffTarget = dropoffTarget;
		startedOrder = false;
		canMineAsteroidsStatusID = getStatusID("CanMineAsteroids");
	}

	AutoMineOrder(SaveFile& file) {
		Order::load(file);
		file >> dropoffTarget;
		file >> miningTarget;
		file >> miningPosition;
		file >> startedOrder;
		file >> moveId;
		file >> mining;
		canMineAsteroidsStatusID = getStatusID("CanMineAsteroids");
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << dropoffTarget;
		file << miningTarget;
		file << miningPosition;
		file << startedOrder;
		file << moveId;
		file << mining;
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
		if (miningTarget !is null && mining) {
			return miningTarget.position;
		}
		if (dropoffTarget !is null) {
			return dropoffTarget.position;
		}
		return vec3d();
	}

	OrderType get_type() {
		return OT_AutoMine;
	}

	void removeAppliedBeam(Object& obj) {
		if (appliedBeam) {
			int64 beam = (obj.id << 32) | (0x2 << 24);
			removeGfxEffect(ALL_PLAYERS, beam);
			appliedBeam = false;
		}
	}

	OrderStatus tick(Object& obj, double time) {
		if (!obj.hasMover || !obj.hasCargo || dropoffTarget is null || !dropoffTarget.hasCargo || dropoffTarget.owner !is obj.owner) {
			removeAppliedBeam(obj);
			return OS_COMPLETED;
		}

		if (!obj.hasStatusEffect(canMineAsteroidsStatusID)) {
			if (appliedBeam) {
				int64 beam = (obj.id << 32) | (0x2 << 24);
				removeGfxEffect(ALL_PLAYERS, beam);
				appliedBeam = false;
			}
			return OS_COMPLETED;
		}

		// mine from where we were when starting this order
		if (!startedOrder) {
			miningPosition = obj.position;
			startedOrder = true;
		}

		if (miningTarget is null) {
			// look for nearest asteroid
			Region@ region = getRegion(miningPosition);

			// TODO: Work out how to find closest region later
			if (region is null) {
				removeAppliedBeam(obj);
				return OS_COMPLETED;
			}

			uint asteroidsInRegion = region.asteroidCount;
			double closestDistance = -1;

			// TODO: Try nearby regions that we have vision of till find an
			// asteroid
			Asteroid@ closest;
			DataList@ objs = region.getAsteroids();
			Object@ obj;
			while (receive(objs, obj)) {
				Asteroid@ asteroid = cast<Asteroid>(obj);
				if (closestDistance == -1 || asteroid.position.distanceToSQ(miningPosition) < closestDistance) {
					@closest = asteroid;
					closestDistance = asteroid.position.distanceToSQ(miningPosition);
				}
			}
			@miningTarget = closest;

			// Depleted all asteroids, stop order
			if (miningTarget is null) {
				removeAppliedBeam(obj);
				return OS_COMPLETED;
			}

			mining = true;
		}

		if (miningTarget !is null && (obj.cargoCapacity - obj.cargoStored) > 0) {
			// mine target
			double distance = obj.position.distanceToSQ(miningTarget.position);
			double range = 100 + obj.radius + miningTarget.radius;
			if (distance >= range*range) {
				obj.moveTo(miningTarget, moveId, range * 0.95, enterOrbit = false);
				removeAppliedBeam(obj);
			} else {
				Ship@ ship = cast<Ship>(obj);
				double rate = 0;
				if (ship !is null) {
					rate = ship.blueprint.design.total(SV_MiningRate);
				}
				if (rate == 0) {
					return OS_COMPLETED;
				}
				miningTarget.transferPrimaryCargoTo(obj, time * rate);
				if (miningTarget.cargoStored == 0) {
					// stop holding a reference to a depleted asteroid, and
					// get ready to look for the closest one next tick
					miningPosition = miningTarget.position;
					@miningTarget = null;
				}
				if (moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}

				// apply beam effect or cancel
				if (!appliedBeam) {
					// compute the beam id we will use for mining beam graphics
					int64 beam = (obj.id << 32) | (0x2 << 24);
					makeBeamEffect(ALL_PLAYERS, beam, obj, miningTarget, 0x91692cff, obj.radius, "Tractor", -1.0);
					appliedBeam = true;
				}
			}
			mining = true;
		}

		if (!((obj.cargoCapacity - obj.cargoStored) > 0)) {
			removeAppliedBeam(obj);

			// dropoff
			double distance = obj.position.distanceToSQ(dropoffTarget.position);
			double range = 100 + obj.radius + dropoffTarget.radius;
			if (distance >= range*range) {
				obj.moveTo(dropoffTarget, moveId, range * 0.95, enterOrbit = false);
			} else {
				obj.transferAllCargoTo(dropoffTarget);
				if (moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
			}
			mining = false;
		}

		// NYI
		return OS_BLOCKING;
	}
}
