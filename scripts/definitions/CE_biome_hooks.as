import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;
import biomes;

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
