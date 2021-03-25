import regions.regions;
import saving;
import systems;
import resources;
import civilians;
import statuses;
// [[ MODIFY BASE GAME START ]]
// Civilian scipt navigation improvements from Industrial Navigation
import oddity_navigation;
from traits import getTraitID;
// [[ MODIFY BASE GAME END ]]

const double ACC_SYSTEM = 2.0;
const double ACC_INTERSYSTEM = 65.0;
const int GOODS_WORTH = 8;
const double CIV_HEALTH = 25.0;
const double CIV_REPAIR = 1.0;
const double BLOCKADE_TIMER = 3.0 * 60.0;
// [[ MODIFY BASE GAME START ]]
const double DEST_RANGE = 20.0;

// Cache system defs to check things are unlocked
const SubsystemDef@ hyperdriveSubsystem = getSubsystemDef("Hyperdrive");
const SubsystemDef@ jumpdriveSubsystem = getSubsystemDef("Jumpdrive");
// [[ MODIFY BASE GAME END ]]

tidy class CivilianScript {
	uint type = 0;
	Object@ origin;
	Object@ pathTarget;
	Object@ intermediate;
	Region@ prevRegion;
	Region@ nextRegion;
	int moveId = -1;
	bool leavingRegion = false, awaitingIntermediate = false;
	// [[ MODIFY BASE GAME START ]]
	bool awaitingGateJump = false;
	// [[ MODIFY BASE GAME END ]]
	bool pickedUp = false;
	double Health = CIV_HEALTH;
	int stepCount = 0;
	int income = 0;
	bool delta = false;

	uint cargoType = CT_Goods;
	const ResourceType@ cargoResource;
	int cargoWorth = 0;

	double get_health() {
		return Health;
	}

	double get_maxHealth(const Civilian& obj) {
		return CIV_HEALTH * obj.radius * obj.owner.ModHP.value;
	}

	void load(Civilian& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		if(msg.readBit()) {
			obj.activateMover();
			msg >> cast<Savable>(obj.Mover);
		}
		msg >> type;
		msg >> origin;
		msg >> pathTarget;
		msg >> intermediate;
		msg >> prevRegion;
		msg >> nextRegion;
		msg >> moveId;
		msg >> leavingRegion;
		msg >> pickedUp;
		msg >> Health;
		msg >> stepCount;
		msg >> income;
		msg >> cargoType;
		if(msg.readBit())
			@cargoResource = getResource(msg.readIdentifier(SI_Resource));
		msg >> cargoWorth;

		makeMesh(obj);
	}

	void save(Civilian& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		if(obj.hasMover) {
			msg.write1();
			msg << cast<Savable>(obj.Mover);
		}
		else {
			msg.write0();
		}
		msg << type;
		msg << origin;
		msg << pathTarget;
		msg << intermediate;
		msg << prevRegion;
		msg << nextRegion;
		msg << moveId;
		msg << leavingRegion;
		msg << pickedUp;
		msg << Health;
		msg << stepCount;
		msg << income;
		msg << cargoType;
		if(cargoResource is null) {
			msg.write0();
		}
		else {
			msg.write1();
			msg.writeIdentifier(SI_Resource, cargoResource.id);
		}
		msg << cargoWorth;
	}

	uint getCargoType() {
		if(cargoType == CT_Resource && !pickedUp)
			return CT_Goods;
		return cargoType;
	}

	uint getCargoResource() {
		if(cargoResource is null)
			return uint(-1);
		return cargoResource.id;
	}

	int getCargoWorth() {
		return cargoWorth;
	}

	void setCargoType(Civilian& obj, uint type) {
		cargoType = type;
		@cargoResource = null;
		if(type == CT_Goods)
			cargoWorth = GOODS_WORTH * obj.radius * CIV_RADIUS_WORTH;
		delta = true;
	}

	void setCargoResource(Civilian& obj, uint id) {
		cargoType = CT_Resource;
		@cargoResource = getResource(id);
		if(pickedUp)
			cargoWorth = cargoResource.cargoWorth * obj.radius * CIV_RADIUS_WORTH;
		else
			cargoWorth = GOODS_WORTH * obj.radius * CIV_RADIUS_WORTH;
		delta = true;
	}

	void modCargoWorth(int diff) {
		cargoWorth += diff;
		delta = true;
	}

	int getStepCount() {
		return stepCount;
	}

	void modStepCount(int mod) {
		stepCount += mod;
	}

	void resetStepCount() {
		stepCount = 0;
	}

	void init(Civilian& obj) {
		obj.sightRange = 0;
	}

	uint getCivilianType() {
		return type;
	}

	void setCivilianType(uint type) {
		this.type = type;
	}

	void modIncome(Civilian& obj, int mod) {
		if(obj.owner !is null && obj.owner.valid)
			obj.owner.modTotalBudget(+mod, MoT_Trade);
		income += mod;
	}

	void postInit(Civilian& obj) {
		if(type == CiT_Freighter && obj.owner !is null)
			obj.owner.CivilianTradeShips += 1;
		if(type == CiT_Freighter) {
			obj.activateMover();
			obj.maxAcceleration = ACC_SYSTEM;
			obj.rotationSpeed = 1.0;
		}
		makeMesh(obj);
		Health = get_maxHealth(obj);
		delta = true;
	}

	void makeMesh(Civilian& obj) {
		MeshDesc mesh;
		@mesh.model = getCivilianModel(obj.owner, type, obj.radius);
		@mesh.material = getCivilianMaterial(obj.owner, type, obj.radius);
		@mesh.iconSheet = getCivilianIcon(obj.owner, type, obj.radius).sheet;
		mesh.iconIndex = getCivilianIcon(obj.owner, type, obj.radius).index;

		bindMesh(obj, mesh);
	}

	bool onOwnerChange(Civilian& obj, Empire@ prevOwner) {
		if(income != 0 && prevOwner !is null && prevOwner.valid)
			prevOwner.modTotalBudget(-income, MoT_Trade);
		if(type == CiT_Freighter && prevOwner !is null)
			prevOwner.CivilianTradeShips -= 1;
		regionOwnerChange(obj, prevOwner);
		if(type == CiT_Freighter && obj.owner !is null)
			obj.owner.CivilianTradeShips += 1;
		if(income != 0 && prevOwner !is null && obj.owner.valid)
			obj.owner.modTotalBudget(-income, MoT_Trade);
		return false;
	}

	void destroy(Civilian& obj) {
		if((obj.inCombat || obj.engaged) && !game_ending) {
			playParticleSystem("ShipExplosion", obj.position, obj.rotation, obj.radius, obj.visibleMask);
		}
		else {
			if(cargoResource !is null) {
				for(uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
					cargoResource.hooks[i].onTradeDestroy(obj, origin, pathTarget, null);
			}
		}
		if(origin !is null && origin.hasResources)
			origin.setAssignedCivilian(null);
		if(pathTarget !is null && pathTarget.isPlanet && pathTarget.owner is obj.owner) {
			auto@ status = getStatusType("Blockaded");
			if(status !is null)
				pathTarget.addStatus(status.id, timer=BLOCKADE_TIMER);
		}
		leaveRegion(obj);
		if(obj.owner !is null && obj.owner.valid) {
			if(type == CiT_Freighter)
				obj.owner.CivilianTradeShips -= 1;
			if(income != 0)
				obj.owner.modTotalBudget(-income, MoT_Trade);
		}
	}

	void freeCivilian(Civilian& obj) {
		if(origin !is null && origin.hasResources)
			origin.setAssignedCivilian(null);

		Region@ region = obj.region;
		if(region !is null) {
			@origin = null;
			@pathTarget = null;
			@prevRegion = null;
			@nextRegion = null;
			region.freeUpCivilian(obj);
		}
		else {
			@origin = null;
			@pathTarget = null;
			@prevRegion = null;
			@nextRegion = null;
			obj.destroy();
		}
	}

	float timer = 0.f;
	void occasional_tick(Civilian& obj) {
		//Update in combat flags
		bool engaged = obj.engaged;
		obj.inCombat = engaged;
		obj.engaged = false;

		if(engaged && obj.region !is null)
			obj.region.EngagedMask |= obj.owner.mask;
	}

	void gotoTradeStation(Civilian@ station) {
		if(!awaitingIntermediate)
			return;
		awaitingIntermediate = false;
		@intermediate = station;
	}

	void gotoTradePlanet(Planet@ planet) {
		if(!awaitingIntermediate)
			return;
		awaitingIntermediate = false;
		@intermediate = planet;
	}

	double tick(Civilian& obj, double time) {
		//Update normal stuff
		updateRegion(obj);
		if(obj.hasMover)
			obj.moverTick(time);

		//Tick occasional stuff
		timer -= float(time);
		if(timer <= 0.f) {
			occasional_tick(obj);
			timer = 1.f;
		}

		//Do repair
		double maxHP = get_maxHealth(obj);
		if(!obj.inCombat && Health < maxHP) {
			Health = min(Health + (CIV_REPAIR * time * obj.radius), maxHP);
			delta = true;
		}

		// [[ MODIFY BASE GAME START ]]
		if(awaitingIntermediate || !awaitingGateJump && obj.isMoving && obj.region !is nextRegion)
			return 0.25;
		// [[ MODIFY BASE GAME END ]]

		//Update pathing
		Region@ curRegion = obj.region;
		if(pathTarget !is null) {
			if(origin !is null && !pickedUp) {
				if(obj.moveTo(origin, moveId, distance=10.0, enterOrbit=false)) {
					pickedUp = true;
					if(cargoResource !is null)
						cargoWorth = cargoResource.cargoWorth * obj.radius * CIV_RADIUS_WORTH;
					delta = true;
					moveId = -1;
					return 0.5;
				}
				else {
					return 0.2;
				}
			}
			Region@ destRegion;
			if(pathTarget.isRegion)
				@destRegion = cast<Region>(pathTarget);
			// [[ MODIFY BASE GAME START ]]
			else if(pathTarget.owner !is null && pathTarget.owner is obj.owner)
			// [[ MODIFY BASE GAME END ]]
				@destRegion = pathTarget.region;
			if(nextRegion is null) {
				if(curRegion is null)
					@nextRegion = findNearestRegion(obj.position);
				else
					@nextRegion = curRegion;
			}
			if(nextRegion is null || destRegion is null) {
				freeCivilian(obj);
				return 0.4;
			}
			if(leavingRegion) {
				// [[ MODIFY BASE GAME START ]]
				vec3d enterDest = nextRegion.position;
				bool arrived = false;
				if(!awaitingGateJump) {
					obj.maxAcceleration = ACC_INTERSYSTEM;
					if(prevRegion !is null && hasGateToNextRegion(prevRegion, obj.owner)) {
						enterDest = nextRegion.position + random3d(nextRegion.radius/5);
						awaitingGateJump = true; // we have a gate, move with normal speed and await jump
						obj.maxAcceleration = ACC_SYSTEM;
					} else {
						enterDest = nextRegion.position;
						enterDest += quaterniond_fromAxisAngle(vec3d_up(), pi * 0.01)
							* (prevRegion.position - nextRegion.position).normalized(nextRegion.radius * 0.85);
						enterDest +=  random3d(0, DEST_RANGE);
					}
					enterDest.y = nextRegion.position.y;
				} else if (curRegion is nextRegion) {
					arrived = true;
				}

				if(arrived || arriveWithEmpirePropulsionTechnology(obj, enterDest)) {
					if(cargoType == CT_Resource)
						prevRegion.bumpTradeCounter(obj.owner);
					moveId = -1;
					leavingRegion = false;
					awaitingGateJump = false;
				}
				return 0.2;
				// [[ MODIFY BASE GAME END ]]
			}
			if(curRegion is null || (nextRegion !is null && nextRegion is curRegion)) {
				if(nextRegion is destRegion) {
					//Move to destination
					obj.maxAcceleration = ACC_SYSTEM;
					if(curRegion is pathTarget || obj.moveTo(pathTarget, moveId, distance=10.0, enterOrbit=false)) {
						moveId = -1;
						if(cargoType == CT_Resource)
							destRegion.bumpTradeCounter(obj.owner);
						if(cargoResource !is null && !pathTarget.isRegion) {
							for(uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
								cargoResource.hooks[i].onTradeDeliver(obj, origin, pathTarget);
						}
						freeCivilian(obj);
						return 0.4;
					}
					else {
						return 0.2;
					}
				}
				else if(curRegion is null) {
					//Move to closest region
					// [[ MODIFY BASE GAME START ]]
					vec3d pos = nextRegion.position;
					pos += (nextRegion.position - obj.position).normalized(nextRegion.radius * 0.85);
					pos.y = nextRegion.position.y;
					obj.maxAcceleration = ACC_INTERSYSTEM;
					if(arriveWithEmpirePropulsionTechnology(obj, pos)) {
						// [[ MODIFY BASE GAME END ]]
						moveId = -1;
						return 0.4;
					}
					else {
						return 0.2;
					}
				}
				else {
					//Find the next region to path to
					TradePath path(obj.owner);
					path.generate(getSystem(curRegion), getSystem(destRegion));

					if(path.pathSize < 2 || !path.valid) {
						freeCivilian(obj);
						return 0.4;
					}
					else {
						@prevRegion = curRegion;
						@nextRegion = path.pathNode[1].object;
						awaitingIntermediate = true;
						@intermediate = null;
						if(curRegion.hasTradeStation(obj.owner))
							curRegion.getTradeStation(obj, obj.owner, obj.position);
						else if(cargoType == CT_Goods)
							curRegion.getTradePlanet(obj, obj.owner);
						else
							awaitingIntermediate = false;
						leavingRegion = false;
					}
				}
			}
			if(!leavingRegion) {
				// [[ MODIFY BASE GAME START ]]
				obj.maxAcceleration = ACC_SYSTEM;
				// [[ MODIFY BASE GAME END ]]
				if(intermediate !is null) {
					if(obj.moveTo(intermediate, moveId, distance=10.0, enterOrbit=false)) {
						moveId = -1;
						@intermediate = null;
						return 0.4;
					}
					else {
						return 0.2;
					}
				}
				else {
					// [[ MODIFY BASE GAME START ]]
					if(moveId == -1 && hasGateToNextRegion(prevRegion, obj.owner)) {
						// [[ MODIFY BASE GAME END ]]
						leavingRegion = true;
						return 0.5;
					}
					vec3d leaveDest;
					if(prevRegion is null)
						leaveDest = obj.position;
					// [[ MODIFY BASE GAME START ]]
					else {
						leaveDest = prevRegion.position;
						leaveDest += quaterniond_fromAxisAngle(vec3d_up(), -pi * 0.01)
							* (nextRegion.position - prevRegion.position).normalized(prevRegion.radius * 0.85);
						leaveDest +=  random3d(0, DEST_RANGE);
						leaveDest.y = prevRegion.position.y;
					}
					if(obj.moveTo(leaveDest, moveId, enterOrbit=false)
						|| leaveDest.distanceToSQ(obj.position) < DEST_RANGE * DEST_RANGE) {
						// [[ MODIFY BASE GAME END ]]
						moveId = -1;
						leavingRegion = true;
						return 0.5;
					}
				}
			}
		}
		return 0.2;
	}

	// [[ MODIFY BASE GAME START ]]
	bool arriveWithEmpirePropulsionTechnology(Civilian& obj, vec3d enterDest) {
		if(awaitingGateJump)
			return obj.moveTo(enterDest, moveId, enterOrbit=false);

		bool allowedCivilianFTL = obj.owner.HasCivilianFTL >= 1;
		bool hasHyperdrives = allowedCivilianFTL && obj.owner.isUnlocked(hyperdriveSubsystem);
		bool hasJumpdrives = allowedCivilianFTL && obj.owner.isUnlocked(jumpdriveSubsystem);

		if(hasJumpdrives) {
			playParticleSystem("GateFlash", obj.position, obj.rotation, obj.radius, obj.visibleMask);
			awaitingGateJump = true;
			obj.position = enterDest;
			obj.clearMovement();
			playParticleSystem("GateFlash", enterDest, obj.rotation, obj.radius, obj.visibleMask);
			return true;
		}
		if(hasHyperdrives) {
			if(!obj.inFTL)
				playParticleSystem("GateFlash", obj.position, obj.rotation, obj.radius, obj.visibleMask);
			if(enterDest.distanceToSQ(obj.position) < DEST_RANGE * DEST_RANGE ||
				obj.FTLTo(enterDest, ACC_INTERSYSTEM * 4, moveId)
			) {
				obj.FTLDrop();
				playParticleSystem("GateFlash", obj.position, obj.rotation, obj.radius, obj.visibleMask);
				return true;
			}
			return false;
		}
		return obj.moveTo(enterDest, moveId, enterOrbit=false);
	}

	bool hasGateToNextRegion(Region& curRegion, Empire& owner) {
		if(hasOddityLink(curRegion, nextRegion))
			return true;

		if(owner.hasStargates()) {
			Object@ thisGate = owner.getFriendlyStargate(curRegion.position);
			Object@ otherGate = owner.getFriendlyStargate(nextRegion.position);
			return thisGate !is null && thisGate.region is curRegion
				&& otherGate !is null && otherGate.region is nextRegion;
		}
		return false;
	}
	// [[ MODIFY BASE GAME END ]]

	void setOrigin(Object@ origin) {
		@this.origin = origin;
		delta = true;
	}

	void pathTo(Civilian& obj, Object@ origin, Object@ target, Object@ stopAt = null) {
		@pathTarget = target;
		@prevRegion = null;
		@nextRegion = null;
		@intermediate = stopAt;
		@this.origin = origin;
		pickedUp = false;
		delta = true;
		leavingRegion = false;
	}

	void pathTo(Civilian& obj, Object@ target) {
		@pathTarget = target;
		@prevRegion = null;
		@nextRegion = null;
		@origin = null;
		@intermediate = null;
		pickedUp = true;
		delta = true;
		leavingRegion = false;
	}

	void damage(Civilian& obj, DamageEvent& evt, double position, const vec2d& direction) {
		if(!obj.valid || obj.destroying)
			return;
		obj.engaged = true;
		Health = max(0.0, Health - evt.damage);
		delta = true;
		if(Health <= 0.0) {
			if(cargoWorth > 0) {
				Empire@ other = evt.obj.owner;
				if(other !is null && other.major) {
					other.addBonusBudget(cargoWorth);
					cargoWorth = 0;
				}
			}
			if(cargoResource !is null) {
				for(uint i = 0, cnt = cargoResource.hooks.length; i < cnt; ++i)
					cargoResource.hooks[i].onTradeDestroy(obj, origin, pathTarget, evt.obj);
			}
			obj.destroy();
		}
	}

	void _writeDelta(const Civilian& obj, Message& msg) {
		msg.writeSmall(cargoType);
		msg.writeSmall(cargoWorth);
		msg.writeBit(pickedUp);
		msg.writeFixed(obj.health/obj.maxHealth);
		if(cargoResource !is null) {
			msg.write1();
			msg.writeLimited(cargoResource.id, getResourceCount()-1);
		}
		else {
			msg.write0();
		}
	}

	void syncInitial(const Civilian& obj, Message& msg) {
		if(obj.hasMover) {
			msg.write1();
			obj.writeMover(msg);
		}
		else {
			msg.write0();
		}
		msg << type;
		_writeDelta(obj, msg);
	}

	void syncDetailed(const Civilian& obj, Message& msg) {
		if(obj.hasMover) {
			msg.write1();
			obj.writeMover(msg);
		}
		else {
			msg.write0();
		}
		_writeDelta(obj, msg);
	}

	bool syncDelta(const Civilian& obj, Message& msg) {
		bool used = false;
		if(obj.hasMover && obj.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		if(delta) {
			used = true;
			delta = false;
			msg.write1();
			_writeDelta(obj, msg);
		}
		else {
			msg.write0();
		}
		return used;
	}
};

void dumpPlanetWaitTimes() {
	uint cnt = playerEmpire.planetCount;
	double avg = 0.0, maxTime = 0.0;
	for(uint i = 0; i < cnt; ++i) {
		Planet@ pl = playerEmpire.planetList[i];
		if(pl !is null && pl.getNativeResourceDestination(playerEmpire, 0) !is null) {
			double timer = pl.getCivilianTimer();
			print(pl.name+" -- "+timer);
			avg += timer;
			if(timer > maxTime)
				maxTime = timer;
		}
	}
	avg /= double(cnt);
	print(" AVERAGE: "+avg);
	print(" MAX: "+maxTime);
}
