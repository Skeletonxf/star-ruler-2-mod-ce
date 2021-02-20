import orders.Order;
import cargo;
import saving;
import resources;
import regions.regions;
import systems;
from statuses import getStatusID;

tidy class AutoSupplyOrder : Order {
	/**
	 * The supply target we are using to get our ore.
	 */
	Object@ pickupTarget;
	/**
	 * The current supply target.
	 */
	Object@ supplyTarget;
	Object@ lastSupplyTarget;
	bool supplying = true;
	int moveId = -1;
	uint systemCheckIndex = 0;
	bool searchingUniverse = false;
	const CargoType@ ore;
	int isDysonStatusID = -1;
	int canGiveCargoStatusID = -1;
	int canTakeCargoStatusID = -1;

	AutoSupplyOrder(Object@ pickupTarget) {
		@this.pickupTarget = pickupTarget;
		@ore = getCargoType("Ore");
		isDysonStatusID = getStatusID("DysonSphere");
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
	}

	AutoSupplyOrder(SaveFile& file) {
		Order::load(file);
		file >> pickupTarget;
		file >> supplyTarget;
		file >> lastSupplyTarget;
		file >> moveId;
		file >> supplying;
		file >> systemCheckIndex;
		file >> searchingUniverse;
		@ore = getCargoType("Ore");
		isDysonStatusID = getStatusID("DysonSphere");
		canGiveCargoStatusID = getStatusID("CanGiveCargo");
		canTakeCargoStatusID = getStatusID("CanTakeCargo");
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << pickupTarget;
		file << supplyTarget;
		file << lastSupplyTarget;
		file << moveId;
		file << supplying;
		file << systemCheckIndex;
		file << searchingUniverse;
	}

	string get_name() {
		string targetName = "";
		if (pickupTarget !is null) {
			targetName = pickupTarget.name;
		}
		return "AutoSupply from " + targetName;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if (supplyTarget !is null && supplying) {
			return supplyTarget.position;
		}
		if (pickupTarget !is null) {
			return pickupTarget.position;
		}
		return vec3d();
	}

	OrderType get_type() {
		return OT_AutoSupply;
	}

	// Finds the best dyson in a list. This is a little overkill as 99% of
	// the time there should only be 0 or 1 dysons in the list, but this is
	// future proofed for if we need to auto supply more things than dysons
	Planet@ findBestDyson(vec3d position, DataList@ objs) {
		double bestWeight = -1;
		Planet@ best;
		Object@ obj;
		while (receive(objs, obj)) {
			Planet@ planet = cast<Planet>(obj);
			if (planet.requiresOre <= 0) {
				continue;
			}
			if (bestWeight == -1 || dysonWeight(position, planet) > bestWeight) {
				@best = planet;
				bestWeight = dysonWeight(position, planet);
			}
		}
		return best;
	}

	/*
	 * Returns a weight score for a dyson. We try to find dysons which are
	 * close by, but also massively penalise dysons which have lots of stored
	 * cargo already. Close by dysons with very little cargo should maximise
	 * their weight score.
	 */
	double dysonWeight(vec3d position, Object& dyson) {
		if (dyson is lastSupplyTarget) {
			return 0.0000000000000001;
		}
		double distanceSQ = dyson.position.distanceToSQ(position);
		double cargo = dyson.getCargoStored(ore.id);
		return 1 / ((distanceSQ ** 0.5) * ((cargo + 0.001) * (cargo + 0.001)));
	}

	OrderStatus tick(Object& obj, double time) {
		if (ore is null) {
			return OS_COMPLETED;
		}

		if (!obj.hasMover || !obj.hasCargo || pickupTarget is null || !pickupTarget.valid || !pickupTarget.hasCargo || pickupTarget.owner !is obj.owner) {
			return OS_COMPLETED;
		}

		// Check obj and pickupTarget still has CanGiveCargo/CanTakeCargo statuses
		// as needed
		if (!obj.hasStatusEffect(canTakeCargoStatusID)) {
			return OS_COMPLETED;
		}
		if (!obj.hasStatusEffect(canGiveCargoStatusID)) {
			return OS_COMPLETED;
		}
		// Cannot call methods with return data on different objects unless the outer function is declared relocking
		// Dysons being planets should mean these checks are redundant anyway so let's just not bother.
		/* if (!pickupTarget.hasStatusEffect(canGiveCargoStatusID)) {
			return OS_COMPLETED;
		}
		if (supplyTarget !is null && !supplyTarget.hasStatusEffect(canGiveCargoStatusID)) {
			@supplyTarget = null;
		} */

		if (searchingUniverse || supplyTarget is null) {
			// look for most suitable dyson that needs supplies

			vec3d searchPosition = pickupTarget.position;
			if (obj.getCargoStored(ore.id) > 0.1) {
				searchPosition = obj.position;
			}

			if (!searchingUniverse && supplyTarget is null) {
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

					Planet@ bestInRegion = findBestDyson(searchPosition, region.getPlanets());
					if (bestInRegion !is null) {
						if (supplyTarget is null) {
							@supplyTarget = bestInRegion;
						} else {
							double currentWeight = dysonWeight(searchPosition, supplyTarget);
							double foundWeight = dysonWeight(searchPosition, bestInRegion);
							if (currentWeight < foundWeight) {
								@supplyTarget = bestInRegion;
							}
						}
					}
				}
				systemCheckIndex = i;

				if (i >= totalSystems) {
					searchingUniverse = false;
					if (supplyTarget is null) {
						// Do we have no dyson spheres anymore?
						return OS_COMPLETED;
					}
				} else {
					// not finished search yet
					return OS_BLOCKING;
				}
			}

			// begin mining
			supplying = true;
		}

		bool haveCargo = obj.getCargoStored(ore.id) > 0.1;
		if (supplyTarget !is null && haveCargo) {
			// supply target
			double distance = obj.position.distanceToSQ(supplyTarget.position);
			double range = 100 + obj.radius + supplyTarget.radius;
			if (distance >= range*range) {
				obj.moveTo(supplyTarget, moveId, range * 0.95, enterOrbit = false);
			} else {
				obj.transferCargoTo(ore.id, supplyTarget);
				@lastSupplyTarget = supplyTarget;
				if (obj.owner.ActiveDysons > 1) {
					// go supply a different one
					@supplyTarget = null;
				}
				if (moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
			}
			supplying = true;
		}

		if (!haveCargo) {
			// pickup cargo
			double distance = obj.position.distanceToSQ(pickupTarget.position);
			double range = 100 + obj.radius + pickupTarget.radius;
			if (distance >= range*range) {
				obj.moveTo(pickupTarget, moveId, range * 0.95, enterOrbit = false);
			} else {
				pickupTarget.transferCargoTo(ore.id, obj);
				if (moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
				@lastSupplyTarget = null;
			}
			supplying = false;
		}

		return OS_BLOCKING;
	}
}
