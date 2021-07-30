import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import statuses;
from statuses import StatusHook;

tidy final class IfInDeepSpace : IfHook {
	Document doc("Only applies the inner hook if the current object is not in a region.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		return obj.region is null;
	}
#section all
};

class IfFewerStatusStacks : IfHook {
	Document doc("Only applies the inner hook if the object has fewer status stacks than an amount.");
	Argument status(AT_Status, doc="Type of status effect to limit.");
	Argument amount(AT_Integer, doc="Minimum number of stacks to stop triggering inner hook at.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		int count = obj.getStatusStackCount(status.integer);
		return count < amount.integer;
	}
#section all
};

class IfMoreStatusStacks : IfHook {
	Document doc("Only applies the inner hook if the object has more status stacks than an amount.");
	Argument status(AT_Status, doc="Type of status effect to limit.");
	Argument amount(AT_Integer, doc="Maximum number of stacks to stop triggering inner hook at.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		int count = obj.getStatusStackCount(status.integer);
		return count > amount.integer;
	}
#section all
};

tidy final class IfData {
	bool enabled;
	any data;
	any parentData;
};

// More powerful IfHook type base class, that passes the delta time and an
// any field to the subclass's condition logic.
//
// As a consequence, the subclass has to manage enable/disable/save/load
// logic if it needs to persist data.
tidy class IfHookWithTimeAndData : GenericEffect {
	GenericEffect@ hook;

	bool withHook(const string& str) {
		@hook = cast<GenericEffect>(parseHook(str, "planet_effects::"));
		if(hook is null) {
			error("If<>(): could not find inner hook: "+escape(str));
			return false;
		}
		return true;
	}

	bool condition(Object& obj, double time, any@ data) const {
		return false;
	}

	void conditionEnable(Object& obj, any@ data) const {}
	void conditionDisable(Object& obj, any@ data) const {}
	void conditionSave(any@ data, SaveFile& file) const {}
	void conditionLoad(any@ data, SaveFile& file) const {}

#section server
	void enable(Object& obj, any@ data) const override {
		IfData info;
		conditionEnable(obj, info.parentData);
		info.enabled = condition(obj, 0.0, info.parentData);
		data.store(@info);

		if(info.enabled)
			hook.enable(obj, info.data);
	}

	void disable(Object& obj, any@ data) const override {
		IfData@ info;
		data.retrieve(@info);
		conditionDisable(obj, info.parentData);

		if(info.enabled)
			hook.disable(obj, info.data);
	}

	void tick(Object& obj, any@ data, double time) const {
		IfData@ info;
		data.retrieve(@info);

		bool cond = condition(obj, time, info.parentData);
		if(cond != info.enabled) {
			if(info.enabled)
				hook.disable(obj, info.data);
			else
				hook.enable(obj, info.data);
			info.enabled = cond;
		}
		if(info.enabled)
			hook.tick(obj, info.data, time);
	}

	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.ownerChange(obj, info.data, prevOwner, newOwner);
	}

	void regionChange(Object& obj, any@ data, Region@ fromRegion, Region@ toRegion) const {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.regionChange(obj, info.data, fromRegion, toRegion);
	}

	void save(any@ data, SaveFile& file) const {
		IfData@ info;
		data.retrieve(@info);

		if(info is null) {
			bool enabled = false;
			file << enabled;
		}
		else {
			file << info.enabled;
			if(info.enabled)
				hook.save(info.data, file);
		}
		conditionSave(info.parentData, file);
	}

	void load(any@ data, SaveFile& file) const {
		IfData info;
		data.store(@info);

		file >> info.enabled;
		if(info.enabled)
			hook.load(info.data, file);
		conditionLoad(info.parentData, file);
	}
#section all
};

class IfTimeOutsideCombat : IfHookWithTimeAndData {
	Document doc("Only applies the inner hook if the object has spent more time out of combat than an amount.");
	Argument amount(AT_Decimal, doc="Time requires out of combat.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj, double time, any@ data) const override {
		bool inCombat = obj.inCombat;
		double gameTimeBeforeCombat = 0.0;
		data.retrieve(gameTimeBeforeCombat);
		if (inCombat) {
			gameTimeBeforeCombat = gameTime;
			data.store(gameTimeBeforeCombat);
		}
		return (gameTime - gameTimeBeforeCombat) > amount.decimal;
	}

	void conditionEnable(Object& obj, any@ data) const override {
		double gameTimeBeforeCombat = gameTime;
		data.store(gameTimeBeforeCombat);
	}
	void conditionDisable(Object& obj, any@ data) const override {
		double gameTimeBeforeCombat = 0;
		data.retrieve(gameTimeBeforeCombat);
	}
	void conditionSave(any@ data, SaveFile& file) const override {
		double gameTimeBeforeCombat = 0;
		data.retrieve(gameTimeBeforeCombat);
		file << gameTimeBeforeCombat;
	}
	void conditionLoad(any@ data, SaveFile& file) const override {
		double gameTimeBeforeCombat = 0;
		file >> gameTimeBeforeCombat;
		data.store(gameTimeBeforeCombat);
	}

#section all
};

tidy final class RandomIfElse : BonusEffect {
	Document doc("Trigger one of two hooks based on a particular chance.");
	Argument chance(AT_Range, doc="Chance between 0.0 and 1.0 to trigger the first hook, otherwise the second will trigger.");
	Argument hook_1(AT_Hook, "bonus_effects::BonusEffect");
	Argument hook_2(AT_Hook, "bonus_effects::BonusEffect");

	BonusEffect@ hook1;
	BonusEffect@ hook2;

	bool instantiate() override {
		@hook1 = cast<BonusEffect>(parseHook(hook_1.str, "bonus_effects::", required=false));
		if(hook1 is null) {
			error("RandomIfElse(): could not find inner hook: "+escape(hook_1.str));
			return false;
		}
		@hook2 = cast<BonusEffect>(parseHook(hook_2.str, "bonus_effects::", required=false));
		if(hook2 is null) {
			error("RandomIfElse(): could not find inner hook: "+escape(hook_2.str));
			return false;
		}
		return BonusEffect::instantiate();
	}

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(hook1 is null || hook2 is null)
			return;
		if (randomd() < chance.fromRange()) {
			hook1.activate(obj, emp);
		} else {
			hook2.activate(obj, emp);
		}
	}
#section all
};


tidy final class IfNotNativeLevel : IfHook {
	Document doc("Only applies the inner hook if a planet's native resource is not of a specified level.");
	Argument level(AT_Integer, doc="Required resource level for the effect to not apply.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	Argument exact(AT_Boolean, "False", doc="If set, only disable the hook if the planet is _exactly_ this level. If not set, all planets of the specified level _or higher_ will be affected.");
	Argument limit(AT_Boolean, "True", doc="Whether to take limit level instead of requirement level.");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.isPlanet)
			return false;
		int lv = 0;
		if(limit.boolean)
			lv = obj.primaryResourceLimitLevel;
		else
			lv = obj.primaryResourceLevel;
		if(exact.boolean)
			return !(lv == level.integer);
		return !(lv >= level.integer);
	}
#section all
};
