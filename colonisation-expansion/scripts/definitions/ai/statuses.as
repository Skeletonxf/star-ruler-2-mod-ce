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
	// okay this one is stretching the concept of a 'generic' hook to the limits
	Argument terrestrial_only(AT_Boolean, "False", doc="Whether the energy maintenance only applies to terrestrial lifestyles.");
}

class ResearchIncome : StatusAI {
	Document doc("This status grants research income.");
}
