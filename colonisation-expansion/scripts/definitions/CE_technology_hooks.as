import research;
from research import TechnologyHook;
import bonus_effects;
from generic_effects import GenericEffect;

class RequireSubsystemUnlocked : TechnologyHook {
	Document doc("This requires a particular subsystem to be unlocked.");
	Argument subsystem(AT_Subsystem, doc="Identifier of the subsystem to check.");

	bool canUnlock(TechnologyNode@ node, Empire& emp) const override {
		return emp.isUnlocked(getSubsystemDef(subsystem.integer));
	}
};

class RequireEither : TechnologyHook {
	Document doc("This requires either of two conditions to apply to allow unlocking");
	Argument condition_one(AT_Hook, "research_effects::ITechnologyHook");
	Argument condition_two(AT_Hook, "research_effects::ITechnologyHook");

	ITechnologyHook@ hook1;
	ITechnologyHook@ hook2;

	bool instantiate() override {
		@hook1 = cast<ITechnologyHook>(parseHook(condition_one.str, "research_effects::", required=false));
		if(hook1 is null) {
			error("RequireEither(): could not find first condition: "+escape(condition_one.str));
			return false;
		}
		@hook2 = cast<ITechnologyHook>(parseHook(condition_two.str, "research_effects::", required=false));
		if(hook2 is null) {
			error("RequireEither(): could not find second condition: "+escape(condition_two.str));
			return false;
		}
		return TechnologyHook::instantiate();
	}

	bool canUnlock(TechnologyNode@ node, Empire& emp) const override {
		return hook1.canUnlock(node, emp) || hook2.canUnlock(node, emp);
	}
};
