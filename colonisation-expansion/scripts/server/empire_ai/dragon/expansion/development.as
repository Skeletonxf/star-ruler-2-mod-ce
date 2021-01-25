import empire_ai.weasel.Development;

interface DevelopmentFocuses {
	/**
	 * The development focuses we have
	 */
	array<DevelopmentFocus@> getFocuses();

	/**
	 * If an object is a focus.
	 */
	bool isFocus(Object@ obj);

	/**
	 * Gets the development focus of a planet, if we have one
	 */
	DevelopmentFocus@ getFocus(Planet& pl);

	/**
	 * Adds a focus for a planet
	 */
	DevelopmentFocus@ addFocus(PlanetAI@ plAI);
}


bool init = false;
const ResourceClass@ scalableClass;

/**
 * Checks if a planet could make a good focus
 * TODO: Should turn into dedicated class and be race specific
 */
bool isGoodFocus(Planet& planet, AI& ai) {
	if (!init) {
		@scalableClass = getResourceClass("Scalable");
		init = true;
	}
	if (planet is null) {
		return false;
	}
	// for now, we assume all scalables and tier 3 planets are good focuses
	// regardless of the race we are playing
	const ResourceType@ resource = getResource(planet.primaryResourceType);
	if (resource is null) {
		return false;
	}
	if (resource.level >= 3 || resource.cls is scalableClass) {
		return true;
	}
	// uplifted planets should be considered focuses too
	return false;
}
