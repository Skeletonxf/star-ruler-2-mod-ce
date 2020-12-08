import empire_ai.weasel.Colonization;

interface ColonizationAbilityOwner {
	void setColonyManagement(ColonizationAbility@ colonyManagement);
}

/**
 * The interface for the colonisation mechanism our race/empire uses.
 */
interface ColonizationAbility {
	/**
	 * The colonisation sources we have
	 */
	array<ColonizationSource@> getSources();

	/**
	 * The closest source to a position
	 */
	ColonizationSource@ getClosestSource(vec3d position);

	/**
	 * The quickest source for colonising a particular planet, will
	 * likely be based on distance, but may also include other factors
	 * like Mothership population
	 */
	ColonizationSource@ getFastestSource(Planet@ colony);

	/**
	 * Update tick for the implementation
	 */
	void colonizeTick();

	/**
	 * Actually orders a colonisation command to colonise the planet
	 * in the ColonizeData with the provided source.
	 */
	void orderColonization(ColonizeData& data, ColonizationSource@ source);

	/**
	 * Saves a colonization source to the file.
	 */
	void saveSource(SaveFile& file, ColonizationSource@ source);
	/**
	 * Reads a colonization source out of the file
	 */
	ColonizationSource@ loadSource(SaveFile& file);

	void saveManager(SaveFile& file);
	void loadManager(SaveFile& file);
}

/**
 * A colony unit. For most races these are planets.
 */
interface ColonizationSource {
	/**
	 * Where this source is
	 */
	vec3d getPosition();

	/**
	 * If this is still a valid unit we can use in colonisation
	 * ie do we still own this planet or does this Mothership still exist?
	 */
	bool valid(AI& ai);

	string toString();
}
