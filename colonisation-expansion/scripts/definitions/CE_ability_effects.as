import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
import abilities;
from abilities import AbilityHook;

class NotifyTargetOwner : AbilityHook {
	Document doc("Notify the target empire of an event.");
	Argument objTarg(TT_Object);
	Argument title("Title", AT_Custom, doc="Title of the notification.");
	Argument desc("Description", AT_Custom, EMPTY_DEFAULT, doc="Description of the notification.");
	Argument icon("Icon", AT_Sprite, EMPTY_DEFAULT, doc="Sprite specifier for the notification icon.");

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(abl.obj is null)
			return;
		if (index != uint(objTarg.integer))
			return;
		if (newTarget.obj is null)
			return;
		if (!newTarget.obj.isStar && (newTarget.obj.owner is null || !newTarget.obj.owner.valid))
			return;
		if (newTarget.obj is abl.obj)
			return;
		if (oldTarget.obj is newTarget.obj)
			return;
		Empire@ emp = newTarget.obj.owner;
		emp.notifyGeneric(title.str, desc.str, icon.str, emp, newTarget.obj);
		if (newTarget.obj.isStar) {
			Region@ region = newTarget.obj.region;
			array<int> notified;
			if (region !is null) {
				uint plCnt = region.planetCount;
				for (uint i = 0; i < plCnt; ++i) {
					Planet@ pl = region.planets[i];
					if(pl is null)
						continue;
					if(pl.owner is null)
						continue;
					if (notified.find(pl.owner.id) == -1) {
						Empire@ emp = pl.owner;
						emp.notifyGeneric(title.str, desc.str, icon.str, emp, newTarget.obj);
						notified.insertLast(pl.owner.id);
					}
				}
			}
		}
	}
#section all
};

class FlingToTarget : AbilityHook {
	Document doc("Flings the ship/station to the target (without using a fling beacon).");
	Argument object(TT_Object);

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ target = object.fromConstTarget(targs).obj;
		if(abl.obj is null || target is null)
			return;

		Ship@ ship = cast<Ship>(abl.obj);
		if (ship is null)
			return;

		ship.addBeaconlessFlingOrder(target.position, append = true);
	}
#section all
};
