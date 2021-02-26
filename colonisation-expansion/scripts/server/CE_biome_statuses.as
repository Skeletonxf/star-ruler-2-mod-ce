import statuses;
import biomes;

// It would be nice if these were exposed to a data file setup so they
// can be configured without modifying code, but I'm probably never going
// to get around to it because there's more effort in setting up a fresh
// config system than editing this code directly ¯\_(ツ)_/¯

bool initialized = false;
uint ice;
uint ocean;
const StatusType@ waterBiome;
const StatusType@ frozenIce;

void refreshBiomeStatuses(Object& planet, uint biome0, uint biome1, uint biome2) {
	if (!initialized) {
		ice = getBiomeID("Ice");
		ocean = getBiomeID("Oceanic");
		@waterBiome = getStatusType("WaterBiome");
		@frozenIce = getStatusType("FrozenIce");
		initialized = true;
	}
	setStatus(planet, waterBiome, biome0 == ocean || biome1 == ocean || biome2 == ocean);
	setStatus(planet, frozenIce, biome0 == ice || biome1 == ice || biome2 == ice);
}

void setStatus(Object& planet, const StatusType@ status, bool shouldHave) {
	if (status is null) {
		return;
	}
	bool has = planet.getStatusStackCountAny(status.id) > 0;
	if (shouldHave && !has) {
		planet.addStatus(status.id);
	}
	if (has && !shouldHave) {
		planet.removeStatusType(status.id);
	}
}
