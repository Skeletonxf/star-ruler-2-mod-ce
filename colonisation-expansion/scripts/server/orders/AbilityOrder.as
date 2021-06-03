import orders.Order;
import saving;

tidy class AbilityOrder : Order {
	int abilityId = -1;
	int moveId = -1;
	double range = 100.0;
	vec3d target;
	Object@ objTarget;
	bool casted = false;
	// [[ MODIFY BASE GAME START ]]
	bool recastIfNotActive = false;
	// [[ MODIFY BASE GAME END ]]

	AbilityOrder(int id, vec3d targ, double range) {
		abilityId = id;
		target = targ;
		this.range = range;
	}

	AbilityOrder(int id, Object@ targ, double range) {
		abilityId = id;
		@objTarget = targ;
		this.range = range;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if(objTarget !is null)
			return objTarget.position;
		return target;
	}

	AbilityOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> moveId;
		file >> abilityId;
		file >> objTarget;
		if(file >= SV_0121)
			file >> casted;
		// [[ MODIFY BASE GAME START ]]
		file >> recastIfNotActive;
		// [[ MODIFY BASE GAME END ]]
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << moveId;
		file << abilityId;
		file << objTarget;
		file << casted;
		// [[ MODIFY BASE GAME START ]]
		file << recastIfNotActive;
		// [[ MODIFY BASE GAME END ]]
	}

	// [[ MODIFY BASE GAME START ]]
	void resetForAnotherLoop() {
		recastIfNotActive = true;
	}
	// [[ MODIFY BASE GAME END ]]

	string get_name() {
		return "Use Ability";
	}

	OrderType get_type() {
		return OT_Ability;
	}

	OrderStatus tick(Object& obj, double time) {
		if(!obj.hasMover)
			return OS_COMPLETED;

		double realRange = range;
		realRange += obj.radius;

		// [[ MODIFY BASE GAME START ]]
		if (recastIfNotActive && casted && !obj.isChanneling(abilityId)) {
			bool alreadyTargeting = false;
			if (objTarget !is null) {
				alreadyTargeting = obj.isTargeting(abilityId, objTarget);
			} else {
				alreadyTargeting = obj.isTargeting(abilityId, target);
			}
			if (!alreadyTargeting) {
				// we need to change the target back
				casted = false;
			}
			recastIfNotActive = false;
		}
		// [[ MODIFY BASE GAME END ]]

		if(objTarget !is null) {
			realRange += objTarget.radius;
			bool finishedMove = false;
			double distance = obj.position.distanceToSQ(objTarget.position);
			if(range != INFINITY && distance >= realRange * realRange)
				finishedMove = obj.moveTo(objTarget, moveId, realRange * 0.95, enterOrbit=false);
			if(casted) {
				if(obj.isChanneling(abilityId))
					return OS_BLOCKING;
				else
					return OS_COMPLETED;
			}
			if(obj.isAbilityOnCooldown(abilityId))
				return OS_BLOCKING;
			if(distance <= realRange * realRange) {
				obj.activateAbility(abilityId, objTarget);
				if(moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
				casted = true;
			}
			return OS_BLOCKING;
		}
		else {
			bool finishedMove = false;
			double distance = obj.position.distanceToSQ(target);
			if(realRange != INFINITY && distance >= realRange * realRange) {
				vec3d pt = target;
				pt += (obj.position - target).normalized(realRange * 0.95);
				finishedMove = obj.moveTo(pt, moveId, enterOrbit=false);
			}
			if(casted) {
				if(obj.isChanneling(abilityId))
					return OS_BLOCKING;
				else
					return OS_COMPLETED;
			}
			if(obj.isAbilityOnCooldown(abilityId))
				return OS_BLOCKING;
			if(distance <= realRange * realRange) {
				obj.activateAbility(abilityId, target);
				if(moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
				casted = true;
			}
			return OS_BLOCKING;
		}
	}
};
