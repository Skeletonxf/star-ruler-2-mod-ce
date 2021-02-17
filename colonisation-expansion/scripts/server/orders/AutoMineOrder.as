import orders.Order;
import cargo;
import saving;
import resources;
import regions.regions;
import systems;
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
	uint systemCheckIndex = 0;
	bool searchingUniverse = false;

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
		file >> systemCheckIndex;
		file >> searchingUniverse;
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
		file << systemCheckIndex;
		file << searchingUniverse;
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

	Asteroid@ findClosestAsteroid(vec3d position, DataList@ objs) {
		double closestDistance = -1;
		Asteroid@ closest;
		Object@ obj;
		while (receive(objs, obj)) {
			Asteroid@ asteroid = cast<Asteroid>(obj);
			// ignore special asteroids that don't have ore
			if (asteroid.nativeResourceCount != 0) {
				continue;
			}
			if (closestDistance == -1 || asteroid.position.distanceToSQ(position) < closestDistance) {
				@closest = asteroid;
				closestDistance = asteroid.position.distanceToSQ(position);
			}
		}
		return closest;
	}

	OrderStatus tick(Object& obj, double time) {
		if (!obj.hasMover || !obj.hasCargo || dropoffTarget is null || !dropoffTarget.valid || !dropoffTarget.hasCargo || dropoffTarget.owner !is obj.owner) {
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

		if (searchingUniverse || miningTarget is null) {
			// look for nearest asteroid

			if (!searchingUniverse) {
				// look in the region the ship already mining in first
				Region@ region = getRegion(miningPosition);
				if (region !is null) {
					@miningTarget = findClosestAsteroid(miningPosition, region.getAsteroids());
				}

				if (miningTarget is null) {
					removeAppliedBeam(obj);
				}
			}

			if (!searchingUniverse && miningTarget is null) {
				// over multiple ticks, check every region
				searchingUniverse = true;
				systemCheckIndex = 0;
			}

			if (searchingUniverse) {
				// continue to check every region
				uint cnt = systemCheckIndex + 10;
				uint totalSystems = systemCount;
				uint i = systemCheckIndex;
				for (; i < totalSystems && i < cnt; ++i) {
					Region@ region = getSystem(i).object;

					// Ignore regions we haven't ever obtained vision of yet
					bool hasVision = region.MemoryMask & obj.owner.mask != 0;
					if (!hasVision) {
						continue;
					}

					Asteroid@ closestInRegion = findClosestAsteroid(miningPosition, region.getAsteroids());
					if (closestInRegion !is null) {
						if (miningTarget is null) {
							@miningTarget = closestInRegion;
						} else {
							double distanceToCurrent = miningTarget.position.distanceToSQ(miningPosition);
							double distanceToFound = closestInRegion.position.distanceToSQ(miningPosition);
							if (distanceToFound < distanceToCurrent) {
								@miningTarget = closestInRegion;
							}
						}
					}
				}
				systemCheckIndex = i;

				if (i >= totalSystems) {
					searchingUniverse = false;
					if (miningTarget is null) {
						// Depleted all asteroids known to the empire, stop order
						removeAppliedBeam(obj);
						return OS_COMPLETED;
					}
				} else {
					// not finished search yet
					return OS_BLOCKING;
				}
			}

			// begin mining
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
				if (ship is null) {
					Planet@ planet = cast<Planet>(obj);
					if (planet !is null) {
						// planets with mining complexes have a hardcoded
						// 'rapid' mining rate
						rate = 300;
					}
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
