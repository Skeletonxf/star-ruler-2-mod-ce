double getShieldOf(Object@ obj) {
    if (obj is null) {
        return 0;
    }
    Planet@ planet = cast<Planet>(obj);
    if (planet !is null) {
        return planet.shield;
    }
    Orbital@ orbital = cast<Orbital>(obj);
    if (orbital !is null) {
        return orbital.shield;
    }
    Ship@ ship = cast<Ship>(obj);
    if (ship !is null) {
        return ship.Shield;
    }
    Star@ star = cast<Star>(star);
    if (star !is null) {
        return star.shield;
    }
    return 0;
}

double getMaxShieldOf(Object@ obj) {
    if (obj is null) {
        return 0;
    }
    Planet@ planet = cast<Planet>(obj);
    if (planet !is null) {
        return planet.maxShield;
    }
    Orbital@ orbital = cast<Orbital>(obj);
    if (orbital !is null) {
        return orbital.maxShield;
    }
    Ship@ ship = cast<Ship>(obj);
    if (ship !is null) {
        return ship.MaxShield;
    }
    Star@ star = cast<Star>(star);
    if (star !is null) {
        return star.maxShield;
    }
    return 0;
}

/**
 * Returns a percentage from 1.0 to 0.0 of the shield percentage for the
 * object. If the object's shields are at max capacity and that capacity is
 * more than nothing, returns 1.0. If the shields are non existant or
 * completely exhausted, returns 0.0.
 */
double getShieldPercentageOf(Object@ obj) {
    if (obj is null) {
        return 0;
    }
    Planet@ planet = cast<Planet>(obj);
    if (planet !is null) {
        double maxShield = planet.maxShield;
        if (maxShield < 0.1) {
            return 0;
        }
        return planet.shield / maxShield;
    }
    Orbital@ orbital = cast<Orbital>(obj);
    if (orbital !is null) {
        double maxShield = orbital.maxShield;
        if (maxShield < 0.1) {
            return 0;
        }
        return orbital.shield / maxShield;
    }
    Ship@ ship = cast<Ship>(obj);
    if (ship !is null) {
        double maxShield = ship.Shield;
        if (maxShield < 0.1) {
            return 0;
        }
        return ship.Shield / maxShield;
    }
    Star@ star = cast<Star>(star);
    if (star !is null) {
        double maxShield = star.maxShield;
        if (maxShield < 0.1) {
            return 0;
        }
        return star.shield / maxShield;
    }
    return 0;
}
