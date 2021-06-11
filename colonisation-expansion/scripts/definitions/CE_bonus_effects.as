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
