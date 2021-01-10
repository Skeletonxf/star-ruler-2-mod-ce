import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.race.Race;

import empire_ai.weasel.Resources;
import empire_ai.weasel.Colonization;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Movement;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Budget;

import empire_ai.dragon.expansion.colonization;
import empire_ai.dragon.expansion.colony_data;

import resources;
import abilities;
import planet_levels;
from constructions import getConstructionType, ConstructionType;
from abilities import getAbilityID;
import oddity_navigation;

const double MAX_POP_BUILDTIME = 3.0 * 60.0;

class ColonizerMechanoidPlanet : ColonizationSource {
	Planet@ planet;

	ColonizerMechanoidPlanet(Planet@ planet) {
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
	double weight(AI& ai) {
		if(!valid(ai))
			return 0.0;
		if(planet.isColonizing)
			return 0.0;
		if(planet.population <= 1)
			return 0.0;
		if(!planet.canSafelyColonize)
			return 0.0;
		double w = 1.0;
		double pop = planet.population;
		double maxPop = planet.maxPopulation;
		// allow colonising from planets that are over their required pop
		// even if that is quite far from the max pop, but penalise harsly
		// for colonising whenever that will delevel the colonise source
		if(pop <= getPlanetLevelRequiredPop(planet, planet.resourceLevel)) {
			w *= 0.01 * (pop / maxPop);
		}
		return w;
	}
}

class PopulationRequest {
	ColonizerMechanoidPlanet@ source;
	double neededPopulation;

	PopulationRequest(ColonizerMechanoidPlanet@ source, double neededPopulation) {
		@this.source = source;
		this.neededPopulation = neededPopulation;
	}
}

class Mechanoid2 : Race, ColonizationAbility {
	IColonization@ colonization;
	Construction@ construction;
	Movement@ movement;
	Budget@ budget;
	Planets@ planets;

	const ResourceType@ unobtanium;
	const ResourceType@ crystals;
	int unobtaniumAbl = -1;

	/* const ResourceClass@ foodClass;
	const ResourceClass@ waterClass;
	const ResourceClass@ scalableClass; */
	const ConstructionType@ buildPop;

	int colonizeAbl = -1;

	/* array<Planet@> popRequests;
	array<Planet@> popSources;
	array<Planet@> popFactories; */

	// wrapper around potential source to implement the colonisation ability
	// interfaces, tracks our planets that are populated enough to colonise with
	array<ColonizationSource@> planetSources;
	uint planetIndex = 0;
	uint sourceIndex = 0;

	// population requests, this is not saved to file as we will repopulate it
	// quickly enough on reloading of a save and saving to a file would
	// introduce quite a bit of complexity with keeping the pointers valid on
	// reload
	array<PopulationRequest@> popRequests;

	void create() {
		@colonization = cast<IColonization>(ai.colonization);
		@construction = cast<Construction>(ai.construction);
		@movement = cast<Movement>(ai.movement);
		@planets = cast<Planets>(ai.planets);
		@budget = cast<Budget>(ai.budget);

		@ai.defs.Shipyard = null;

		@crystals = getResource("FTL");
		@unobtanium = getResource("Unobtanium");
		unobtaniumAbl = getAbilityID("UnobtaniumMorph");

		/* @foodClass = getResourceClass("Food");
		@waterClass = getResourceClass("WaterType");
		@scalableClass = getResourceClass("Scalable"); */

		colonizeAbl = getAbilityID("MechanoidColonize");
		colonization.PerformColonization = false;

		@buildPop = getConstructionType("MechanoidPopulation");
	}

	void start() {
		/* //Oh yes please can we have some ftl crystals sir
		if(crystals !is null) {
			ResourceSpec spec;
			spec.type = RST_Specific;
			@spec.resource = crystals;
			spec.isLevelRequirement = false;
			spec.isForImport = false;

			colonization.queueColonizeLowPriority(spec);
		} */
	}

	double transferCost(double dist) {
		return 20 + dist * 0.002;
	}

	bool canBuildPopulation(Planet& pl, double factor=1.0) {
		if(buildPop is null)
			return false;
		if(!buildPop.canBuild(pl, ignoreCost=true))
			return false;
		auto@ primFact = construction.primaryFactory;
		if(primFact !is null && pl is primFact.obj)
			return true;

		double laborCost = buildPop.getLaborCost(pl);
		double laborIncome = pl.laborIncome;
		return laborCost < laborIncome * MAX_POP_BUILDTIME * factor;
	}

	void removeInvalidSources() {
		uint sourceCount = planetSources.length;
		for (uint i = 0; i < sourceCount; ++i) {
			if (!planetSources[i].valid(ai)) {
				planetSources.removeAt(i);
				--i; --sourceCount;
			}
		}
	}

	void checkForSources() {
		uint planetCount = planets.planets.length;
		uint sourceCount = planetSources.length;
		planetIndex = (planetIndex + 1) % planetCount;
		auto@ plAI = planets.planets[planetIndex];
		for (uint i = 0; i < sourceCount; ++i) {
			 auto@ source = cast<ColonizerMechanoidPlanet>(planetSources[i]);
			 if (source.planet is plAI.obj) {
				 // we have this one already
				 return;
			 }
		}
		planetSources.insertLast(ColonizerMechanoidPlanet(plAI.obj));
	}

	void checkSources() {
		uint sourceCount = planetSources.length;
		sourceIndex = (sourceIndex + 1) % sourceCount;
		auto@ source = cast<ColonizerMechanoidPlanet>(planetSources[sourceIndex]);

		// Make pop requests when we are not meeting our resource level
		double pop = source.planet.population;
		double needPop = getPlanetLevelRequiredPop(source.planet, source.planet.resourceLevel);
		if (pop < needPop) {
			popRequests.insertLast(PopulationRequest(source, needPop - pop));
		}
	}

	void meetPopRequests(PopulationRequest@ request) {
		ColonizerMechanoidPlanet@ source;
		while (request.neededPopulation > 1) {
			auto@ source = cast<ColonizerMechanoidPlanet>(getFastestSource(request.source.planet));
			if (source is null) {
				return;
			}
			// TODO: source should transfer as much pop as able to request
			// TODO: decrement needPop by the same amount
			// TODO: keep looping till meet request or run out of pop/FTL
		}
	}

	void focusTick(double time) override {
		removeInvalidSources();
		checkForSources();

		uint planetCount = planets.planets.length;
		uint checks = min(15, planetCount);
		for (uint i = 0; i < checks; ++i) {
			checkSources();
		}

		// try to meet requested population
		for (uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
			if (!popRequests[i].source.valid(ai)) {
				popRequests.removeAt(i);
				--i; --cnt;
			} else {
				meetPopRequests(popRequests[i]);
			}
		}

		/* //Check existing lists
		for(uint i = 0, cnt = popFactories.length; i < cnt; ++i) {
			auto@ obj = popFactories[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				popFactories.removeAt(i);
				--i; --cnt;
				continue;
			}
			if(!canBuildPopulation(popFactories[i])) {
				popFactories.removeAt(i);
				--i; --cnt;
				continue;
			}
		}

		for(uint i = 0, cnt = popSources.length; i < cnt; ++i) {
			auto@ obj = popSources[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				popSources.removeAt(i);
				--i; --cnt;
				continue;
			}
			if(!canSendPopulation(popSources[i])) {
				popSources.removeAt(i);
				--i; --cnt;
				continue;
			}
		}

		for(uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
			auto@ obj = popRequests[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				popRequests.removeAt(i);
				--i; --cnt;
				continue;
			}
			if(!requiresPopulation(popRequests[i])) {
				popRequests.removeAt(i);
				--i; --cnt;
				continue;
			}
		}

		//Find new planets to add to our lists
		bool checkMorph = false;
		Planet@ hw = ai.empire.Homeworld;
		if(hw !is null && hw.valid && hw.owner is ai.empire && unobtanium !is null) {
			if(hw.primaryResourceType == unobtanium.id)
				checkMorph = true;
		}

		uint plCnt = planets.planets.length;
		for(uint n = 0, cnt = min(15, plCnt); n < cnt; ++n) {
			chkInd = (chkInd+1) % plCnt;
			auto@ plAI = planets.planets[chkInd];

			//Find planets that can build population reliably
			if(canBuildPopulation(plAI.obj)) {
				if(popFactories.find(plAI.obj) == -1)
					popFactories.insertLast(plAI.obj);
			}

			//Find planets that need population
			if(requiresPopulation(plAI.obj)) {
				if(popRequests.find(plAI.obj) == -1)
					popRequests.insertLast(plAI.obj);
			}

			//Find planets that have extra population
			if(canSendPopulation(plAI.obj)) {
				if(popSources.find(plAI.obj) == -1)
					popSources.insertLast(plAI.obj);
			}

			if(plAI.resources !is null && plAI.resources.length != 0) {
				auto@ res = plAI.resources[0];

				//Get rid of food and water we don't need
				if(res.resource.cls is foodClass || res.resource.cls is waterClass) {
					if(res.request is null) {
						Region@ reg = res.obj.region;
						if(reg !is null && reg.getPlanetCount(ai.empire) >= 2) {
							plAI.obj.abandon();
						}
					}
				}

				//See if we have anything useful to morph our homeworld too
				if(checkMorph) {
					bool morph = false;
					if(res.resource is crystals)
						morph = true;
					else if(res.resource.level >= 2 && res.resource.tilePressure[TR_Labor] >= 5)
						morph = true;
					else if(res.resource.level >= 3 && res.resource.totalPressure > 10)
						morph = true;
					else if(res.resource.cls is scalableClass && gameTime > 30.0 * 60.0)
						morph = true;
					else if(res.resource.level >= 2 && res.resource.totalPressure >= 5 && gameTime > 60.0 * 60.0)
						morph = true;

					if(morph) {
						if(log)
							ai.print("Morph homeworld to "+res.resource.name+" from "+res.obj.name, hw);
						hw.activateAbilityTypeFor(ai.empire, unobtaniumAbl, plAI.obj);
					}
				}
			}
		}

		//See if we can find something to send population to
		availSources = popSources;

		for(uint i = 0, cnt = popRequests.length; i < cnt; ++i) {
			Planet@ dest = popRequests[i];
			if(canBuildPopulation(dest, factor=(availSources.length == 0 ? 2.5 : 1.5))) {
				Factory@ f = construction.get(dest);
				if(f !is null) {
					if(f.active is null) {
						auto@ build = construction.buildConstruction(buildPop);
						construction.buildNow(build, f);
						if(log)
							ai.print("Build population", f.obj);
						continue;
					}
					else {
						auto@ cons = cast<BuildConstruction>(f.active);
						if(cons !is null && cons.consType is buildPop) {
							if(double(dest.maxPopulation) <= dest.population + 0.0)
								continue;
						}
					}
				}
			}
			transferBest(dest, availSources);
		}

		if(availSources.length != 0) {
			//If we have any population left, do stuff from our colonization queue
			 // [[ MODIFY BASE GAME START ]]
			for(uint i = 0, cnt = colonization.AwaitingSource.length; i < cnt && availSources.length != 0; ++i) {
				Planet@ dest = colonization.AwaitingSource[i].target;
				Planet@ source = transferBest(dest, availSources);
				if(source !is null) {
					@colonization.AwaitingSource[i].colonizeFrom = source;
					colonization.AwaitingSource.removeAt(i);
					--i; --cnt;
				}
			}
			 // [[ MODIFY BASE END ]]
		}

		//Build population on idle planets
		if(budget.canSpend(BT_Development, 100)) {
			for(int i = popFactories.length-1; i >= 0; --i) {
				Planet@ dest = popFactories[i];
				Factory@ f = construction.get(dest);
				if(f is null || f.active !is null)
					continue;
				if(dest.population >= double(dest.maxPopulation) + 1.0)
					continue;

				auto@ build = construction.buildConstruction(buildPop);
				construction.buildNow(build, f);
				if(log)
					ai.print("Build population for idle", f.obj);
				break;
			}
		} */
	}

	Planet@ transferBest(Planet& dest, array<Planet@>& availSources) {
		//Find closest source
		Planet@ bestSource;
		double bestDist = INFINITY;
		for(uint j = 0, jcnt = availSources.length; j < jcnt; ++j) {
			double d = movement.getPathDistance(availSources[j].position, dest.position);
			if(d < bestDist) {
				bestDist = d;
				@bestSource = availSources[j];
			}
		}

		if(bestSource !is null) {
			double cost = transferCost(bestDist);
			if(cost <= ai.empire.FTLStored) {
				if(log)
					ai.print("Transfering population to "+dest.name, bestSource);
				availSources.remove(bestSource);
				bestSource.activateAbilityTypeFor(ai.empire, colonizeAbl, dest);
				return bestSource;
			}
		}
		return null;
	}

	void tick(double time) override {
	}

	array<ColonizationSource@> getSources() {
		return planetSources;
	}

	ColonizationSource@ getClosestSource(vec3d position) {
		// TODO
		return null;
	}

	ColonizationSource@ getFastestSource(Planet@ colony) {
		// TODO
		return null;
	}

	void colonizeTick() {
		// Don't need to do anything here
	}

	void orderColonization(ColonizeData& data, ColonizationSource@ source) {
		// TODO
	}

	void saveSource(SaveFile& file, ColonizationSource@ source) {
		if (source !is null) {
			file.write1();
			auto@ source = cast<ColonizerMechanoidPlanet>(source);
			file << source.planet;
		} else {
			file.write0();
		}
	}

	ColonizationSource@ loadSource(SaveFile& file) {
		if (file.readBit()) {
			Planet@ planet;
			file >> planet;
			return ColonizerMechanoidPlanet(planet);
		}
		return null;
	}

	// We save our state in our save and load methods
	void saveManager(SaveFile& file) {}
	void loadManager(SaveFile& file) {}
};

AIComponent@ createMechanoid2() {
	return Mechanoid2();
}
