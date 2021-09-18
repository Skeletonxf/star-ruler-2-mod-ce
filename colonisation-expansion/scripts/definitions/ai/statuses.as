import hooks;

// This is a dummy class as these hooks exist only to be casted and effectively
// checked for the presence of by dragon AI code, and hence do not depend on
// or use any Consider AI component infrastructure
class StatusAI : Hook {
};

class NegativeEnergyIncome : StatusAI {
	Document doc("This status costs energy income.");
	Argument energy_maintenance(AT_Decimal, "3", doc="Energy maintenance per second.");
	Argument min_level(AT_Integer, "1", doc="Minimum level the planet needs to be at for the energy income to be required.");
}

// TODO: Dragon First AI should care about this
class UnremovableDefaultBuilding : StatusAI {
	Document doc("This condition adds a building we can't remove.");
}

class NegativePopulationCap : StatusAI {
	Document doc("This status/condition reduces max population.");
}

class NegativePressureCap : StatusAI {
	Document doc("This status/condition reduces pressure capacity.");
}

class ResearchIncome : StatusAI {
	Document doc("This status/condition grants research income.");
}

class ResearchBoost : StatusAI {
	Document doc("This status/condition grants research points.");
}

class ExtraPressure : StatusAI {
	Document doc("This status/condition grants extra pressure points.");
	Argument pressure(AT_Integer, "1", doc="Pressure granted.");
}
