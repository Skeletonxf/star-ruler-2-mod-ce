import regions.regions;
import saving;
import systems;
// [[ MODIFY BASE GAME START ]]
from objects.Oddity import createNebula;
from statuses import getStatusID;
// [[ MODIFY BASE GAME END ]]

LightDesc lightDesc;

tidy class StarScript {
	bool hpDelta = false;
	// [[ MODIFY BASE GAME START ]]
	double shieldRegen = 0.0;
	bool shieldDelta = false;
	// [[ MODIFY BASE GAME END ]]

	void syncInitial(const Star& star, Message& msg) {
		msg << float(star.temperature);
		star.writeOrbit(msg);
		// [[ MODIFY BASE GAME START ]]
		syncShields(star, msg);
		// [[ MODIFY BASE GAME END ]]
	}

	void save(Star& star, SaveFile& file) {
		saveObjectStates(star, file);
		file << star.temperature;
		file << cast<Savable>(star.Orbit);
		file << star.Health;
		file << star.MaxHealth;
		// [[ MODIFY BASE GAME START ]]
		file << star.Shield;
		file << star.MaxShield;
		file << shieldRegen;
		// [[ MODIFY BASE GAME END ]]
	}

	void load(Star& star, SaveFile& file) {
		loadObjectStates(star, file);
		file >> star.temperature;

		if(star.owner is null)
			@star.owner = defaultEmpire;

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

		addAmbientSource(CURRENT_PLAYER, "star_rumble", star.id, star.position, soundRadius);

		if(file >= SV_0028)
			file >> cast<Savable>(star.Orbit);

		if(file >= SV_0102) {
			file >> star.Health;
			file >> star.MaxHealth;
		}

		lightDesc.position = vec3f(star.position);
		lightDesc.radius = star.radius;
		lightDesc.diffuse = node.color * 1.0f;
		if(temp <= 0)
			lightDesc.diffuse.a = 0.f;
		lightDesc.specular = lightDesc.diffuse;

		if(star.inOrbit)
			makeLight(lightDesc, node);
		else
			makeLight(lightDesc);

		// [[ MODIFY BASE GAME START ]]
		file >> star.Shield;
		file >> star.MaxShield;
		file >> shieldRegen;
		// [[ MODIFY BASE GAME END ]]
	}

	// [[ MODIFY BASE GAME START ]]
	void syncShields(const Star& star, Message& msg) {
		if (star.MaxShield > 0) {
			msg.write1();
			msg << float(star.Shield);
			msg << float(star.MaxShield);
		} else {
			msg.write0();
		}
	}
	// [[ MODIFY BASE GAME END ]]

	void syncDetailed(const Star& star, Message& msg) {
		msg << float(star.Health);
		msg << float(star.MaxHealth);
		// [[ MODIFY BASE GAME START ]]
		syncShields(star, msg);
		// [[ MODIFY BASE GAME END ]]
	}

	bool syncDelta(const Star& star, Message& msg) {
		// [[ MODIFY BASE GAME START ]]
		bool used = false;

		if (hpDelta) {
			msg.write1();
			used = true;
			hpDelta = false;
			msg << float(star.Health);
			msg << float(star.MaxHealth);
		} else {
			msg.write0();
		}

		if (shieldDelta) {
			used = true;
			shieldDelta = false;
			msg.write1();
			syncShields(star, msg);
		} else {
			msg.write0();
		}

		return used;
		// [[ MODIFY BASE GAME END ]]
	}

	void postLoad(Star& star) {
		Node@ node = star.getNode();
		if(node !is null)
			node.hintParentObject(star.region, false);
	}

	void postInit(Star& star) {
		double soundRadius = star.radius;
		//Blackholes need a 'bigger' sound
		if(star.temperature == 0.0)
			soundRadius *= 10.0;
		addAmbientSource(CURRENT_PLAYER, "star_rumble", star.id, star.position, soundRadius);
	}

	// [[ MODIFY BASE GAME START ]]
	void modProjectedShield(Star& star, float regen, float capacity) {
		shieldRegen += regen;
		star.MaxShield += capacity;
		shieldDelta = true;
	}

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

	void dealStarDamage(Star& star, double amount) {
		// [[ MODIFY BASE GAME START ]]
		double shieldFactor = 1;
		if (star.owner !is null) {
			shieldFactor = star.owner.StarShieldProjectorFactor;
		}
		double shield = star.Shield * shieldFactor;
		double maxShield = star.MaxShield * shieldFactor;
		double shieldBlock = 0;
		if (maxShield > 0)
			shieldBlock = min(shield * min(shield / maxShield, 1.0), amount);
		else
			shieldBlock = min(shield, amount);

		shield -= shieldBlock;
		amount -= shieldBlock;

		// [[ MODIFY BASE GAME START ]]
		if (shieldBlock > 0) {
			star.Shield = shield / shieldFactor;
			shieldDelta = true;
		}

		if (amount > 0) {
			hpDelta = true;
			star.Health -= amount;
			if(star.Health <= 0) {
				star.Health = 0;
				star.destroy();
			}
		}
		// [[ MODIFY BASE GAME END ]]
	}

	void destroy(Star& star) {
		if(!game_ending) {
			// [[ MODIFY BASE GAME START ]]
			// Double star explosion radius
			double explRad = 2 * star.radius;
			if(star.temperature == 0.0) {
				// Double black hole explosion radius, for a combined x4 factor
				explRad *= 40.0;
				// [[ MODIFY BASE GAME END ]]

				for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
					auto@ sys = getSystem(i);
					double dist = star.position.distanceTo(sys.position);
					// [[ MODIFY BASE GAME START ]]
					// Double explosion damage range
					if(dist < 200000.0) {
						double factor = sqr(1.0 - (dist / 200000));
						sys.object.addStarDPS(factor * star.MaxHealth * 0.08);
					}
					// [[ MODIFY BASE GAME END ]]
				}
			}
			playParticleSystem("StarExplosion", star.position, star.rotation, explRad);

			//auto@ node = createNode("NovaNode");
			//if(node !is null)
			//	node.position = star.position;
			removeAmbientSource(CURRENT_PLAYER, star.id);
			if(star.region !is null)
				star.region.addSystemDPS(star.MaxHealth * 0.12);

			// [[ MODIFY BASE GAME START ]]
			// Have a 33% chance of leaving a nebulae behind on star death
			if (randomd() < 0.33 && star.region !is null) {
				SystemDesc@ sys = getSystem(star.region);
				Node@ node = star.getNode();
				if (sys !is null && sys.object !is null && node !is null) {
					Color col = node.color;
					// create oddity
					createNebula(sys.position, sys.radius, color=col.rgba, region=sys.object);
					// check the system isn't already a nebulae before applying vision mechanics
					if (sys.donateVision) {
						// turn off region vision
						sys.donateVision = false;
						// set static seeable range
						for(uint i = 0, cnt = sys.object.objectCount; i < cnt; ++i) {
							Object@ obj = sys.object.objects[i];
							if(obj.hasStatuses)
							continue;
							obj.seeableRange = 100;
						}
						star.region.addRegionStatus(null, getStatusID("LimitedSight"));
					}
				}
			}
			// [[ MODIFY BASE GAME END ]]
		}
		leaveRegion(star);
	}

	/*void damage(Star& star, DamageEvent& evt, double position, const vec2d& direction) {
		evt.damage -= 100.0;
		if(evt.damage > 0.0)
			star.HP -= evt.damage;
	}*/

	double tick(Star& obj, double time) {
		updateRegion(obj);
		obj.orbitTick(time);

		Region@ reg = obj.region;
		uint mask = ~0;
		if(reg !is null && obj.temperature > 0)
			mask = reg.ExploredMask.value;
		obj.donatedVision = mask;

		// [[ MODIFY BASE GAME START ]]
		// Shields tick
		if (obj.MaxShield > 0) {
			if (obj.Shield < obj.MaxShield) {
				obj.Shield = min(obj.Shield + shieldRegen * time, obj.MaxShield);
				shieldDelta = true;
			}
		} else {
			if (obj.Shield != 0 || shieldRegen != 0) {
				obj.Shield = 0;
				shieldRegen = 0;
				shieldDelta = true;
			}
		}
		// [[ MODIFY BASE GAME END ]]

		return 1.0;
	}
};
