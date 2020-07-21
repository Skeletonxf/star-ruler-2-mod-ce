import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Development;
import empire_ai.weasel.Orbitals;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Military;

import biomes;

from traits import getTraitID;
from orbitals import getOrbitalModuleID;

const double FTL_EXTRACTOR_MIN_HELD_BASE_TIMER = 3 * 60.0;

class Improvement : AIComponent {
	Planets@ planets;
	Resources@ resources;
	Colonization@ colonization;
	Development@ development;
	Orbitals@ orbitals;
	Construction@ construction;
	Systems@ systems;
	Budget@ budget;
	Military@ military;

	uint atmosphere = 0;
	int moon_base = -1;
	const ConstructionType@ build_moon_base;
	bool no_build_moon_bases = false;

	int ftlExtractorModuleID = -1;
	bool ftlExtractorsUnlocked = false;

	AllocateConstruction@ extractorBuild = null;

	void create() {
		@planets = cast<Planets>(ai.planets);
		@resources = cast<Resources>(ai.resources);
		@colonization = cast<Colonization>(ai.colonization);
		@development = cast<Development>(ai.development);
		@orbitals = cast<Orbitals>(ai.orbitals);
	    @construction = cast<Construction>(ai.construction);
		@systems = cast<Systems>(ai.systems);
	    @budget = cast<Budget>(ai.budget);
		@military = cast<Military>(ai.military);

		// cache lookups
		atmosphere = getBiomeID("Atmosphere");
		moon_base = getStatusID("MoonBase");
		@build_moon_base = getConstructionType("MoonBase");
		no_build_moon_bases = ai.empire.hasTrait(getTraitID("Ancient")) || ai.empire.hasTrait(getTraitID("StarChildren"));
		ftlExtractorModuleID = getOrbitalModuleID("FTLExtractor");
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;
	}

	void save(SaveFile& file) {
		construction.saveConstruction(file, extractorBuild);
	}

	void load(SaveFile& file) {
		@extractorBuild = construction.loadConstruction(file);
	}

	void start() {
		// TODO
	}

	void focusTick(double time) override {
		// looks like this is where we should perform actions?
		lookToBuildGasGiants();

		// check again to see if we unlocked FTL Extractors
		ftlExtractorsUnlocked = ai.empire.FTLExtractorsUnlocked >= 1;
		lookToBuildFTLExtractors();
	}

	void lookToBuildGasGiants() {
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
				if (!plAI.failedGasGiantBuild) {
					// don't need a moon base if this planet has all its
					// food and water imported
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

	void lookToBuildFTLExtractors() {
		if (!development.requestsFTLIncome()) {
			return;
		}

		if (!ftlExtractorsUnlocked) {
			// TODO: Queue up the research for Extractors
			return;
		}

		if (extractorBuild !is null) {
			// Don't try to build a second extractor while first is in progress
			return;
		}

		if (!budget.canSpend(BT_Military, 300, 50)) {
			// TODO: Pull these values from the orbital module rather than
			// hardcoding
			return;
		}

		// Try to find a staging base to build this orbital at as they are
		// easily shot down if not protected
		for (uint i = 0, cnt = military.stagingBases.length; i < cnt; ++i) {
			auto@ base = military.stagingBases[i];
			if (base.occupiedTime < FTL_EXTRACTOR_MIN_HELD_BASE_TIMER) {
				continue;
			}

			auto@ factory = construction.getFactory(base.region);
			if (factory is null) {
				continue;
			}

			if (factory.busy) {
				continue;
			}

			if (!factory.obj.canBuildOrbitals) {
				continue;
			}

			// TODO: Should this be military money?
			BuildOrbital@ buildPlan = construction.buildLocalOrbital(getOrbitalModule(ftlExtractorModuleID));

			@extractorBuild = construction.buildNow(buildPlan, factory);
			if (log) {
				ai.print("Creating FTL Extractor", base.region);
			}
			return;
		}
	}

	void tick(double time) override {
		// TODO
	}

	void turn() override {
		// Check the progress of building FTL Extractors once per budget cycle
		if (extractorBuild !is null) {
			if (extractorBuild.completed) {
				@extractorBuild = null;
			} else {
				if (!extractorBuild.started) {
					// assume it failed
					construction.cancel(extractorBuild);
					@extractorBuild = null;
				}
			}
		}
	}
}

AIComponent@ createImprovement() {
	return Improvement();
}
