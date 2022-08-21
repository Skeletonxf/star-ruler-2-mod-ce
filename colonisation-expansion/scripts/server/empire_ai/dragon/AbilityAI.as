import empire_ai.weasel.WeaselAI;
import abilities;
from ai.abilities import AbilitiesAI, AsCreatedCard, CanFireIonCannon;

/**
 * CE mod code for the AI to track abilities on objects it owns.
 */

/**
 * Stateless closed superclass of AbilityTypes
 *
 * There is not much in common between different abilities, so this mainly
 * serves as an interface to try to cast to subtypes.
 */
class AbilityTypeAI {
	const Ability@ type;
}

/**
 * Constructs the AbilityTypeAI for an Ability. Will return null if the Ability
 * has no recognised AI hooks.
 */
AbilityTypeAI@ abilityTypeAIFactory(const Ability@ ability) {
	const AbilityType@ type = ability.type;
	if (type is null)
		return null;

	if (type.ai.length == 0)
		return null;

	// TODO: Multiple ability (hooks) on one object
	for (uint i = 0, cnt = type.ai.length; i < cnt; ++i) {
		auto@ hook = cast<AbilitiesAI>(type.ai[i]);
		if (hook !is null) {
			auto@ buyCard = cast<AsCreatedCard>(hook);
			if (buyCard !is null) {
				return AsCreatedCardAbility(ability, buyCard);
			}
			auto@ utilityWeapon = cast<CanFireIonCannon>(hook);
			if (utilityWeapon !is null) {
				return CanFireIonCannonAbility(ability);
			}
		}
	}
	return null;
}

/**
 * TODO: AI helpers to actually buy the card
 * TODO: Call this from Diplomacy.as
 */
class AsCreatedCardAbility : AbilityTypeAI {
	AsCreatedCard@ buyCard;
	AsCreatedCardAbility(const Ability@ type, AsCreatedCard@ buyCard) {
		@this.type = type;
		@this.buyCard = buyCard;
	}
}

class CanFireIonCannonAbility : AbilityTypeAI {
	CanFireIonCannonAbility(const Ability@ type) {
		@this.type = type;
	}
}

interface AbilitiesComponentI {
	void remove(AbilityAI@ data);
	void removedAbilityAI(AbilityAI@ abilityAI);
}

class AbilityAI {
	Object@ obj;
	array<AbilityTypeAI@> abilities;

	bool init(AI& ai, AbilitiesComponentI& abilitiesComponent) {
		return checkAbilities();
	}

	/**
	 * Checks the object for abilities the AI knows how to use, returning
	 * true if some were found.
	 */
	bool checkAbilities() {
		if (obj is null) {
			return false;
		}

		if (obj.hasAbilities) {
			this.abilities.length = 0;

			array<Ability> abilities;
			abilities.syncFrom(obj.getAbilities());

			for (uint i = 0, cnt = abilities.length; i < cnt; ++i) {
				Ability@ ability = abilities[i];
				const AbilityType@ type = ability.type;

				AbilityTypeAI@ abilityTypeAI = abilityTypeAIFactory(ability);
				if (abilityTypeAI is null)
					continue;

				this.abilities.insertLast(abilityTypeAI);
			}
		}

		// TODO: Once we're tracking more than one kind of ability an object
		// can have this is going to need to return the number
		return this.abilities.length > 0;
	}

	void save(AbilitiesComponentI& abilitiesComponent, SaveFile& file) {
		file << obj;
	}

	void load(AbilitiesComponentI& abilitiesComponent, SaveFile& file) {
		file >> obj;
	}

	void remove(AI& ai, AbilitiesComponentI& abilitiesComponent) {
		abilitiesComponent.removedAbilityAI(this);
	}

	void tick(AI& ai, AbilitiesComponentI& abilitiesComponent) {
		//Deal with losing object ownership or no longer having abilities
		if(obj is null || !obj.valid || obj.owner !is ai.empire || !obj.hasAbilities) {
			abilitiesComponent.remove(this);
			return;
		}

		// Refresh our info on the abilities this object has
		bool stillHasAbilities = checkAbilities();

		if (!stillHasAbilities) {
			abilitiesComponent.remove(this);
			return;
		}
	}
}

/**
 * An interface for other components to register themselves as listeners onto
 * the Abilities component so they can respond to events without having to
 * track the lifetimes of everything themselves.
 */
interface AbilitiesEventListener {
	/**
	 * An AbilityAI that was previously tracked is no longer valid for tracking
	 */
	void onRemovedAbilityAI(AbilityAI@ abilityAI);
}
