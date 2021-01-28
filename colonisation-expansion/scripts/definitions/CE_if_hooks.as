import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;

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
