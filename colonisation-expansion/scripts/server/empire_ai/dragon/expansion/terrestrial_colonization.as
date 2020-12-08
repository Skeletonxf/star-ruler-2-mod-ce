import empire_ai.weasel.Planets;
import empire_ai.weasel.Colonization;
import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;

interface ColonizeBudgeting {
	void payColonize();
	bool canAffordColonize();
}

class ColonizerPlanet : ColonizationSource {
	PotentialSource@ colonizeFrom;

	ColonizerPlanet(PotentialSource@ source) {
		@this.colonizeFrom = source;
	}

	vec3d getPosition() {
		return colonizeFrom.pl.position;
	}

	bool valid(AI& ai) {
		return colonizeFrom.pl.owner is ai.empire;
	}

	string toString() {
		return colonizeFrom.pl.name;
	}
}

class TerrestrialColonization : ColonizationAbility {
	Planets@ planets;
	double sourceUpdate = 0;
	// wrapper around potential source to implement the colonisation ability
	// interfaces, tracks our planets that are populated enough to colonise with
	array<ColonizationSource@> planetSources;
	ColonizeBudgeting@ budgeting;

	TerrestrialColonization(Planets@ planets, ColonizeBudgeting@ budgeting) {
		@this.planets = planets;
		@this.budgeting = budgeting;
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
			double distance = source.colonizeFrom.pl.position.distanceTo(position);
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
			// TODO: Might want to consider gates/slipstreams here?
			// colonising from further away takes longer
			double weight = source.colonizeFrom.weight;
			weight /= colony.position.distanceTo(source.colonizeFrom.pl.position);
			if (weight > colonizeFromWeight) {
				colonizeFromWeight = weight;
				@colonizeFrom = source;
			}
		}
		return colonizeFrom;
	}

	void orderColonization(ColonizeData& data, ColonizationSource@ isource) {
		ColonizerPlanet@ source = cast<ColonizerPlanet>(isource);
		@data.colonizeFrom = source.colonizeFrom.pl;
		ColonizeData2@ _data = cast<ColonizeData2>(data);
		if (_data !is null) {
			@_data.colonizeUnit = source;
		}
		// Assuming the AI will never need to colonise multiple planets at
		// once from a single planet
		planetSources.remove(source);
		source.colonizeFrom.pl.colonize(data.target);
		budgeting.payColonize();
	}

	void saveSource(SaveFile& file, ColonizationSource@ source) {
		if (source !is null) {
			file.write1();
			ColonizerPlanet@ source = cast<ColonizerPlanet>(source);
			// just save the planet
			file << source.colonizeFrom.pl;
		} else {
			file.write0();
		}
	}

	bool refreshOnReload = false;
	ColonizationSource@ loadSource(SaveFile& file) {
		if (!refreshOnReload) {
			refreshOnReload = true;
			refreshSources();
		}
		if (file.readBit()) {
			// read back the planet
			Planet@ planet;
			file >> planet;
			// look for the source that has this planet
			for (uint i = 0, cnt = planetSources.length; i < cnt; ++i) {
				ColonizerPlanet@ source = cast<ColonizerPlanet>(planetSources[i]);
				if (source.colonizeFrom.pl is planet) {
					return source;
				}
			}
		}
		return null;
	}
}
