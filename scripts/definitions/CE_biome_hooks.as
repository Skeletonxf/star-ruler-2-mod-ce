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
