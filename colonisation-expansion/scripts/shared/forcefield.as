bool checkForcefield(Design& design, Subsystem& sys) {
	auto@ emitter = sys.type.module("Emitter");
	bool failed = false;
	for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
		vec2u hex = sys.hexagon(i);
		if(sys.module(i) is emitter || sys.core == hex) {
			if(!forcefieldExposedInOneDirection(design, sys, hex)) {
				failed = true;
				design.addErrorHex(hex);
				continue;
			}
			if(!isTouchingOnlyTwoOfSelf(design, sys, hex)) {
				failed = true;
				design.addErrorHex(hex);
				continue;
			}
		}
	}

	if(failed) {
		design.addError(true, locale::ERROR_FORCEFIELD_SHAPE, null, null, vec2u());
		return true;
	}
	return false;
}

bool forcefieldExposedInOneDirection(Design& design, Subsystem& sys, const vec2u& hex) {
	auto@ emitter = sys.type.module("Emitter");
	vec2u other;
	for(uint i = 0; i < 6; ++i) {
		other = hex;
		if(!design.hull.active.advance(other, HexGridAdjacency(i)))
			return true;
		while(design.hull.active.valid(other)) {
			auto@ otherSys = design.subsystem(other);
			if(otherSys !is null) {
				uint j = 0;
				while(other != otherSys.hexagon(j)) {
					j++; // We can't directly check which module is attached to a certain hex. Instead, we need to find the hex first, *then* check its module.
				}

				if(otherSys is sys && sys.module(j) !is emitter && sys.core != other) {
					break;
				}
			}
			if(!design.hull.active.advance(other, HexGridAdjacency(i)))
				return true;
		}
	}
	return false;
}

bool isTouchingOnlyTwoOfSelf(Design& design, Subsystem& sys, const vec2u& hex) {
	uint touchCount = 0;
	for(uint i = 0; i < 6; ++i) {
		vec2u other = hex;
		if(design.hull.active.advance(other, HexGridAdjacency(i))) {
			auto@ otherSys = design.subsystem(other);
			if(otherSys is sys) {
				touchCount++;
				if(touchCount > 2) {
					return false;
				}
			}
		}
	}
	return true;
}
