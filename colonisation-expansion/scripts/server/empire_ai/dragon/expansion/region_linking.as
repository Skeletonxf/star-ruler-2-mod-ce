import empire_ai.weasel.Planets;

import orbitals;

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
	double lastCheckedRegionsLinked = 0;
	const OrbitalModule@ outpost;
	const OrbitalModule@ starTemple;
	const OrbitalModule@ beacon;
	const OrbitalModule@ commerceStation;

	RegionLinking(Planets@ planets) {
		@this.planets = planets;
		@this.outpost = getOrbitalModule("TradeOutpost");
	}

	// TODO: Check roughly every minute or so that we can connect trade lines
	// from a random subset of our planets
	// and check that we don't have broken trade links in any of our actual
	// trade lines
	// If we do, try to build an outpost or star temple to connect them, and
	// restort to a commerce station if they're more than 3 hops disconnected
	//
	// Also, we should also check if we've hit a system that we need to expand
	// through to reach more planets but has nothing of value to colonise
	// itself, in which case we should build an outpost/star temple onto it.
	// check if any of our borders
	void tick() {
		if (lastCheckedRegionsLinked < gameTime) {
			checkRegionsLinked();
		}
	}

	void checkRegionsLinked() {
		lastCheckedRegionsLinked = gameTime;
	}

	void save(SaveFile& file) {
		file << lastCheckedRegionsLinked;
	}

	void load(SaveFile& file) {
		file >> lastCheckedRegionsLinked;
	}
}
