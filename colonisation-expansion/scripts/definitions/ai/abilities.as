import hooks;

// This is a dummy class as these hooks exist only to be casted and effectively
// checked for the presence of by modded AI code, and hence do not depend on
// or use any Consider AI component infrastructure
class AbilitiesAI : Hook {
};

class AsCreatedCard : AbilitiesAI {
	Document doc("This ability grants a particular type of card to the empire.");
	Argument card(AT_InfluenceCard, doc="Card type given.");
}

class CanFireIonCannon : AbilitiesAI {
	Document doc("This ability grants the ship the ability to manually fire a weapon like an Ion Cannon that can stop enemy ships from moving.");
}
