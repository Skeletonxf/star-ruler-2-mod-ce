import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;

// TODO: This is extremely expensive compared to getting object orbits for regions
// Need some kind of deep space objects manager that can loop through only deep space planets
Object@ getOrbitObjectInDeepSpace(vec3d destPoint) {
	Object@ orbit;
	double closestDist = INFINITY;
	for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
		Empire@ empire = getEmpire(i);
		// don't filter out emp == empire, we want to track ally + self
		if (empire.valid && empire.major) {
			Planet@ closest = empire.getClosestPlanet(destPoint);
			if (closest !is null) {
				double distance = destPoint.distanceToSQ(closest.position);
				if ((distance < closest.OrbitSize * closest.OrbitSize) && (distance < closestDist)) {
					closestDist = distance;
					@orbit = closest;
				}
			}
		}
	}
	return orbit;
}

#section server
bool regionHasStars(Region@ region, bool ignoreBlackHoles = true) {
	if (region is null) {
		return false;
	}
	if (ignoreBlackHoles) {
		bool noStars = region.starCount == 0 || region.starTemperature == 0;
		return !noStars;
	} else {
		return region.starCount > 0;
	}
}
#section all

class IfSystemHasNoStars : IfHook {
	Document doc("Only applies the inner hook if the object is in a system that has no stars (ignores black holes).");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		return !regionHasStars(obj.region);
	}
#section all
}
