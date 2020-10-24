import regions.regions;
import oddity_navigation;
import oddities;

tidy class OddityScript {
	StrategicIconNode@ icon;
	bool gate = false;
	double timer = -1.0;
	uint visualType = uint(-1);
	uint visualColor = 0xffffffff;
	Object@ link;

	bool isGate() {
		return gate;
	}

	vec3d getGateDest() {
		if(link !is null)
			return link.position;
		return vec3d();
	}

	Object@ getLink() {
		return link;
	}

	double getTimer() {
		return timer;
	}

	vec3d get_strategicIconPosition(Oddity& obj) {
		if(icon is null)
			return obj.position;
		return icon.position;
	}

	void _read(Oddity& obj, Message& msg) {
		uint prevVisual = visualType;
		bool prevGate = gate;

		msg >> gate;
		msg >> timer;
		msg >> visualType;
		msg >> visualColor;
		msg >> link;

		if(prevVisual == uint(-1) && visualType != uint(-1)) {
			if(link !is null)
				obj.rotation = quaterniond_fromVecToVec(vec3d_front(), (link.position - obj.position).normalized(), vec3d_up());
			makeVisuals(obj, visualType, color=visualColor);
		}

		if(gate != prevGate) {
			if(gate)
				addOddityGate(obj);
			else
				removeOddityGate(obj);
		}
	}

	double tick(Oddity& obj, double time) {
		//Handle region changes
		Region@ prevRegion = obj.region;
		if(updateRegion(obj)) {
			Region@ newRegion = obj.region;
			if(icon !is null) {
				if(prevRegion !is null)
					prevRegion.removeStrategicIcon(-1, icon);
				if(newRegion !is null)
					newRegion.addStrategicIcon(-1, obj, icon);
			}
			@prevRegion = newRegion;
		}

		//Handle timer
		if(timer > 0.0)
			timer = max(timer - time, 0.0);
		return 0.25;
	}

	void syncInitial(Oddity& obj, Message& msg) {
		_read(obj, msg);
	}

	void syncDelta(Oddity& obj, Message& msg, double tDiff) {
		if(msg.readBit())
			_read(obj, msg);
	}

	void syncDetailed(Oddity& obj, Message& msg, double tDiff) {
		_read(obj, msg);
	}

	void makeVisuals(Oddity& obj, uint type, bool fromCreation = true, uint color = 0xffffffff) {
		visualType = type;
		@icon = makeOddityVisuals(obj, type, fromCreation, color=color);

		// [[ MODIFY BASE GAME START ]]
		if (visualType == Odd_MiniWormhole && obj.getLink() !is null && obj.id > obj.getLink().id) {
			int64 beam = (obj.id << 32) | (0x2 << 24);
			makeBeamEffect(beam, obj, obj.getLink(), 0xdad9ecff, 10, "Tractor", obj.getTimer());
		}
		// [[ MODIFY BASE GAME END ]]
	}

	void destroy(Oddity& obj) {
		// [[ MODIFY BASE GAME START ]]
		// remove any beams created
		if (visualType == Odd_MiniWormhole && obj.getLink() !is null) {
			// remove the beam for either id, as the second wormhole linked
			// to this one won't have the link by the time it is destroyed
			int64 beam = (obj.id << 32) | (0x2 << 24);
			removeGfxEffect(beam);
			beam = (obj.getLink().id << 32) | (0x2 << 24);
			removeGfxEffect(beam);
		}

		// Check if icon is null too, as mini wormholes spawn without icons
		if(obj.region !is null && icon !is null)
			obj.region.removeStrategicIcon(-1, icon);
		// [[ MODIFY BASE GAME END ]]
		if(icon !is null)
			icon.markForDeletion();
		leaveRegion(obj);
		if(gate)
			removeOddityGate(obj);
		removeAmbientSource(obj.id);
	}
};
