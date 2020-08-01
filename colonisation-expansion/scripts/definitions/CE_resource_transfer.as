import abilities;

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
