import empire_ai.weasel.WeaselAI;
from empire_ai.weasel.ftl.generic import FTLGeneric;

// Class for FTL incomes that we are aiming for.
class FTLResourceIncomes {
	double FTLIncome = 1.0;
	double FTLStorage = 0.0;
	FTLGeneric@ ftl;

	bool requestsFTLStorage(AI& ai) {
		if (!ftl.hasAnyFTL()) {
			return false;
		}
		double capacity = ai.empire.FTLCapacity;
		if(FTLStorage <= capacity)
			return false;
		if(ai.empire.FTLStored < capacity * 0.5)
			return false;
		return true;
	}

	bool requestsFTLIncome(AI& ai) {
		if (!ftl.hasAnyFTL()) {
			return false;
		}
		double income = ai.empire.FTLIncome;
		double unused = income - ai.empire.FTLUse;
		if (unused < FTLIncome) {
			return true;
		}
		if(ai.empire.FTLStored < ai.empire.FTLCapacity * 0.1)
			return true;
		return false;
	}

	void save(SaveFile& file) {
		file << FTLIncome;
		file << FTLStorage;
	}

	void load(SaveFile& file) {
		file >> FTLIncome;
		file >> FTLStorage;
	}
}

interface FTLRequirements {
	bool requestsFTLStorage();
	bool requestsFTLIncome();
}
