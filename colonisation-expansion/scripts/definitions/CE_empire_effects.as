import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;

class NotifyOwnerMessage : EmpireTrigger {
	Document doc("Notify the triggering empire of an event.");
	Argument text("Text", AT_Custom, doc="Text of the notification.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp is null && obj !is null)
			@emp = obj.owner;
		if(emp !is null)
			emp.notifyMessage(text.str, obj);
	}
#section all
};
