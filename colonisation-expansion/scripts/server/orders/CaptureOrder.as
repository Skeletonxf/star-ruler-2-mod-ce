import orders.Order;

tidy class CaptureOrder : Order {
	Planet@ target;
	vec3d offset;
	int moveId = -1;
	bool reachedTarget = false;

	CaptureOrder(Planet& targ) {
		@target = targ;
		double radius = targ.OrbitSize - targ.radius;
		vec2d pos = random2d(targ.radius + radius * 0.15, targ.radius + radius*0.75); // [[ MODIFY BASE GAME ]] 0.85 -> 0.75
		offset = vec3d(pos.x, 0, pos.y);
		moveId = -1;
	}

	CaptureOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> target;
		msg >> offset;
		msg >> moveId;
		msg >> reachedTarget;
	}

	void save(SaveFile& msg) {
		Order::save(msg);
		msg << target;
		msg << offset;
		msg << moveId;
		msg << reachedTarget;
	}

	OrderType get_type() {
		return OT_Capture;
	}

	string get_name() {
		return "Capture " + target.name;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		return target.position + offset;
	}

	OrderStatus tick(Object& obj, double time) {
		if(!obj.hasMover)
			return OS_COMPLETED;

		Empire@ targOwner = target.owner;
		if(targOwner is obj.owner)
			return OS_COMPLETED;
		if(!obj.owner.isHostile(targOwner))
			return OS_COMPLETED;
		if(obj.isShip && cast<Ship>(obj).Supply <= 0.1)
			return OS_COMPLETED;

		if(target.isProtected(obj.owner))
			return OS_COMPLETED;

		double capRadius = target.OrbitSize;
		if(obj.position.distanceToSQ(target.position) < capRadius * capRadius) {
			int loy = target.getLoyaltyFacing(obj.owner);
			if(loy <= 0) {
				target.annex(obj.owner);
				return OS_COMPLETED;
			}
			reachedTarget = true;
		}
		// [[ MODIFY BASE GAME START ]]
		else {
			// if we fell back out of range, do not allow the movement order
			// to finish (this has a side effect of resetting our path, so
			// we cannot call this every tick or we break pathing through
			// oddities)
			if (reachedTarget) {
				moveId = -1;
				reachedTarget = false;
			}
		}
		// [[ MODIFY BASE GAME END ]]

		// [[ MODIFY BASE GAME START ]]
		// move to the position the planet is going to be at after 3 seconds
		// so we chase planets trying to flee
		vec3d targetHeaded = target.position + offset + target.velocity * 3;
		obj.moveTo(targetHeaded, moveId, enterOrbit=true);
		// [[ MODIFY BASE GAME END ]]
		return OS_BLOCKING;
	}
};
