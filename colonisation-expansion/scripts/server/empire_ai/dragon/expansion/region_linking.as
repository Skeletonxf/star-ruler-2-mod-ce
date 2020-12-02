import empire_ai.weasel.Planets;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Resources;
import system_pathing;

import orbitals;

class LinkBuild {
	Region@ region;
	AllocateConstruction@ build;

	LinkBuild(AllocateConstruction@ build, Region@ region) {
		@this.build = build;
		@this.region = region;
	}
}

/**
 * TODO
 *
 * Will be responsible for letting the AI reconnect broken trade links and
 * expand through empty or occupied systems
 *
 * No more abusing the AI by boxing it in!
 */
class RegionLinking {
	Planets@ planets;
	Construction@ construction;
	Resources@ resources;
	Systems@ systems;

	double lastCheckedRegionsLinked = 0;
	const OrbitalModule@ outpost;
	const OrbitalModule@ starTemple;
	const OrbitalModule@ beacon;
	const OrbitalModule@ commerceStation;

	array<LinkBuild@> linkBuilds;

	RegionLinking(Planets@ planets, Construction@ construction, Resources@ resources, Systems@ systems) {
		@this.planets = planets;
		@this.construction = construction;
		@this.resources = resources;
		@this.systems = systems;
		@this.outpost = getOrbitalModule("TradeOutpost");
	}

	// TODO: Check roughly every 20 seconds or so that we can connect trade lines
	// from a random subset of our planets
	//
	// If we can't, try to build an outpost or star temple to connect them, and
	// restort to a commerce station if they're more than 3 hops disconnected
	//
	// TODO, we should also check if we've hit a system that we need to expand
	// through to reach more planets but has nothing of value to colonise
	// itself, in which case we should build an outpost/star temple onto it.
	// check if any of our borders
	void focusTick(AI& ai) {
		if (lastCheckedRegionsLinked + 20 < gameTime) {
			checkRegionsLinked(ai);
		}
		checkLinkBuilds();
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
				print("No trade connection found between "+planet_i.obj.name+" and "+planet_j.obj.name);
				tryToConnectTrade(planet_i, planet_j, ai.empire);
			}
		}
	}

	void tryToConnectTrade(PlanetAI@ a, PlanetAI@ b, Empire@ emp) {
		Region@ fromRegion = a.obj.region;
		Region@ toRegion = b.obj.region;
		// path based on links not our empire's connections, as we'll be looking
		// to add a connection
		TradePath tradePather(null);
		//tradePather.maxLinkDistance = 5; // abort if we would save money using a commerce station
		tradePather.generate(getSystem(fromRegion), getSystem(toRegion), keepCache=true);
		if (!tradePather.valid) {
			// might not be connected to each other closely, perhaps we need a commerce station
		} else {
			for (uint i = 0, cnt = tradePather.path.length; i < cnt; ++i) {
				SystemDesc@ hop = tradePather.get_pathNode(i);
				Region@ region = hop.object;
				if (alreadyMakingLinkAt(region)) {
					continue;
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
								BuildOrbital@ buildPlan = construction.buildOrbital(outpost, position);
								linkBuilds.insertLast(LinkBuild(construction.buildNow(buildPlan, factory), region));
								print("Making outpost for trade connection at "+region.name);
							}
						}
					}
				}
			}
		}
	}

	bool alreadyMakingLinkAt(Region@ region) {
		for (uint i = 0, cnt = linkBuilds.length; i < cnt; ++i) {
			if (linkBuilds[i].region is region) {
				return true;
			}
		}
		return false;
	}

	void checkLinkBuilds() {
		for (uint i = 0, cnt = linkBuilds.length; i < cnt; ++i) {
			AllocateConstruction@ build = linkBuilds[i].build;
			// TODO: We should probably manually timeout builds here as there
			// doesn't seem to be any automatic timeout in Construction.as
			if (build.completed) {
				linkBuilds.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void save(SaveFile& file) {
		file << lastCheckedRegionsLinked;
		file << linkBuilds.length;
		for (uint i = 0, cnt = linkBuilds.length; i < cnt; ++i) {
			construction.saveConstruction(file, linkBuilds[i].build);
			file << linkBuilds[i].region;
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
	}
}
