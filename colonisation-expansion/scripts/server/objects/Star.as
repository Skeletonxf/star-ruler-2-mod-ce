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

	void syncInitial(const Star& star, Message& msg) {
		msg << float(star.temperature);
		star.writeOrbit(msg);
	}

	void save(Star& star, SaveFile& file) {
		saveObjectStates(star, file);
		file << star.temperature;
		file << cast<Savable>(star.Orbit);
		file << star.Health;
		file << star.MaxHealth;
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
	}

	void syncDetailed(const Star& star, Message& msg) {
		msg << float(star.Health);
		msg << float(star.MaxHealth);
	}

	bool syncDelta(const Star& star, Message& msg) {
		if(!hpDelta)
			return false;

		msg << float(star.Health);
		msg << float(star.MaxHealth);
		hpDelta = false;
		return true;
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

	void dealStarDamage(Star& star, double amount) {
		hpDelta = true;
		star.Health -= amount;
		if(star.Health <= 0) {
			star.Health = 0;
			star.destroy();
		}
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

		return 1.0;
	}
};
