import empire_ai.weasel.WeaselAI;
import empire_ai.weasel.Movement;
import empire_ai.weasel.Military;
import empire_ai.weasel.Construction;
import empire_ai.weasel.Designs;
import empire_ai.weasel.Development;
import empire_ai.weasel.Systems;
import empire_ai.weasel.Budget;
import empire_ai.weasel.Fleets;

/*
 * Holistic FTL AI that can use/understand all types of FTL rather than just one
 * TODO: Fling gates to target location instead of manual sublight travel
 * TODO: Aim for FTL income in same way as FTL storage
 * TODO: Avoid placing slipstreams/gates and fling beacons in the same systems
 * TODO: Use slipstreams to improve colonisation speed
 */

// Fling data
import ftl;
from orbitals import getOrbitalModuleID;

// Jumpdrive data
import system_flags;
import regions.regions;
import systems;

const double FLING_MIN_DISTANCE_STAGE = 10000;
const double FLING_MIN_DISTANCE_DEVELOP = 20000;
const double FLING_MIN_TIMER = 3.0 * 60.0;

int flingModule = -1;

// Gate data
from statuses import getStatusID;
from abilities import getAbilityID;

const double GATE_MIN_DISTANCE_STAGE = 10000;
const double GATE_MIN_DISTANCE_DEVELOP = 20000;
const double GATE_MIN_DISTANCE_BORDER = 30000;
const double GATE_MIN_TIMER = 3.0 * 60.0;
const int GATE_BUILD_MOVE_HOPS = 5;

int packAbility = -1;
int unpackAbility = -1;
int packedStatus = -1;
int unpackedStatus = -1;

// Hyperdrive data
from orders import OrderType;

const double HYPERDRIVE_REJUMP_MIN_DIST = 8000.0; // TODO handle rejumps
const double HYPERDRIVE_STORAGE_AIM_DISTANCE = 40000;

// Slipstream data
from oddity_navigation import hasOddityLink;
const double SS_MIN_DISTANCE_STAGE = 0;
const double SS_MIN_DISTANCE_DEVELOP = 10000;
const double SS_MIN_TIMER = 3.0 * 60.0;
// max distance an existing slipstream can be to target, reduced from 3000
// from the Slipstream.as code
const double SS_MAX_DISTANCE = 1000.0;

// Cache system defs to check things are unlocked
const SubsystemDef@ hyperdriveSubsystem = getSubsystemDef("Hyperdrive");
const SubsystemDef@ jumpdriveSubsystem = getSubsystemDef("Jumpdrive");
const SubsystemDef@ gateSubsystem = getSubsystemDef("GateModule");
const SubsystemDef@ slipstreamSubsystem = getSubsystemDef("Slipstream");

void init() {
	// Fling data
	flingModule = getOrbitalModuleID("FlingCore");
	// Gate data
	packAbility = getAbilityID("GatePack");
	unpackAbility = getAbilityID("GateUnpack");
	packedStatus = getAbilityID("GatePacked");
	unpackedStatus = getAbilityID("GateUnpacked");
}

class FlingRegion : Savable {
	Region@ region;
	Object@ obj;
	bool installed = false;
	vec3d destination;

	void save(SaveFile& file) {
		file << region;
		file << obj;
		file << installed;
		file << destination;
	}

	void load(SaveFile& file) {
		file >> region;
		file >> obj;
		file >> installed;
		file >> destination;
	}
};

class GateRegion : Savable {
	Region@ region;
	Object@ gate;
	bool installed = false;
	vec3d destination;

	void save(SaveFile& file) {
		file << region;
		file << gate;
		file << installed;
		file << destination;
	}

	void load(SaveFile& file) {
		file >> region;
		file >> gate;
		file >> installed;
		file >> destination;
	}
};

class SSRegion : Savable {
	Region@ region;
	Object@ obj;
	bool arrived = false;
	vec3d destination;

	void save(SaveFile& file) {
		file << region;
		file << obj;
		file << arrived;
		file << destination;
	}

	void load(SaveFile& file) {
		file >> region;
		file >> obj;
		file >> arrived;
		file >> destination;
	}
};

// Travel types to consider in move orders
enum FTLTravelMethod {
	TRAVEL_SUBLIGHT = 1,
	TRAVEL_FLING = 2,
	TRAVEL_HYPERDRIVE = 3,
	TRAVEL_JUMPDRIVE = 4,
	TRAVEL_SLIPSTREAM = 5,
};

class FTLGeneric : FTL {
	Military@ military;
	Designs@ designs;
	Construction@ construction;
	Development@ development;
	Systems@ systems;
	Budget@ budget;
	Fleets@ fleets;

	// Fling data
	array<FlingRegion@> trackedFling;
	array<Object@> unusedFling;
	BuildOrbital@ buildFling;
	double nextBuildTryFling = 15.0 * 60.0;
	bool wantToBuildFling = false;

	// Gate data
	DesignTarget@ gateDesign;
	array<GateRegion@> trackedGate;
	array<Object@> unassignedGate;

	BuildStation@ buildGate;
	double nextBuildTryGate = 15.0 * 60.0;

	// Jumpdrive data
	int safetyFlag = -1;
	array<Region@> safeRegions;

	// Slipstream data
	DesignTarget@ ssDesign;
	array<SSRegion@> trackedSS;
	array<Object@> unassignedSS;
	BuildFlagship@ buildSS;
	double nextBuildTrySS = 15.0 * 60.0;

	// Tracking available FTL methods
	// Note: This is only relevant for building, not for using each of these
	// If we obtain additional FTL methods through non building means
	// we can still use them without having them 'unlocked'!
	bool hasHyperdrives = false;
	bool hasJumpdrives = false;
	bool hasGates = false;
	bool hasFling = false;
	bool hasSlipstreams = false;

	void create() override {
		@military = cast<Military>(ai.military);
		@designs = cast<Designs>(ai.designs);
		@construction = cast<Construction>(ai.construction);
		@development = cast<Development>(ai.development);
		@systems = cast<Systems>(ai.systems);
		@budget = cast<Budget>(ai.budget);
		@fleets = cast<Fleets>(ai.fleets);
		/* @movement = cast<Movement>(ai.movement); */
		safetyFlag = getSystemFlag("JumpdriveSafety");

		checkAvailableFTLMethods();
	}

	void save(SaveFile& file) override {
		{
			// Fling data
			construction.saveConstruction(file, buildFling);
			file << nextBuildTryFling;
			file << wantToBuildFling;

			uint cnt = trackedFling.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
			file << trackedFling[i];

			cnt = unusedFling.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
			file << unusedFling[i];
		}
		{
			// Gate data
			designs.saveDesign(file, gateDesign);
			construction.saveConstruction(file, buildGate);
			file << nextBuildTryGate;

			uint cnt = trackedGate.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
			file << trackedGate[i];

			cnt = unassignedGate.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
			file << unassignedGate[i];
		}
		{
			// Jumpdrive data
			uint cnt = safeRegions.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
				file << safeRegions[i];
		}
		{
			// Slipstream data
			designs.saveDesign(file, ssDesign);
			construction.saveConstruction(file, buildSS);
			file << nextBuildTrySS;

			uint cnt = trackedSS.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
				file << trackedSS[i];

			cnt = unassignedSS.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
				file << unassignedSS[i];
		}
	}

	void load(SaveFile& file) override {
		{
			// Fling data
			@buildFling = cast<BuildOrbital>(construction.loadConstruction(file));
			file >> nextBuildTryFling;
			file >> wantToBuildFling;

			uint cnt = 0;
			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				FlingRegion fr;
				file >> fr;
				trackedFling.insertLast(fr);
			}

			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				Object@ obj;
				file >> obj;
				if(obj !is null)
				unusedFling.insertLast(obj);
			}
		}
		{
			// Gate data
			@gateDesign = designs.loadDesign(file);
			@buildGate = cast<BuildStation>(construction.loadConstruction(file));
			file >> nextBuildTryGate;

			uint cnt = 0;
			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				GateRegion gt;
				file >> gt;
				trackedGate.insertLast(gt);
			}

			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				Object@ obj;
				file >> obj;
				if(obj !is null)
				unassignedGate.insertLast(obj);
			}
		}
		{
			// Jumpdrive data
			uint cnt = 0;
			file >> cnt;
			safeRegions.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				file >> safeRegions[i];
		}
		{
			// Slipstream data
			@ssDesign = designs.loadDesign(file);
			@buildSS = cast<BuildFlagship>(construction.loadConstruction(file));
			file >> nextBuildTrySS;

			uint cnt = 0;
			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				SSRegion gt;
				file >> gt;
				trackedSS.insertLast(gt);
			}

			file >> cnt;
			for(uint i = 0; i < cnt; ++i) {
				Object@ obj;
				file >> obj;
				if(obj !is null)
					unassignedSS.insertLast(obj);
			}
		}
	}

	// Fling methods
	FlingRegion@ getFling(Region@ reg) {
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			if(trackedFling[i].region is reg)
				return trackedFling[i];
		}
		return null;
	}

	void removeFling(FlingRegion@ gt) {
		if(gt.obj !is null && gt.obj.valid && gt.obj.owner is ai.empire)
			unusedFling.insertLast(gt.obj);
		trackedFling.remove(gt);
	}

	Object@ getClosestFling(const vec3d& position) {
		Object@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			Object@ obj = trackedFling[i].obj;
			if(obj is null)
				continue;
			double d = obj.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = obj;
			}
		}
		for(uint i = 0, cnt = unusedFling.length; i < cnt; ++i) {
			Object@ obj = unusedFling[i];
			if(obj is null)
				continue;
			double d = obj.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = obj;
			}
		}
		return closest;
	}

	FlingRegion@ getClosestFlingRegion(const vec3d& position) {
		FlingRegion@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			double d = trackedFling[i].region.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = trackedFling[i];
			}
		}
		return closest;
	}

	/**
	 * Gets the distance from any position to the closest fling region
	 * TODO: Consider wormholes/gates in distance estimates
	 */
	double getClosestFlingRegionDistance(const vec3d& position) {
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			double d = trackedFling[i].region.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
			}
		}
		return minDist;
	}

	void assignFlingTo(FlingRegion@ track, Object@ closest) {
		unusedFling.remove(closest);
		@track.obj = closest;
	}

	bool trackingBeacon(Object@ obj) {
		for(uint i = 0, cnt = unusedFling.length; i < cnt; ++i) {
			if(unusedFling[i] is obj)
				return true;
		}
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			if(trackedFling[i].obj is obj)
				return true;
		}
		return false;
	}

	bool shouldHaveFlingBeacon(Region@ reg, bool always = false) {
		if(military.getBase(reg) !is null)
			return true;
		if(development.isDevelopingIn(reg))
			return true;
		return false;
	}

	// Gate methods
	GateRegion@ getGate(Region@ reg) {
		for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
			if(trackedGate[i].region is reg)
				return trackedGate[i];
		}
		return null;
	}

	void removeGate(GateRegion@ gt) {
		if(gt.gate !is null && gt.gate.valid && gt.gate.owner is ai.empire)
			unassignedGate.insertLast(gt.gate);
		trackedGate.remove(gt);
	}

	Object@ getClosestGate(const vec3d& position) {
		Object@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
			Object@ gate = trackedGate[i].gate;
			if(gate is null)
				continue;
			if(!trackedGate[i].installed)
				continue;
			double d = gate.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = gate;
			}
		}
		return closest;
	}

	GateRegion@ getClosestGateRegion(const vec3d& position) {
		GateRegion@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
			double d = trackedGate[i].region.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = trackedGate[i];
			}
		}
		return closest;
	}

	void assignGateTo(GateRegion@ gt, Object@ closest) {
		unassignedGate.remove(closest);
		@gt.gate = closest;
		gt.installed = false;

		if(closest.region is gt.region) {
			if(closest.hasStatusEffect(unpackedStatus)) {
				gt.installed = true;
			}
		}

		if(!gt.installed) {
			gt.destination = military.getStationPosition(gt.region);
			closest.activateAbilityTypeFor(ai.empire, packAbility);
			closest.addMoveOrder(gt.destination);
		}
	}

	bool trackingGate(Object@ obj) {
		for(uint i = 0, cnt = unassignedGate.length; i < cnt; ++i) {
			if(unassignedGate[i] is obj)
				return true;
		}
		for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
			if(trackedGate[i].gate is obj)
				return true;
		}
		return false;
	}

	bool shouldHaveGate(Region@ reg, bool always = false) {
		if(military.getBase(reg) !is null)
			return true;
		if(development.isDevelopingIn(reg))
			return true;
		if(!always) {
			auto@ sys = systems.getAI(reg);
			if(sys !is null) {
				if(sys.border && sys.bordersEmpires)
					return true;
			}
		}
		return false;
	}

	void turn() override {
		// gate logic
		if(gateDesign !is null && gateDesign.active !is null) {
			int newSize = round(double(budget.spendable(BT_Military)) * 0.5 * ai.behavior.shipSizePerMoney / 64.0) * 64;
			if(newSize < 128)
				newSize = 128;
			if(newSize != gateDesign.targetSize) {
				@gateDesign = designs.design(DP_Gate, newSize);
				gateDesign.customName = "Gate";
			}
		}
		// slipstream logic
		if(ssDesign !is null && ssDesign.active !is null) {
			int newSize = round(double(budget.spendable(BT_Military)) * 0.2 * ai.behavior.shipSizePerMoney / 64.0) * 64;
			if(newSize < 128)
				newSize = 128;
			if(newSize != ssDesign.targetSize) {
				@ssDesign = designs.design(DP_Slipstream, newSize);
				ssDesign.customName = "Slipstream";
			}
		}
	}

	// Slipstream methods
	SSRegion@ getSS(Region@ reg) {
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			if(trackedSS[i].region is reg)
				return trackedSS[i];
		}
		return null;
	}

	void removeSS(SSRegion@ gt) {
		if(gt.obj !is null && gt.obj.valid && gt.obj.owner is ai.empire)
			unassignedSS.insertLast(gt.obj);
		trackedSS.remove(gt);
	}

	Object@ getClosestSS(const vec3d& position) {
		Object@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			Object@ obj = trackedSS[i].obj;
			if(obj is null)
				continue;
			if(!trackedSS[i].arrived)
				continue;
			double d = obj.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = obj;
			}
		}
		return closest;
	}

	SSRegion@ getClosestSSRegion(const vec3d& position) {
		SSRegion@ closest;
		double minDist = INFINITY;
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			double d = trackedSS[i].region.position.distanceTo(position);
			if(d < minDist) {
				minDist = d;
				@closest = trackedSS[i];
			}
		}
		return closest;
	}

	void assignSSTo(SSRegion@ gt, Object@ closest) {
		unassignedSS.remove(closest);
		@gt.obj = closest;
		gt.arrived = false;
		military.stationFleet(fleets.getAI(closest), gt.region);

		if(closest.region is gt.region)
			gt.arrived = true;

		if(!gt.arrived) {
			gt.destination = military.getStationPosition(gt.region);
			closest.addMoveOrder(gt.destination);
		}
	}

	bool trackingSSGen(Object@ obj) {
		for(uint i = 0, cnt = unassignedSS.length; i < cnt; ++i) {
			if(unassignedSS[i] is obj)
				return true;
		}
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			if(trackedSS[i].obj is obj)
				return true;
		}
		return false;
	}

	bool shouldHaveSSGen(Region@ reg, bool always = false) {
		if(military.getBase(reg) !is null)
			return true;
		if(development.isDevelopingIn(reg))
			return true;
		return false;
	}

	double getSSCost(Object@ ssGen, const vec3d& position) {
		return slipstreamCost(ssGen, 0, position.distanceTo(ssGen.position));
	}

	double getSSETA(Object@ ssGen, Object& obj, const vec3d& position) {
		return max(SLIPSTREAM_CHARGE_TIME, getSublightETA(obj, ssGen.position));
	}

	// Hyperengine methods
	double getHyperdriveETA(Object& obj, const vec3d& position) {
		double charge = HYPERDRIVE_CHARGE_TIME;
		if(obj.owner.HyperdriveNeedCharge == 0)
			charge = 0.0;
		double dist = position.distanceTo(obj.position);
		double speed = hyperdriveMaxSpeed(obj);
		return charge + dist / speed;
	}

	double getSublightETA(Object& obj, const vec3d& position) {
		double direct = newtonArrivalTime(obj.maxAcceleration, position - obj.position, vec3d());
		// estimate using pathing distance that includes wormholes/gates
		double pathDistance = cast<Movement>(ai.movement).getPathDistance(obj.position, position, obj.maxAcceleration);
		double pathEstimate = pathDistance * obj.maxAcceleration;
		// path estimate time doesn't consider acceleration properly
		// so only use it if it is substantially shorter than direct
		// (which implies there's a shortcut like a wormhole/gate)
		if ((pathEstimate * 1.4) < direct) {
			return pathEstimate;
		}
		return direct;
	}

	// Not a hyperdrive method but fits here best
	double getFlingETA(Object& obj, const vec3d& position) {
		double closestBeacon = getClosestFlingRegionDistance(obj.position);
		if (closestBeacon < FLING_BEACON_RANGE) {
			return 15;
		} else {
			return INFINITY;
		}
	}

	double getJumpdriveETA(Object& obj, const vec3d& fromPosition, const vec3d& toPosition) {
		double charge = JUMPDRIVE_CHARGE_TIME;
		double distance = fromPosition.distanceTo(toPosition);

		// work out if this jump is safe
		double maxRange = jumpdriveRange(obj);
		bool isSafe = false;
		Region@ reg = getRegion(toPosition);
		if (reg !is null) {
			isSafe = reg.getSystemFlag(ai.empire, safetyFlag);
		}

		if (distance > maxRange && !isSafe) {
			// jumping will damage the ship
			return INFINITY;
		}

		return charge;
	}

	uint sysChk = 0;
	void start() {
		for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
			Region@ reg = getSystem(i).object;
			if(reg.getSystemFlag(ai.empire, safetyFlag))
				safeRegions.insertLast(reg);
		}
	}

	/*
	 * Provide logic for when to use FTL instead of sublight
	 * TODO: Using FTL/sublight to reach fling beacon currently out of range
	 * TODO: Multi jump hyperdrive commands (check if multiple jumps is
	 * cheaper than one)
	 */
	uint order(MoveOrder& ord) override {
		// Note: We don't check if we have each FTL method unlocked here
		// as if we obtain FTL methods we don't have the ability to build
		// ourselves that doesn't stop us using them!

		// Find the position to travel to
		vec3d toPosition;
		if(!targetPosition(ord, toPosition))
			return F_Pass;

		bool ableToHyperdrive = canHyperdrive(ord.obj);
		bool ableToJumpdrive = canJumpdrive(ord.obj);
		bool ableToFling = canFling(ord.obj);
		bool ableToSS = true;
		//Check if we have a slipstream generator in this region
		auto@ ss = getSS(ord.obj.region);
		if (ss is null || ss.obj is null || !ss.arrived) {
			ableToSS = false;
		}
		Object@ ssGen = ableToSS ? ss.obj : null;
		if (ableToSS) {
			ableToSS = canSlipstream(ssGen);
		}

		if (!ableToFling && !ableToHyperdrive && !ableToJumpdrive && !ableToSS) {
			return F_Pass;
		}

		double hyperdriveETA = INFINITY;
		double hyperdriveFTLCost = INFINITY;
		double jumpdriveETA = INFINITY;
		double jumpdriveFTLCost = INFINITY;
		double flingETA = INFINITY;
		double flingFTLCost = INFINITY;
		double ssETA = INFINITY;
		double ssFTLCost = INFINITY;
		double sublightETA = INFINITY;
		double sublightFTLCost = 0;

		if (ableToHyperdrive) {
			hyperdriveETA = getHyperdriveETA(ord.obj, toPosition);
			hyperdriveFTLCost = hyperdriveCost(ord.obj, toPosition);
		}

		vec3d doubleHopPosition;
		bool makeDoubleHop = false;
		if (ableToJumpdrive) {
			jumpdriveETA = getJumpdriveETA(ord.obj, ord.obj.position, toPosition);
			jumpdriveFTLCost = jumpdriveCost(ord.obj, toPosition);
			// consider doing a hop to a safe region first
			// with the jumpdrive to reach the destination
			if (jumpdriveETA == INFINITY) {
				double bestHop = INFINITY;
				Region@ hopRegion;
				vec3d doubleHopPosition;
				for (uint i = 0, cnt = safeRegions.length; i < cnt; ++i) {
					if (!safeRegions[i].getSystemFlag(ai.empire, safetyFlag)) {
						continue;
					}
					vec3d hopPos = safeRegions[i].position;
					hopPos = hopPos + (ord.obj.position -  hopPos).normalized(safeRegions[i].radius * 0.85);
					double d = hopPos.distanceTo(toPosition);
					if (d < bestHop) {
						bestHop = d;
						@hopRegion = safeRegions[i];
						doubleHopPosition = hopPos;
					}
				}
				jumpdriveETA = JUMPDRIVE_CHARGE_TIME;
				jumpdriveETA += getJumpdriveETA(ord.obj, doubleHopPosition, toPosition);
				jumpdriveFTLCost = jumpdriveCost(ord.obj, ord.obj.position, doubleHopPosition);
				jumpdriveFTLCost += jumpdriveCost(ord.obj, doubleHopPosition, toPosition);
				makeDoubleHop = true;
			}
		}

		if (ableToFling) {
			flingETA = getFlingETA(ord.obj, toPosition);
			flingFTLCost = flingCost(ord.obj, toPosition);
		}

		if (ableToSS) {
			//Check if we already have a link
			if (hasOddityLink(ss.region, toPosition, SS_MAX_DISTANCE, minDuration=60.0)) {
				// we've already paid for this so set slipstream estimates
				// to infinity and let sublight 'win'
				ssETA = INFINITY;
				ssFTLCost = INFINITY;
			} else {
				ssETA = getSSETA(ssGen, ord.obj, toPosition);
				ssFTLCost = getSSCost(ssGen, toPosition);
			}
		}

		sublightETA = getSublightETA(ord.obj, toPosition);

		// Reserve some FTL if we're saving our FTL for a new beacon
		double availableFTL = usableFTL(ai, ord);
		if ((buildFling !is null && !buildFling.started) || wantToBuildFling) {
			availableFTL = min(availableFTL, ai.empire.FTLStored - 250.0);
		}

		// Allow using all of FTL storage for critical movements
		if (ord.priority == MP_Critical) {
			availableFTL = ai.empire.FTLStored;
		}

		// set eta to infinity if unable to afford cost
		if (hyperdriveFTLCost > availableFTL) {
			hyperdriveETA = INFINITY;
		}
		if (jumpdriveFTLCost > availableFTL) {
			jumpdriveETA = INFINITY;
		}
		if (flingFTLCost > availableFTL) {
			flingETA = INFINITY;
		}
		if (ssFTLCost > availableFTL) {
			ssETA = INFINITY;
		}

		if (hyperdriveFTLCost == INFINITY && jumpdriveFTLCost == INFINITY
				&& flingFTLCost == INFINITY && ssFTLCost == INFINITY) {
			return F_Pass;
		}

		double travelMethod = TRAVEL_SUBLIGHT;
		double travelETA = sublightETA;
		double travelCost = 0;
		// Determine what to prioritize for FTL travel
		if (ord.priority == MP_Critical) {
			// choose fastest travel method
			if (hyperdriveETA < travelETA) {
				travelMethod = TRAVEL_HYPERDRIVE;
				travelETA = hyperdriveETA;
				travelCost = hyperdriveFTLCost;
			}
			if (jumpdriveETA < travelETA) {
				travelMethod = TRAVEL_JUMPDRIVE;
				travelETA = jumpdriveETA;
				travelCost = jumpdriveFTLCost;
			}
			if (flingETA < travelETA) {
				travelMethod = TRAVEL_FLING;
				travelETA = flingETA;
				travelCost = flingFTLCost;
			}
			// err on the side of caution due to slipstream inaccuracy
			if ((ssETA * 1.2) < travelETA) {
				travelMethod = TRAVEL_SLIPSTREAM;
				travelETA = ssETA;
				travelCost = ssFTLCost;
			}
		} else {
			// choose cheapest travel method, being
			// willing to take FTL over sublight if it substantially
			// reduces the journey time
			if ((hyperdriveETA * 3) < sublightETA) {
				travelMethod = TRAVEL_HYPERDRIVE;
				travelETA = hyperdriveETA;
				travelCost = hyperdriveFTLCost;
			}
			if ((jumpdriveETA * 3) < sublightETA) {
				if (travelMethod == TRAVEL_SUBLIGHT) {
					travelMethod = TRAVEL_JUMPDRIVE;
					travelETA = jumpdriveETA;
					travelCost = jumpdriveFTLCost;
				} else {
					if (jumpdriveFTLCost < travelCost) {
						travelMethod = TRAVEL_JUMPDRIVE;
						travelETA = jumpdriveETA;
						travelCost = jumpdriveFTLCost;
					}
				}
			}
			if ((flingETA * 3) < sublightETA) {
				if (travelMethod == TRAVEL_SUBLIGHT) {
					travelMethod = TRAVEL_FLING;
					travelETA = flingETA;
					travelCost = flingFTLCost;
				} else {
					if (flingFTLCost < travelCost) {
						travelMethod = TRAVEL_FLING;
						travelETA = flingETA;
						travelCost = flingFTLCost;
					}
				}
			}
			if ((ssETA * 3) < sublightETA) {
				if (travelMethod == TRAVEL_SUBLIGHT) {
					travelMethod = TRAVEL_SLIPSTREAM;
					travelETA = ssETA;
					travelCost = ssFTLCost;
				} else {
					if (ssFTLCost < travelCost) {
						travelMethod = TRAVEL_SLIPSTREAM;
						travelETA = ssETA;
						travelCost = ssFTLCost;
					}
				}
			}
		}

		if (travelMethod == TRAVEL_SUBLIGHT) {
			return F_Pass;
		}

		if (travelMethod == TRAVEL_HYPERDRIVE) {
			ord.obj.addHyperdriveOrder(toPosition);
			return F_Continue;
		}

		if (travelMethod == TRAVEL_JUMPDRIVE) {
			if (makeDoubleHop) {
				ai.print("Making double hop");
				ord.obj.addJumpdriveOrder(doubleHopPosition);
				ord.obj.addJumpdriveOrder(toPosition, append=true);
				return F_Continue;
			} else {
				ord.obj.addJumpdriveOrder(toPosition);
				return F_Continue;
			}
		}

		if (travelMethod == TRAVEL_FLING) {
			//Make sure we're in range of a beacon
			Object@ beacon = getClosestFling(ord.obj.position);
			if (beacon is null || beacon.position.distanceTo(ord.obj.position) > FLING_BEACON_RANGE) {
				return F_Pass;
			}

			ord.obj.addFlingOrder(beacon, toPosition);
			return F_Continue;
		}

		if (travelMethod == TRAVEL_SLIPSTREAM) {
			ssGen.addSlipstreamOrder(toPosition, append=true);
			if (ssGen !is ord.obj) {
				ord.obj.addWaitOrder(ssGen, moveTo=true);
				ssGen.addSecondaryToSlipstream(ord.obj);
			}
			else {
				ord.obj.addMoveOrder(toPosition, append=true);
			}
			return F_Continue;
		}

		return F_Pass;
	}

	void focusTick(double time) override {
		checkAvailableFTLMethods();

		designGateIfNone();
		designSSIfNone();

		manageOrbitalsList();
		detectNewOrbitals();

		manageSSGensList();
		detectNewSS();

		updateOrbitalsForStagingBases();
		updateSSForStagingBases();

		detectNewStagingBases();
		detectImportantPlanetBuildLocations();
		detectNewBorderSystemBuildLocations();

		destroyOrbitalsOnFTLTrouble();

		lookToBuildNew();

		checkSafeRegions();

		//Scuttle anything unused if we don't need beacons in those regions
		for(uint i = 0, cnt = unusedFling.length; i < cnt; ++i) {
			if(getFling(unusedFling[i].region) is null && unusedFling[i].isOrbital) {
				cast<Orbital>(unusedFling[i]).scuttle();
				unusedFling.removeAt(i);
				--i; --cnt;
			}
		}

		// Try to get enough ftl storage that we can FTL our largest fleet by any method
		// or open a slipstream with every generator and have some remaining
		double highestCost = 0.0;
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if (flAI.fleetClass != FC_Combat) {
				continue;
			}
			if (hasFling) {
				// check the fling cost for this combat ship
				highestCost = max(highestCost, double(flingCost(flAI.obj, vec3d())));
			}
			// check the Hyperdrive cost for this combat ship
			if (canHyperdrive(flAI.obj)) {
				vec3d toPosition = flAI.obj.position + vec3d(0, 0, HYPERDRIVE_STORAGE_AIM_DISTANCE);
				highestCost = max(highestCost, double(hyperdriveCost(flAI.obj, toPosition)));
			}
			if (canJumpdrive(flAI.obj)) {
				double dist = jumpdriveRange(flAI.obj);
				vec3d toPosition = flAI.obj.position + vec3d(0, 0, dist);
				highestCost = max(highestCost, double(jumpdriveCost(flAI.obj, toPosition)));
			}
		}
		double mostSSCost = 0.0;
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			Ship@ obj = cast<Ship>(trackedSS[i].obj);
			if(obj is null)
				continue;

			double baseCost = obj.blueprint.design.average(SV_SlipstreamCost);
			double duration = obj.blueprint.design.average(SV_SlipstreamDuration);
			mostSSCost += baseCost / duration;
		}
		development.aimFTLStorage = max(
			highestCost / (1.0 - ai.behavior.ftlReservePctCritical - ai.behavior.ftlReservePctNormal),
			mostSSCost);

		// TODO: Make AI aim for FTL income at some level
	}

	void designGateIfNone() {
		if (!hasGates) {
			return;
		}

		//Design a gate
		if(gateDesign is null) {
			@gateDesign = designs.design(DP_Gate, 128);
			gateDesign.customName = "Gate";
		}
	}

	void designSSIfNone() {
		if (!hasSlipstreams) {
			return;
		}

		//Design a generator
		if(ssDesign is null) {
			@ssDesign = designs.design(DP_Slipstream, 128);
			ssDesign.customName = "Slipstream";
		}
	}

	void manageOrbitalsList() {
		//Manage unused fling beacons list
		for(uint i = 0, cnt = unusedFling.length; i < cnt; ++i) {
			Object@ obj = unusedFling[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				unusedFling.removeAt(i);
				--i; --cnt;
			}
		}

		//Manage unassigned gates list
		for(uint i = 0, cnt = unassignedGate.length; i < cnt; ++i) {
			Object@ obj = unassignedGate[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				unassignedGate.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void manageSSGensList() {
		//Manage unassigned gens list
		for(uint i = 0, cnt = unassignedSS.length; i < cnt; ++i) {
			Object@ obj = unassignedSS[i];
			if(obj is null || !obj.valid || obj.owner !is ai.empire) {
				unassignedSS.removeAt(i);
				--i; --cnt;
			}
		}
	}

	void detectNewOrbitals() {
		{
			//Detect new beacons
			auto@ data = ai.empire.getFlingBeacons();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
				continue;
				if(!trackingBeacon(obj))
				unusedFling.insertLast(obj);
			}
		}
		{
			//Detect new gates
			auto@ data = ai.empire.getStargates();
			Object@ obj;
			while(receive(data, obj)) {
				if(obj is null)
				continue;
				if(!trackingGate(obj))
				unassignedGate.insertLast(obj);
			}
		}
	}

	void detectNewSS() {
		//Detect new gens
		for(uint i = 0, cnt = fleets.fleets.length; i < cnt; ++i) {
			auto@ flAI = fleets.fleets[i];
			if(flAI.fleetClass != FC_Slipstream)
				continue;
			if(!trackingSSGen(flAI.obj))
				unassignedSS.insertLast(flAI.obj);
		}
	}

	void updateOrbitalsForStagingBases() {
		//Update existing beacons for staging bases
		for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
			auto@ reg = trackedFling[i];
			bool checkAlways = false;
			if(reg.obj !is null) {
				if(!reg.obj.valid || reg.obj.owner !is ai.empire || reg.obj.region !is reg.region) {
					@reg.obj = null;
					checkAlways = true;
				}
			}
			if(!shouldHaveFlingBeacon(reg.region, checkAlways)) {
				removeFling(trackedFling[i]);
				--i; --cnt;
			}
		}

		//Update existing gates for staging bases
		for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
			auto@ gt = trackedGate[i];
			bool checkAlways = false;
			if(gt.gate !is null) {
				if(!gt.gate.valid || gt.gate.owner !is ai.empire || (gt.installed && gt.gate.region !is gt.region)) {
					@gt.gate = null;
					gt.installed = false;
					checkAlways = true;
				}
				else if(!gt.installed && !gt.gate.hasOrders) {
					if(gt.destination.distanceTo(gt.gate.position) < 10.0) {
						gt.gate.activateAbilityTypeFor(ai.empire, unpackAbility, gt.destination);
						gt.installed = true;
					}
					else {
						gt.gate.activateAbilityTypeFor(ai.empire, packAbility);
						gt.gate.addMoveOrder(gt.destination);
					}
				}
			}
			if(!shouldHaveGate(gt.region, checkAlways)) {
				removeGate(trackedGate[i]);
				--i; --cnt;
			}
		}
	}

	void updateSSForStagingBases() {
		//Update existing gens for staging bases
		for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
			auto@ gt = trackedSS[i];
			bool checkAlways = false;
			if(gt.obj !is null) {
				if(!gt.obj.valid || gt.obj.owner !is ai.empire || (gt.arrived && gt.obj.region !is gt.region)) {
					@gt.obj = null;
					gt.arrived = false;
					checkAlways = true;
				}
				else if(!gt.arrived && !gt.obj.hasOrders) {
					if(gt.destination.distanceTo(gt.obj.position) < 10.0)
						gt.arrived = true;
					else
						assignSSTo(gt, gt.obj);
				}
			}
			if(!shouldHaveSSGen(gt.region, checkAlways)) {
				removeSS(trackedSS[i]);
				--i; --cnt;
			}
		}
	}

	void detectNewStagingBases() {
		//Detect new staging bases to build beacons at
		for(uint i = 0, cnt = military.stagingBases.length; i < cnt; ++i) {
			auto@ base = military.stagingBases[i];
			if(base.occupiedTime < FLING_MIN_TIMER)
				continue;

			if(getFling(base.region) is null) {
				FlingRegion@ closest = getClosestFlingRegion(base.region.position);
				if(closest !is null && closest.region.position.distanceTo(base.region.position) < FLING_MIN_DISTANCE_STAGE)
					continue;

				FlingRegion gt;
				@gt.region = base.region;
				trackedFling.insertLast(gt);
				break;
			}
		}

		//Detect new staging bases to build gates at
		for(uint i = 0, cnt = military.stagingBases.length; i < cnt; ++i) {
			auto@ base = military.stagingBases[i];
			if(base.occupiedTime < GATE_MIN_TIMER)
				continue;

			if(getGate(base.region) is null) {
				GateRegion@ closest = getClosestGateRegion(base.region.position);
				if(closest !is null && closest.region.position.distanceTo(base.region.position) < GATE_MIN_DISTANCE_STAGE)
					continue;

				GateRegion gt;
				@gt.region = base.region;
				trackedGate.insertLast(gt);
				break;
			}
		}
		//Detect new staging bases to build SS gens at
		for(uint i = 0, cnt = military.stagingBases.length; i < cnt; ++i) {
			auto@ base = military.stagingBases[i];
			if(base.occupiedTime < SS_MIN_TIMER)
				continue;

			if(getSS(base.region) is null) {
				SSRegion@ closest = getClosestSSRegion(base.region.position);
				if(closest !is null && closest.region.position.distanceTo(base.region.position) < SS_MIN_DISTANCE_STAGE)
					continue;

				SSRegion gt;
				@gt.region = base.region;
				trackedSS.insertLast(gt);
				break;
			}
		}
	}

	void detectImportantPlanetBuildLocations() {
		//Detect new important planets to build beacons at
		for(uint i = 0, cnt = development.focuses.length; i < cnt; ++i) {
			auto@ focus = development.focuses[i];
			Region@ reg = focus.obj.region;
			if(reg is null)
				continue;

			if(getFling(reg) is null) {
				FlingRegion@ closest = getClosestFlingRegion(reg.position);
				if(closest !is null && closest.region.position.distanceTo(reg.position) < FLING_MIN_DISTANCE_DEVELOP)
					continue;

				FlingRegion gt;
				@gt.region = reg;
				trackedFling.insertLast(gt);
				break;
			}
		}

		//Detect new important planets to build gates at
		for(uint i = 0, cnt = development.focuses.length; i < cnt; ++i) {
			auto@ focus = development.focuses[i];
			Region@ reg = focus.obj.region;
			if(reg is null)
				continue;

			if(getGate(reg) is null) {
				GateRegion@ closest = getClosestGateRegion(reg.position);
				if(closest !is null && closest.region.position.distanceTo(reg.position) < GATE_MIN_DISTANCE_DEVELOP)
					continue;

				GateRegion gt;
				@gt.region = reg;
				trackedGate.insertLast(gt);
				break;
			}
		}

		//Detect new important planets to build SS generator at
		for(uint i = 0, cnt = development.focuses.length; i < cnt; ++i) {
			auto@ focus = development.focuses[i];
			Region@ reg = focus.obj.region;
			if(reg is null)
				continue;

			if(getSS(reg) is null) {
				SSRegion@ closest = getClosestSSRegion(reg.position);
				if(closest !is null && closest.region.position.distanceTo(reg.position) < SS_MIN_DISTANCE_DEVELOP)
					continue;

				SSRegion gt;
				@gt.region = reg;
				trackedSS.insertLast(gt);
				break;
			}
		}
	}

	void detectNewBorderSystemBuildLocations() {
		// we don't build fling beacons or slipstream generators
		// at border systems so this is just for gates

		//Detect new border systems to build gates at
		uint offset = randomi(0, systems.border.length-1);
		for(uint i = 0, cnt = systems.border.length; i < cnt; ++i) {
			auto@ sys = systems.border[(i+offset)%cnt];
			Region@ reg = sys.obj;
			if(reg is null)
				continue;
			if(!sys.bordersEmpires)
				continue;

			if(getGate(reg) is null) {
				GateRegion@ closest = getClosestGateRegion(reg.position);
				if(closest !is null && closest.region.position.distanceTo(reg.position) < GATE_MIN_DISTANCE_DEVELOP)
					continue;

				GateRegion gt;
				@gt.region = reg;
				trackedGate.insertLast(gt);
				break;
			}
		}
	}

	void destroyOrbitalsOnFTLTrouble() {
		if (!ai.empire.FTLShortage) {
			return;
		}

		// Destroy beacons/gates if we're having FTL trouble
		// TODO: For now just destroy from whichever we have more of
		if (trackedFling.length > trackedGate.length) {
			// destroy a fling beacon
			Orbital@ leastImportant;
			double leastWeight = INFINITY;

			for(uint i = 0, cnt = unusedFling.length; i < cnt; ++i) {
				Orbital@ obj = cast<Orbital>(unusedFling[i]);
				if(obj is null || !obj.valid)
					continue;

				@leastImportant = obj;
				leastWeight = 0.0;
				break;
			}

			if(leastImportant !is null) {
				if(log)
					ai.print("Scuttle unused beacon for ftl", leastImportant.region);
				leastImportant.scuttle();
			}
			else {
				for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
					Orbital@ obj = cast<Orbital>(trackedFling[i].obj);
					if(obj is null || !obj.valid)
						continue;

					double weight = 1.0;
					auto@ base = military.getBase(trackedFling[i].region);
					if(base is null) {
						weight *= 5.0;
					}
					else if(base.idleTime >= 1) {
						weight *= 1.0 + (base.idleTime / 60.0);
					}
					else {
						weight /= 2.0;
					}

					if(weight < leastWeight) {
						@leastImportant = obj;
						leastWeight = weight;
					}
				}

				if(leastImportant !is null) {
					if(log)
						ai.print("Scuttle unimportant beacon for ftl", leastImportant.region);
					leastImportant.scuttle();
				}
			}
		} else {
			// destroy a gate
			Ship@ leastImportant;
			double leastWeight = INFINITY;

			for(uint i = 0, cnt = unassignedGate.length; i < cnt; ++i) {
				Ship@ ship = cast<Ship>(unassignedGate[i]);
				if(ship is null || !ship.valid)
					continue;

				double weight = ship.blueprint.design.size;
				weight *= 10.0;

				if(weight < leastWeight) {
					@leastImportant = ship;
					leastWeight = weight;
				}
			}

			if(leastImportant !is null) {
				if(log)
					ai.print("Scuttle unassigned gate for ftl", leastImportant.region);
				leastImportant.scuttle();
			}
			else {
				for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
					Ship@ ship = cast<Ship>(trackedGate[i].gate);
					if(ship is null || !ship.valid)
						continue;

					double weight = ship.blueprint.design.size;
					auto@ base = military.getBase(trackedGate[i].region);
					if(base is null) {
						weight *= 5.0;
					}
					else if(base.idleTime >= 1) {
						weight *= 1.0 + (base.idleTime / 60.0);
					}
					else {
						weight /= 2.0;
					}

					if(weight < leastWeight) {
						@leastImportant = ship;
						leastWeight = weight;
					}
				}

				if(leastImportant !is null) {
					if(log)
						ai.print("Scuttle unimportant gate for ftl", leastImportant.region);
					leastImportant.scuttle();
				}
			}
		}
	}

	void lookToBuildNew() {
		//See if we should build a new orbital
		if(buildFling !is null) {
			if(buildFling.completed) {
				@buildFling = null;
				if (hasGates) {
					// try to make a new gate after a fling beacon
					nextBuildTryGate = gameTime + 60.0;
					nextBuildTryFling = gameTime + 120.0;
				} else {
					nextBuildTryFling = gameTime + 60.0;
					nextBuildTryGate = gameTime + 120.0;
				}
			}
		}
		if(buildGate !is null) {
			if(buildGate.completed) {
				@buildGate = null;
				if (trackedGate.length > 2 && hasFling) {
					// try to make a new fling beacon after a gate
					nextBuildTryFling = gameTime + 60.0;
					nextBuildTryGate = gameTime + 120.0;
				} else {
					// if we have less than 2 gates try to make another
					// gate as a single gate is useless
					nextBuildTryGate = gameTime + 60.0;
					nextBuildTryFling = gameTime + 120.0;
				}
			}
		}
		//See if we should build a new SS generator
		// As slipstreams don't use FTL when not in use this
		// is seperate to building gates/fling beacons
		if(buildSS !is null) {
			if(buildSS.completed) {
				@buildSS = null;
				nextBuildTrySS = gameTime + 60.0;
			}
		}

		if (hasFling) {
			// attempt to mkae fling beacons
			wantToBuildFling = false;
			for(uint i = 0, cnt = trackedFling.length; i < cnt; ++i) {
				auto@ gt = trackedFling[i];
				if(gt.obj is null && gt.region.ContestedMask & ai.mask == 0 && gt.region.BlockFTLMask & ai.mask == 0) {
					Object@ found;
					for(uint n = 0, ncnt = unusedFling.length; n < ncnt; ++n) {
						Object@ obj = unusedFling[n];
						if(obj.region is gt.region) {
							@found = obj;
							break;
						}
					}

					if(found !is null) {
						if(log)
							ai.print("Assign beacon to => "+gt.region.name, found.region);
						assignFlingTo(gt, found);
					} else if(buildFling is null && gameTime > nextBuildTryFling && !ai.empire.isFTLShortage(0.15)) {
						if(ai.empire.FTLStored >= 250) {
							if(log)
								ai.print("Build beacon for this system", gt.region);

							@buildFling = construction.buildOrbital(getOrbitalModule(flingModule), military.getStationPosition(gt.region));
						}
						else {
							wantToBuildFling = true;
						}
					}
				}
			}
		}

		if (hasGates) {
			// attempt to make gates
			for(uint i = 0, cnt = trackedGate.length; i < cnt; ++i) {
				auto@ gt = trackedGate[i];
				if(gt.gate is null && gt.region.ContestedMask & ai.mask == 0 && gt.region.BlockFTLMask & ai.mask == 0) {
					Object@ closest;
					double closestDist = INFINITY;
					for(uint n = 0, ncnt = unassignedGate.length; n < ncnt; ++n) {
						Object@ obj = unassignedGate[n];
						if(obj.region is gt.region) {
							@closest = obj;
							break;
						}
						if(!obj.hasMover)
							continue;
						if(buildGate is null && gameTime > nextBuildTryGate) {
							double d = obj.position.distanceTo(gt.region.position);
							if(d < closestDist) {
								closestDist = d;
								@closest = obj;
							}
						}
					}

					if(closest !is null) {
						if(log)
							ai.print("Assign gate to => "+gt.region.name, closest.region);
						assignGateTo(gt, closest);
					} else if(buildGate is null && gameTime > nextBuildTryGate && !ai.empire.isFTLShortage(0.15)) {
						if(log)
							ai.print("Build gate for this system", gt.region);

						bool buildLocal = true;
						auto@ factory = construction.primaryFactory;
						if(factory !is null) {
							Region@ factRegion = factory.obj.region;
							if(factRegion !is null && systems.hopDistance(gt.region, factRegion) < GATE_BUILD_MOVE_HOPS)
								buildLocal = false;
						}

						if(buildLocal)
							@buildGate = construction.buildLocalStation(gateDesign);
						else
							@buildGate = construction.buildStation(gateDesign, military.getStationPosition(gt.region));
					}
				}
			}
		}

		if (hasSlipstreams) {
			for(uint i = 0, cnt = trackedSS.length; i < cnt; ++i) {
				auto@ gt = trackedSS[i];
				if(gt.obj is null && gt.region.ContestedMask & ai.mask == 0 && gt.region.BlockFTLMask & ai.mask == 0) {
					Object@ closest;
					double closestDist = INFINITY;
					for(uint n = 0, ncnt = unassignedSS.length; n < ncnt; ++n) {
						Object@ obj = unassignedSS[n];
						if(obj.region is gt.region) {
							@closest = obj;
							break;
						}
						if(!obj.hasMover)
							continue;
						if(buildSS is null && gameTime > nextBuildTrySS) {
							double d = obj.position.distanceTo(gt.region.position);
							if(d < closestDist) {
								closestDist = d;
								@closest = obj;
							}
						}
					}

					if(closest !is null) {
						if(log)
							ai.print("Assign slipstream gen to => "+gt.region.name, closest.region);
						assignSSTo(gt, closest);
					} else if(buildSS is null && gameTime > nextBuildTrySS) {
						if(log)
							ai.print("Build slipstream gen for this system", gt.region);

						@buildSS = construction.buildFlagship(ssDesign);
					}
				}
			}
		}
	}

	void checkSafeRegions() {
		//Disable systems that are no longer safe
		for(uint i = 0, cnt = safeRegions.length; i < cnt; ++i) {
			if(!safeRegions[i].getSystemFlag(ai.empire, safetyFlag)) {
				safeRegions.removeAt(i);
				--i; --cnt;
			}
		}

		//Try to find regions that are safe for us
		{
			sysChk = (sysChk+1) % systemCount;
			auto@ reg = getSystem(sysChk).object;
			if(reg.getSystemFlag(ai.empire, safetyFlag)) {
				if(safeRegions.find(reg) == -1)
					safeRegions.insertLast(reg);
			}
		}
	}

	void checkAvailableFTLMethods() {
		hasHyperdrives = ai.empire.isUnlocked(hyperdriveSubsystem);
		hasJumpdrives = ai.empire.isUnlocked(jumpdriveSubsystem);
		hasGates = ai.empire.isUnlocked(gateSubsystem);
		hasFling = ai.empire.HasFling >= 1;
		hasSlipstreams = ai.empire.isUnlocked(slipstreamSubsystem);
	}
};

AIComponent@ createFTLGeneric() {
	return FTLGeneric();
}
