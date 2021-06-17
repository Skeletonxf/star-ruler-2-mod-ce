import hooks;
import hook_globals;
import generic_effects;
from generic_effects import GenericEffect;

class HealFleetPerSecondSubsystemVar : GenericEffect {
	Document doc("The fleet this effect is active on is healed by a certain amount of HP per second.");
	Argument amount(AT_SysVar, doc="Amount of HP per second to heal.");
	Argument spread(AT_Boolean, "True", doc="If set to false, each individual ship in the fleet will be healed by the full amount. If set to true, the healed amount is spread out evenly amongst ships.");

#section server
	void tick(Object& obj, any@ data, double time) const override {
		double amt = amount.fromShipEfficiencySum(obj);
		if(obj.hasLeaderAI)
			obj.repairFleet(amt, spread=arguments[1].boolean);
	}
#section all
};
