import empire_ai.weasel.Planets;
import empire_ai.weasel.Budget;

import buildings;

from statuses import getStatusID;
from traits import getTraitID;

class PlanetManagement {
	Planets@ planets;
	Budget@ budget;
	bool log;

	uint nativeLifeStatus = 0;
	const ConstructionType@ uplift_planet;
	const ConstructionType@ genocide_planet;
	bool no_uplift = false;
	double uplift_cost = 800;

	uint planetCheckIndex = 0;

	// TODO: Need focus management interface to call from here
	PlanetManagement(Planets@ planets, Budget@ budget, AI& ai, bool log) {
		@this.planets = planets;
		@this.budget = budget;
		this.log = log;

		// cache lookups
		nativeLifeStatus = getStatusID("NativeLife");
		@uplift_planet = getConstructionType("SharePlanet");
		@genocide_planet = getConstructionType("TakePlanet");
		// ancient empire has automatic, free, genocide effect, and cannot
		// uplift
		no_uplift = ai.empire.hasTrait(getTraitID("Ancient"));
		// mono empire has a cheaper uplift option
		if (ai.empire.hasTrait(getTraitID("Mechanoid"))) {
			@uplift_planet = getConstructionType("SharePlanetMono");
		}
		if (uplift_planet !is null) {
			uplift_cost = uplift_planet.buildCost;
		}
	}

	/**
	 * Checks one of the planets we own, acting as necessary to fix problems
	 * or act on things we might want to do.
	 */
	void focusTick(AI& ai) {
		if (planets.planets.length == 0) {
			return;
		}

		planetCheckIndex = (planetCheckIndex+1) % planets.planets.length;
		PlanetAI@ plAI = planets.planets[planetCheckIndex];

		if (plAI.obj is null) {
			return;
		}

		manageUplift(plAI, ai);
		// TODO: Respond to primitive life statuses
		// TODO: Long term this should all be generic hook based responses
	}

	// TODO: Track the construction requests we make in a ConstructionTracker
	// so we can prompt other parts of the AI to do things when they complete
	// or fail.
	// Should add uplifted planets as dev focus when the uplift finishes
	// Should also open a new colonise to makeup for lost resource
	// this would ideally be done by unsetting the import request the planet
	// was matched to but this info isn't tracked yet

	/**
	 * Deals with native life status on planets
	 */
	void manageUplift(PlanetAI@ plAI, AI& ai) {
		if (!plAI.obj.hasStatusEffect(nativeLifeStatus)) {
			return;
		}
		if ((!planets.isConstructing(plAI.obj, uplift_planet))
				&& (!planets.isConstructing(plAI.obj, genocide_planet))
				&& !no_uplift) {
			// check if we can afford to uplift this planet
			// Uplift costs 800k, 5 influence, 500 energy
			// 500 energy is pretty cheap to save up for so isn't
			// factored in here for evaluating
			if (ai.empire.Influence >= 8 && budget.canSpend(BT_Development, uplift_cost)) {
				if (log) {
					ai.print("found native life planet to uplift");
				}
				planets.requestConstruction(
					plAI, plAI.obj, uplift_planet, priority=1, expire=gameTime + 600, moneyType=BT_Development);
				//auto@ focus = addFocus(plAI);
				//focus.targetLevel = 3;
				//// we'll automatically seek to level it to 3 now
			} else {
				if (log) {
					ai.print("can't afford uplift, taking over planet");
				}
				// this is high priority because until the NativeLife status is removed the
				// AI may think it can use this planet as an export and get very confused or
				// cripple its resource chains which would be very bad.
				planets.requestConstruction(
					plAI, plAI.obj, genocide_planet, priority=3, expire=gameTime + 600, moneyType=BT_Development);
			}
		}
	}

	void save(SaveFile& file) {
		file << planetCheckIndex;
	}

	void load(SaveFile& file) {
		file >> planetCheckIndex;
	}
}
