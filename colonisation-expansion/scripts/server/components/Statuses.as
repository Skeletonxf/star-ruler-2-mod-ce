import statuses;
import saving;

tidy class Statuses : Component_Statuses, Savable {
	array<Status@> statuses;
	array<StatusInstance@> instances;
	int nextInstanceId = 1;
	bool delta = false;

	void save(SaveFile& file) {
		file << nextInstanceId;

		uint cnt = statuses.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file << statuses[i];

		cnt = instances.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			file << statuses.find(instances[i].status);
			file << instances[i];
		}
	}

	void load(SaveFile& file) {
		if(file < SV_0013)
			return;

		file >> nextInstanceId;

		uint cnt = 0;
		file >> cnt;
		statuses.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			@statuses[i] = Status();
			file >> statuses[i];
		}

		file >> cnt;
		instances.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			@instances[i] = StatusInstance();
			int index = 0;
			file >> index;
			@instances[i].status = statuses[index];
			file >> instances[i];
		}
	}

	void getStatusEffects(Player& pl, Object& obj) {
		Empire@ plEmp = pl.emp;
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			if(!statuses[i].isVisibleTo(obj, plEmp))
				continue;
			yield(statuses[i]);
		}
	}

	uint get_statusEffectCount() {
		return statuses.length;
	}

	uint get_statusEffectType(uint index) {
		if(index >= statuses.length)
			return uint(-1);
		return statuses[index].type.id;
	}

	uint get_statusEffectStacks(uint index) {
		if(index >= statuses.length)
			return 0;
		return statuses[index].stacks;
	}

	// [[ MODIFY BASE GAME START ]]
	double get_statusEffectDuration(uint index) {
		if(index >= statuses.length)
			return 0.0;
		uint statusTypeID = statuses[index].type.id;
		if (!statuses[index].type.showDuration) {
			return -2.0;
		}
		// We can have multiple stacks of instances of the same status (type)
		// but all instances tick down at the same time, so we just need
		// to find the longest lasting instance (-1 is permanent)
		double duration = 0.0;
		for(uint i = 0, cnt = instances.length; i < cnt; ++i) {
			StatusInstance@ instance = instances[i];
			if (instance.status.type.id == statusTypeID) {
				if (instance.timer == -1.0) {
					duration = -1.0;
					continue;
				}
				if (duration != -1.0 && instance.timer > duration) {
					duration = instance.timer;
				}
			}
		}
		return duration;
	}
	// [[ MODIFY BASE GAME END ]]

	Object@ get_statusEffectOriginObject(uint index) {
		if(index >= statuses.length)
			return null;
		return statuses[index].originObject;
	}

	Empire@ get_statusEffectOriginEmpire(uint index) {
		if(index >= statuses.length)
			return null;
		return statuses[index].originEmpire;
	}

	uint getStatusStackCountAny(uint typeId) {
		uint count = 0;
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			if(statuses[i].type.id == typeId)
				count += statuses[i].stacks;
		}
		return count;
	}

	uint getStatusStackCount(uint typeId, Object@ originObject = null, Empire@ originEmpire = null) {
		uint count = 0;
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			if(statuses[i].type.id == typeId && statuses[i].originObject is originObject && statuses[i].originEmpire is originEmpire)
				count += statuses[i].stacks;
		}
		return count;
	}

	uint get_statusInstanceCount() {
		return instances.length;
	}

	uint get_statusInstanceType(uint index) {
		if(index >= instances.length)
			return uint(-1);
		return instances[index].status.type.id;
	}

	int get_statusInstanceId(uint index) {
		if(index >= instances.length)
			return -1;
		return instances[index].id;
	}

	bool hasStatusEffect(uint typeId) {
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			if(statuses[i].type.id == typeId)
				return true;
		}
		return false;
	}

	// [[ MODIFY BASE GAME START ]]
	int getStatusEffectOfType(uint typeId) {
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			if(statuses[i].type.id == typeId)
				return i;
		}
		return -1;
	}
	// [[ MODIFY BASE GAME END ]]

	int addStatus(Object& obj, double timer, uint typeId, Empire@ boundEmpire = null, Region@ boundRegion = null, Empire@ originEmpire = null, Object@ originObject = null) {
		const StatusType@ type = getStatusType(typeId);
		if(type is null)
			return -1;

		Status@ status;
		if(type.collapses) {
			for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
				auto@ cur = statuses[i];
				if(cur.type is type && originEmpire is cur.originEmpire && originObject is cur.originObject) {
					@status = cur;
					break;
				}
			}
		}
		if(status is null) {
			@status = Status(type);
			@status.originEmpire = originEmpire;
			@status.originObject = originObject;
			status.create(obj);
			statuses.insertLast(status);
		}

		auto@ instance = status.instance(obj);
		instance.id = nextInstanceId++;
		instance.timer = timer;
		@instance.boundEmpire = boundEmpire;
		@instance.boundRegion = boundRegion;
		instances.insertLast(instance);
		delta = true;
		return instance.id;
	}

	void addStatus(Object& obj, uint typeId, double timer = -1.0, Empire@ boundEmpire = null, Region@ boundRegion = null, Empire@ originEmpire = null, Object@ originObject = null) {
		addStatus(obj, timer, typeId, boundEmpire, boundRegion, originEmpire, originObject);
	}

	void addRandomCondition(Object& obj) {
		if(!obj.isPlanet)
			return;
		auto@ type = getRandomCondition(cast<Planet>(obj));
		if(type !is null)
			addStatus(obj, type.id);
	}

	void removeStatus(Object& obj, int id) {
		StatusInstance@ instance;
		for(uint i = 0, cnt = instances.length; i < cnt; ++i) {
			if(instances[i].id == id) {
				@instance = instances[i];
				instances.removeAt(i);
				break;
			}
		}
		if(instance is null)
			return;
		instance.remove(obj);
		if(instance.status.stacks <= 0) {
			statuses.remove(instance.status);
			instance.status.destroy(obj);
		}
		delta = true;
	}

	bool isStatusInstanceActive(int id) {
		for(uint i = 0, cnt = instances.length; i < cnt; ++i) {
			if(instances[i].id == id)
				return true;
		}
		return false;
	}

	void removeStatusInstanceOfType(Object& obj, uint typeId) {
		StatusInstance@ instance;
		for(uint i = 0, cnt = instances.length; i < cnt; ++i) {
			auto@ inst = instances[i];
			if(inst.boundEmpire !is null)
				continue;
			if(inst.boundRegion !is null)
				continue;
			if(inst.timer >= 0)
				continue;
			if(inst.status.type.id == typeId) {
				@instance = inst;
				instances.removeAt(i);
				break;
			}
		}
		if(instance is null)
			return;
		instance.remove(obj);
		if(instance.status.stacks <= 0) {
			statuses.remove(instance.status);
			instance.status.destroy(obj);
		}
		delta = true;
	}

	void removeStatusType(Object& obj, uint typeId) {
		uint index = uint(-1);
		for(uint i = 0, cnt = statuses.length; i < cnt; ++i) {
			auto@ cur = statuses[i];
			if(cur.type.id == typeId) {
				index = i;
				break;
			}
		}
		if(index == uint(-1))
			return;
		removeStatusTypeByIndex(obj, index);
	}

	void removeStatusTypeByIndex(Object& obj, uint index) {
		Status@ status;
		if(index < statuses.length)
			@status = statuses[index];
		if(status is null)
			return;
		for(int j = instances.length - 1; j >= 0; --j) {
			if(instances[j].status is status) {
				status.remove(obj, instances[j]);
				instances.removeAt(j);
			}
		}
		statuses.removeAt(index);
		status.destroy(obj);
		delta = true;
	}

	void changeStatusOwner(Object& obj, Empire@ prevOwner, Empire@ newOwner) {
		for(int i = instances.length - 1; i >= 0; --i) {
			auto@ instance = instances[i];
			if(instance.boundEmpire !is null && instance.boundEmpire is prevOwner) {
				instance.remove(obj);
				instances.removeAt(i);
			}
		}
		for(int i = statuses.length - 1; i >= 0; --i) {
			auto@ status = statuses[i];
			if(status.stacks <= 0 || !status.ownerChange(obj, prevOwner, newOwner))
				removeStatusTypeByIndex(obj, i);
		}
	}

	void changeStatusRegion(Object& obj, Region@ prevRegion, Region@ newRegion) {
		for(int i = instances.length - 1; i >= 0; --i) {
			auto@ instance = instances[i];
			if(instance.boundRegion !is null && instance.boundRegion is prevRegion) {
				instance.remove(obj);
				instances.removeAt(i);
			}
		}
		for(int i = statuses.length - 1; i >= 0; --i) {
			auto@ status = statuses[i];
			if(status.stacks <= 0 || !status.regionChange(obj, prevRegion, newRegion))
				removeStatusTypeByIndex(obj, i);
		}
	}

	void removeRegionBoundStatus(Object& obj, Region@ region, uint typeId, double timer = -1.0) {
		for(int i = instances.length - 1; i >= 0; --i) {
			auto@ instance = instances[i];
			if(instance.boundRegion is region && instance.status.type.id == typeId
				&& abs(instance.timer - timer) < 0.9) {
				instances.removeAt(i);
				instance.remove(obj);

				for(int j = statuses.length - 1; j >= 0; --j) {
					auto@ status = statuses[j];
					if(status.stacks <= 0)
						removeStatusTypeByIndex(obj, j);
				}
				break;
			}
		}
	}

	void statusTick(Object& obj, double time) {
		for(int i = instances.length - 1; i >= 0; --i) {
			auto@ instance = instances[i];
			if(!instance.tick(obj, time))
				instances.removeAt(i);
		}
		for(int i = statuses.length - 1; i >= 0; --i) {
			auto@ status = statuses[i];
			if(status.stacks <= 0 || !status.tick(obj, time))
				removeStatusTypeByIndex(obj, i);
		}
	}

	void destroyStatus(Object& obj) {
		for(int i = statuses.length - 1; i >= 0; --i) {
			auto@ status = statuses[i];
			status.objectDestroy(obj);
		}
		for(uint i = 0; i < instances.length; ++i) {
			auto@ instance = instances[i];
			instance.remove(obj);
			if(instance.status.stacks <= 0) {
				statuses.remove(instance.status);
				instance.status.destroy(obj);
			}
		}

		statuses.length = 0;
		instances.length = 0;
	}

	void writeStatuses(Message& msg) const {
		uint cnt = statuses.length;
		msg.writeSmall(cnt);
		for(uint i = 0; i < cnt; ++i)
			msg << statuses[i];
		// [[ MODIFY BASE GAME START ]]
		// We'd have deltas literally every frame if we tried to sync the
		// current timer on each instance because it updates in real time, so
		// instead we sync the time as of the netcode sync and the timer, and
		// approximate the present time timer on the client each frame.
		// Since the server still uses the real timer, any rounding disrepances
		// will fix themselves when something makes us write the statuses again.
		msg << gameTime;
		cnt = instances.length;
		msg.writeSmall(cnt);
		for (uint i = 0; i < cnt; ++i) {
			StatusInstance@ instance = instances[i];
			// The client only needs to care about a timers in a few
			// statuses when they're not infinite, so don't waste network
			// bandwidth writing the timer or the status type if the instance
			// isn't on a timer or it's not a type we need to display in the client
			if (instance.timer == -1.0 || !instance.status.type.showDuration) {
				msg.write0();
			} else {
				msg.write1();
				msg << float(instance.timer);
				msg << instance.status.type.id;
			}
		}
		// [[ MODIFY BASE GAME END ]]
	}

	bool writeStatusDelta(Message& msg) {
		if(delta) {
			delta = false;
			msg.write1();
			writeStatuses(msg);
			return true;
		}
		return false;
	}
};
