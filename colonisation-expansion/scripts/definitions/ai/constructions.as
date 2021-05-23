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
