import resources;

interface RaceResourceValuation {
	/**
	 * Updates a resource valuation to accomodate race specific factors.
	 */
	double modifyValue(const ResourceType@ resource, double currentValue);
}

/**
 * A valuator of a resource.
 */
class ResourceValuator {
	RaceResourceValuation@ race;
	const ResourceClass@ scalableClass;
	const ResourceType@ ftlCrystals;
	const ResourceType@ altar;
	const ResourceType@ razed;

	ResourceValuator() {
		// TODO: Race specific valuations
		@scalableClass = getResourceClass("Scalable");
		@ftlCrystals = getResource("FTL");
		@altar = getResource("Altar");
		@razed = getResource("Razed");
	}

	/**
	 * Gets the value of a resouce to the AI in terms of a
	 * resource to build up via levelling.
	 */
	double getValue(const ResourceType@ resource) {
		double value = 0.0;
		// scalabe resources are generally the best for levelling
		if (resource.cls is scalableClass) {
			value += 10;
		}
		// tier 3 resources are generally pretty good too
		if (resource.level == 3) {
			value += 7;
		}
		// tier 2 resources will do if we have nothing better
		if (resource.level == 2) {
			value += 3;
		}
		// tier 1 resources will do if we completely out of options
		if (resource.level == 2) {
			value += 1;
		}
		// Resources with pressure are generally more helpful than ones
		// without, if nothing else is a major difference
		value += double(resource.totalPressure) * 0.1;
		// FTL crystals is extremely useful for levelling
		if (ftlCrystals !is null && resource.id == ftlCrystals.id) {
			value += 20;
		}
		value = devalueUselessResources(resource, value);
		if (race !is null) {
			value = race.modifyValue(resource, value);
		}
		return value;
	}

	double devalueUselessResources(const ResourceType@ resource, double currentValue) {
		if (altar !is null && resource.id == altar.id)
			return -1;
		if (razed !is null && resource.id == razed.id)
			return -5;
		return currentValue;
	}
}
