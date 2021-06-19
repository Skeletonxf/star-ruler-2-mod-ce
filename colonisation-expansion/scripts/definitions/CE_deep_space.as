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

class IfSystemHasNoStars : IfHook {
	Document doc("Only applies the inner hook if the object is in a system that has no stars.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		Region@ reg = obj.region;
		if(reg is null)
			return true;
		return reg.starCount == 0;
	}
#section all
}
