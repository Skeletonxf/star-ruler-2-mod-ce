import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import biomes;
import abilities;
from abilities import AbilityHook;
#section server
import Planet@ spawnPlanetSpec(const vec3d& point, const string& resourceSpec, bool distributeResource = true, double radius = 0.0, bool physics = true) from "map_effects";
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
