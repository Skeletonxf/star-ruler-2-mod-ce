import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Development;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Budget;

import biomes;

class Improvement : AIComponent {
	Planets@ planets;
	Resources@ resources;
	Colonization@ colonization;
	Development@ development;
	Orbitals@ orbitals;
	Construction@ construction;
	Systems@ systems;
	Budget@ budget;

	uint atmosphere = 0;
	int moon_base = -1;
	const ConstructionType@ build_moon_base;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@resources = cast<Resources>(ai.resources);
		@colonization = cast<Colonization>(ai.colonization);
	    @development = cast<Development>(ai.development);
		@orbitals = cast<Orbitals>(ai.orbitals);
	    @construction = cast<Construction>(ai.construction);
		@systems = cast<Systems>(ai.systems);
	    @budget = cast<Budget>(ai.budget);

		// cache lookups
		atmosphere = getBiomeID("Atmosphere");
		moon_base = getStatusID("MoonBase");
		@build_moon_base = getConstructionType("MoonBase");
	}

	void save(SaveFile& file) {
		// TODO
	}

	void load(SaveFile& file) {
		// TODO
	}

	void start() {
		// TODO
	}

	void focusTick(double time) override {
		// looks like this is where we should perform actions?
		// check for any gas giants we have no moon bases on
		if (budget.canSpend(BT_Development, 500)) {
			for(uint i = 0, cnt = planets.planets.length; i < cnt; ++i) {
				auto@ plAI = planets.planets[i];
				auto@ planet = plAI.obj;
				// TODO: don't build moon bases as Star Children
				if (planet.moonCount == 0) {
					continue;
				}
				if (planet.get_Biome0() != atmosphere) {
					continue;
				}
				if (planet.getStatusStackCountAny(moon_base) > 0) {
					continue;
				}
				if (!planets.isConstructing(planet, build_moon_base)) {
					// just build first moon base on gas giants for v1
					planets.requestConstruction(
						plAI, planet, build_moon_base, priority=3, expire=gameTime + 600, moneyType=BT_Development);
						// only build one thing each tick so the empire
						// does other things than improvements
						return;
				}
			}
		}
	}

	void tick(double time) override {
		// TODO
	}
}

AIComponent@ createImprovement() {
	return Improvement();
}
