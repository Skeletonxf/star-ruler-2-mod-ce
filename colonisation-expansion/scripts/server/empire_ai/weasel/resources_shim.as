import empire_ai.weasel.ImportData;

import resources;

// This would have been in the Resources component but the Resources of
// the resources file and the Resources of the Resources file have a name
// clash.

/**
 * Infers the dummy resources from a given Resources class and the
 * native/imported resources
 */
class ResourcesShim {
	array<ResourceSpec@> inferDummyResources(const Object& obj) {
		Resources availableResources;
		availableResources.clear();
		receive(obj.getResourceAmounts(), availableResources);
		array<Resource> resources;
		resources.syncFrom(obj.getAvailableResources());

		// subtract each resource the planet has from the resource
		// amounts the planet has, which will leave the dummy resources
		// (or remove everything, if availableResources had been used
		// as negative dummy resourcing, but that shouldn't happen and
		// won't cause anything bad here if it does)
		for (uint i = 0, cnt = resources.length; i < cnt; ++i) {
			Resource@ resource = resources[i];
			if (resource is null || resource.type is null) {
				continue;
			}
			if (availableResources.getAmount(resource.type) > 0) {
				availableResources.modAmount(resource.type, -1);
			}
		}

		array<ResourceSpec@> inferredDummyResourceSpecs;

		for (uint i = 0, cnt = availableResources.types.length; i < cnt; ++i) {
			uint id = availableResources.types[i];
			int amount = availableResources.amounts[i];
			auto@ type = getResource(id);
			//print("Found dummy resource of type "+type.name+" and amount "+amount);

			for (int j = 0; j < amount; ++j) {
				// assume dummy resources are always used for levelling, as
				// otherwise they would have no purpose
				ResourceSpec spec;
				spec.isLevelRequirement = true;
				// assume dummy resource was used for a level requirement or as
				// a class requirement, as again otherwise it would have had
				// no purpose
				if (type.cls !is null) {
					spec.type = RST_Class;
					@spec.cls = type.cls;
				} else {
					spec.type = RST_Level_Specific;
					spec.level = type.level;
				}
				inferredDummyResourceSpecs.insertLast(spec);
			}
		}

		return inferredDummyResourceSpecs;
	}
}
