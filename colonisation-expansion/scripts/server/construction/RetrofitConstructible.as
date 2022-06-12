import construction.Constructible;
import resources;

tidy class RetrofitConstructible : Constructible {
	Object@ fleet;
	Object@ constructFrom;

	RetrofitConstructible(Object& obj, Object@ Fleet, int cost, double labor, int extraMaint) {
		@fleet = Fleet;
		buildCost = cost;
		maintainCost = extraMaint;
		totalLabor = labor;
	}

	RetrofitConstructible(SaveFile& file) {
		Constructible::load(file);
		file >> fleet;
		if(file >= SV_0149)
			file >> constructFrom;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file << fleet;
		file << constructFrom;
	}

	bool repeat(Object& obj) {
		return false;
	}

	ConstructibleType get_type() {
		return CT_Retrofit;
	}

	string get_name() {
		return format(locale::BUILD_RETROFIT, fleet.name);
	}

	// [[ MODIFY BASE GAME START ]]
	bool cancelled = false;

	void cancel(Object& obj) {
		if (cancelled) {
			// cancel may be called followed by remove, but sometimes we might
			// only be called with remove. In both cases, we need to cancel
			// exactly once.
			return;
		}
		// probably don't need to serialise this?
		cancelled = true;
		fleet.stopFleetRetrofit(obj);
		Constructible::cancel(obj);
	}

	// Cancel on destroy
	void remove(Object& obj) {
		cancel(obj);
		Constructible::remove(obj);
	}
	// [[ MODIFY BASE GAME END ]]

	void complete(Object& obj) {
		fleet.finishFleetRetrofit(obj);
	}

	TickResult tick(Object& obj, double time) override {
		// [[ MODIFY BASE GAME START ]]
		// Cancel if no longer valid like the other constructibles
		if(obj.owner !is fleet.owner || obj.region is null || !obj.valid) {
			// [[ MODIFY BASE GAME END ]]
			cancel(obj);
			return TR_Remove;
		}
		if(constructFrom !is null) {
			if(constructFrom.region !is fleet.region) {
				cancel(obj);
				return TR_Remove;
			}
		}
		else {
			if(obj.region !is fleet.region) {
				cancel(obj);
				return TR_Remove;
			}
		}
		return TR_UsedLabor;
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << fleet;
	}
};
