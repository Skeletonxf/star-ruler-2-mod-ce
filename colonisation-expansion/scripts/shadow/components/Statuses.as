import statuses;

// [[ MODIFY BASE GAME START ]]
class StatusInstanceShadow {
	double timer = -1.0;
	uint statusTypeID = uint(-1);
}
// [[ MODIFY BASE GAME END ]]

tidy class Statuses : Component_Statuses {
	array<Status@> statuses;
	// [[ MODIFY BASE GAME START ]]
	array<StatusInstanceShadow@> instances;
	double networkSyncTime = gameTime;
	// [[ MODIFY BASE GAME END ]]

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
			StatusInstanceShadow@ instance = instances[i];
			if (instance.statusTypeID == statusTypeID) {
				if (instance.timer == -1.0) {
					duration = -1.0;
					continue;
				}
				if (duration != -1.0 && instance.timer > duration) {
					duration = instance.timer;
				}
			}
		}
		if (duration == -1.0) {
			return -1.0;
		} else {
			double elapsedTime = gameTime - networkSyncTime;
			return max(duration - elapsedTime, 0.0);
		}
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

	void readStatuses(Message& msg) {
		uint cnt = msg.readSmall();
		statuses.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			if(statuses[i] is null)
				@statuses[i] = Status();
			msg >> statuses[i];
		}
		// [[ MODIFY BASE GAME START ]]
		msg >> networkSyncTime;
		cnt = msg.readSmall();
		instances.length = cnt;
		for (uint i = 0; i < cnt; ++i) {
			if (msg.readBit()) {
				StatusInstanceShadow@ instance = StatusInstanceShadow();
				instance.timer = msg.read_float();
				msg >> instance.statusTypeID;
				@instances[i] = instance;
			} else {
				@instances[i] = StatusInstanceShadow();
			}
		}
		// [[ MODIFY BASE GAME END ]]
	}

	void readStatusDelta(Message& msg) {
		readStatuses(msg);
	}
};
