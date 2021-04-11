import hooks;
import abilities;
from abilities import AbilityHook;

/**
 * Filters an array of Abilities likely retrieved from an object to
 * only those which have an AbilityType that is a resource transfering
 * ability added by Colonisation Expansion.
 */
void filterToResourceTransferAbilities(array<Ability>& abilities) {
	for (int i = abilities.length - 1; i >= 0; --i) {
		Ability@ abl = abilities[i];
		// remove from list if fails filter
		if (!isResourceTransferAbility(abl)) {
			abilities.removeAt(i);
		}
	}
}

// Checks the flag set on the ability's abilitytype to determine if this
// is considered a resource transfer ability.
bool isResourceTransferAbility(Ability& ability) {
	return ability.type.isResourceTransfer;
}

class RequireHasTransferAbilities : AbilityHook {
	Document doc("Ability can only be cast if the planet has resource transfer abilities.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		if (abl.obj is null)
			return false;
		if (!abl.obj.isPlanet || !abl.obj.hasAbilities)
			return false;

		array<Ability> abilities;
		abilities.syncFrom(abl.obj.getAbilities());

		if (abilities.length == 0)
			return false;

		for (uint i = 0, cnt = abilities.length; i < cnt; ++i) {
			Ability@ ability = abilities[i];
			// found a resource transfer ability
			if (ability.type.resource !is null) {
				return true;
			}
		}
		return false;
	}
};
