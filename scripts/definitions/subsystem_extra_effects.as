import hooks;
from subsystem_effects import SubsystemEffect, SolarData;
from ability_effects import getMassFor;

class SolarThrust : SubsystemEffect {
	Document doc("Modify the ship's thrust based on how much light it is getting.");
	Argument loss(AT_Decimal, doc="Amount of efficiency lost when in deep space.");
	Argument min_boost(AT_Decimal, doc="Minimum boost when on a cold star or far away from a star.");
	Argument max_boost(AT_Decimal, doc="Maximum boost when on a hot star or close to a star.");
	Argument step(AT_Decimal, "0.05", doc="Only apply changes in steps of this size.");
	Argument temperature_max(AT_Decimal, "15000", doc="Solar temperature (modified by distance) that triggers the maximum boost.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		SolarData@ dat;
		event.data.retrieve(@dat);
		if(dat is null) {
			@dat = SolarData();
			event.data.store(@dat);
		}

		dat.timer -= time;
		if(dat.timer <= 0) {
			Object@ obj = event.obj;
			Region@ reg = obj.region;

			dat.timer += 1.0;
			if(obj.velocity.lengthSQ <= 1.0 && !obj.inCombat)
				dat.timer += 10.0;

			Ship@ ship = cast<Ship>(obj);
			double powerFactor = event.workingPercent;
			if(ship !is null) {
				const Design@ dsg = ship.blueprint.design;
				if(dsg !is null)
					powerFactor *= dsg.total(SV_SolarPower); // TODO check this doesn't accidentally count solar panels too
			}

			double newBoost = 0.0;
			if(reg is null) {
				// deep space boost
				newBoost = -loss.decimal * powerFactor;
			}
			else {
				double solarFactor = reg.starTemperature * (1.0 - (obj.position.distanceToSQ(reg.position) / sqr(reg.radius)));
				newBoost = min_boost.decimal + clamp(solarFactor / temperature_max.decimal, 0.0, max_boost.decimal);
				newBoost *= powerFactor;
			}

			newBoost = round(newBoost / step.decimal) * step.decimal;
			if(abs(dat.prevBoost - newBoost) >= step.decimal * 0.5) {
				// only difference with solar efficiency effect is we modify acceleration instead
				obj.modAccelerationBonus((newBoost - dat.prevBoost) / getMassFor(obj));
				dat.prevBoost = newBoost;
			}
		}
	}

	void save(SubsystemEvent& event, SaveFile& file) const {
		SolarData@ dat;
		event.data.retrieve(@dat);

		if(dat is null) {
			double t = 0.0;
			file << t << t;
		}
		else {
			file << dat.timer;
			file << dat.prevBoost;
		}
	}

	void load(SubsystemEvent& event, SaveFile& file) const {
		SolarData dat;
		event.data.store(@dat);

		file >> dat.timer;
		file >> dat.prevBoost;
	}
#section all
};
