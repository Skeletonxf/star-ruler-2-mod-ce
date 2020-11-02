import resources;

// This would have been in the Resources component but the Resources of
// the resources file and the Resources of the Resources file have a name
// clash.

/**
 * Infers the dummy resources from a given Resources class and the
 * native/imported resources
 */
class ResourcesShim {
	Resources availableResources;

	void inferDummyResources(const Object& obj) {
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

		for (uint i = 0, cnt = availableResources.types.length; i < cnt; ++i) {
			uint id = availableResources.types[i];
			int amount = availableResources.amounts[i];
			auto@ type = getResource(id);
			print("Found dummy resource of type "+type.name+" and amount "+amount);
		}
	}
}
