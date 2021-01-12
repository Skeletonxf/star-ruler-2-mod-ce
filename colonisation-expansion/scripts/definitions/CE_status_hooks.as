import hooks;
import statuses;
from statuses import StatusHook;
import planet_effects;
from bonus_effects import BonusEffect;

class AllowPathlessImport : StatusHook {
	Document doc("Allows the planet to import resources without a trade path.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		if (obj !is null && obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.allowPathlessImport += 1;
		}
	}

	void onDestroy(Object& obj, Status@ status, any@ data) override {
		if (obj !is null && obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.allowPathlessImport -= 1;
		}
	}
#section all
}
