import hooks;
import statuses;
from bonus_effects import BonusEffect;

class EnableShipResources : BonusEffect {
	Document doc("Enables resources on the flagship/station");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (obj !is null && obj.isShip && obj.hasLeaderAI && !obj.hasResources) {
			cast<Ship>(obj).activateResources();
		}
	}
#section all
};

class DestroySystemStars : BonusEffect {
	Document doc("Destroy all the stars in the target region.");
	Argument quiet(AT_Boolean, "False", doc="Whether to silently destroy the stars.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;
		Region@ reg = obj.region;
		if(reg is null)
			return;
		for (uint i = 0, cnt = reg.starCount; i < cnt; ++i) {
			Star@ star = reg.stars[i];
			if (quiet.boolean)
				star.destroyQuiet();
			else
				star.destroy();
		}
	}
#section all
}
