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

// Yes this probably should just be a flag added to the AbilityType class
// but this entire file is not a hot path and I don't want to break any
// serialization or deseralization logic modifying the AbilityType class
//
// It can always be changed to refer to a flag added later, as this is
// the authoritative check for resource transfer abilties.
bool isResourceTransferAbility(Ability& ability) {
    // the identifier format for battleworlder resource transfer abilities is
    // BW<resource name>Transfer
    // There are no other resource transfer abilities at this time
    if (ability.type.ident.length < 11) {
        return false;
    }
    if (ability.type.ident[0] != 'B' || ability.type.ident[1] != 'W') {
        return false;
    }
    uint end = ability.type.ident.length - 1;
    if ((ability.type.ident[end - 7] != 'T')
        || (ability.type.ident[end - 6] != 'r')
        || (ability.type.ident[end - 5] != 'a')
        || (ability.type.ident[end - 4] != 'n')
        || (ability.type.ident[end - 3] != 's')
        || (ability.type.ident[end - 2] != 'f')
        || (ability.type.ident[end - 1] != 'e')
        || (ability.type.ident[end] != 'r')) {
        return false;
    }
    return true;
}
