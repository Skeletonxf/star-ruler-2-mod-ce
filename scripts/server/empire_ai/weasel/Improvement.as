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

from traits import getTraitID;

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
	bool no_build_moon_bases = false;

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
		no_build_moon_bases = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
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
				if (no_build_moon_bases) {
					// don't build moon bases as Star Children or Ancient
					// star children don't need them as they don't build
					// and Ancient bypasses biome cost/build time mods
					// so can just build on planet surfaces as normal and
					// thus doesn't need them
					continue;
				}
				if (planet.moonCount == 0) {
					continue;
				}
				if (planet.get_Biome0() != atmosphere) {
					continue;
				}
				if (planet.getStatusStackCountAny(moon_base) > 0 && !plAI.failedGasGiantBuild) {
					// If we already have a moon base and haven't attempted
					// and failed to build anything on this planet we don't need
					// more
					continue;
				}
				if (planet.moonCount >= planet.getStatusStackCountAny(moon_base)) {
					// can't build more moon bases
					continue;
				}
				if (!planets.isConstructing(planet, build_moon_base)) {
					// This is always high priority because we either have no
					// moon base in which case we can't build anything
					// or we already tried to build something and don't have
					// enough moon bases
					if (log && planet.getStatusStackCountAny(moon_base) > 1) {
						ai.print("Building additional moon base at " + planet.name);
					}
					// Set the flag back
					plAI.failedGasGiantBuild = false;
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
