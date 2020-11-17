import empire_ai.weasel.Planets;
import empire_ai.weasel.Colonization;

interface ColonizeBudgeting {
	void payColonize();
	bool canAffordColonize();
}

class TerrestrialColonization {
	Planets@ planets;
	double sourceUpdate = 0;
	// planets we can colonize from
	array<PotentialSource@> sources;
	RaceColonization@ race;
	ColonizeBudgeting@ budgeting;

	TerrestrialColonization(Planets@ planets, RaceColonization@ race, ColonizeBudgeting@ budgeting) {
		@this.planets = planets;
		@this.race = race;
		@this.budgeting = budgeting;
	}

	void refreshColonizeSources() {
		planets.getColonizeSources(sources);
	}

	void tick() {
		if (sourceUpdate < gameTime) {
			refreshColonizeSources();
			if (sources.length == 0 && gameTime < 60.0) {
				sourceUpdate = gameTime + 1.0;
			} else {
				sourceUpdate = gameTime + 10.0;
			}
		}
	}

	double getSourceWeight(PotentialSource& source, ColonizeData& data) {
		double w = source.weight;
		// TODO: Might want to consider gates here?
		// colonising from further away takes longer
		w /= data.target.position.distanceTo(source.pl.position);
		return w;
	}

	/**
	 * Finds the best planet to colonize another.
	 */
	PotentialSource@ findPlanetColonizeSource(ColonizeData@ colonizeData) {
		if (!budgeting.canAffordColonize()) {
			return null;
		}
		PotentialSource@ colonizeFrom;
		double colonizeFromWeight = 0;

		for (uint j = 0, jcnt = sources.length; j < jcnt; ++j) {
			double w = getSourceWeight(sources[j], colonizeData);
			if (w > colonizeFromWeight) {
				colonizeFromWeight = w;
				@colonizeFrom = sources[j];
			}
		}

		return colonizeFrom;
	}

	/**
	 * Begins actually colonising a planet via another one
	 */
	void orderColonization(ColonizeData& data, PotentialSource@ source) {
		// TODO: This stops us if we try to colonise as Ancient, would like
		// to unspecial case Ancient colonisation later in
		if (race !is null) {
			if (race.orderColonization(data, source.pl))
				return;
		}

		@data.colonizeFrom = source.pl;
		sources.remove(source);
		source.pl.colonize(data.target);
		budgeting.payColonize();
	}

	// We could save the sourceUpdate to file but if we don't bother then
	// we'll just immediately recompute our potential sources when reloading
	// which also solves the issue of saving them
	void save(SaveFile& file) {}
	void load(SaveFile& file) {}
}
