// A revamped Military component that decouples designing fleets from
// building them, so build now actually means start building now.
// Does not deal with actually using the fleets to fight, that is the purview
// of the War component.

import empire_ai.weasel.WeaselAI;

import empire_ai.weasel.Military;
import empire_ai.weasel.Designs;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Fleets;
import empire_ai.weasel.Development;
import empire_ai.weasel.Movement;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Orbitals;

import resources;

// FIXME: Avoid hack'n'slashing the Support Order and Staging Base classes
// from the Military component, instead, make them have a proper Interface
// to expose to outside modules like the Military component itself now does.

// TODO: Actually rewrite, rather than just copy and paste

class SupportOrder2 : SupportOrder {
	/* DesignTarget@ design;
	Object@ onObject;
	AllocateBudget@ alloc;
	bool isGhostOrder = false;
	double expires = INFINITY;
	uint count = 0; */

	void save(Military2& military, SaveFile& file) {
		military.designs.saveDesign(file, design);
		file << onObject;
		military.budget.saveAlloc(file, alloc);
		file << isGhostOrder;
		file << expires;
		file << count;
	}

	void load(Military2& military, SaveFile& file) {
		@design = military.designs.loadDesign(file);
		file >> onObject;
		@alloc = military.budget.loadAlloc(file);
		file >> isGhostOrder;
		file >> expires;
		file >> count;
	}

	bool tick(AI& ai, Military2& military, double time) {
		if(alloc !is null) {
			if(alloc.allocated) {
				if(isGhostOrder)
					onObject.rebuildAllGhosts();
				else
					onObject.orderSupports(design.active.mostUpdated(), count);
				if(military.log && design !is null)
					ai.print("Support order completed for "+count+"x "+design.active.name+" ("+design.active.size+")", onObject);
				return false;
			}
		}
		else if(design !is null) {
			if(design.active !is null)
				@alloc = military.budget.allocate(BT_Military, getBuildCost(design.active.mostUpdated()) * count);
		}
		if(expires < gameTime) {
			if(alloc !is null && !alloc.allocated)
				military.budget.remove(alloc);
			if(isGhostOrder)
				onObject.clearAllGhosts();
			if(military.log)
				ai.print("Support order expired", onObject);
			return false;
		}
		return true;
	}
};

class StagingBase2 : StagingBase {
	/* Region@ region;
	array<FleetAI@> fleets;

	double idleTime = 0.0;
	double occupiedTime = 0.0;

	OrbitalAI@ shipyard;
	BuildOrbital@ shipyardBuild;
	Factory@ factory;

	bool isUnderAttack = false; */

	void save(Military2& military, SaveFile& file) {
		file << region;
		file << idleTime;
		file << occupiedTime;
		file << isUnderAttack;

		military.orbitals.saveAI(file, shipyard);
		military.construction.saveConstruction(file, shipyardBuild);

		uint cnt = fleets.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			military.fleets.saveAI(file, fleets[i]);
	}

	void load(Military2& military, SaveFile& file) {
		file >> region;
		file >> idleTime;
		file >> occupiedTime;
		file >> isUnderAttack;

		@shipyard = military.orbitals.loadAI(file);
		@shipyardBuild = cast<BuildOrbital>(military.construction.loadConstruction(file));

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			if(i > 200 && file < SV_0158) {
				//Something went preeeetty wrong in an old save
				if(file.readBit()) {
					Object@ obj;
					file >> obj;
				}
			}
			else {
				auto@ fleet = military.fleets.loadAI(file);
				if(fleet !is null)
					fleets.insertLast(fleet);
			}
		}
	}

	bool tick(AI& ai, Military2& military, double time) {
		if(fleets.length == 0) {
			occupiedTime = 0.0;
			idleTime += time;
		}
		else {
			occupiedTime += time;
			idleTime = 0.0;
		}

		isUnderAttack = region.ContestedMask & ai.mask != 0;

		//Manage building our shipyard
		if(shipyardBuild !is null) {
			if(shipyardBuild.completed) {
				@shipyard = military.orbitals.getInSystem(ai.defs.Shipyard, region);
				if(shipyard !is null)
					@shipyardBuild = null;
			}
		}
		if(shipyard !is null) {
			if(!shipyard.obj.valid) {
				@shipyard = null;
				@shipyardBuild = null;
			}
		}

		if(factory !is null && (!factory.valid || factory.obj.region !is region))
			@factory = null;
		if(factory is null)
			@factory = military.construction.getFactory(region);

		if(factory !is null) {
			factory.needsSupportLabor = false;
			factory.waitingSupportLabor = 0.0;
			if(factory.obj.hasOrderedSupports) {
				factory.needsSupportLabor = true;
				factory.waitingSupportLabor += double(factory.obj.SupplyOrdered) * ai.behavior.estSizeSupportLabor;
			}
			for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
				if(fleets[i].isHome && fleets[i].obj.hasOrderedSupports) {
					factory.needsSupportLabor = true;
					factory.waitingSupportLabor += double(fleets[i].obj.SupplyOrdered) * ai.behavior.estSizeSupportLabor;
					break;
				}
			}
			if(factory.waitingSupportLabor > 0)
				factory.aimForLabor(factory.waitingSupportLabor / ai.behavior.constructionMaxTime);
		}

		bool isFactorySufficient = false;
		if(factory !is null) {
			if(factory.waitingSupportLabor <= factory.laborIncome * ai.behavior.constructionMaxTime
					|| factory.obj.canImportLabor || factory !is military.construction.primaryFactory)
				isFactorySufficient = true;
		}

		for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
			Object@ obj = fleets[i].obj;
			if(obj is null || !obj.valid) {
				fleets.removeAt(i);
				--i; --cnt;
				continue;
			}
			fleets[i].stationedFactory = isFactorySufficient;
		}

		if(occupiedTime >= 3.0 * 60.0 && ai.defs.Shipyard !is null && shipyard is null && shipyardBuild is null
				&& !isUnderAttack && (!isFactorySufficient && factory !is military.construction.primaryFactory)) {
			//If any fleets need construction try to queue up a shipyard
			bool needYard = false;
			for(uint i = 0, cnt = fleets.length; i < cnt; ++i) {
				auto@ flt = fleets[i];
				if(flt.obj.hasOrderedSupports || flt.filled < 0.8) {
					needYard = true;
					break;
				}
			}

			if(needYard) {
				@shipyard = military.orbitals.getInSystem(ai.defs.Shipyard, region);
				if(shipyard is null) {
					vec3d pos = region.position;
					vec2d offset = random2d(region.radius * 0.4, region.radius * 0.8);
					pos.x += offset.x;
					pos.z += offset.y;

					@shipyardBuild = military.construction.buildOrbital(ai.defs.Shipyard, pos);
				}
			}
		}

		if((idleTime >= 10.0 * 60.0 || region.PlanetsMask & ai.mask == 0) && (shipyardBuild is null || shipyard !is null) && (factory is null || (shipyard !is null && factory.obj is shipyard.obj)) && military.stagingBases.length >= 2) {
			if(shipyard !is null) {
				cast<Orbital>(shipyard.obj).scuttle();
			}
			else {
				if(factory !is null) {
					factory.needsSupportLabor = false;
					@factory = null;
				}
				return false;
			}
		}
		return true;
	}
};

class Military2 : AIComponent, IMilitary {
	Fleets@ fleets;
	Development@ development;
	Designs@ designs;
	Construction@ construction;
	Budget@ budget;
	Systems@ systems;
	Orbitals@ orbitals;

	array<SupportOrder2@> supportOrders;
	array<StagingBase@> stagingBases;

	bool spentMoney = true;

	array<AllocateConstruction@> constructionsInProgress;
	array<DesignTarget@> flagshipDesigns;
	double lastDesignedFlagship = 0;

	void create() {
		@fleets = cast<Fleets>(ai.fleets);
		@development = cast<Development>(ai.development);
		@designs = cast<Designs>(ai.designs);
		@construction = cast<Construction>(ai.construction);
		@budget = cast<Budget>(ai.budget);
		@systems = cast<Systems>(ai.systems);
		@orbitals = cast<Orbitals>(ai.orbitals);
	}

	void save(SaveFile& file) {
		uint cnt = supportOrders.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			supportOrders[i].save(this, file);

		cnt = constructionsInProgress.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			construction.saveConstruction(file, constructionsInProgress[i]);
		file << spentMoney;

		cnt = stagingBases.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			saveStaging(file, cast<StagingBase2>(stagingBases[i]));
			cast<StagingBase2>(stagingBases[i]).save(this, file);
		}

		file << lastDesignedFlagship;

		cnt = flagshipDesigns.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			designs.saveDesign(file, flagshipDesigns[i]);
		}
	}

	void load(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			SupportOrder2 ord;
			ord.load(this, file);
			if(ord.onObject !is null)
				supportOrders.insertLast(ord);
		}

		file >> cnt;
		constructionsInProgress.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			@constructionsInProgress[i] = construction.loadConstruction(file);
		file >> spentMoney;

		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			StagingBase2@ base = loadStaging(file);
			if(base !is null) {
				base.load(this, file);
				if(stagingBases.find(base) == -1)
					stagingBases.insertLast(base);
			}
			else {
				StagingBase2().load(this, file);
			}
		}

		file >> lastDesignedFlagship;

		file >> cnt;
		flagshipDesigns.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			@flagshipDesigns[i] = designs.loadDesign(file);
		}
	}

	void loadFinalize(AI& ai) override {
		for(uint i = 0, cnt = stagingBases.length; i < cnt; ++i) {
			auto@ base = stagingBases[i];
			for(uint n = 0, ncnt = base.fleets.length; n < ncnt; ++n) {
				Object@ obj = base.fleets[n].obj;
				if(obj is null || !obj.valid || !obj.initialized) {
					base.fleets.removeAt(n);
					--n; --ncnt;
				}
			}
		}
	}

	StagingBase2@ loadStaging(SaveFile& file) {
		Region@ reg;
		file >> reg;

		if(reg is null)
			return null;

		StagingBase2@ base = cast<StagingBase2>(getBase(reg));
		if(base is null) {
			@base = StagingBase2();
			@base.region = reg;
			stagingBases.insertLast(base);
		}
		return base;
	}

	void saveStaging(SaveFile& file, StagingBase2@ base) {
		Region@ reg;
		if(base !is null)
			@reg = base.region;
		file << reg;
	}

	Region@ getClosestStaging(Region& targetRegion) {
		//Check if we have anything close enough
		StagingBase@ best;
		int minHops = INT_MAX;
		for(uint i = 0, cnt = stagingBases.length; i < cnt; ++i) {
			int d = systems.hopDistance(stagingBases[i].region, targetRegion);
			if(d < minHops) {
				minHops = d;
				@best = stagingBases[i];
			}
		}
		if(best !is null)
			return best.region;
		return null;
	}

	Region@ getStagingFor(Region& targetRegion) {
		//Check if we have anything close enough
		StagingBase@ best;
		int minHops = INT_MAX;
		for(uint i = 0, cnt = stagingBases.length; i < cnt; ++i) {
			int d = systems.hopDistance(stagingBases[i].region, targetRegion);
			if(d < minHops) {
				minHops = d;
				@best = stagingBases[i];
			}
		}
		if(minHops < ai.behavior.stagingMaxHops)
			return best.region;

		//Create a new staging base for this
		Region@ bestNew;
		minHops = INT_MAX;
		for(uint i = 0, cnt = systems.border.length; i < cnt; ++i) {
			auto@ sys = systems.border[i].obj;
			int d = systems.hopDistance(sys, targetRegion);
			if(d < minHops) {
				minHops = d;
				@bestNew = sys;
			}
		}

		if(minHops > ai.behavior.stagingMaxHops && best !is null)
			return best.region;

		auto@ base = getBase(bestNew);
		if(base !is null)
			return base.region;
		else
			return createStaging(bestNew).region;
	}

	StagingBase@ createStaging(Region@ region) {
		if(region is null)
			return null;

		if(log)
			ai.print("Create new staging base.", region);

		StagingBase2 newBase;
		@newBase.region = region;

		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			if(fleets.fleets[i].stationed is region)
				newBase.fleets.insertLast(fleets.fleets[i]);
		}

		stagingBases.insertLast(newBase);
		return newBase;
	}

	StagingBase@ getBase(Region@ inRegion) {
		if(inRegion is null)
			return null;
		for(uint i = 0, cnt = stagingBases.length; i < cnt; ++i) {
			if(stagingBases[i].region is inRegion)
				return stagingBases[i];
		}
		return null;
	}

	vec3d getStationPosition(Region& inRegion, double distance = 100.0) {
		auto@ base = getBase(inRegion);
		if(base !is null) {
			if(base.shipyard !is null) {
				vec3d pos = base.shipyard.obj.position;
				vec2d offset = random2d(distance * 0.5, distance * 1.5);
				pos.x += offset.x;
				pos.z += offset.y;

				return pos;
			}
		}

		vec3d pos = inRegion.position;
		vec2d offset = random2d(inRegion.radius * 0.4, inRegion.radius * 0.8);
		pos.x += offset.x;
		pos.z += offset.y;
		return pos;
	}

	void stationFleet(FleetAI@ fleet, Region@ inRegion) {
		if(inRegion is null || fleet.stationed is inRegion)
			return;

		auto@ prevBase = getBase(fleet.stationed);
		if(prevBase !is null)
			prevBase.fleets.remove(fleet);

		auto@ base = getBase(inRegion);
		if(base !is null)
			base.fleets.insertLast(fleet);

		@fleet.stationed = inRegion;
		fleet.stationedFactory = construction.getFactory(inRegion) !is null;
		if(fleet.mission is null)
			fleets.returnToBase(fleet);
	}

	void orderSupportsOn(Object& obj, double expire = 60.0) {
		if(obj.SupplyGhost > 0) {
			if(ai.behavior.fleetsRebuildGhosts) {
				//Try to rebuild the fleet's ghosts
				SupportOrder2 ord;
				@ord.onObject = obj;
				@ord.alloc = budget.allocate(BT_Military, obj.rebuildGhostsCost());
				ord.expires = gameTime + expire;
				ord.isGhostOrder = true;

				supportOrders.insertLast(ord);

				if(log)
					ai.print("Attempting to rebuild ghosts", obj);
				return;
			}
			else {
				obj.clearAllGhosts();
			}
		}

		int supCap = obj.SupplyCapacity;
		int supHave = obj.SupplyUsed - obj.SupplyGhost;

		//Build some supports
		int supSize = pow(2, round(::log(double(supCap) * randomd(0.005, 0.03))/::log(2.0)));
		supSize = max(min(supSize, supCap - supHave), 1);

		SupportOrder2 ord;
		@ord.onObject = obj;
		@ord.design = designs.design(DP_Support, supSize);
		ord.expires = gameTime + expire;
		ord.count = clamp((supCap - supHave)/supSize, 1, int(ceil((randomd(0.01, 0.1)*supCap)/double(supSize))));

		if(log)
			ai.print("Attempting to build supports: "+ord.count+"x size "+supSize, obj);

		supportOrders.insertLast(ord);
	}

	void retrofitFleets() {
		//See if we should retrofit anything
		if(!spentMoney && gameTime > ai.behavior.flagshipBuildMinGameTime) {
			int availMoney = budget.spendable(BT_Military);
			int moneyTargetSize = floor(double(availMoney) * ai.behavior.shipSizePerMoney);

			//See if one of our fleets is old enough that we can retrofit it
			for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
				FleetAI@ fleet = fleets.fleets[i];
				if(fleet.mission !is null && fleet.mission.isActive)
					continue;
				if(fleet.fleetClass != FC_Combat)
					continue;
				if(fleet.obj.hasOrders)
					continue;

				Ship@ ship = cast<Ship>(fleet.obj);
				if(ship is null)
					continue;

				//Don't retrofit free fleets
				if(ship.isFree && !ai.behavior.retrofitFreeFleets)
					continue;

				//Find the factory assigned to this
				Factory@ factory;
				if(fleet.isHome) {
					Region@ reg = fleet.obj.region;
					@factory = construction.getFactory(reg);
				}
				if(factory is null)
					continue;
				if(factory.busy)
					continue;

				//Find how large we can make this flagship
				const Design@ dsg = ship.blueprint.design;
				int targetSize = min(int(moneyTargetSize * 1.2), int(factory.laborToBear(ai) * 1.3 * ai.behavior.shipSizePerLabor));
				targetSize = 5 * floor(double(targetSize) / 5.0);

				//See if we should retrofit this
				int size = ship.blueprint.design.size;
				if(size > targetSize)
					continue;

				double pctDiff = (double(targetSize) / double(size)) - 1.0;
				if(pctDiff < ai.behavior.shipRetrofitThreshold)
					continue;

				DesignTarget@ newDesign = designs.scale(dsg, targetSize);
				spentMoney = true;

				auto@ retrofit = construction.retrofit(ship);
				construction.buildNow(retrofit, factory);

				if(log)
					ai.print("Retrofitting to size "+targetSize, fleet.obj);

				//TODO: This should mark the fleet as occupied for missions while we retrofit

				return;
			}
		}
	}

	void refillFleets() {
		//See if any of our fleets need refilling
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			FleetAI@ fleet = fleets.fleets[i];
			if(fleet.mission !is null && fleet.mission.isActive)
				continue;
			if(fleet.fleetClass != FC_Combat)
				continue;
			if(fleet.obj.hasOrders)
				continue;
			if(fleet.filled >= 1.0)
				continue;
			if(hasSupportOrderFor(fleet.obj))
				continue;
			if(!fleet.isHome)
				continue;

			//Re-station to our factory if we're idle and need refill without being near a factory
			Factory@ f = construction.getFactory(fleet.obj.region);
			if(f is null) {
				if(fleet.filled < ai.behavior.stagingToFactoryFill && construction.primaryFactory !is null)
					stationFleet(fleet, construction.primaryFactory.obj.region);
				continue;
			}

			//Don't order if the factory has support orders, it'll just make everything take longer
			if(f !is null && ai.behavior.supportOrderWaitOnFactory && fleet.filled < 0.9 && fleet.obj.SupplyGhost == 0) {
				if(f.obj.hasOrderedSupports && f.obj.SupplyUsed < f.obj.SupplyCapacity)
					continue;
			}

			int supCap = fleet.obj.SupplyCapacity;
			int supHave = fleet.obj.SupplyUsed - fleet.obj.SupplyGhost;
			if(supHave < supCap) {
				orderSupportsOn(fleet.obj);
				spentMoney = true;
				return;
			}
		}
	}

	bool hasSupportOrderFor(Object& obj) {
		for(uint i = 0, cnt = supportOrders.length; i < cnt; ++i) {
			if(supportOrders[i].onObject is obj)
				return true;
		}
		return false;
	}

	void tick(double time) override {
		//Manage our orders for support ships
		for(uint i = 0, cnt = supportOrders.length; i < cnt; ++i) {
			if(!supportOrders[i].tick(ai, this, time)) {
				supportOrders.removeAt(i);
				--i; --cnt;
			}
		}
	}

	/**
	 * Allow building and designing ships that take a while if we already
	 * have many fleets, likewise, if we're down to 0 fleets, we need a
	 * new flagship ASAP.
	 */
	double flagshipBuildTimeFactor(Factory@ factory) {
		return factory.laborIncome * (4 + fleets.fleets.length) * 60.0;
	}

	void designNewFlagship() {
		if (construction.primaryFactory is null) {
			return;
		}
		// available labor to build flagships and the available cost of
		// building at that size may vary quite a bit, so randomise the
		// target size around the available labor to ensure if we have
		// more labor than eco we still design things we can build
		double targetSize = (0.7 + (0.4 * randomd())) * ai.behavior.shipSizePerLabor * flagshipBuildTimeFactor(construction.primaryFactory);
		// tiny ships just give remnants xp
		if (targetSize < 250) {
			targetSize = 250;
		}
		DesignTarget@ newFlashipDesign = designs.design(
				DP_Combat,
				targetSize,
				availableMoneyForNewFlagship(),
				availableMaintenanceForNewFlagship(),
				// aim for 6 minutes of labor
				flagshipBuildTimeFactor(construction.primaryFactory),
				findSize=true);
		flagshipDesigns.insertLast(newFlashipDesign);
		ai.print("Designing flaship of target size "+targetSize);
		lastDesignedFlagship = gameTime;

		// Cull old designs
		if (flagshipDesigns.length > 12) {
			flagshipDesigns.removeAt(0);
		}
	}

	// TODO: Count maintenace of fleets being built as well
	double availableMoneyForNewFlagship() {
		double existing = 0.0;
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if (flAI.obj is null) {
				continue;
			}
			Ship@ ship = cast<Ship>(flAI.obj);
			if (ship is null) {
				continue;
			}
			existing += ship.blueprint.design.total(HV_MaintainCost);
		}
		return budget.spendable(BT_Military) - existing;
	}

	// TODO: Count maintenace of fleets being built as well
	double availableMaintenanceForNewFlagship() {
		// try to reserve half a million for buying supports
		double existing = 500.0;
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if (flAI.obj is null) {
				continue;
			}
			Ship@ ship = cast<Ship>(flAI.obj);
			if (ship is null) {
				continue;
			}
			existing += ship.blueprint.design.total(HV_MaintainCost);
		}
		// try to leave enough maintence left over for another ship
		return (budget.maintainable(BT_Military) - existing) * 0.5;
	}

	void focusTick(double time) override {
		if (flagshipDesigns.length == 0 || gameTime > lastDesignedFlagship + (4 * 60)) {
			designNewFlagship();
		}

		//TODO: Aim for labor on the factory so that the supports are built in reasonable time
		//TODO: Build defense stations

		retrofitFleets();
		refillFleets();

		//If we're far into the budget, spend our money on building supports at our factories
		if(budget.Progress > 0.9 && budget.canSpend(BT_Military, 10)) {
			for(uint i = 0, cnt = construction.factories.length; i < cnt; ++i) {
				//TODO: Build on planets in the system if this is full
				auto@ f = construction.factories[i];
				if(f.obj.SupplyUsed < f.obj.SupplyCapacity && !hasSupportOrderFor(f.obj)) {
					orderSupportsOn(f.obj, expire=budget.RemainingTime);
					break;
				}
			}
		}

		//Check if we should re-station any of our fleets
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if(flAI.stationed is null) {
				Region@ reg = flAI.obj.region;
				if(reg !is null && reg.PlanetsMask & ai.mask != 0)
					stationFleet(flAI, reg);
			}
		}

		//Make sure all our major factories are considered staging bases
		for(uint i = 0, cnt = construction.factories.length; i < cnt; ++i) {
			auto@ f = construction.factories[i];
			if(f.obj.isShip)
				continue;
			Region@ reg = f.obj.region;
			if(reg is null)
				continue;
			auto@ base = getBase(reg);
			if(base is null)
				createStaging(reg);
		}

		//If we don't have any staging bases, make one at a focus
		if(stagingBases.length == 0 && development.focuses.length != 0) {
			Region@ reg = development.focuses[0].obj.region;
			if(reg !is null)
				createStaging(reg);
		}

		//Update our staging bases
		for(uint i = 0, cnt = stagingBases.length; i < cnt; ++i) {
			StagingBase2@ base = cast<StagingBase2>(stagingBases[i]);
			if(!base.tick(ai, this, time)) {
				stagingBases.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void turn() override {
		//Fleet construction happens in the beginning of the turn, because we want
		//to use our entire military budget on it.
		for (uint i = 0, cnt = constructionsInProgress.length; i < cnt; ++i) {
			if (constructionsInProgress[i] is null || constructionsInProgress[i].completed) {
				constructionsInProgress.removeAt(i);
				// removing the i'th item from the array downshifts
				// all the others, so downshift i and cnt too
				--i; --cnt;
				continue;
			}
		}
		spentMoney = false;

		int availMoney = availableMoneyForNewFlagship();

		// make a new flagship if we have money
		// this might be a bit overkill in willingness to make new flagships
		// as the only stopping condition here is running out of money
		// it also might be better to allow parallel construction based
		// on how many factories we have instead of income
		bool makeNewFlagship = (availMoney > 500 || fleets.fleets.length == 0)
			&& fleets.fleets.length < ai.behavior.maxActiveFleets;

		int availableMaint = availableMaintenanceForNewFlagship();
		Factory@ factory = construction.primaryFactory;

		if (factory is null || factory.busy) {
			// find best non primary factory
			for(uint i = 0, cnt = construction.factories.length; i < cnt; ++i) {
				Factory@ f = construction.factories[i];
				if ((!f.busy && f.obj.canBuildShips)
						&& (factory is null
							|| (factory.busy && f.laborIncome > (0.7 * factory.laborIncome))
							|| f.laborIncome > factory.laborIncome)) {
					@factory = f;
				}
			}
		}

		budget.checkedMilitarySpending = true;
		if (factory is null) {
			spentMoney = false;
			return;
		}

		double factoryLabor = flagshipBuildTimeFactor(factory);

		// find the design to use
		const Design@ flagshipDesign;
		double weight = -1;
		for(uint i = 0, cnt = flagshipDesigns.length; i < cnt; ++i) {
			DesignTarget@ target = flagshipDesigns[i];
			if (target.active is null) {
				continue;
			}
			const Design@ possibleDesign = target.active;
			double labor = possibleDesign.total(HV_LaborCost);
			double build = possibleDesign.total(HV_BuildCost);
			double maint = possibleDesign.total(HV_MaintainCost);
			double w = 0;
			if (build > availMoney) {
				w = -1000;
			} else {
				// maximise w if we are building something that costs
				// all the allocated military spending money
				w += 2 * (build / availMoney);
			}
			if (maint > availableMaint) {
				w = -1000;
			} else {
				// everything else being equal, favor designs that
				// cost less to maintain
				w += 0.3 * (availableMaint / (maint + (availableMaint * 0.5)));
			}
			// try to match up labor cost with available labor, but
			// be willing to go over or under
			if (labor > factoryLabor) {
				w += factoryLabor / labor;
			} else {
				w += labor / factoryLabor;
			}

			if (w > weight) {
				@flagshipDesign = possibleDesign;
				weight = w;
			}
		}

		if (flagshipDesign !is null) {
			// Build immediately from the existing design
			factory.obj.buildFlagship(flagshipDesign);
			spentMoney = true;
			ai.print("Building flagship of size "+flagshipDesign.size+" at "+factory.obj.name+" for "+flagshipDesign.total(HV_BuildCost)+"k.");
			ai.print("Budget is "+availMoney+"k / "+availableMaint+"k.");
		} else {
			spentMoney = false;
		}
	}

	array<StagingBase@> get_StagingBases() {
		return stagingBases;
	}
}

AIComponent@ createMilitary2() {
	return Military2();
}
