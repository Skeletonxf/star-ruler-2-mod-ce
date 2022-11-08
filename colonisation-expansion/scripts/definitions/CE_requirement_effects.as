import hooks;
import resources;
import requirement_effects;
// It's already imported for gui but not server or shadow????
#section server
import bool hasInvasionMap() from "Invasion.InvasionMap";
#section shadow
import bool hasInvasionMap() from "Invasion.InvasionMap";
#section all

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

class RequireNotInvasionMap : Requirement {
	Document doc("Require that the invasion map is not present to build this.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		return !hasInvasionMap();
	}
}

class RequireInvasionMap : Requirement {
	Document doc("Require that the invasion map is present to build this.");

	bool meets(Object& obj, bool ignoreState = false) const override {
		return hasInvasionMap();
	}
}
