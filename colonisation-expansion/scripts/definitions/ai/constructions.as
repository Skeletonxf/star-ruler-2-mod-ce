import hooks;

// This is a dummy class as these hooks exist only to be casted and effectively
// checked for the presence of by modded AI code, and hence do not depend on
// or use any Consider AI component infrastructure
class ConstructionAI : Hook {
};

class AsCreatedPopulationIncome : ConstructionAI {
	Document doc("This construction gives max population to the building planet which grants net income.");
	Argument population(AT_Integer, "0", doc="Max population increase.");
}

class AsConstructedResource : ConstructionAI {
	Document doc("This construction spawns a new resource type on the planet that makes it.");
	Argument resource(AT_PlanetResource, doc="Resource to match import requests to.");
}

class ShortTermIncomeLoss : ConstructionAI {
	Document doc("This construction should not be used if the AI's economy isn't already strong since it causes short term economic loss.");
	Argument spare_budget(AT_Decimal, "1000", doc="Spare development budget that should be available before considering this construction");
}
