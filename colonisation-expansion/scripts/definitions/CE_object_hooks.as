import hooks;
import abilities;
import artifacts;
from abilities import AbilityHook;
import orbitals;
import target_filters;
from generic_effects import GenericEffect;

class DealStarTemperatureDamageOverTime : AbilityHook {
	Document doc("Reduces the temperature of the target star over time. Does not explode the star if reducing its temperature to 0.");
	Argument objTarg(TT_Object);
	Argument dmg_per_second(AT_SysVar, doc="Damage to deal per second.");

#section server
	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Object@ obj = storeTarg.obj;
		if(obj is null)
			return;

		double amt = dmg_per_second.fromSys(abl.subsystem) * time;
		if (obj.isStar) {
			Star@ star = cast<Star>(obj);
			star.dealStarTemperatureDamage(amt);
			if (star.temperature <= 1.0) {
				// finished
				Target newTarg = storeTarg;
				@newTarg.obj = null;
				abl.changeTarget(objTarg, newTarg);
			}
		}
	}
#section all
}
