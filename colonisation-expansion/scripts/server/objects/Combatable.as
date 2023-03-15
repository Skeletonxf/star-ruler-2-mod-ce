import saving;

// How much time a ship needs to be out of combat for before we consider
// it to not have recently been in combat, at which point we may enable
// things like % hp based repair again.
const float TIME_OUTSIDE_COMBAT_STILL_RECENT = 60;

class Combatable {
	float recentlyInCombatTimer = 0.0;
	float combatTimer = 0.f;

	void save(SaveFile& file) {
		file << recentlyInCombatTimer;
		file << combatTimer;
	}

	void load(SaveFile& file) {
		file >> recentlyInCombatTimer;
		file >> combatTimer;
	}

	void occasional_tick(float time, bool engaged) {
		if(engaged) {
			// 5 -> 25, even lasers struggle to maintain sub 5 seconds continual damage
			combatTimer = 25.f;
			recentlyInCombatTimer = TIME_OUTSIDE_COMBAT_STILL_RECENT;
		} else {
			combatTimer -= time;
			if (combatTimer <= 0.f) {
				recentlyInCombatTimer -= time;
			}
		}
	}

	bool inCombat() {
		return combatTimer > 0.0;
	}

	bool inRecentCombat() {
		return recentlyInCombatTimer > 0.0;
	}
}
