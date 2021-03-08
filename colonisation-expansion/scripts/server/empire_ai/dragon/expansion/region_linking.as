import empire_ai.weasel.Planets;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Resources;
import empire_ai.dragon.expansion.colonization;
import system_pathing;
import orbitals;

class AvoidOutpostMarker {
	Region@ region;
	/**
	 * Minimum game time to consider making outposts in this region again
	 */
	double until;

	void save(SaveFile& file) {
		file << region;
		file << until;
	}

	AvoidOutpostMarker(Region@ region, double until) {
		@this.region = region;
		this.until = until;
	}

	AvoidOutpostMarker(SaveFile& file) {
		file >> region;
		file >> until;
	}
}

class LinkBuild {
	Region@ region;
	AllocateConstruction@ build;

	LinkBuild(AllocateConstruction@ build, Region@ region) {
		@this.build = build;
		@this.region = region;
	}
}

/**
 * Responsible for letting the AI reconnect broken trade links and
 * expand through empty or occupied systems
 *
 * No more abusing the AI by boxing it in!
 */
// TODO: We should actually keep track of the outposts we've made so we can respond
// to them being attacked or tractored out of their position
class RegionLinking {
	Planets@ planets;
	Construction@ construction;
	Resources@ resources;
	Systems@ systems;
	Budget@ budget;
	ColonizationAbilityOwner@ colonization;

	double lastCheckedRegionsLinked = 0;
	const OrbitalModule@ outpost;
	const OrbitalModule@ starTemple;
	const OrbitalModule@ beacon; // TODO
	const OrbitalModule@ commerceStation; // TODO

	array<LinkBuild@> linkBuilds;

	// list of penalties that will stop us outposting regions we recently
	// failed at doing so
	array<AvoidOutpostMarker@> penalties;
	// a set of the ids in penalties
	set_int penaltySet;

	RegionLinking(Planets@ planets, Construction@ construction, Resources@ resources, Systems@ systems, Budget@ budget, ColonizationAbilityOwner@ colonization) {
		@this.planets = planets;
		@this.construction = construction;
		@this.resources = resources;
		@this.systems = systems;
		@this.budget = budget;
		@this.colonization = colonization;
		@this.outpost = getOrbitalModule("TradeOutpost");
		@this.starTemple = getOrbitalModule("Temple");
	}

	// Check roughly every 20 seconds or so that we can connect trade lines
	// from a random subset of our planets
	//
	// If we can't, try to build an outpost or star temple to connect them, and
	// restort to a commerce station if they're more than 3 hops disconnected
	void focusTick(AI& ai) {
		if (lastCheckedRegionsLinked + 20 < gameTime) {
			checkRegionsLinked(ai);
		}
		checkLinkBuilds(ai);
		updatePenalties();
	}

	void checkRegionsLinked(AI& ai) {
		lastCheckedRegionsLinked = gameTime;
		uint totalPlanets = planets.planets.length;
		if (totalPlanets < 2) {
			return;
		}
		array<uint> rolls;
		for (uint i = 0; i < 4 + (totalPlanets / 10); ++i) {
			rolls.insertLast(randomi(0, totalPlanets - 1));
		}
		uint totalRolls = rolls.length;
		for (uint i = 1; i < totalRolls; ++i) {
			uint index_i = rolls[i - 1];
			uint index_j = rolls[i];
			if (index_i == index_j) {
				continue;
			}
			PlanetAI@ planet_i = planets.planets[index_i];
			PlanetAI@ planet_j = planets.planets[index_j];
			if (planet_i is null || planet_j is null) {
				continue;
			}
			if (planet_i.obj is null || planet_j.obj is null) {
				continue;
			}
			if (planet_i.obj.region is planet_j.obj.region) {
				continue;
			}
			if (!resources.canTradeBetween(planet_i.obj.region, planet_j.obj.region)) {
				ai.print("No trade connection found between "+planet_i.obj.name+" and "+planet_j.obj.name);
				tryToConnectTrade(planet_i.obj.region, planet_j.obj.region, ai.empire);
			}
		}
	}

	void tryToConnectTrade(Region@ a, Region@ b, Empire@ emp) {
		// path based on links not our empire's connections, as we'll be looking
		// to add a connection
		TradePath tradePather(null);
		//tradePather.maxLinkDistance = 5; // abort if we would save money using a commerce station
		tradePather.generate(getSystem(a), getSystem(b), keepCache=true);
		if (!tradePather.valid) {
			// might not be connected to each other closely, perhaps we need a commerce station
		} else {
			for (uint i = 0, cnt = tradePather.path.length; i < cnt; ++i) {
				SystemDesc@ hop = tradePather.get_pathNode(i);
				Region@ region = hop.object;
				considerMakingLinkAt(region, emp, force=true);
			}
		}
	}

	// Potentially makes an outpost/temple to establish a trade link at a
	// particular region on the border of the AI
	void considerMakingLinkAt(Region@ region, Empire@ emp, bool force=false) {
		if (alreadyMakingLinkAt(region, emp)) {
			return;
		}
		// TODO: We should dynamically change our priorities as our eco grows
		// outposts are cheaper to claim a system than a planet is, but a colony
		// is much easier to make than an outpost in the early game
		// Since even a useless planet takes some effort to destroy, for now
		// just always try colonising first, since this is at least more robust
		// than outpost first.
		bool colonizingForLink = colonization.requestColonyInRegion(region);
		if (!force && colonizingForLink) {
			return;
		}
		if (penaltySet.contains(region.id)) {
			return; // probably enemy ships guarding
		}
		bool canAfford = force
			|| (outpost !is null && budget.canSpend(BT_Development, outpost.buildCost, outpost.maintenance));
		if (!canAfford) {
			return;
		}
		if (region.TradeMask & emp.TradeMask.value == 0) {
			// we should consider building an outpost here, if this is
			// a border system
			for (uint i = 0, cnt = systems.outsideBorder.length; i < cnt; ++i) {
				SystemAI@ sys = systems.outsideBorder[i];
				if (sys.explored && sys.obj is region) {
					// TODO: The AI should use this method for all the orbitals it builds like Mainframes and Gates
					auto@ factory = construction.getClosestFactory(region);
					if (factory !is null) {
						vec3d position;
						vec2d offset = random2d(sys.desc.radius * 0.1, sys.desc.radius * 0.4);
						position.x = sys.obj.position.x + offset.x;
						position.y = sys.obj.position.y;
						position.z = sys.obj.position.z + offset.y;

						BuildOrbital@ buildPlan;
						if (outpost !is null && outpost.canBuild(factory.obj, position)) {
							@buildPlan = construction.buildOrbital(outpost, position, force=force, moneyType=BT_Development);
						} else if (starTemple !is null && starTemple.canBuild(factory.obj, position)) {
							@buildPlan = construction.buildOrbital(starTemple, position, force=force, moneyType=BT_Development);
						}
						if (buildPlan !is null) {
							AllocateConstruction@ allocation = construction.buildNow(buildPlan, factory);
							if (allocation !is null) {
								linkBuilds.insertLast(LinkBuild(allocation, region));
								print("Making outpost for trade connection at "+region.name);
							}
						}
					}
				}
			}
		}
	}

	bool alreadyMakingLinkAt(Region@ region, Empire@ empire) {
		for (uint i = 0, cnt = linkBuilds.length; i < cnt; ++i) {
			if (linkBuilds[i].region is region) {
				return true;
			}
		}

		// the AI has an annoying habit of forgetting about things it actually
		// enqueued previously, check we don't actually have an outpost here already
		// TODO: Are outposts in the process of being built/activated not being noticed here?
		return getOutposts(region, empire) > 0;
	}

	uint getOutposts(Region@ region, Empire@ empire) {
		uint totalOrbitals = region.orbitalCount;
		uint totalOwnedOutpostsPresent = 0;
		for (uint i = 0; i < totalOrbitals; i++) {
			Orbital@ orbital = region.get_orbitals(i);
			if (orbital.owner is empire
				&& ((outpost !is null && orbital.coreModule == outpost.id)
					|| (starTemple !is null && orbital.coreModule == starTemple.id))) {
				totalOwnedOutpostsPresent += 1;
			}
		}
		return totalOwnedOutpostsPresent;
	}

	void checkLinkBuilds(AI& ai) {
		for (uint i = 0, cnt = linkBuilds.length; i < cnt; ++i) {
			AllocateConstruction@ build = linkBuilds[i].build;
			// TODO: We should probably manually timeout builds here as there
			// doesn't seem to be any automatic timeout in Construction.as
			if (build is null || build.completed) {
				if (linkBuilds[i].region !is null && getOutposts(linkBuilds[i].region, ai.empire) == 0) {
					// did it get shot down?
					ai.print("Outpost missing in "+linkBuilds[i].region.name);
					double nextAllowedOutpostTime = gameTime + ai.behavior.colonizePenalizeTime;
					AvoidOutpostMarker@ penalty = AvoidOutpostMarker(linkBuilds[i].region, nextAllowedOutpostTime);
					penalties.insertLast(penalty);
					penaltySet.insert(penalty.region.id);
				}
				linkBuilds.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void updatePenalties() {
		for (uint i = 0, cnt = penalties.length; i < cnt; ++i) {
			AvoidOutpostMarker@ penalty = penalties[i];
			if (penalty.region is null || gameTime > penalty.until) {
				penalties.removeAt(i);
				if (penalty.region !is null) {
					penaltySet.erase(penalty.region.id);
				}
				--i; --cnt;
			}
		}
	}

	void save(SaveFile& file) {
		file << lastCheckedRegionsLinked;
		uint cnt = linkBuilds.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			construction.saveConstruction(file, linkBuilds[i].build);
			file << linkBuilds[i].region;
		}
		cnt = penalties.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			penalties[i].save(file);
		}
	}

	void load(SaveFile& file) {
		file >> lastCheckedRegionsLinked;
		uint cnt = 0;
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			AllocateConstruction@ build = construction.loadConstruction(file);
			Region@ region;
			file >> region;
			if (build !is null && region !is null) {
				linkBuilds.insertLast(LinkBuild(build, region));
			}
		}
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			AvoidOutpostMarker@ penalty = AvoidOutpostMarker(file);
			if (penalty.region !is null) {
				penalties.insertLast(penalty);
				penaltySet.insert(penalty.region.id);
			}
		}
	}
}
