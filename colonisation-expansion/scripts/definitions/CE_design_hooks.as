import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import util.design_export;

class LoadDesigns : EmpireTrigger {
	Document doc("Load default designs from a particular directory into the empire.");
	Argument directory(AT_Custom, doc="Relative path to the directory to add designs from.");
	Argument limit_shipset(AT_Boolean, "True", doc="Whether to only load designs that have a saved hull that matches the current shipset.");
	Argument retry_without_limit(AT_Boolean, "True", doc="Whether to override the shipset limit and load all designs if no designs were found.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (emp is null) {
			return;
		}
		DesignSet designs;
		designs.readDirectory("data/designs/"+directory.str);
		designs.limitShipset = limit_shipset.boolean;
		designs.softLimitRetry = retry_without_limit.boolean;
		designs.createFor(emp);
	}
#section all
};

class LoadDesignsEffect : EmpireEffect, TriggerableGeneric {
	Document doc("Load default designs from a particular directory into the empire.");
	Argument directory(AT_Custom, doc="Relative path to the directory to add designs from.");
	Argument limit_shipset(AT_Boolean, "True", doc="Whether to only load designs that have a saved hull that matches the current shipset.");
	Argument retry_without_limit(AT_Boolean, "True", doc="Whether to override the shipset limit and load all designs if no designs were found.");

#section server
	void enable(Empire& emp, any@ data) const override {
		if (emp is null) {
			return;
		}
		DesignSet designs;
		designs.readDirectory("data/designs/"+directory.str);
		designs.limitShipset = limit_shipset.boolean;
		designs.softLimitRetry = retry_without_limit.boolean;
		designs.createFor(emp);
	}
#section all
};
