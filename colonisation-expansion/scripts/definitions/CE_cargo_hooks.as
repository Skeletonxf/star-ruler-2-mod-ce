import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
from generic_effects import GenericEffect;

class SetCargoStorage : GenericEffect {
	Document doc("Sets a new amount of cargo storage to the object (THIS HAS NO INBUILT RACE CONDITION HANDLING, USE WITH CARE).");
	Argument amount(AT_Decimal, doc="Amount of cargo storage to set.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isShip && !obj.hasCargo)
			cast<Ship>(obj).activateCargo();
		else if(obj.isOrbital && !obj.hasCargo)
			cast<Orbital>(obj).activateCargo();
		double amt = 0;
		if (obj.hasCargo) {
			amt = obj.cargoCapacity;
			obj.overrideCargoStorage(amount.decimal);
		}
		data.store(amt);
	}

	void disable(Object& obj, any@ data) const override {
		double amt = 0;
		data.retrieve(amt);
		if(obj.hasCargo)
			obj.overrideCargoStorage(amt);
	}

	void save(any@ data, SaveFile& file) const override {
		double amt = 0;
		data.retrieve(amt);
		file << amt;
	}

	void load(any@ data, SaveFile& file) const override {
		double amt = 0;
		file >> amt;
		data.store(amt);
	}
#section all
}

class ConsumeCargo : GenericEffect {
	Document doc("Consume cargo at a particular rate.");
	Argument cargo_type(AT_Cargo, doc="Type of cargo to process.");
	Argument rate(AT_Decimal, doc="Rate at which to process the cargo per second.");

#section server
	void tick(Object& obj, any@ data, double time) const override {
		if(obj.hasCargo) {
			obj.consumeCargo(cargo_type.integer, time * rate.decimal, partial=true);
		}
	}
#section all
};
