import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import biomes;
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
