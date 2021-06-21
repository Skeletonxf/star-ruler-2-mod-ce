import empire_ai.weasel.WeaselAI;

interface OnStarAttack {
	/**
	 * Called whenever the star loses HP or Shields. This means either someone
	 * is attacking our star, or we are attacking our own star (from a star forge???)
	 *
	 * Since the AI doesn't know how to build star forges much less order them
	 * to build something, it can safely assume the attacker is an enemy.
	 */
	void onStarAttack(AI& ai, Star@ star, double previousHP);
}

class StarAI {
	Star@ star;
	double lastKnownHP;
	double lastKnownShield;
	double lastKnownMaxShield;
	OnStarAttack@ listener;

	StarAI(OnStarAttack@ listener) {
		@this.listener = listener;
	}

	StarAI(Star@ star, OnStarAttack@ listener) {
		@this.star = star;
		@this.listener = listener;
		lastKnownHP = star.Health;
		lastKnownShield = star.Shield;
		lastKnownMaxShield = star.MaxShield;
	}

	void save(SaveFile& file) {
		file << star;
		file << lastKnownHP;
		file << lastKnownShield;
		file << lastKnownMaxShield;
	}

	void load(SaveFile& file) {
		file >> star;
		file >> lastKnownHP;
		file >> lastKnownShield;
		file >> lastKnownMaxShield;
	}

	void focusTick(AI& ai) {
		double currentHP = star.Health;
		double currentShield = star.Shield;
		double currentMaxShield = star.MaxShield;
		if (currentHP < lastKnownHP) {
			listener.onStarAttack(ai, star, lastKnownHP);
		} else if (currentShield < lastKnownShield && currentMaxShield == lastKnownMaxShield) {
			listener.onStarAttack(ai, star, lastKnownHP);
		}
		lastKnownHP = currentHP;
		lastKnownShield = currentShield;
		lastKnownMaxShield = currentMaxShield;
	}
}
