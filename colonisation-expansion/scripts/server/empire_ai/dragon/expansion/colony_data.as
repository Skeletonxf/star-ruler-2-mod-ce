import empire_ai.weasel.Resources;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Colonization;
import empire_ai.dragon.expansion.colonization;

/**
 * Subclass of ColonizeData, with save/load methods for use here.
 */
class ColonizeData2 : ColonizeData {
	/* int id = -1;
	Planet@ target;
	Planet@ colonizeFrom;
	bool completed = false;
	bool canceled = false;
	double checkTime = -1.0; */
	// Nullable import data that might be associated with our node
	ImportData@ request;
	// The time we began actually colonising for this data, or -1
	// if we didn't start yet
	double startColonizeTime = -1;
	// Replacement of colonizeFrom, valid for any race's colony units
	ColonizationSource@ colonizeUnit;

	void save(Resources& resources, ColonizationAbility& colonyManagement, SaveFile& file) {
		file << target;
		file << colonizeFrom;
		file << completed;
		file << canceled;
		file << checkTime;
		if (request !is null) {
			file.write1();
			resources.saveImport(file, request);
		} else {
			file.write0();
		}
		file << startColonizeTime;
		colonyManagement.saveSource(file, colonizeUnit);
	}

	void load(Resources& resources, ColonizationAbility& colonyManagement, SaveFile& file) {
		file >> target;
		file >> colonizeFrom;
		file >> completed;
		file >> canceled;
		file >> checkTime;
		if (file.readBit()) {
			@this.request = resources.loadImport(file);
		}
		file >> startColonizeTime;
		@colonizeUnit = colonyManagement.loadSource(file);
	}

	bool hasTakenTooLong(double colonizePenalizeTime) {
		return startColonizeTime != -1 && gameTime > startColonizeTime + colonizePenalizeTime;
	}
};

/**
 * This is essentially the same as Colonization's ColonizePenalty but
 * with a different name to avoid name conflicts and potentially be
 * expanded later.
 */
class AvoidColonizeMarker {
	Planet@ planet;
	/**
	 * Minimum game time to consider colonising this planet again
	 */
	double until;

	void save(SaveFile& file) {
		file << planet;
		file << until;
	}

	void load(SaveFile& file) {
		file >> planet;
		file >> until;
	}

	AvoidColonizeMarker(Planet@ planet, double until) {
		@this.planet = planet;
		this.until = until;
	}

	// only for deserialisation
	AvoidColonizeMarker() {}
}
