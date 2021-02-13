import buildings;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
from ai.buildings import Buildings, BuildingAI, BuildingUse;

interface BuildingTracker {
	/// Registers a building to be tracked by the implementation
	void trackBuilding(BuildTracker@ build);

	/// Checks if a building type is tracked as being built currently
	bool isBuilding(const BuildingType& type);
}

/**
 * Tracks a BuildingRequest AND the reason we made it, so we can respond
 * appropriately if it gets cancelled.
 */
class BuildTracker {
	// Building request we are tracking
	BuildingRequest@ buildingRequest;
	// Nullable set of reasons we made the building request:
	// - To meet an import data
	ImportData@ importRequestReason;

	BuildTracker(BuildingRequest@ buildingRequest) {
		@this.buildingRequest = buildingRequest;
	}

	void save(Planets& planets, Resources& resources, SaveFile& file) {
		planets.saveBuildingRequest(file, buildingRequest);
		if (importRequestReason !is null) {
			file.write1();
			resources.saveImport(file, importRequestReason);
		} else {
			file.write0();
		}
	}

	BuildTracker(Planets& planets, Resources& resources, SaveFile& file) {
		@this.buildingRequest = planets.loadBuildingRequest(file);
		if (file.readBit()) {
			@this.importRequestReason = resources.loadImport(file);
		}
	}

	const BuildingType@ buildingType() {
		if (buildingRequest is null) {
			return null;
		}
		return buildingRequest.type;
	}
}
