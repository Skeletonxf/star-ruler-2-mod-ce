import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;

interface ConstructionsTracker {
	/// Registers a construction to be tracked by the implementation
	void trackConstruction(ConstructionTracker@ project);

	/// Checks if a construction type is tracked as being built currently
	bool isConstructing(const ConstructionType& type);
}

/**
 * Tracks a ConstructionRequest AND the reason we made it, so we can respond
 * appropriately if it gets cancelled.
 */
class ConstructionTracker {
	// Construction request we are tracking
	ConstructionRequest@ constructionRequest;
	// Nullable set of reasons we made the construction request:
	// - To meet an import data
	ImportData@ importRequestReason;

	ConstructionTracker(ConstructionRequest@ constructionRequest) {
		@this.constructionRequest = constructionRequest;
	}

	void save(Planets& planets, Resources& resources, SaveFile& file) {
		planets.saveConstructionRequest(file, constructionRequest);
		if (importRequestReason !is null) {
			file.write1();
			resources.saveImport(file, importRequestReason);
		} else {
			file.write0();
		}
	}

	ConstructionTracker(Planets& planets, Resources& resources, SaveFile& file) {
		@this.constructionRequest = planets.loadConstructionRequest(file);
		if (file.readBit()) {
			@this.importRequestReason = resources.loadImport(file);
		}
	}

	const ConstructionType@ constructionType() {
		if (constructionRequest is null) {
			return null;
		}
		return constructionRequest.type;
	}
}
