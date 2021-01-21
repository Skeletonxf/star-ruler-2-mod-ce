import orders.Order;

tidy class ChaseOrder : Order {
	Object@ target;
	bool initialized = false;
	vec3d offset = vec3d();
	int moveId = -1;

	ChaseOrder(Object& targ) {
		@target = targ;
		moveId = -1;
	}

	ChaseOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> target;
		msg >> offset;
		msg >> moveId;
		msg >> initialized;
	}

	void save(SaveFile& msg) {
		Order::save(msg);
		msg << target;
		msg << offset;
		msg << moveId;
		msg << initialized;
	}

	OrderType get_type() {
		return OT_Chase;
	}

	string get_name() {
		return "Chase " + target.name;
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

		if(target is null
			|| !target.valid
			|| !target.memorable && !target.isVisibleTo(obj.owner)
			|| !target.isVisibleTo(obj.owner) && (!target.memorable || !target.isKnownTo(obj.owner))
		) {
			if(moveId != -1) {
				obj.stopMoving();
				moveId = -1;
			}
			return OS_COMPLETED;
		}

		if (!initialized) {
			vec2d pos = random2d((obj.radius + target.radius) * 1.25, (obj.radius + target.radius) * 1.45);
			offset = vec3d(pos.x, 0, pos.y);
			initialized = true;
		}

		// do not allow the movement order to finish
		moveId = -1;

		// move to the position the target is going to be at after 3 seconds
		// so we chase objects trying to flee
		vec3d targetHeaded = target.position + offset + target.velocity * 3;
		obj.moveTo(targetHeaded, moveId);
		return OS_BLOCKING;
	}
};
