import empire_ai.weasel.Planets;
import empire_ai.weasel.Colonization;
import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;

class ColonizerPlanet : ColonizationSource {
	Planet@ planet;

	ColonizerPlanet(PotentialSource@ source) {
		@this.planet = source.pl;
	}

	ColonizerPlanet(Planet@ planet) {
		@this.planet = planet;
	}

	vec3d getPosition() {
		return planet.position;
	}

	bool valid(AI& ai) {
		return planet.owner is ai.empire;
	}

	string toString() {
		return planet.name;
	}

	// How useful this planet is for colonising others, (ie sufficient pop)
	// can't change this, this is a copy of how PotentialSource is allocated
	// weights
	double weight(AI& ai) {
		if(!valid(ai))
			return 0.0;
		if(planet.isColonizing)
			return 0.0;
		if(planet.level == 0)
			return 0.0;
		if(!planet.canSafelyColonize)
			return 0.0;
		double w = 1.0;
		double pop = planet.population;
		double maxPop = planet.maxPopulation;
		if(pop < maxPop-0.1) {
			if(planet.resourceLevel > 1 && pop/maxPop < 0.9)
				return 0.0;
			w *= 0.01 * (pop / maxPop);
		}
		return w;
	}
}

class TerrestrialColonization : ColonizationAbility {
	Planets@ planets;
	double sourceUpdate = 0;
	// wrapper around potential source to implement the colonisation ability
	// interfaces, tracks our planets that are populated enough to colonise with
	array<ColonizationSource@> planetSources;
	ColonizeBudgeting@ budgeting;
	AI@ ai;

	TerrestrialColonization(Planets@ planets, ColonizeBudgeting@ budgeting, AI@ ai) {
		@this.planets = planets;
		@this.budgeting = budgeting;
		@this.ai = ai;
	}

	void colonizeTick() {
		if (sourceUpdate < gameTime) {
			refreshSources();
			if (planetSources.length == 0 && gameTime < 60.0) {
				sourceUpdate = gameTime + 1.0;
			} else {
				sourceUpdate = gameTime + 10.0;
			}
		}
	}

	// We could save the sourceUpdate to file but if we don't bother then
	// we'll just immediately recompute our potential sources when reloading
	// which also solves the issue of saving them
	void saveManager(SaveFile& file) {}
	void loadManager(SaveFile& file) {}

	// ColonizeAbility implementation
	array<ColonizationSource@> getSources() {
		return planetSources;
	}

	void refreshSources() {
		array<PotentialSource@> sources;
		planets.getColonizeSources(sources);
		uint total_sources = sources.length;
		planetSources.length = total_sources;
		for (uint i = 0, cnt = planetSources.length; i < cnt; ++i) {
			@planetSources[i] = ColonizerPlanet(sources[i]);
		}
	}

	ColonizationSource@ getClosestSource(vec3d position) {
		if (!budgeting.canAffordColonize()) {
			return null;
		}
		double shortestDistance = -1;
		ColonizerPlanet@ closestSource;
		for (uint i = 0, cnt = planetSources.length; i < cnt; ++i) {
			ColonizerPlanet@ source = cast<ColonizerPlanet>(planetSources[i]);
			double distance = source.planet.position.distanceTo(position);
			if (shortestDistance == -1 || distance < shortestDistance) {
				shortestDistance = distance;
				@closestSource = source;
			}
		}
		return closestSource;
	}

	/**
	 * Returns the best source based on distance and the weights Planets.as
	 * assigns to each potential source.
	 */
	ColonizationSource@ getFastestSource(Planet@ colony) {
		if (!budgeting.canAffordColonize()) {
			return null;
		}
		ColonizerPlanet@ colonizeFrom;
		double colonizeFromWeight = 0;
		for (uint i = 0, cnt = planetSources.length; i < cnt; ++i) {
			ColonizerPlanet@ source = cast<ColonizerPlanet>(planetSources[i]);
			double dist = getPathDistance(ai.empire, source.planet.position, colony.position);
			double weight = source.weight(ai);
			weight /= dist;
			if (weight > colonizeFromWeight) {
				colonizeFromWeight = weight;
				@colonizeFrom = source;
			}
		}
		return colonizeFrom;
	}

	void orderColonization(ColonizeData@ data, ColonizationSource@ isource) {
		ColonizerPlanet@ source = cast<ColonizerPlanet>(isource);
		@data.colonizeFrom = source.planet;
		ColonizeData2@ _data = cast<ColonizeData2>(data);
		if (_data !is null) {
			@_data.colonizeUnit = source;
		}
		// Assuming the AI will never need to colonise multiple planets at
		// once from a single planet
		planetSources.remove(source);
		source.planet.colonize(data.target);
		budgeting.payColonize();
	}

	void saveSource(SaveFile& file, ColonizationSource@ source) {
		if (source !is null) {
			file.write1();
			ColonizerPlanet@ source = cast<ColonizerPlanet>(source);
			if (source is null) {
				print("source casted became null!");
			}
			file << source.planet;
		} else {
			file.write0();
		}
	}

	ColonizationSource@ loadSource(SaveFile& file) {
		if (file.readBit()) {
			Planet@ planet;
			file >> planet;
			return ColonizerPlanet(planet);
		}
		return null;
	}
}
