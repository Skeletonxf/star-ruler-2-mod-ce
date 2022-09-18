import hooks;
import hook_globals;
import generic_effects;
import repeat_hooks;
import abilities;
from abilities import AbilityHook;
from ability_effects import getMassFor;
import target_filters;

class NotifyTargetOwner : AbilityHook {
	Document doc("Notify the target empire of an event.");
	Argument objTarg(TT_Object);
	Argument title("Title", AT_Custom, doc="Title of the notification.");
	Argument desc("Description", AT_Custom, EMPTY_DEFAULT, doc="Description of the notification.");
	Argument icon("Icon", AT_Sprite, EMPTY_DEFAULT, doc="Sprite specifier for the notification icon.");

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(abl.obj is null)
			return;
		if (index != uint(objTarg.integer))
			return;
		if (newTarget.obj is null)
			return;
		if (!newTarget.obj.isStar && (newTarget.obj.owner is null || !newTarget.obj.owner.valid))
			return;
		if (newTarget.obj is abl.obj)
			return;
		if (oldTarget.obj is newTarget.obj)
			return;
		Empire@ emp = newTarget.obj.owner;
		if (emp !is null) {
			emp.notifyGeneric(title.str, desc.str, icon.str, emp, newTarget.obj);
		}
		if (newTarget.obj.isStar) {
			Region@ region = newTarget.obj.region;
			array<int> notified;
			if (region !is null) {
				uint plCnt = region.planetCount;
				for (uint i = 0; i < plCnt; ++i) {
					Planet@ pl = region.planets[i];
					if(pl is null)
						continue;
					if(pl.owner is null)
						continue;
					if (notified.find(pl.owner.id) == -1) {
						Empire@ emp = pl.owner;
						emp.notifyGeneric(title.str, desc.str, icon.str, emp, newTarget.obj);
						notified.insertLast(pl.owner.id);
					}
				}
			}
		}
	}
#section all
};

class FlingToTarget : AbilityHook {
	Document doc("Flings the ship/station to the target (without using a fling beacon).");
	Argument object(TT_Object);

#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ target = object.fromConstTarget(targs).obj;
		if(abl.obj is null || target is null)
			return;

		Ship@ ship = cast<Ship>(abl.obj);
		if (ship is null)
			return;

		ship.addBeaconlessFlingOrder(target.position, append = true);
	}
#section all
};

tidy final class StellarDamageData {
	double timeFiring = 0;
}

class DealStellarDamageOverTimeWithRampUp : AbilityHook {
	Document doc("Deal damage to the stored target stellar object over time. Damages things like stars and planets.");
	Argument objTarg(TT_Object);
	Argument dmg_per_second(AT_SysVar, doc="Damage to deal per second.");
	Argument ramp_up_time(AT_SysVar, doc="Time to 100% damage output (lerp the dps while below time period).");

#section server
	void create(Ability@ abl, any@ data) const override {
		StellarDamageData damageData;
		data.store(@damageData);
	}

	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(index != uint(objTarg.integer))
			return;

		Object@ prev = oldTarget.obj;
		Object@ next = newTarget.obj;

		if(prev is next)
			return;

		// [[ MODIFY BASE GAME START ]]
		// Read tractor data sooner
		StellarDamageData@ damageData;
		data.retrieve(@damageData);
		damageData.timeFiring = 0;
	}

	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Object@ obj = storeTarg.obj;
		if(obj is null)
			return;

		StellarDamageData@ damageData;
		data.retrieve(@damageData);

		damageData.timeFiring += time;

		double amt = dmg_per_second.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;

		double rampUpFactor = 1.0;
		double rampUpTime = ramp_up_time.fromSys(abl.subsystem);
		if (rampUpTime != 0) {
			rampUpFactor = damageData.timeFiring / rampUpTime;
			if (rampUpFactor > 1) {
				rampUpFactor = 1;
			}
		}

		if(obj.isPlanet)
			cast<Planet>(obj).dealPlanetDamage(amt * rampUpFactor);
		else if(obj.isStar)
			cast<Star>(obj).dealStarDamage(amt * rampUpFactor);
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		StellarDamageData@ damageData;
		data.retrieve(@damageData);
		file << damageData.timeFiring;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		StellarDamageData damageData;
		data.store(@damageData);
		file >> damageData.timeFiring;
	}
#section all
};

final class TractorData {
	bool enabled;
	array<Object@> manipulated;
	double tractorMass = 0;
}

class TractorNearby : AbilityHook {
	Document doc("The objects in the nearby range are tractored continually.");
	Argument max_distance(AT_Decimal, "100", doc="Maximum distance to tractor.");

#section server
	void create(Ability@ abl, any@ data) const {
		TractorData info;
		info.enabled = false;
		data.store(info);
	}

	void activate(Ability@ abl, any@ data, const Targets@ targs) const override {
		TractorData info;
		data.retrieve(info);

		if (!info.enabled) {
			info.enabled = true;
			info.manipulated.length = 0;
			info.tractorMass = 0;
			data.store(info);
		} else {
			disable(abl, data);
		}
	}

	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null || abl.obj.owner is null)
			return;

		TractorData info;
		data.retrieve(info);

		if (!info.enabled)
			return;

		if (abl.obj.inFTL) {
			disable(abl, data);
			return;
		}

		double ourMass = getMassFor(abl.obj); // ignores our bonus mass

		double radius = max_distance.decimal;
		vec3d center = abl.obj.position;

		// As per SR2 docs, Bit 1 filters for objects not owned by a player.
		// TractorNearby applies to owned and unowned only, not enemy players
		uint mask = abl.obj.owner.mask & 1;
		array<Object@>@ objs = findInBox(center - vec3d(radius), center + vec3d(radius), mask);

		array<Object@> manipulatedNew;
		array<Object@> manipulatedLast;
		for (uint i = 0, cnt = info.manipulated.length; i < cnt; ++i) {
			manipulatedLast.insertLast(info.manipulated[i]);
		}

		double newTractorMass = 0;

		for (uint i = 0, cnt = objs.length; i < cnt; ++i) {
			Object@ target = objs[i];

			// Hilarious yes, but balanced no
			if (target.isStar)
				continue;

			vec3d off = target.position - center;
			double dist = off.length - target.radius;
			if (dist > radius)
				continue;

			manipulatedNew.insertLast(target);
			{
				int index = manipulatedLast.find(target);
				if (index != -1) {
					manipulatedLast.removeAt(index);
				}
			}

			target.donatedVision |= abl.obj.visibleMask;

			if (target.hasOrbit) {
				if (target.inOrbit) {
					target.stopOrbit();
				}
			}

			vec3d dir = (abl.obj.position - target.position).normalized(1);
			double interp = 1.0 - pow(0.2, time * getMassFor(abl.obj) / getMassFor(target));
			double targetMass = getMassFor(target);

			if (target.hasOrbit) {
				target.velocity = target.velocity.interpolate(abl.obj.velocity + dir, interp);
				target.position = target.position.interpolate(target.position + target.velocity, interp);
				target.acceleration = target.acceleration.interpolate(abl.obj.acceleration, interp);
			} else if (target.hasMover) {
				// This follows the same logic as the understanding in TractorObject
				// Our maxAcceleration isn't recalculated the moment we adjust mass,
				// but it should asyncronously cause the tick in the Ship.as to recalculate
				// our maxAcceleration based on the ship's thrust and new bonus mass.
				// In this case, it's better for controllability if we're imparting the
				// same amount of acceleration to different mass objects anyway.
				double tracForce = abl.obj.maxAcceleration * time;
				vec3d force = dir.normalized(min(tracForce, dir.length));
				target.impulse(force);
			}

			newTractorMass += targetMass;
		}

		// Zero out the movement of anything we manipulated and lost control over
		for (uint i = 0, cnt = manipulatedLast.length; i < cnt; ++i) {
			Object@ target = manipulatedLast[i];
			target.velocity = vec3d();
			target.acceleration = vec3d();
			if (target.hasOrbit) {
				target.remakeStandardOrbit();
			}
		}

		info.manipulated.length = 0;
		for (uint i = 0, cnt = manipulatedNew.length; i < cnt; ++i) {
			info.manipulated.insertLast(manipulatedNew[i]);
		}

		// Gain mass based on what we're tractoring
		double massDiff = newTractorMass - info.tractorMass;
		info.tractorMass += massDiff;
		if (abl.obj !is null && abl.obj.isShip) {
			cast<Ship>(abl.obj).modMass(massDiff);
		}

		data.store(info);
	}

	void destroy(Ability@ abl, any@ data) const {
		disable(abl, data);
	}

	void disable(Ability@ abl, any@ data) const {
		TractorData info;
		data.retrieve(info);

		if (info.enabled) {
			info.enabled = false;

			for (uint i = 0, cnt = info.manipulated.length; i < cnt; ++i) {
				Object@ target = info.manipulated[i];

				target.velocity = vec3d();
				target.acceleration = vec3d();
				if (target.hasOrbit) {
					target.remakeStandardOrbit();
				}
			}

			info.manipulated.length = 0;
		}

		// remove the bonus mass we gaind from tractoring
		if (abl.obj !is null && abl.obj.isShip) {
			cast<Ship>(abl.obj).modMass(-info.tractorMass);
			info.tractorMass = 0;
		}

		data.store(info);
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		TractorData info;
		data.retrieve(info);
		file << info.enabled;
		file << info.tractorMass;
		uint cnt = info.manipulated.length;
		file << cnt;
		for (uint i = 0; i < cnt; ++i) {
			file << info.manipulated[i];
		}
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		TractorData info;
		file >> info.enabled;
		file >> info.tractorMass;
		uint cnt = 0;
		file >> cnt;
		for (uint i = 0; i < cnt; ++i) {
			Object@ obj;
			file >> obj;
			if (obj !is null) {
				info.manipulated.insertLast(obj);
			}
		}
		data.store(info);
	}
#section all
};

tidy final class ProjectionData {
	float regen = 0;
	float capacity = 0;
}

class AddBonusShieldProjected : AbilityHook {
	Document doc("Add a shield to a target while this effect is active.");
	Argument objTarg(TT_Object);
	Argument shield_regen(AT_SysVar, doc="Shield regeneration per second.");
	Argument max_shield(AT_SysVar, doc="Maximum shield capacity.");
	Argument max_distance(AT_Decimal, "500", doc="Maximum distance to project.");

#section server
	void create(Ability@ abl, any@ data) const override {
		ProjectionData pd;
		data.store(@pd);
	}

	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if (index != uint(objTarg.integer))
			return;

		Object@ prev = oldTarget.obj;
		Object@ next = newTarget.obj;

		if (prev is next)
			return;

		ProjectionData@ pd;
		data.retrieve(@pd);

		// Clear effect on old target
		if (prev !is null) {
			if (prev.isShip) {
				Ship@ ship = cast<Ship>(prev);
				if (ship !is null) {
					ship.modProjectedShield(-pd.regen, -pd.capacity);
				}
			} else if (prev.isOrbital) {
				Orbital@ orb = cast<Orbital>(prev);
				if (orb !is null) {
					orb.modProjectedShield(-pd.regen, -pd.capacity);
				}
			} else if (prev.isPlanet) {
				Planet@ planet = cast<Planet>(prev);
				if (planet !is null) {
					planet.modProjectedShield(-pd.regen, -pd.capacity);
				}
			} else if (prev.isStar) {
				Star@ star = cast<Star>(prev);
				if (star !is null) {
					star.modProjectedShield(-pd.regen, -pd.capacity);
				}
			}
		}

		float regen = shield_regen.fromSys(abl.subsystem);
		float capacity = max_shield.fromSys(abl.subsystem);

		pd.regen = regen;
		pd.capacity = capacity;

		if (next !is null) {
			if (next.isShip) {
				Ship@ ship = cast<Ship>(next);
				if (ship !is null) {
					ship.modProjectedShield(pd.regen, pd.capacity);
				}
			} else if (next.isOrbital) {
				Orbital@ orb = cast<Orbital>(next);
				if (orb !is null) {
					orb.modProjectedShield(pd.regen, pd.capacity);
				}
			} else if (next.isPlanet) {
				Planet@ planet = cast<Planet>(next);
				if (planet !is null) {
					planet.modProjectedShield(pd.regen, pd.capacity);
				}
			} else if (next.isStar) {
				Star@ star = cast<Star>(next);
				if (star !is null) {
					star.modProjectedShield(pd.regen, pd.capacity);
				}
			}
		}
	}

	void tick(Ability@ abl, any@ data, double time) const {
		if (abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if (storeTarg is null)
			return;

		Object@ obj = storeTarg.obj;
		if (obj is null)
			return;

		ProjectionData@ pd;
		data.retrieve(@pd);

		float regen = shield_regen.fromSys(abl.subsystem);
		float capacity = max_shield.fromSys(abl.subsystem);

		if (pd.regen != regen || pd.capacity != capacity) {
			double regenDiff = regen - pd.regen;
			pd.regen += regenDiff;
			double capacityDiff = capacity - pd.capacity;
			pd.capacity += capacityDiff;
			if (obj.isShip) {
				Ship@ ship = cast<Ship>(obj);
				if (ship !is null) {
					ship.modProjectedShield(regenDiff, capacityDiff);
				}
			} else if (obj.isOrbital) {
				Orbital@ orb = cast<Orbital>(obj);
				if (orb !is null) {
					orb.modProjectedShield(regenDiff, capacityDiff);
				}
			} else if (obj.isPlanet) {
				Planet@ planet = cast<Planet>(obj);
				if (planet !is null) {
					planet.modProjectedShield(regenDiff, capacityDiff);
				}
			} else if (obj.isStar) {
				Star@ star = cast<Star>(obj);
				if (star !is null) {
					star.modProjectedShield(regenDiff, capacityDiff);
				}
			}
		}

		double dist = obj.position.distanceTo(abl.obj.position);
		if (dist > max_distance.decimal) {
			Target newTarg = storeTarg;
			@newTarg.obj = null;
			abl.changeTarget(objTarg, newTarg);
			return;
		}
	}

	void save(Ability@ abl, any@ data, SaveFile& file) const override {
		ProjectionData@ pd;
		data.retrieve(@pd);

		file << pd.regen;
		file << pd.capacity;
	}

	void load(Ability@ abl, any@ data, SaveFile& file) const override {
		ProjectionData pd;
		data.store(@pd);

		file >> pd.regen;
		file >> pd.capacity;
	}
#section all
};

class TargetFilterOrbitalAny : TargetFilter {
	Document doc("Restricts target to orbitals.");
	Argument allow_null(AT_Boolean, "True", doc="Whether to allow the ability to be triggered on nulls (for example, for toggle deactivates.)");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_ORBITAL;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
		 	return allow_null.boolean;
		return targ.obj.isOrbital;
	}
};

class TargetFilterPlanet : TargetFilter {
	Document doc("Restricts target to planets.");
	Argument allow_null(AT_Boolean, "True", doc="Whether to allow the ability to be triggered on nulls (for example, for toggle deactivates.)");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_PLANET;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
		 	return allow_null.boolean;
		return targ.obj.isPlanet;
	}
};

class TargetFilterStar : TargetFilter {
	Document doc("Restricts target to stars.");
	Argument allow_null(AT_Boolean, "True", doc="Whether to allow the ability to be triggered on nulls (for example, for toggle deactivates.)");
	Argument allow_blackholes(AT_Boolean, "True", doc="If black holes are considered stars.");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_STAR;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
		 	return allow_null.boolean;
		if (targ.obj.isStar) {
			if (allow_blackholes.boolean) {
				return true;
			} else {
				Star@ star = cast<Star>(targ.obj);
				return star !is null && star.temperature != 0.0;
			}
		} else {
			return false;
		}
	}
};

class TargetFilterNoStarsInRegion : TargetFilter {
	Document doc("Restricts target to objects in regions that don't have any stars.");
	Argument allow_null(AT_Boolean, "True", doc="Whether to allow the ability to be triggered on nulls (for example, for toggle deactivates.)");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_STAR;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
			return allow_null.boolean;
		Region@ region = targ.obj.region;
		return region is null || region.starCount == 0;
	}
};
