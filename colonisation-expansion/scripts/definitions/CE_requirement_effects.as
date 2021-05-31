import hooks;
import resources;
import requirement_effects;

class RequireNotPlanetResource : Requirement {
	Document doc("Require that a particular resource is not present to build this.");
	Argument resource(AT_PlanetResource, doc="Type of resource to give.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(!obj.hasResources)
			return false;

		if (resource.integer >= 0) {
			return !obj.hasNativeResourceType(uint(resource.integer));
		} else {
			return false;
		}
	}
}

class RequirePlanetResource : Requirement {
	Document doc("Require that a particular resource is present to build this.");
	Argument resource(AT_PlanetResource, doc="Type of resource to give.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		if(!obj.hasResources)
			return false;

		if (resource.integer >= 0) {
			return obj.hasNativeResourceType(uint(resource.integer));
		} else {
			return false;
		}
	}
}
