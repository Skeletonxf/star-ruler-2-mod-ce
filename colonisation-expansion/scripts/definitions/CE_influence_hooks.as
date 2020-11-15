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

tidy final class CardGenerationData {
	double lastTickTime = 0;
	double scaleFactor = 1;
}

class ScalingCardGenerationIfAttributeGTE : EmpireEffect {
	Document doc("Gives a card to the empire every x * factor seconds if an attribute is >= to an amount.");
	Argument card(AT_InfluenceCard, doc="Card type to give.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to check.");
	Argument value(AT_Decimal, "1", doc="Value to test against.");
	Argument interval(AT_Decimal, "60", doc="Base Seconds to wait between giving cards.");
	Argument scale_factor(AT_Decimal, "1.5", doc="Scaling factor to apply to base seconds, multiplying with each grant.");

#section server
	void enable(Empire& emp, any@ data) const override {
		CardGenerationData cardData;
		data.store(@cardData);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		if (emp.getAttribute(attribute.integer) < value.decimal) {
			return;
		}

		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		if (cardData is null) {
			return;
		}

		// tick every x seconds
		double scaledInterval = interval.decimal * cardData.scaleFactor;
		if (gameTime > (cardData.lastTickTime + scaledInterval)) {
			cardData.lastTickTime = gameTime;

			// give card
			const InfluenceCardType@ cardType =  getInfluenceCardType(card.str);
			if (cardType is null) {
				error("Invalid card type: "+card.str);
				return;
			}
			InfluenceCard@ card = cardType.create();
			cast<InfluenceStore>(emp.InfluenceManager).addCard(emp, card);
			cardData.scaleFactor *= scale_factor.decimal;
		} else {
			return;
		}
	}

	void disable(Empire& emp, any@ data) const override {
		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		if(cardData is null)
			return;

		@cardData = null;
		data.store(@cardData);
	}

	void save(any@ data, SaveFile& file) const override {
		CardGenerationData@ cardData;
		data.retrieve(@cardData);
		file << cardData.lastTickTime;
		file << cardData.scaleFactor;
	}

	void load(any@ data, SaveFile& file) const override {
		CardGenerationData cardData;
		file >> cardData.lastTickTime;
		file >> cardData.scaleFactor;
		data.store(cardData);
	}
#section all
};
