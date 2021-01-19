#priority init 10

enum StatType {
	ST_Hex,
	ST_Subsystem,
	ST_Global,
};

enum SysVariableType {
	SVT_SubsystemVariable,
	SVT_HexVariable,
	SVT_ShipVariable,
	// [[ MODIFY BASE GAME START ]]
	SVT_CustomVariable
	// [[ MODIFY BASE GAME END ]]
};

enum StatAggregate {
	SA_Sum,
};

enum StatDisplayMode {
	SDM_Normal,
	SDM_Short,
};

int MASS_CUSTOM_VARIABLE = -2;
int SUPPORT_CAPACITY_CUSTOM_VARIABLE = -3;
int REPAIR_CUSTOM_VARIABLE = -4;
int TOTAL_MAINT_DISCOUNT_VARIABLE = -5;
int SUPPLY_DRAIN_CUSTOM_VARIABLE = -6;

class DesignStat {
	uint index = 0;
	string ident;
	string name;
	string description;
	string suffix;
	Sprite icon;
	Color color;
	StatDisplayMode display = SDM_Normal;

	int reqTag = -1;
	int secondary = -1;

	StatType type;

	SysVariableType varType;
	int variable;
	int usedVariable;

	SysVariableType divType;
	int divVar = -1;

	int importance;

	StatAggregate aggregate;
	double defaultValue;

	// [[ MODIFY BASE GAME START ]]
	bool alwaysShow = false;
	// [[ MODIFY BASE GAME END ]]

	DesignStat() {
		importance = 0;
		aggregate = SA_Sum;
		varType = SVT_SubsystemVariable;
		defaultValue = 0;
		variable = -1;
		usedVariable = -1;
	}
};

class DesignStats {
	DesignStat@[] stats;
	double[] values;
	double[] used;

	void dump() {
		for(uint i = 0, cnt = stats.length; i < cnt; ++i)
			print(stats[i].name+": "+values[i]);
	}
};

namespace design_stats {
	bool hasValue(const ::Design@ dsg, const ::Subsystem@ sys, ::DesignStat@ stat) {
		switch(stat.varType) {
			case ::SVT_HexVariable:
				return sys.has(::HexVariable(stat.variable));
			case ::SVT_SubsystemVariable:
				return sys.has(::SubsystemVariable(stat.variable)) && sys.variable(::SubsystemVariable(stat.variable)) != 0;
		}
		return false;
	}

	// [[ MODIFY BASE GAME START ]]
	/**
	 * Applies the mass scaling factor from empire stat variables on a per hex or subsystem
	 * calculation.
	 */
	double massScalingFactor(double baseMass, bool isSupportHex = false, bool isRepairHex = false) {
		if (playerEmpire is null) {
			return baseMass;
		}
		double mass = baseMass * playerEmpire.EmpireMassFactor;
		if (isSupportHex) {
			// increase mass by support capacity mass factor, in
			// proportion to the amount of support capacity on the ship
			double bonusMass = baseMass * playerEmpire.EmpireMassFactor;
			mass += bonusMass * max(playerEmpire.EmpireSupportCapacityMassFactor - 1.0, 0.0);
		}
		if (isRepairHex) {
			// also increase mass by repair mass factor, in proportion
			// to the amount of repair on the ship
			double repairBonusMass = baseMass * playerEmpire.EmpireMassFactor;
			mass += repairBonusMass * max(playerEmpire.EmpireRepairMassFactor - 1.0, 0.0);
		}
		return mass;
	}

	double getValue(const Design@ dsg, const Subsystem@ sys, vec2u hex, SysVariableType type, int var, int aggregate = 0) {
		if(type == SVT_HexVariable) {
			if(hex != vec2u(uint(-1))) {
				// [[ MODIFY BASE GAME START ]]
				if (HexVariable(var) == HV_Mass) {
					return massScalingFactor(
						dsg.variable(hex, HexVariable(var)),
						isSupportHex=sys !is null && sys.has(HV_SupportCapacityMass),
						isRepairHex=sys !is null && sys.has(HV_RepairMass)
					);
				}
				// [[ MODIFY BASE GAME END ]]
				return dsg.variable(hex, HexVariable(var));
			}
			else if(sys !is null) {
				double val = 0.0;
				for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
					switch(aggregate) {
						case ::SA_Sum:
							val += double(sys.hexVariable(HexVariable(var), i));
						break;
					}
				}
				// [[ MODIFY BASE GAME START ]]
				if (HexVariable(var) == HV_Mass) {
					return massScalingFactor(
						val,
						isSupportHex=sys.has(HV_SupportCapacityMass),
						isRepairHex=sys.has(HV_RepairMass)
					);
				}
				// [[ MODIFY BASE GAME END ]]
				return val;
			}
			else {
				double val = 0.0;
				for(uint n = 0, ncnt = dsg.subsystemCount; n < ncnt; ++n) {
					auto@ sys = dsg.subsystem(n);
					if(sys.has(HexVariable(var))) {
						// [[ MODIFY BASE GAME START ]]
						if (HexVariable(var) == HV_Mass) {
							for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
								switch(aggregate) {
									case ::SA_Sum:
										val += massScalingFactor(
											double(sys.hexVariable(HexVariable(var), i)),
											isSupportHex=sys.has(HV_SupportCapacityMass),
											isRepairHex=sys.has(HV_RepairMass)
										);
									break;
								}
							}
						} else {
							for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
								switch(aggregate) {
									case ::SA_Sum:
										val += double(sys.hexVariable(HexVariable(var), i));
									break;
								}
							}
						}
						// [[ MODIFY BASE GAME END ]]
					}
				}
				return val;
			}
		}
		else if(type == SVT_SubsystemVariable) {
			if(sys !is null) {
				return dsg.variable(sys, SubsystemVariable(var));
			}
			else {
				double val = 0.0;
				for(uint n = 0, ncnt = dsg.subsystemCount; n < ncnt; ++n) {
					auto@ sys = dsg.subsystem(n);
					if(sys.has(SubsystemVariable(var))) {
						switch(aggregate) {
							case ::SA_Sum:
								val += double(dsg.variable(sys, SubsystemVariable(var)));
							break;
						}
					}
				}
				return val;
			}
		}
		else if(type == SVT_ShipVariable) {
			return dsg.variable(ShipVariable(var));
		}
		// [[ MODIFY BASE GAME START ]]
		else if ((type == SVT_CustomVariable) && (var == MASS_CUSTOM_VARIABLE)) {
			// Custom mass formula
			if (playerEmpire !is null) {
				double mass = dsg.total(HV_Mass) * playerEmpire.EmpireMassFactor;
				// increase mass by support capacity mass factor, in
				// proportion to the amount of support capacity on the ship
				double bonusMass = dsg.total(HV_SupportCapacityMass) * playerEmpire.EmpireMassFactor;
				mass += bonusMass * max(playerEmpire.EmpireSupportCapacityMassFactor - 1.0, 0.0);
				// also increase mass by repair mass factor, in proportion
				// to the amount of repair on the ship
				double repairBonusMass = dsg.total(HV_RepairMass) * playerEmpire.EmpireMassFactor;
				mass += repairBonusMass * max(playerEmpire.EmpireRepairMassFactor - 1.0, 0.0);
				return mass;
			}
			return dsg.total(HV_Mass); // should never happen
		}
		else if ((type == SVT_CustomVariable) && (var == SUPPORT_CAPACITY_CUSTOM_VARIABLE)) {
			// Custom support capacity formula
			if (playerEmpire !is null) {
				return dsg.total(SV_SupportCapacity) * playerEmpire.EmpireSupportCapacityFactor;
			}
			return dsg.total(SV_SupportCapacity); // should never happen
		}
		else if ((type == SVT_CustomVariable) && (var == REPAIR_CUSTOM_VARIABLE)) {
			// Custom shipwide repair formula
			if (playerEmpire !is null) {
				return dsg.total(SV_Repair) * playerEmpire.EmpireRepairFactor;
			}
			return dsg.total(SV_Repair); // should never happen
		}
		else if ((type == SVT_CustomVariable) && (var == TOTAL_MAINT_DISCOUNT_VARIABLE)) {
			// Custom total maintence discount formula
			// Honestly this one should be done in data files by extending the formula logic but this is less effort
			return min(dsg.variable(ShV_RamjetDiscount) + dsg.variable(ShV_HullDiscount), 60.0);
		}
		else if ((type == SVT_CustomVariable) && (var == SUPPLY_DRAIN_CUSTOM_VARIABLE)) {
			// Custom shipwide repair supply drain formula
			if (playerEmpire !is null) {
				double nonRepairSupplyDrain = dsg.total(SV_SupplyDrain) - dsg.total(SV_RepairSupplyCost);
				double repairSupplyDrain = dsg.total(SV_RepairSupplyCost) * playerEmpire.EmpireRepairFactor;
				return nonRepairSupplyDrain + repairSupplyDrain;
			}
			return dsg.total(SV_SupplyDrain); // should never happen
		}
		// [[ MODIFY BASE GAME END ]]
		return 0.0;
	}

	::DesignStat@[] hexStats;
	::DesignStat@[] sysStats;
	::DesignStat@[] globalStats;
};

DesignStats@ getDesignStats(const Design@ dsg) {
	DesignStats stats;

	uint sysCnt = dsg.subsystemCount;
	for(uint i = 0, cnt = design_stats::globalStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::globalStats[i];
		if(stat.reqTag != -1 && !dsg.hasTag(SubsystemTag(stat.reqTag)))
			continue;
		bool has = false;
		double val = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.varType, stat.variable, stat.aggregate);
		double used = -1.0;
		if(stat.usedVariable != -1)
			used = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.varType, stat.usedVariable, stat.aggregate);
		if(stat.divVar != -1) {
			double div = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.divType, stat.divVar, stat.aggregate);
			if(div != 0.0)
				val /= div;
		}

		// [[ MODIFY BASE GAME START ]]
		if(val != 0.0 || stat.alwaysShow) {
			// [[ MODIFY BASE GAME END ]]
			stats.stats.insertLast(stat);
			stats.values.insertLast(val);
			stats.used.insertLast(used);
		}
	}

	return stats;
}

DesignStats@ getHexStats(const Design@ dsg, vec2u hex) {
	DesignStats stats;

	const Subsystem@ sys = dsg.subsystem(hex);
	for(uint i = 0, cnt = design_stats::hexStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::hexStats[i];
		if(stat.reqTag != -1 && !dsg.hasTag(stat.reqTag))
			continue;
		if(design_stats::hasValue(dsg, sys, stat)) {
			float val = design_stats::getValue(dsg, sys, hex, stat.varType, stat.variable, stat.aggregate);
			if(val != 0.f) {
				stats.stats.insertLast(stat);
				stats.values.insertLast(val);
			}
		}
	}

	return stats;
}


DesignStats@ getSubsystemStats(const Design@ dsg, const Subsystem@ sys) {
	DesignStats stats;

	for(uint i = 0, cnt = design_stats::sysStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::sysStats[i];
		if(stat.reqTag != -1 && !sys.type.hasTag(stat.reqTag))
			continue;
		if(design_stats::hasValue(dsg, sys, stat)) {
			float val = design_stats::getValue(dsg, sys, vec2u(uint(-1)),
							stat.varType, stat.variable, stat.aggregate);
			if(val != 0.f) {
				stats.stats.insertLast(stat);
				stats.values.insertLast(val);
			}
		}
	}

	return stats;
}

void loadStats(const string& filename) {
	//Load stat descriptors
	ReadFile file(filename);

	DesignStat@ stat;
	array<DesignStat@>@ list;
	string key, value;
	while(file++) {
		key = file.key;
		value = file.value;

		if(key == "HexStat") {
			@list = design_stats::hexStats;
			@stat = DesignStat();
			stat.type = ST_Hex;
			stat.ident = value;
			stat.display = SDM_Short;
			stat.index = design_stats::hexStats.length;
			design_stats::hexStats.insertLast(stat);
		}
		else if(key == "SubsystemStat") {
			@list = design_stats::sysStats;
			@stat = DesignStat();
			stat.ident = value;
			stat.type = ST_Subsystem;
			stat.display = SDM_Short;
			stat.index = design_stats::sysStats.length;
			design_stats::sysStats.insertLast(stat);
		}
		else if(key == "GlobalStat") {
			@list = design_stats::globalStats;
			@stat = DesignStat();
			stat.ident = value;
			stat.type = ST_Global;
			stat.index = design_stats::globalStats.length;
			design_stats::globalStats.insertLast(stat);
		}
		else if(key == "Name") {
			stat.name = localize(value);
		}
		else if(key == "Description") {
			stat.description = localize(value);
		}
		else if(key == "Variable") {
			if(value.startswith("Hex.")) {
				value = value.substr(4);
				stat.varType = SVT_HexVariable;
				stat.variable = getHexVariable(value);
			}
			else if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.varType = SVT_ShipVariable;
				stat.variable = getShipVariable(value);
			}
			else {
				stat.varType = SVT_SubsystemVariable;
				stat.variable = getSubsystemVariable(value);
			}
		}
		else if(key == "UsedVariable") {
			if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.usedVariable = getShipVariable(value);
			}
			else {
				error("UsedVariable needs to be a ship variable.");
			}
		}
		else if(key == "Default") {
			stat.defaultValue = toDouble(value);
		}
		else if(key == "Aggregate") {
			if(value == "Sum") {
				stat.aggregate = SA_Sum;
				stat.defaultValue = 0;
			}
		}
		else if(key == "Importance") {
			stat.importance = toInt(value);
		}
		else if(key == "Icon") {
			stat.icon = getSprite(value);
		}
		else if(key == "Color") {
			stat.color = toColor(value);
		}
		else if(key == "Suffix") {
			stat.suffix = localize(value);
		}
		else if(key == "RequireTag") {
			stat.reqTag = getSubsystemTag(value);
		}
		// [[ MODIFY BASE GAME START ]]
		else if(key == "AlwaysShow") {
			stat.alwaysShow = toBool(value);
		}
		// custom mass formulas that use the empire attributes to apply
		// First building stat modifiers
		else if (key == "MassFormula") {
			stat.varType = SVT_CustomVariable;
			stat.variable = MASS_CUSTOM_VARIABLE;
		}
		else if (key == "DivByMassFormula") {
			stat.divType = SVT_CustomVariable;
			stat.divVar = MASS_CUSTOM_VARIABLE;
		}
		else if (key == "SupportCapacityFormula") {
			stat.varType = SVT_CustomVariable;
			stat.variable = SUPPORT_CAPACITY_CUSTOM_VARIABLE;
		}
		else if (key == "RepairFormula") {
			stat.varType = SVT_CustomVariable;
			stat.variable = REPAIR_CUSTOM_VARIABLE;
		}
		else if (key == "SupplyDrainFormula") {
			stat.varType = SVT_CustomVariable;
			stat.variable = SUPPLY_DRAIN_CUSTOM_VARIABLE;
		}
		else if (key == "TotalMaintDiscountFormula") {
			stat.varType = SVT_CustomVariable;
			stat.variable = TOTAL_MAINT_DISCOUNT_VARIABLE;
		}
		// [[ MODIFY BASE GAME END ]]
		else if(key == "Secondary") {
			int sec = -1;
			for(uint i = 0, cnt = list.length; i < cnt; ++i) {
				if(list[i].ident.equals_nocase(value)) {
					sec = int(i);
					break;
				}
			}
			if(sec == -1)
				file.error("Could not find previous stat for secondary: "+value);
			else
				stat.secondary = sec;
		}
		else if(key == "DivBy") {
			if(value.startswith("Hex.")) {
				value = value.substr(4);
				stat.divType = SVT_HexVariable;
				stat.divVar = getHexVariable(value);
			}
			else if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.divType = SVT_ShipVariable;
				stat.divVar = getShipVariable(value);
			}
			else {
				stat.divType = SVT_SubsystemVariable;
				stat.divVar = getSubsystemVariable(value);
			}
		}
	}
}

void init() {
	FileList list("data/design_stats", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadStats(list.path[i]);
}
