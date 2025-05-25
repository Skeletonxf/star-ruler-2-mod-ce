import saving;
import attributes;
from influence_global import giveRandomReward, DiplomacyEdictType;

// How much time a ship needs to be out of combat for before we consider
// it to not have recently been in combat, at which point we may enable
// things like % hp based repair again.
const float TIME_OUTSIDE_COMBAT_STILL_RECENT = 60;

class Combatable {
	float recentlyInCombatTimer = 0.0;
	float combatTimer = 0.f;
	Empire@ killCredit;

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

	void rewardKiller(double maintenanceOfDestroyed, Empire@ owner, double fleetStrength) {
		Empire@ master = killCredit.SubjugatedBy;
		if(master !is null && master.getEdictType() == DET_Conquer) {
			if(master.getEdictEmpire() is owner) {
				giveRandomReward(killCredit, double(maintenanceOfDestroyed) / 100.0);
			}
		}

		if (owner !is null) {
			double reward = killCredit.DestroyShipReward + owner.ShipDestroyBounty;
			if(reward > 0.001) {
				reward = floor(reward * maintenanceOfDestroyed);
				if(reward >= 1.0)
					killCredit.addBonusBudget(int(reward));
			}
		}

		if(owner.major && fleetStrength >= 1000.0)
			killCredit.modAttribute(EA_EnemyFlagshipsDestroyed, AC_Add, 1.0);

		if(owner !is null && owner.valid && killCredit !is owner)
			owner.recordStatDelta(stat::ShipsLost, 1);

		if(killCredit !is null && killCredit !is owner && killCredit.valid)
			killCredit.recordStatDelta(stat::ShipsDestroyed, 1);
	}
}
