import orders.Order;
import saving;

tidy class AttackOrder : Order {
	Object@ target;
	int moveId = -1;
	uint flags = TF_Preference;
	bool movement = true;
	double minRange = 0;
	quaterniond facing;

	bool isBound = false;
	vec3d boundPos;
	double boundDistance = 0;
	vec3d fleePos;
	bool closeIn = false;
	bool dodgeObstacle = false;

	// graphical only, so not saved to file
	vec3d moveDestination = vec3d();

	// [[ MODIFY BASE GAME START ]]
	AttackOrder(Object& targ, double engagementRange, bool closeIn) {
		minRange = engagementRange;
		@target = targ;
		this.closeIn = closeIn;
		moveDestination = target.position;
	}

	AttackOrder(Object& targ, double engagementRange, const vec3d bindPosition, double bindDistance, bool closeIn) {
		minRange = engagementRange;
		@target = targ;
		boundPos = bindPosition;
		boundDistance = bindDistance;
		isBound = true;
		this.closeIn = closeIn;
		moveDestination = target.position;
	}
	// [[ MODIFY BASE GAME END ]]

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		return moveDestination;
	}

	AttackOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> target;
		msg >> moveId;
		msg >> flags;
		msg >> movement;
		msg >> minRange;
		if(msg >= SV_0062) {
			msg >> isBound;
			msg >> boundPos;
			msg >> boundDistance;
			msg >> fleePos;
		}
		if(msg >= SV_0066)
			msg >> closeIn;
	}

	void save(SaveFile& msg) {
		Order::save(msg);
		msg << target;
		msg << moveId;
		msg << flags;
		msg << movement;
		msg << minRange;
		msg << isBound;
		msg << boundPos;
		msg << boundDistance;
		msg << fleePos;
		msg << closeIn;
	}

	string get_name() {
		return "Attack " + target.name;
	}

	OrderType get_type() {
		return OT_Attack;
	}

	OrderStatus tick(Object& obj, double time) {
		if(!obj.hasMover)
			return OS_COMPLETED;

		//Switch targets if targeting a group
		if(target is null || !target.valid) {
			//Only complete the order if we're out
			//of combat, so we don't mess up the
			//combat positioning
			if(obj.inCombat && flags & TF_Group != 0) {
				if(moveId != -1) {
					obj.stopMoving();
					moveId = -1;
				}
				return OS_BLOCKING;
			}
			return OS_COMPLETED;
		}

		if(!target.memorable && !target.isVisibleTo(obj.owner)) {
			if(moveId != -1) {
				obj.stopMoving();
				moveId = -1;
			}
			return OS_COMPLETED;
		}

		if(!target.isVisibleTo(obj.owner) && (!target.memorable || !target.isKnownTo(obj.owner))) {
			if(moveId != -1) {
				obj.stopMoving();
				moveId = -1;
			}
			return OS_COMPLETED;
		}

		Ship@ ship = cast<Ship>(obj);
		// [[ MODIFY BASE GAME START ]]
		Planet@ planet = cast<Planet>(obj);
		Orbital@ orbital = cast<Orbital>(obj);
		if (ship is null && planet is null && orbital is null) {
			// break only if attacking with neither a ship, orbital or planet,
			//  not just if attacking with a non ship
			return OS_COMPLETED;
		}
		// [[ MODIFY BASE GAME END ]]

		Empire@ myOwner = obj.owner;
		Empire@ targOwner = target.owner;
		if(myOwner is null || targOwner is null || !myOwner.isHostile(targOwner)) {
			if(moveId != -1) {
				obj.stopMoving();
				moveId = -1;
			}
			return OS_COMPLETED;
		}

		// [[ MODIFY BASE GAME START ]]
		// Not sure what this does with ships, but just do nothing if
		// attacking with something else
		if (ship !is null) {
			//Set effector targets
			ship.blueprint.target(obj, target, flags);
		}
		// [[ MODIFY BASE GAME END ]]

		// [[ MODIFY BASE GAME START ]]
		// set visual to target
		moveDestination = target.position;
		// head to where the target will be in 2 seconds
		// has no effect if the target is stationary, but should help
		// pursuing moving targets
		vec3d targetHeaded = target.position + target.velocity * 2.0;
		vec3d targetPosition = target.position;
		double distSQ = obj.position.distanceToSQ(targetHeaded);
		if (!closeIn) {
			// if set to keep distance, scan the nearby area for enemies
			// this does scan a square instead of a circle but circles are
			// expensive and I doubt anyone will notice
			// TODO: We should probably *keep* keeping distance even if we
			// take out the enemy target while we remain in combat
			array<Object@>@ objs = findInBox(obj.position - minRange, obj.position + minRange, obj.owner.hostileMask);
			for (uint i = 0, cnt = objs.length; i < cnt; ++i) {
				Object@ enemy = objs[i];
				if (!enemy.isShip && !enemy.isOrbital) {
					continue;
				}
				if (enemy.hasSupportAI) {
					continue;
				}
				if (!enemy.valid || !enemy.isVisibleTo(obj.owner)) {
					continue;
				}
				double d = obj.position.distanceToSQ(enemy.position + enemy.velocity * 2.0);
				if (d < distSQ) {
					// this becomes the target we strafe for as long as they are
					// too close to us
					targetHeaded = enemy.position + enemy.velocity * 2.0;
					targetPosition = enemy.position;
					distSQ = d;
				}
			}
		}

		// [[ MODIFY BASE GAME END ]]
		if(distSQ > minRange * minRange) {
			if(!movement)
				return OS_COMPLETED;
			if(moveId == -1)
				facing = quaterniond_fromVecToVec(vec3d_front(), target.position - obj.position);
			if(obj.moveTo(target, moveId, minRange * 0.9, enterOrbit=false))
				obj.setRotation(facing);
			fleePos = vec3d();
		}
		// [[ MODIFY BASE GAME START ]]
		else if((!closeIn) && distSQ < (minRange * 0.75) * (minRange * 0.75)) {
			// get out of there
			if(!movement)
				return OS_COMPLETED;

			// strafe in 2d because math is hard and no one uses the y dimension anyway
			vec3d plane = targetPosition - obj.position;
			plane.y = 0;

			// in the extremely unlikely scenario of no x or z difference, add one in
			if (plane.x == 0 && plane.z == 0)
				plane.x += 1;

			// compute the two orthogonal vectors to the line between us and the target
			// in the 2d plane
			vec3d left = vec3d();
			left.x = plane.z * -1;
			left.z = plane.x;
			vec3d right = vec3d();
			right.x = plane.z;
			right.z = plane.x * -1;


			left = left.normalize();
			right = right.normalize();

			// pick the evade direction that requires the least adjustment
			vec3d evade = vec3d();
			// use the plane as a fallback if we're stationary
			// compute quaternions in evade directions
			quaterniond leftRotation = quaterniond_fromVecToVec(vec3d_front(), left);
			quaterniond rightRotation = quaterniond_fromVecToVec(vec3d_front(), right);
			// check what percent out of 0 to 1 are we towards each direction
			// and take the closest
			double toLeft = obj.rotation.dot(leftRotation);
			double toRight = obj.rotation.dot(rightRotation);
			// FIXME: This doesn't seem quite right
			// borrow this angle checking code from the mover component
			// instead, it looks more like an actual angle calculation
			/* double dot = targRot.dot(obj.rotation);
			if(dot < 0.999) {
				if(dot < -1.0)
					dot = -1.0;
				double angle = acos(dot); // we don't need to take acos for our comparison as acos is monotonic
				double tickRot = rotSpeed * time;
				if(angle > tickRot) {
					obj.rotation = obj.rotation.slerp(targRot, tickRot / angle);
				}
				else {
					obj.rotation = targRot;
					rotating = false;
				}
			}
			else {
				if(dot != 1.0)
					obj.rotation = targRot;
				rotating = false;
			} */
			if (toLeft > toRight) {
				evade.x = left.x;
				evade.z = left.z;
			} else {
				evade.x = right.x;
				evade.z = right.z;
			}

			// we need to pick a reasonable distance to evade by, now we have
			// a direction. As we want to stay in attack range we'll evade by
			// the difference.
			double distance = sqrt(distSQ);
			double evadeDistance = minRange - distance;

			evade.x *= evadeDistance;
			evade.z *= evadeDistance;

			// convert evade from offset to a position
			evade.x += obj.position.x;
			evade.z += obj.position.z;
			// reset the y to be in the same plane as we are currently
			evade.y = obj.position.y;

			if(moveId == -1)
				facing = quaterniond_fromVecToVec(vec3d_front(), evade);

			// set visual to evade position
			moveDestination = evade;

			// HACK: make sure the move actually happens
			// Not quite sure why this is needed but it is
			moveId = -1;
			// move to evasion point
			if(obj.moveTo(evade, moveId, doPathing=false, enterOrbit=false))
				obj.setRotation(facing);
			fleePos = vec3d();
		}
		// [[ MODIFY BASE GAME END ]]
		else if(closeIn && distSQ < (minRange * 0.75) * (minRange * 0.75)) {
			if(!movement)
				return OS_COMPLETED;
			if(moveId == -1)
				facing = quaterniond_fromVecToVec(vec3d_front(), target.position - obj.position);

			//Calculate the position we would be going to
			if(!fleePos.zero) {
				if(obj.moveTo(fleePos, moveId, doPathing=false, enterOrbit=false))
					fleePos = vec3d();
			}
			else {
				// [[ MODIFY BASE GAME START ]]
				// I do not understand why blind mind would want a ship that was ordered
				// to close in on an enemy ever deciding it should not close in if that
				// would leave its current region?
				// perhaps it makes sense when vanilla wouldn't let you tell a ship to close in
				// manually????
				// we just use the constructor that makes ships bound when appropriate from
				// LeaderAI now, so no need for this
				/* if(!isBound) {
					Region@ reg = obj.region;
					if(reg !is null) {
						boundPos = reg.position;
						boundDistance = reg.radius;
						isBound = true;
					}
				} */
				// [[ MODIFY BASE GAME END ]]
				if(isBound) {
					vec3d offset = (obj.position - target.position).normalized(minRange);
					vec3d destPos = target.position + offset;
					if(destPos.distanceToSQ(boundPos) > boundDistance * boundDistance * 0.95 * 0.95) {
						double angle = randomd(pi*0.4,pi*0.6) * (randomi(0,1) == 0 ? -1.0 : 1.0);
						auto rot = quaterniond_fromAxisAngle(vec3d_up(), angle);
						fleePos = target.position + rot * offset;
						moveId = -1;
						return OS_BLOCKING;
					}
				}

				// [[ MODIFY BASE GAME START ]]
				// If we're set to close in, and we're already closer than minRange,
				// don't try to back off because that makes us run away which
				// is the opposite of closing in
				double desiredDistanceToTarget = min(minRange, sqrt(distSQ));
				if(obj.moveTo(target, moveId, desiredDistanceToTarget, enterOrbit=false))
					obj.setRotation(facing);
				// [[ MODIFY BASE GAME END ]]
			}
		}
		else if(dodgeObstacle) {
			if(moveId == -1 || !obj.isOnMoveOrder(moveId))
				dodgeObstacle = false;
		}
		else {
			fleePos = vec3d();
			if(moveId != -1) {
				obj.stopMoving(enterOrbit=false);
				moveId = -1;
			}
			else {
				line3dd line(obj.position, target.position);
				auto@ blocker = trace(line, obj.owner.hostileMask | 0x1);
				if(blocker !is null && blocker !is target && (blocker.isPlanet || blocker.isStar)) {
					//Move to a position that gets us around the obstacle
					double dist = (blocker.radius + obj.radius * 2.0) * 1.2;
					vec3d to = line.getClosestPoint(blocker.position, false);
					if(to != blocker.position)
						to = blocker.position + (to - blocker.position).normalized(dist);
					else
						to = blocker.position + quaterniond_fromAxisAngle(line.direction, randomd(-pi,pi)) * line.direction.cross(vec3d_up()).normalized(dist);
					obj.moveTo(to, moveId, false, false);
					dodgeObstacle = true;
				}
			}
		}

		return OS_BLOCKING;
	}
};
