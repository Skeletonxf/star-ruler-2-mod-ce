import regions.regions;

LightDesc lightDesc;

tidy class StarScript {
	// [[ MODIFY BASE GAME START ]]
	void syncShields(Star& star, Message& msg) {
		if (msg.readBit()) {
			star.Shield = msg.read_float();
			star.MaxShield = msg.read_float();
		} else {
			star.Shield = 0;
			star.MaxShield = 0;
		}
	}
	// [[ MODIFY BASE GAME END ]]

	// [[ MODIFY BASE GAME START ]]
	// recalculate temperature based color
	void refreshTemperatureColor(Star& star) {
		double temp = star.temperature;
		Node@ node = star.getNode();
		if (node is null)
			return;
		if (temp != 0.0) {
			node.color = blackBody(temp, max((temp + 15000.0) / 40000.0, 1.0));
		} else {
			node.color = blackBody(16000.0, max((16000.0 + 15000.0) / 40000.0, 1.0));
		}
	}
	// [[ MODIFY BASE GAME END ]]

	void syncInitial(Star& star, Message& msg) {
		star.temperature = msg.read_float();

		lightDesc.att_quadratic = 1.f/(2000.f*2000.f);

		double temp = star.temperature;
		Node@ node;
		double soundRadius = star.radius;
		if(temp > 0.0) {
			@node = bindNode(star, "StarNode");
			node.color = blackBody(temp, max((temp + 15000.0) / 40000.0, 1.0));
		}
		else {
			@node = bindNode(star, "BlackholeNode");
			node.color = blackBody(16000.0, max((16000.0 + 15000.0) / 40000.0, 1.0));
			cast<BlackholeNode>(node).establish(star);
			soundRadius *= 10.0;
		}

		if(node !is null)
			node.hintParentObject(star.region);

		star.readOrbit(msg);

		lightDesc.position = vec3f(star.position);
		lightDesc.diffuse = node.color * 1.0f;
		lightDesc.specular = lightDesc.diffuse;
		lightDesc.radius = star.radius;

		if(star.inOrbit)
			makeLight(lightDesc, node);
		else
			makeLight(lightDesc);

		addAmbientSource("star_rumble", star.id, star.position, soundRadius);

		// [[ MODIFY BASE GAME START ]]
		syncShields(star, msg);
		// [[ MODIFY BASE GAME END ]]
	}

	void destroy(Star& obj) {
		removeAmbientSource(obj.id);
		leaveRegion(obj);
	}

	void syncDetailed(Star& star, Message& msg, double tDiff) {
		star.Health = msg.read_float();
		star.MaxHealth = msg.read_float();
		// [[ MODIFY BASE GAME START ]]
		syncShields(star, msg);
		star.temperature = msg.read_float();
		refreshTemperatureColor(star);
		// [[ MODIFY BASE GAME END ]]
	}

	void syncDelta(Star& star, Message& msg, double tDiff) {
		// [[ MODIFY BASE GAME START ]]
		if (msg.readBit()) {
			star.Health = msg.read_float();
			star.MaxHealth = msg.read_float();
		}

		if (msg.readBit()) {
			syncShields(star, msg);
		}

		if (msg.readBit()) {
			star.temperature = msg.read_float();
			refreshTemperatureColor(star);
		}
		// [[ MODIFY BASE GAME END ]]
	}

	double tick(Star& star, double time) {
		if(updateRegion(star)) {
			auto@ node = star.getNode();
			if(node !is null)
				node.hintParentObject(star.region);
		}
		star.orbitTick(time);

		return 1.0;
	}

	// [[ MODIFY BASE GAME START ]]
	double get_shield(const Star& star) {
		double value = star.Shield;
		if (star.owner !is null) {
			return value * star.owner.StarShieldProjectorFactor;
		} else {
			return value;
		}
	}

	double get_maxShield(const Star& star) {
		double value = star.MaxShield;
		if (star.owner !is null) {
			return value * star.owner.StarShieldProjectorFactor;
		} else {
			return value;
		}
	}
	// [[ MODIFY BASE GAME END ]]
};
