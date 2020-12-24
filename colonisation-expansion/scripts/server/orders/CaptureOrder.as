import orders.Order;

tidy class CaptureOrder : Order {
	Planet@ target;
	vec3d offset;
	int moveId = -1;

	CaptureOrder(Planet& targ) {
		@target = targ;
		double radius = targ.OrbitSize - targ.radius;
		vec2d pos = random2d(targ.radius + radius * 0.15, targ.radius + radius*0.85);
		offset = vec3d(pos.x, 0, pos.y);
		moveId = -1;
	}

	CaptureOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> target;
		msg >> offset;
		msg >> moveId;
	}

	void save(SaveFile& msg) {
		Order::save(msg);
		msg << target;
		msg << offset;
		msg << moveId;
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
		}

		// [[ MODIFY BASE GAME START ]]
		// TODO: Can probably make capturing a moving planet work a lot better
		// if we move to the position the planet is going to be at after x amount
		// of time, just need to find some good heuristics for this
		// Might also need to not use a moveTo order, as it tries to reach
		// its destination at 0 velocity whereas we need to match the velocity
		// of our target
		// [[ MODIFY BASE GAME END ]]
		obj.moveTo(target.position + offset, moveId);
		return OS_BLOCKING;
	}
};
