import research;
from research import TechnologyHook;
import bonus_effects;
from generic_effects import GenericEffect;

class RequireSubsystemUnlocked : TechnologyHook {
	Document doc("This requires a particular subsystem to be unlocked.");
	Argument subsystem(AT_Subsystem, doc="Identifier of the subsystem to check.");

	bool canUnlock(TechnologyNode@ node, Empire& emp) const override {
		return emp.isUnlocked(getSubsystemDef(subsystem.integer));
	}
};

class RequireEither : TechnologyHook {
	Document doc("This requires either of two conditions to apply to allow unlocking");
	Argument condition_one(AT_Hook, "research_effects::ITechnologyHook");
	Argument condition_two(AT_Hook, "research_effects::ITechnologyHook");

	ITechnologyHook@ hook1;
	ITechnologyHook@ hook2;

	bool instantiate() override {
		@hook1 = cast<ITechnologyHook>(parseHook(condition_one.str, "research_effects::", required=false));
		if(hook1 is null) {
			error("RequireEither(): could not find first condition: "+escape(condition_one.str));
			return false;
		}
		@hook2 = cast<ITechnologyHook>(parseHook(condition_two.str, "research_effects::", required=false));
		if(hook2 is null) {
			error("RequireEither(): could not find second condition: "+escape(condition_two.str));
			return false;
		}
		return TechnologyHook::instantiate();
	}

	bool canUnlock(TechnologyNode@ node, Empire& emp) const override {
		return hook1.canUnlock(node, emp) || hook2.canUnlock(node, emp);
	}
};

// Cache system defs to check things are unlocked
const SubsystemDef@ hyperdriveSubsystem = getSubsystemDef("Hyperdrive");
const SubsystemDef@ jumpdriveSubsystem = getSubsystemDef("Jumpdrive");
const SubsystemDef@ gateSubsystem = getSubsystemDef("GateModule");
const SubsystemDef@ slipstreamSubsystem = getSubsystemDef("Slipstream");

class RequireEmpireDistinctFTLTypesGTE : TechnologyHook {
	Document doc("This technology can only be researched if an empire has at least a particular value of different FTL types unlocked.");
	Argument value(AT_Decimal, doc="Required value.");
	Argument text(AT_Locale, doc="Requirement text to display.");

	double countFTL(Empire& emp) {
		if (emp is null) {
			return 0;
		}
		double distinctFTL = 0;
		bool hasHyperdrives = emp.isUnlocked(hyperdriveSubsystem);
		bool hasJumpdrives = emp.isUnlocked(jumpdriveSubsystem);
		bool hasGates = emp.isUnlocked(gateSubsystem);
		bool hasFling = emp.HasFling >= 1;
		bool hasSlipstreams = emp.isUnlocked(slipstreamSubsystem);
		if (hasHyperdrives) {
			distinctFTL += 1;
		}
		if (hasJumpdrives) {
			distinctFTL += 1;
		}
		if (hasGates) {
			distinctFTL += 1;
		}
		if (hasFling) {
			distinctFTL += 1;
		}
		if (hasSlipstreams) {
			distinctFTL += 1;
		}
		return distinctFTL;
	}

	bool canUnlock(TechnologyNode@ node, Empire& emp) const override {
		return countFTL(emp) >= value.decimal;
	}

	void addToDescription(TechnologyNode@ node, Empire@ emp, string& desc) const override {
		double count = countFTL(emp);

		Color col;
		if(count >= value.decimal)
			col = colors::Green;
		else
			col = colors::Red;

		string req = format(text.str, standardize(count,true), standardize(value.decimal,true));
		req = format(locale::RESEARCH_REQ, req, toString(col));
		desc += "\n\n"+req;
	}
};
