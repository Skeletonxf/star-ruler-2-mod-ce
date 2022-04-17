/**
 * Color compability checks for a leader (flagship/planet) to build or autofill a support ship design with alpha/beta/gamma colors.
 *
 * The colors of the tags in the support ship design need to match the color checks the flagship has.
 */
bool meetsColorCompatibility(const Design@ dsg, bool planetDefenseGen, bool flagshipDefenseGen, bool alphaDefenseGen, bool betaDefenseGen, bool gammaDefenseGen) {
	if (planetDefenseGen && dsg.hasTag(ST_IsNotSpawnPlanets))
		return false;
	if (flagshipDefenseGen && dsg.hasTag(ST_IsOnlySpawnPlanets))
		return false;

	bool coloredCheck = alphaDefenseGen || betaDefenseGen || gammaDefenseGen;
	// accept supports which meet any of the (up to) three color checks
	// the spawning object applies
	// (if supports had to meet all checks this would always fail for
	// more than one color set on the spawning object)
	if (coloredCheck) {
		return (alphaDefenseGen && dsg.hasTag(ST_IsAlphaDefense))
			|| (betaDefenseGen && dsg.hasTag(ST_IsBetaDefense))
			|| (gammaDefenseGen && dsg.hasTag(ST_IsGammaDefense));
	} else {
		return true;
	}
}

class LeaderDefense {
	bool planetDefense = false;
	bool flagshipDefense = false;
	bool alphaDefense = false;
	bool betaDefense = false;
	bool gammaDefense = false;

	void getFor(Object& obj) {
		planetDefense = obj.isPlanet;
		flagshipDefense = obj.isShip;
		alphaDefense = false;
		betaDefense = false;
		gammaDefense = false;
		if (flagshipDefense) {
			Ship@ ship = cast<Ship>(obj);
			if (ship !is null) {
				const Design@ dsg = ship.blueprint.design;
				alphaDefense = dsg.hasTag(ST_IsAlphaDefense);
				betaDefense = dsg.hasTag(ST_IsBetaDefense);
				gammaDefense = dsg.hasTag(ST_IsGammaDefense);
			}
		}
	}
}
