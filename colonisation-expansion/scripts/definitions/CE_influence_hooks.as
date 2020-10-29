import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;

// New influence based hooks added by CE will go here
// Some are still in biome hooks

class GrantOthersInfluenceCard : EmpireTrigger {
	Document doc("Give all other empires a particular influence card.");
	Argument card(AT_InfluenceCard, doc="Card type to give.");
	Argument uses(AT_Range, "1", doc="Amount of uses to give the card.");
	Argument quality(AT_Range, "0", doc="Amount of extra quality to give the card.");

	const InfluenceCardType@ type;
	bool instantiate() override {
		@type = getInfluenceCardType(card.str);
		if(type is null) {
			error("Invalid card type: "+card.str);
			return false;
		}
		return BonusEffect::instantiate();
	}

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		InfluenceCard@ card = type.create(uses=round(uses.fromRange()), quality=1+round(quality.fromRange()));
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ empire = getEmpire(i);
			if (empire.major && empire !is emp) {
				cast<InfluenceStore>(empire.InfluenceManager).addCard(empire, card);
			}
		}
	}
#section all
};

class GrantOthersLeverage : EmpireTrigger {
	Document doc("Give all other empires leverage against the empire.");
	Argument quality(AT_Range, doc="Quality factor of the leverage.");

#section server
	void activate(Object@ obj, Empire@ emp) const override {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ empire = getEmpire(i);
			if (empire.major && empire !is emp) {
				// gain leverage on emp
				empire.gainRandomLeverage(emp, quality.fromRange());
			}
		}
	}
#section all
};
