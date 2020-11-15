import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import biomes;
import abilities;
import target_filters;
from abilities import AbilityHook;
import int getAbilityID(const string&) from "abilities";
import int getUnlockTag(const string& ident, bool create = true) from "unlock_tags";
from requirement_effects import Requirement;
#section server
from objects.Oddity import createMiniWormhole;
from objects.Oddity import createNebula;
import Planet@ spawnPlanetSpec(const vec3d& point, const string& resourceSpec, bool distributeResource = true, double radius = 0.0, bool physics = true) from "map_effects";
import void filterToResourceTransferAbilities(array<Ability>&) from "CE_resource_transfer";
import CE_array_map;
import influence_global;
import systems;
import planet_levels;
#section all

// TODO: Rename as no longer just biomes

class SwapBiome : GenericEffect, TriggerableGeneric {
		Document doc("Changes a biome on a planet to a new one");
		Argument old_biome(AT_PlanetBiome, doc="old biome");
		Argument new_biome(AT_PlanetBiome, doc="new biome");

#section server
	void enable(Object& obj, any@ data) const override {
		if (obj.isPlanet) {
			int old_biome_id = getBiomeID(old_biome.str);
			int new_biome_id = getBiomeID(new_biome.str);
			if (old_biome_id == -1) {
				return;
			}
			if (new_biome_id == -1) {
				return;
			}
			obj.swapBiome(uint(old_biome_id), uint(new_biome_id));
		}
	}
#section all
};

class SetHomeworld : BonusEffect {
		Document doc("Set the planet as the empire homeworld");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (obj is null) {
			return;
		}
		if (!obj.isPlanet) {
			return;
		}
		@emp.Homeworld = cast<Planet>(obj);
		@emp.HomeObj = cast<Planet>(obj);
	}
#section all
}

class UnlockSubsystem : EmpireEffect {
	Document doc("Set a particular subsystem as unlocked in the affected empire.");
	Argument subsystem(AT_Subsystem, doc="Identifier of the subsystem to unlock.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.setUnlocked(getSubsystemDef(subsystem.integer), true);
	}
#section all
};

class UnlockTag : EmpireEffect {
	Document doc("Set a particular tag as unlocked in the affected empire.");
	Argument tag(AT_UnlockTag, doc="The unlock tag to unlock. Unlock tags can be named any arbitrary thing, and will be created as specified. Use the same tag value in any RequireUnlockTag() or similar hooks that check for it.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.setTagUnlocked(tag.integer, true);
	}
#section all
};

class CancelIfAttributeGT : InfluenceVoteEffect {
	Document doc("Cancel the vote if the owner's attribute is too high.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");

#section server
	bool onTick(InfluenceVote@ vote, double time) const override {
		Empire@ owner = vote.startedBy;
		if(owner is null || !owner.valid)
			return false;
		if(owner.getAttribute(attribute.integer) > value.decimal)
			vote.end(false, true);
		return false;
	}
#section all
};

class CancelIfAnyAttributeGT : InfluenceVoteEffect {
	Document doc("Cancel the vote if any empires's attribute is too high. Works with ownerless votes");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");

#section server
	bool onTick(InfluenceVote@ vote, double time) const override {
		for (uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ emp = getEmpire(i);
			if (emp.getAttribute(attribute.integer) > value.decimal) {
				vote.end(false, true);
				return false;
			}
		}
		return false;
	}
#section all
};

class SpawnDamagedPlanet : BonusEffect {
	Document doc("Spawn a new planet at the current position with half health.");
	Argument resource(AT_Custom, "distributed");
	Argument owned(AT_Boolean, "False", doc="Whether the planet starts colonized.");
	Argument add_status(AT_Status, EMPTY_DEFAULT, doc="A status to add to the planet after it is spawned.");
	Argument in_system(AT_Boolean, "False", doc="Whether to spawn the planet somewhere in the system, instead of on top of the object.");
	Argument radius(AT_Range, "0", doc="Radius of the resulting planet.");
	Argument physics(AT_Boolean, "True", doc="Whether the planet should be a physical object.");
	Argument set_homeworld(AT_Boolean, "False", doc="Whether to set this planet as the homeworld.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;
		vec3d point = obj.position;
		if(in_system.boolean) {
			Region@ reg = obj.region;
			if(reg !is null) {
				point = reg.position;
				vec2d off = random2d(200.0, reg.radius);
				point.x += off.x;
				point.y += randomd(-20.0, 20.0);
				point.z += off.y;
			}
		}
		auto@ planet = spawnPlanetSpec(point, resource.str, true, radius.fromRange(), physics.boolean);
		if(owned.boolean && emp !is null)
			planet.colonyShipArrival(emp, 1.0);
		if(add_status.integer != -1)
			planet.addStatus(add_status.integer);
		if(set_homeworld.boolean) {
			@emp.Homeworld = planet;
			@emp.HomeObj = planet;
		}
		planet.Health *= 0.5;
	}
#section all
};

class DealStellarPercentageDamage : BonusEffect {
	Document doc("Deal percentage damage to a stellar object such as a planet or star.");
	Argument amount(AT_Decimal, doc="Amount of % damage to deal (% of current HP).");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;

		if (obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.dealPlanetDamage(planet.Health * amount.decimal);
		} else if (obj.isStar) {
			Star@ star = cast<Star>(obj);
			star.dealStarDamage(star.Health * amount.decimal);
		}
	}
#section all
};

tidy final class IfHaveEnergyIncome : IfHook {
	Document doc("Only applies the inner hook if the empire has at least a certain amount of energy income per second.");
	Argument amount(AT_Decimal, doc="Minimum amount of energy income per second required.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		return (obj.owner.EnergyIncome / obj.owner.EnergyGenerationFactor) >= amount.decimal;
	}
#section all
};

class GenerateCargoWhile : AbilityHook {
	Document doc("Generate cargo on the object casting the ability while is has a target.");
	Argument type(AT_Cargo, doc="Type of cargo to add.");
	Argument objTarg(TT_Object);
	Argument rate(AT_SysVar, "1", doc="Rate to create cargo at.");

#section server
	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null || !abl.obj.hasCargo)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Object@ target = storeTarg.obj;
		if(target is null || !target.hasCargo)
			return;
		abl.obj.addCargo(type.integer, time * rate.fromSys(abl.subsystem));
	}
#section all
};

class IfFewerStatusStacks : IfHook {
	Document doc("Only applies the inner hook if the object has fewer status stacks than an amount.");
	Argument status(AT_Status, doc="Type of status effect to limit.");
	Argument amount(AT_Integer, doc="Minimum number of stacks to stop triggering inner hook at.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if(!obj.hasStatuses)
			return false;
		int count = obj.getStatusStackCount(status.integer);
		return count < amount.integer;
	}
#section all
};

class DealPlanetTrueDamage : BonusEffect {
	Document doc("Deal true damage to a planet (bypassing pop based modifiers).");
	Argument amount(AT_Decimal, doc="Amount of damage to deal.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;

		if (obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.Health -= amount.decimal;
			if (planet.Health <= 0) {
				planet.Health = 0;
				planet.destroy();
			}
		}
	}
#section all
};

class DealPlanetPercentageTrueDamage : BonusEffect {
	Document doc("Deal percentage max hp true damage to a planet (bypassing pop based modifiers).");
	Argument amount(AT_Decimal, doc="Amount of % damage to deal (% of max HP).");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(obj is null)
			return;

		if (obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.Health -= planet.MaxHealth * amount.decimal;
			if (planet.Health <= 0) {
				planet.Health = 0;
				planet.destroy();
			}
		}
	}
#section all
};

class IfPlanetPercentageHealthLessThan : IfHook {
	Document doc("Only applies the inner hook if the planet has the specified % hp or less remaining.");
	Argument amount(AT_Decimal, doc="% of hp threshold.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if (obj is null) {
			return false;
		}
		if (obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			return (planet.Health / planet.MaxHealth) <= amount.decimal;
		}
		return false;
	}
#section all
};

class DealPlanetPercentageTrueDamageOverTime : GenericEffect, TriggerableGeneric {
	Document doc("Deal percentage max hp true damage to the targeted planet over time. Stops when hits threshold");
	Argument amount(AT_Decimal, doc="Amount of % damage to deal (% of max HP) per second.");

#section server
	void tick(Object& obj, any@ data, double time) const override {
		if (obj is null) {
			return;
		}

		if (obj.isPlanet) {
			Planet@ planet = cast<Planet>(obj);
			planet.Health -= planet.MaxHealth * amount.decimal * time;
			if (planet.Health <= 0) {
				planet.Health = 0;
				planet.destroy();
			}
		}
	}
#section all
};

class IfPlanetHasBiome : IfHook {
	Document doc("Only applies the inner hook if the planet has the specified biome.");
	Argument biome(AT_PlanetBiome, doc="biome");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

#section server
	bool condition(Object& obj) const override {
		if (obj is null) {
			return false;
		}
		if (obj.isPlanet) {
			int biome_id = getBiomeID(biome.str);
			if (biome_id == -1) {
				return false;
			}
			uint id = int(biome_id);
			Planet@ planet = cast<Planet>(obj);
			return planet.Biome0 == id || planet.Biome1 == id || planet.Biome2 == id;
		}
		return false;
	}
#section all
};


class ConsumePlanetResource : AbilityHook {
	Document doc("Removes a planet resource from the object casting the ability.");
	Argument resource(AT_PlanetResource, doc="Type of resource to consume.");
	Argument objTarg(TT_Object);

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		if(abl.obj is null)
			return false;

		if (abl.obj.isPlanet) {
			Planet@ planet = cast<Planet>(abl.obj);
			array<Resource> planetResources;
			planetResources.syncFrom(planet.getNativeResources());
			for (uint i = 0, cnt = planetResources.length; i < cnt; i++) {
				auto planetResourceType = planetResources[i].type;
				if (planetResourceType.id == uint(resource.integer)) {
					return true;
				}
			}
		}
		return false;
	}

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		if(abl.obj is null)
			return;

		// remove planet resource from abl.obj
		if (abl.obj.isPlanet) {
			Planet@ planet = cast<Planet>(abl.obj);
			array<Resource> planetResources;
			planetResources.syncFrom(planet.getNativeResources());
			for (uint i = 0, cnt = planetResources.length; i < cnt; i++) {
				auto planetResourceType = planetResources[i].type;
				if (planetResourceType.id == uint(resource.integer)) {
					// native resources are identified differently to their
					// type identifier
					planet.removeResource(planetResources[i].id);
					return;
				}
			}
		}
	}
#section all
};

tidy final class UpdatedValue {
	double value = 0;
	double timer = 0;
}

class ModEfficiencyDistanceToOwnedPlanets : GenericEffect {
	Document doc("Modify the efficiency of the fleet based on the distance to the nearest owned planet.");
	Argument minrange_efficiency(AT_Decimal, doc="Efficiency at minimum range.");
	Argument maxrange_efficiency(AT_Decimal, doc="Efficiency at maximum range.");
	Argument minrange(AT_Decimal, doc="Minimum range for min efficiency.");
	Argument maxrange(AT_Decimal, doc="Maximum range for max efficiency.");

#section server
	void enable(Object& obj, any@ data) const override {
		UpdatedValue value;
		data.store(@value);
	}

	void tick(Object& obj, any@ data, double time) const override {
		UpdatedValue@ value;
		data.retrieve(@value);

		value.timer -= time;
		if(value.timer <= 0) {
			value.timer = randomd(0.5, 5.0);

			double prevValue = value.value;
			double dist = maxrange.decimal;

			// determine closest planet distance
			Object@ planet;
			DataList@ objs = obj.owner.getPlanets();
			while (receive(objs, planet)) {
				if (planet.isPlanet) {
					double planet_dist = planet.position.distanceTo(obj.position);
					if (planet_dist < dist) {
						dist = planet_dist;
						// no need to store the planet
					}
				}
			}

			if(dist <= minrange.decimal) {
				value.value = minrange_efficiency.decimal;
			}
			else if(dist >= maxrange.decimal) {
				value.value = maxrange_efficiency.decimal;
			}
			else {
				double pct = (dist - minrange.decimal) / (maxrange.decimal - minrange.decimal);
				value.value = minrange_efficiency.decimal + pct * (maxrange_efficiency.decimal - minrange_efficiency.decimal);
			}

			if(prevValue != value.value)
				obj.modFleetEffectiveness(value.value - prevValue);
		}
	}

	void disable(Object& obj, any@ data) const override {
		UpdatedValue@ value;
		data.retrieve(@value);

		if(value.value > 0) {
			obj.modFleetEffectiveness(-value.value);
			value.value = 0;
		}
	}

	void save(any@ data, SaveFile& file) const override {
		UpdatedValue@ value;
		data.retrieve(@value);
		file << value.value;
		file << value.timer;
	}

	void load(any@ data, SaveFile& file) const override {
		UpdatedValue value;
		file >> value.value;
		file >> value.timer;
		data.store(value);
	}
#section all
};

// Cache system defs to check things are unlocked
const SubsystemDef@ hyperdriveSubsystem = getSubsystemDef("Hyperdrive");
const SubsystemDef@ jumpdriveSubsystem = getSubsystemDef("Jumpdrive");
const SubsystemDef@ gateSubsystem = getSubsystemDef("GateModule");
const SubsystemDef@ slipstreamSubsystem = getSubsystemDef("Slipstream");
const SubsystemDef@ warpdriveSubsystem = getSubsystemDef("Warpdrive");

enum FTLUnlock {
	FTLU_Hyperdrive,
	FTLU_Jumpdrive,
	FTLU_Gate,
	FTLU_Slipstream,
	FTLU_Fling,
	FTLU_Warpdrive,
};

// TODO: Add way to exclude the FTL about to be unlocked for all from the pool
class UnlockRandomFTL : EmpireTrigger {
	Document doc("Make the empire this is triggered on gain a random FTL it doesn't yet have.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (emp is null) {
			return;
		}
		bool hasHyperdrives = emp.isUnlocked(hyperdriveSubsystem);
		bool hasJumpdrives = emp.isUnlocked(jumpdriveSubsystem);
		bool hasGates = emp.isUnlocked(gateSubsystem);
		bool hasFling = emp.HasFling >= 1;
		bool hasSlipstreams = emp.isUnlocked(slipstreamSubsystem);
		bool hasWarpdrive = emp.isUnlocked(warpdriveSubsystem);

		array<FTLUnlock> unlockPool = array<FTLUnlock>();
		if (!hasHyperdrives)
			unlockPool.insertLast(FTLU_Hyperdrive);
		if (!hasJumpdrives)
			unlockPool.insertLast(FTLU_Jumpdrive);
		if (!hasGates)
			unlockPool.insertLast(FTLU_Gate);
		if (!hasSlipstreams)
			unlockPool.insertLast(FTLU_Slipstream);
		if (!hasFling)
			unlockPool.insertLast(FTLU_Fling);

		if (unlockPool.length == 0) {
			if (!hasWarpdrive) {
				unlockPool.insertLast(FTLU_Warpdrive);
			} else {
				// How did this user unlock all the FTL types and still try to
				// win this vote?
				// TODO: Some consolation prize
				return;
			}
		}

		// randomi generates a number in the inclusive range
		int randomSelection = randomi(0, unlockPool.length - 1);
		uint unlock = unlockPool[randomSelection];

		// mark the empire attribute as unlocked, and unlock the subsystem
		if (unlock == FTLU_Hyperdrive) {
			emp.setUnlocked(hyperdriveSubsystem, true);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Hyperdrives unlocked", "You have unlocked Hyperdrives through a galactic senate vote");
		}
		if (unlock == FTLU_Jumpdrive) {
			emp.setUnlocked(jumpdriveSubsystem, true);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Jumpdrives unlocked", "You have unlocked Jumpdrives through a galactic senate vote");
		}
		if (unlock == FTLU_Gate) {
			emp.setUnlocked(gateSubsystem, true);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Gates unlocked", "You have unlocked Gates through a galactic senate vote");
		}
		if (unlock == FTLU_Slipstream) {
			emp.setUnlocked(slipstreamSubsystem, true);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Slipstreams unlocked", "You have unlocked Slipstreams through a galactic senate vote");
		}
		if (unlock == FTLU_Fling) {
			int hasFlingUnlockTagID = getUnlockTag("HasFling", false);
			emp.setTagUnlocked(hasFlingUnlockTagID, true);
			emp.modAttribute(EA_HasFling, AC_Add, 1);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Fling Beacons unlocked", "You have unlocked Fling Beacons through a galactic senate vote");
		}
		if (unlock == FTLU_Warpdrive) {
			emp.setUnlocked(warpdriveSubsystem, true);
			if(emp.player is null)
				return;
			sendClientMessage(emp.player, "Warpdrives unlocked", "You have unlocked Warpdrives through a galactic senate vote");
		}
	}
#section all
};

class TransferAllResourcesAndAbandon : AbilityHook {
	Document doc("Queue up all available resource transfer abilities onto the target then abandon this object.");
	Argument objTarget(TT_Object, doc="Target to cast ability on.");

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		if(abl.obj is null)
			return;

		auto@ targ = objTarget.fromConstTarget(targs);
		if(targ is null || targ.obj is null)
			return;

		if (!abl.obj.isPlanet)
		 	return;

		Planet@ planet = cast<Planet>(abl.obj);

		array<Ability> abilities;
		abilities.syncFrom(abl.obj.getAbilities());

		int abandonAbility = -1;
		for (uint i = 0, cnt = abilities.length; i < cnt; ++i) {
			if (abilities[i].type.ident == "AbilityAbandon") {
				abandonAbility = abilities[i].id;
			}
		}

		// Queue up orders for each resource transfer and then abandon
		filterToResourceTransferAbilities(abilities);

		// Build up a map of planet resource type ids to occurrences,
		// to find out if a particular resource is present multiple times
		// on this planet already
		array<Resource> planetResources;
		ArrayMap resourceOccurances = ArrayMap();
		planetResources.syncFrom(planet.getNativeResources());
		for (uint i = 0, cnt = planetResources.length; i < cnt; i++) {
			auto planetResourceType = planetResources[i].type;
			resourceOccurances.increment(planetResourceType.id);
		}

		for (uint i = 0, cnt = abilities.length; i < cnt; ++i) {
			Ability@ transferAbility = abilities[i];
			if (transferAbility.type.resource is null) {
				// Error in ability definition?
				continue;
			}
			uint resourceTypeID = transferAbility.type.resource.id;
			uint resourceCount = 1;
			if (resourceOccurances.has(resourceTypeID)) {
				resourceCount = resourceOccurances.get(resourceTypeID);
			}
			// Queue up as many copies of this ability as we have occurances
			// of the resource the ability transfers
			for (uint j = 0; j < resourceCount; j++) {
				abl.obj.addAbilityOrder(transferAbility.id, targ.obj, true);
			}
		}
		abl.obj.addAbilityOrder(abandonAbility, abl.obj, true);
	}
#section all
};

class RequireNotHomeworld : Requirement {
	Document doc("Can only be built on planets that are not the homeworld.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if (obj is null || !obj.isPlanet || obj.owner is null) {
			return false;
		}
		if (obj.owner.Homeworld is null) {
			return true;
		}
		Planet@ planet = cast<Planet>(obj);
		return obj.owner.Homeworld.id != planet.id;
	}
};

class RequireHomeworld : Requirement {
	Document doc("Can only be built on planets that are the homeworld.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if (obj is null || !obj.isPlanet || obj.owner is null || obj.owner.Homeworld is null) {
			return false;
		}
		Planet@ planet = cast<Planet>(obj);
		return obj.owner.Homeworld.id == planet.id;
	}
};

class RequireUndevelopedTiles : Requirement {
	Document doc("Can only be built on planets with undeveloped tiles remaining.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if (obj is null || !obj.isPlanet) {
			return false;
		}
		Planet@ planet = cast<Planet>(obj);
		return planet.hasUndevelopedSurfaceTiles;
	}
};

class PickupSpecificCargoFrom : AbilityHook {
	Document doc("Pick up all cargo of a type from the target object, as much as possible.");
	Argument cargo_type(AT_Cargo, doc="Type of cargo to pickup.");
	Argument targ(TT_Object);

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		auto@ objTarg = targ.fromConstTarget(targs);
		if(objTarg is null || objTarg.obj is null)
			return;
		Object@ other = objTarg.obj;
		if(!other.hasCargo || abl.obj is null || !abl.obj.hasCargo)
			return;
		other.transferCargoTo(cargo_type.integer, abl.obj);
	}
#section all
};

class TransferSpecificCargoTo : AbilityHook {
	Document doc("Transfer all cargo of a type to the target object, as much as possible.");
	Argument cargo_type(AT_Cargo, doc="Type of cargo to transfer.");
	Argument targ(TT_Object);

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		auto@ objTarg = targ.fromConstTarget(targs);
		if(objTarg is null || objTarg.obj is null)
			return;
		Object@ other = objTarg.obj;
		if(!other.hasCargo || abl.obj is null || !abl.obj.hasCargo)
			return;
		abl.obj.transferCargoTo(cargo_type.integer, other);
	}
#section all
};

class TargetFilterHasSpecificCargoStored : TargetFilter {
	Document doc("Only allow targets that have some type of cargo stored.");
	Argument cargo_type(AT_Cargo, doc="Type of cargo to have.");
	Argument objTarg(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_CARGO;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasCargo)
			return false;
		if(targ.obj.cargoStored < 0.001)
			return false;
		return targ.obj.getCargoStored(cargo_type.integer) > 0;
	}
};

class RequireHeldSpecificCargo : AbilityHook {
	Document doc("Ability can only be used if cargo space contains a type of cargo.");
	Argument cargo_type(AT_Cargo, doc="Type of cargo to have.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		if(abl.obj is null || !abl.obj.hasCargo)
			return false;
		return abl.obj.getCargoStored(cargo_type.integer) >= 0.001;
	}
};

class StartVoteIfAllAttributeLT : EmpireTrigger {
	Document doc("Start a new influence vote if all empires with this attribute are less than a value. If the vote takes an object target, fill it with the triggered object. Other targets will not be filled.");
	Argument type(AT_InfluenceVote, doc="Type of vote to start.");
	Argument start_ownerless(AT_Boolean, "False", doc="Whether to start the vote without an owner, like zeitgeists, or whether to have the triggering empire as its owner.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp is null || start_ownerless.boolean)
			@emp = defaultEmpire;

		auto@ type = getInfluenceVoteType(type.integer);
		Targets targs(type.targets);
		if(targs.length != 0 && targs[0].type == TT_Object) {
			@targs[0].obj = obj;
			targs[0].filled = true;
		}

		if(type !is null) {
			for (uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
				Empire@ emp = getEmpire(i);
				if (emp.getAttribute(attribute.integer) >= value.decimal) {
					return;
				}
			}
			startInfluenceVote(emp, type, targs);
		}
	}
#section all
};

tidy final class SystemIndexData {
	double lastTickTime = 0;
	uint index = 0;
}

class MiniWormholeNetwork : EmpireEffect {
	Document doc("Scripting for the mini wormhole network FTL trait.");
	Argument orbital("Core", AT_OrbitalModule, doc="Type of orbital to spawn.");

#section server
	void enable(Empire& emp, any@ data) const override {
		SystemIndexData indexes;
		data.store(@indexes);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		if (emp.WormholeNetworkUnlocked == 0) {
			return;
		}

		SystemIndexData@ indexes;
		data.retrieve(@indexes);
		if (indexes is null) {
			return;
		}

		// tick every 30 seconds
		if (gameTime > (indexes.lastTickTime + 30.0)) {
			indexes.lastTickTime = gameTime;
		} else {
			return;
		}

		auto@ def = getOrbitalModule(orbital.integer);
		if (def is null) {
			return;
		}
		uint defID = uint(orbital.integer);

		// try to tick through 20% of the systems each 30 seconds to
		// avoid lag
		// this will roughly tick through 120% of the systems each
		// budget cycle
		uint tickRange = ceil(double(systemCount) / 5.0);
		uint i = indexes.index;
		for (; i < indexes.index + tickRange; ++i) {
			if (i >= systemCount) {
				// reset the index back to 0 and continue in 30 seconds
				indexes.index = 0;
				return;
			}
			auto@ sys = getSystem(i);

			Region@ reg = sys.object;
			uint tradeMask = reg.TradeMask;

			bool ownedSpace = false;
			if (tradeMask & emp.mask != 0) {
				ownedSpace = true;
			}

			if (!ownedSpace) {
				continue;
			}

			uint totalOrbitals = reg.orbitalCount;
			uint totalHubsPresent = 0;
			for (uint i = 0; i < totalOrbitals; i++) {
				if (reg.get_orbitals(i).coreModule == defID) {
					totalHubsPresent += 1;
				}
			}

			// spawn two hubs to start, if none are present
			uint hubsToSpawn = 1;
			if (totalHubsPresent == 0) {
				hubsToSpawn = 2;
			}

			// stop spawning after 5 hubs, 7 was a bit too much, leave the
			// chance to spawn in based on 7 though.
			if (totalHubsPresent >= 5) {
				continue;
			}

			// spawn immediately if no hubs present, gradually reduce the
			// probability of spawning another hub on a given tick down to 0%
			// at 7 hubs in a system.
			if (totalHubsPresent == 0 || (randomd() < (1 - totalHubsPresent * 0.15))) {
				for (uint i = 0; i < hubsToSpawn; i++) {
					vec3d pos = reg.position;
					vec2d offset = random2d(reg.radius * 0.3, reg.radius * 0.3);
					pos.x += offset.x;
					pos.z += offset.y;
					auto@ orb = createOrbital(pos, def, emp);
				}
			}
		}
		indexes.index = i;
	}

	void disable(Empire& emp, any@ data) const override {
		SystemIndexData@ indexes;
		data.retrieve(@indexes);
		if(indexes is null)
			return;

		@indexes = null;
		data.store(@indexes);
	}

	void save(any@ data, SaveFile& file) const override {
		SystemIndexData@ indexes;
		data.retrieve(@indexes);
		file << indexes.lastTickTime;
		file << indexes.index;
	}

	void load(any@ data, SaveFile& file) const override {
		SystemIndexData indexes;
		file >> indexes.lastTickTime;
		file >> indexes.index;
		data.store(indexes);
	}
#section all
};


tidy final class WormholeControlHubData {
	bool hasWormhole = false;
	Oddity@ wormhole;
};

tidy final class SpawnMiniWormhole : GenericEffect {
	Document doc("Spawns a mini wormhole to a location tied to the lifetime of this object.");

#section server
	void enable(Object& obj, any@ data) const override {
		WormholeControlHubData hubData;
		data.store(@hubData);
	}

	void disable(Object& obj, any@ data) const override {
		WormholeControlHubData@ hubData;
		data.retrieve(@hubData);

		if (hubData.wormhole !is null) {
			if (hubData.wormhole.getLink() !is null) {
				hubData.wormhole.getLink().destroy();
			}
			hubData.wormhole.destroy();
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		WormholeControlHubData@ hubData;
		data.retrieve(@hubData);

		if (!hubData.hasWormhole) {
			// avoid spawning the wormhole if FTL is jammed
			bool jammed = obj.region.BlockFTLMask.value & obj.owner.mask != 0;
			if (jammed) {
				return;
			}

			vec3d from = obj.position;
			vec3d to = obj.position;

			if (randomd() < 0.6) {
				Region@ region = obj.region;
				if (region !is null) {
					SystemDesc@ sys = getSystem(region);
					uint index = randomi(0, sys.adjacent.length - 1);
					SystemDesc@ neighbour = getSystem(sys.adjacent[index]);
					to = neighbour.position;
				}
			}

			vec2d offset = random2d(1000.0, 1000.0);
			to.x += offset.x;
			to.z += offset.y;

			@hubData.wormhole = createMiniWormhole(from, to, -1);
			hubData.hasWormhole = true;

			obj.stopOrbit();
		}

		if (hubData.wormhole !is null) {
			// check if we need to disable the control hub if either end
			// of the wormhole or the hub itself are in a FTL jammed region
			Region@ source = hubData.wormhole.region;
			if (disableOnFTLJamming(obj, hubData, source)) {
				return;
			}
			if (hubData.wormhole.getLink() !is null) {
				Region@ destination = hubData.wormhole.getLink().region;
				if (disableOnFTLJamming(obj, hubData, destination)) {
					return;
				}
			}
			Region@ hub = obj.region;
			if (disableOnFTLJamming(obj, hubData, hub)) {
				return;
			}
		}
	}

	/**
	 * Disables the wormholes, returning true iff the region is FTL jammed
	 * and the hub and wormholes were disabled.
	 */
	bool disableOnFTLJamming(Object& obj, WormholeControlHubData@ hubData, Region@ region) {
		if (region !is null) {
			if (region.BlockFTLMask.value & obj.owner.mask != 0) {
				// FTL jamming is applied
				if (hubData.wormhole !is null) {
					if (hubData.wormhole.getLink() !is null) {
						hubData.wormhole.getLink().destroy();
					}
					hubData.wormhole.destroy();
					@hubData.wormhole = null;
					hubData.hasWormhole = false;
					return true;
				}
			}
		}
		return false;
	}

	void save(any@ data, SaveFile& file) const override {
		WormholeControlHubData@ hubData;
		data.retrieve(@hubData);
		file << hubData.hasWormhole;
		file << hubData.wormhole;
	}

	void load(any@ data, SaveFile& file) const override {
		WormholeControlHubData hubData;
		file >> hubData.hasWormhole;
		file >> hubData.wormhole;
		data.store(@hubData);
	}
#section all
};

class StatusToPlanetDuringVote : InfluenceVoteEffect {
	Document doc("Marks a planet or all planets in a system with a status while the vote is ongoing.");
	Argument targ("Target", TT_Object);
	Argument status(AT_Status, EMPTY_DEFAULT, doc="A status to add to the planet(s) during the vote.");

#section server
	void onStart(InfluenceVote@ vote) const override {
		array<Object@> contested;
		vote.data[hookIndex].store(@contested);

		Object@ obj = targ.fromTarget(vote.targets).obj;
		if (status.integer != -1) {
			if (obj.isPlanet && obj !is null) {
				obj.addStatus(status.integer);
			} else {
				Region@ region = cast<Region>(obj);
				if (region is null) {
					@region = obj.region;
				}
				if (region !is null) {
					for(uint i = 0, cnt = region.planetCount; i < cnt; ++i) {
						Planet@ pl = region.planets[i];
						if (pl !is null && pl.owner !is null && pl.owner !is vote.startedBy && pl.owner.valid) {
							pl.addStatus(status.integer);
							contested.insertLast(pl);
						}
					}
				}
			}
		}
	}

	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const override {
		array<Object@>@ contested;
		vote.data[hookIndex].retrieve(@contested);

		Object@ obj = targ.fromTarget(vote.targets).obj;
		if (status.integer != -1) {
			if (obj.isPlanet && obj !is null) {
				obj.removeStatusInstanceOfType(status.integer);
			} else {
				if (contested !is null) {
					for (uint i = 0, cnt = contested.length; i < cnt; ++i) {
						contested[i].removeStatusInstanceOfType(status.integer);
					}
				}
			}
		}
	}

	void save(InfluenceVote@ vote, SaveFile& file) const override {
		array<Object@>@ contested;
		vote.data[hookIndex].retrieve(@contested);

		uint cnt = 0;
		if (contested !is null) {
			cnt = contested.length;
		}
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			file << contested[i];
		}
	}

	void load(InfluenceVote@ vote, SaveFile& file) const override {
		array<Object@> contested;
		vote.data[hookIndex].store(@contested);

		uint cnt = 0;
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			Object@ obj;
			file >> obj;
			if (obj !is null) {
				contested.insertLast(obj);
			}
		}
	}
#section all
};

class TargetFilterHasTradePresenceOrDeepSpace : TargetFilter {
	Document doc("Restricts target to regions with the empire's trade presence or targets in deep space.");
	Argument targ(TT_Object);
	Argument adjacent("Allow Adjacent", AT_Decimal, "True", doc="Whether to allow the target if adjacent regions have trade presence.");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_TRADE_PRESENCE;
	}

#section game
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		Object@ obj = targ.obj;
		Region@ reg = cast<Region>(obj);
		if(reg is null)
			@reg = obj.region;
		if(reg is null)
			return true; // diff from TargetFilterHasTradePresence
		if(reg.TradeMask & emp.TradeMask.value == 0) {
			if(!arguments[1].boolean)
				return false;
			const SystemDesc@ sys = getSystem(reg);
			if(sys !is null) {
				bool found = false;
				for(uint i = 0, cnt = sys.adjacent.length; i < cnt; ++i) {
					const SystemDesc@ other = getSystem(sys.adjacent[i]);
					if(other.object.TradeMask & emp.TradeMask.value != 0) {
						found = true;
						break;
					}
				}
				if(!found)
					return false;
			}
		}
		return true;
	}
#section all
};

// Not making this usable until I have no better alternatives, this
// is not very safe to use on arbitrary traits
/* tidy final class GrantTrait : EmpireTrigger {
	Document doc("Give a trait to the empire, post game start, via research.");
	Argument trait(AT_Trait, EMPTY_DEFAULT, doc="Trait to give.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (emp is null) {
			return;
		}
		if (!emp.hasTrait(trait.integer)) {
			emp.addTraitPostStart(trait.integer);
		}
	}
#section all
}; */

tidy final class CardGenerationData {
	double lastTickTime = 0;
}

class CardGenerationIfAttributeGTE : EmpireEffect {
	Document doc("Gives a card to the empire every x seconds if an attribute is >= to an amount.");
	Argument card(AT_InfluenceCard, doc="Card type to give.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");
	Argument interval(AT_Decimal, "60", doc="Seconds to wait between giving cards.");

#section server
	void enable(Empire& emp, any@ data) const override {
		CardGenerationData cardData;
		data.store(@cardData);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		if (emp.getAttribute(attribute.integer) < value.decimal) {
			return;
		}

		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		if (cardData is null) {
			return;
		}

		// tick every x seconds
		if (gameTime > (cardData.lastTickTime + interval.decimal)) {
			cardData.lastTickTime = gameTime;

			// give card
			const InfluenceCardType@ cardType =  getInfluenceCardType(card.str);
			if (cardType is null) {
				error("Invalid card type: "+card.str);
				return;
			}
			InfluenceCard@ card = cardType.create();
			cast<InfluenceStore>(emp.InfluenceManager).addCard(emp, card);
		} else {
			return;
		}
	}

	void disable(Empire& emp, any@ data) const override {
		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		if(cardData is null)
			return;

		@cardData = null;
		data.store(@cardData);
	}

	void save(any@ data, SaveFile& file) const override {
		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		file << cardData.lastTickTime;
	}

	void load(any@ data, SaveFile& file) const override {
		CardGenerationData cardData;
		file >> cardData.lastTickTime;
		data.store(cardData);
	}
#section all
};

class GiveRandomUnlock : EmpireTrigger {
	Document doc("Gives a random unlock to this empire's research grid.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if(emp !is null)
			emp.grantRandomUnlock();
	}
#section all
};


class BreakExcessFoodImports : BonusEffect {
	Document doc("Breaks excess food imports to this planet");
	Argument gaining_food(AT_Boolean, "True", doc="If the planet is about to gain 1 food resource.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (obj is null) {
			return;
		}
		if (!obj.isPlanet) {
			return;
		}
		if (obj.owner !is emp) {
			return;
		}
		Planet@ planet = cast<Planet>(obj);
		if (planet is null) {
			return;
		}
		const PlanetLevelChain@ chain = getLevelChain(obj.levelChain);
		if (chain is null) {
			return;
		}
		// consider the level of the planet as what is currently is, or
		// its resource level, whichever is higher (assume players will
		// want to level planets up to their resource level)
		int level = max(planet.level, planet.resourceLevel);
		if (level < 0) {
			return;
		}
		if (uint(level) >= chain.levels.length) {
			return;
		}
		PlanetLevel@ currentLevel = chain.levels[level];
		const ResourceClass@ foodClass = getResourceClass("Food");
		uint foodNeededForCurrentLevel = 0;
		// go through each level of the chain up to the current level of
		// the planet
		for (uint i = 0, metLevels = uint(level); i <= metLevels; ++i) {
			PlanetLevel@ levelRow = chain.levels[i];
			if (levelRow is null) {
				continue;
			}
			// get requirements for this level
			ResourceRequirements requirements = levelRow.reqs;
			ResourceRequirement@[] reqs = requirements.reqs;
			// go through each requirement
			for (uint j = 0, jcnt = reqs.length; j < jcnt; ++j) {
				ResourceRequirement@ requirement = reqs[j];
				// not sure what the difference is between these two
				if (requirement.type == RRT_Class || requirement.type == RRT_Class_Types) {
					if (requirement.cls is foodClass) {
						foodNeededForCurrentLevel += max(requirement.amount, 1);
					}
				}
			}
		}
		// Now find out how many food resources the planet has
		uint hasFood = planet.getFoodCount();
		if (gaining_food.boolean) {
			hasFood += 1;
		}
		// print("Planet "+string(planet.name)+ " needs "+string(foodNeededForCurrentLevel)+ " food resources for level "+string(level)+" Has "+string(hasFood)+ " food.");
		if (hasFood <= foodNeededForCurrentLevel) {
			return;
		}
		const ResourceType@ doubleFood = getResource("HyperOats");
		int foodImportsToBreak = hasFood - foodNeededForCurrentLevel;
		array<Resource> resources;
		resources.syncFrom(obj.getImportedResources());
		for(uint i = 0, cnt = resources.length; i < cnt; ++i) {
			Resource@ resource = resources[i];
			if (resource !is null && resource.type !is null) {
				if (resource.type.cls is foodClass && foodImportsToBreak > 0) {
					if (resource.origin !is null) {
						if (resource.type is doubleFood) {
							if (foodImportsToBreak >= 2) {
								foodImportsToBreak -= 2;
								resource.origin.exportResource(resource.id, null);
							}
						} else {
							foodImportsToBreak -= 1;
							resource.origin.exportResource(resource.id, null);
						}
					}
				}
			}
		}
	}
#section all
}

class SpawnNebula : BonusEffect {
	Document doc("Turn the system the object is in into a nebula.");
	Argument color(AT_Color, "#f0c870", doc="Color of the nebula.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		if (obj is null || obj.region is null) {
			return;
		}
		SystemDesc@ sys = getSystem(obj.region);
		if (sys is null || sys.object is null) {
			return;
		}
		Color col = toColor(color.str);
		// create oddity
		createNebula(sys.position, sys.radius, color=col.rgba, region=sys.object);
		// turn off region vision
		sys.donateVision = false;
		// set static seeable range
		for(uint i = 0, cnt = sys.object.objectCount; i < cnt; ++i) {
			Object@ obj = sys.object.objects[i];
			if(obj.hasStatuses)
				continue;
			obj.seeableRange = 100;
		}
	}
#section all
};

class RemoveRegionStatus : BonusEffect {
	Document doc("Remove a status effect from everything in the target region.");
	Argument type(AT_Status, doc="Type of status effect to remove.");
	Argument empire_limited(AT_Boolean, "True", doc="Whether the status should be limited to the target empire.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		Region@ region = cast<Region>(obj);
		if(region is null)
			@region = obj.region;
		if(region is null)
			return;
		if(!empire_limited.boolean)
			@emp = null;
		region.removeRegionStatus(emp, uint(type.integer));
	}
#section all
};

tidy final class RegionData {
	Region@ region = null;
}

class DamageIfLeavesRegion : GenericEffect {
	Document doc("Deal percent max hp damage to the object if it leaves its starting region.");
	Argument amount(AT_Decimal, "0.01", doc="Percent damage per second.");

#section server
	void enable(Object& obj, any@ data) const override {
		RegionData regionData;
		data.store(@regionData);
		@regionData.region = obj.region;
	}

	void tick(Object& obj, any@ data, double time) const override {
		RegionData@ regionData;
		data.retrieve(@regionData);

		Region@ region = obj.region;
		if(region !is regionData.region) {
			if (obj.isShip) {
				Ship@ ship = cast<Ship>(obj);
				const Blueprint@ bp = ship.blueprint;
				const Design@ design = bp.design;
				double maxHP = (design.totalHP - bp.removedHP) * bp.hpFactor;
				ship.damageAllHexes(maxHP * amount.decimal * time);
			} else if (obj.isPlanet) {
				Planet@ planet = cast<Planet>(obj);
				planet.dealPlanetDamage(planet.MaxHealth * amount.decimal * time);
			} else if (obj.isStar) {
				Star@ star = cast<Star>(obj);
				star.dealStarDamage(star.MaxHealth * amount.decimal * time);
			}
			// TODO: Orbital dps
		}
	}

	void save(any@ data, SaveFile& file) const override {
		RegionData@ regionData;
		data.retrieve(@regionData);
		file << regionData.region;
	}

	void load(any@ data, SaveFile& file) const override {
		RegionData regionData;
		file >> regionData.region;
		data.store(regionData);
	}
#section all
};
