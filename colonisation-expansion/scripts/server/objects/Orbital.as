import regions.regions;
from resources import MoneyType;
import object_creation;
import orbitals;
import saving;
import util.target_search;
// [[ MODIFY BASE GAME START ]]
import CE_deep_space;
import objects.Combatable;
// [[ MODIFY BASE GAME END ]]

const int STRATEGIC_RING = -1;
const double RECOVERY_TIME = 3.0 * 60.0;
const double COMBAT_RECOVER_RATE = 0.25;

tidy class OrbitalScript {
	OrbitalNode@ node;
	StrategicIconNode@ icon;
	OrbitalRequirements reqs;
	Object@ lastHitBy;

	OrbitalSection@ core;
	array<OrbitalSection@> sections;
	int nextSectionId = 1;
	int contestion = 0;
	bool isFree = false;

	bool delta = false;
	bool deltaHP = false;
	// [[ MODIFY BASE GAME START ]]
	bool deltaShields = false;
	// [[ MODIFY BASE GAME END ]]
	bool deltaOrbit = false;
	bool disabled = false;

	double Health = 0;
	double MaxHealth = 0;
	double Armor = 0;
	double MaxArmor = 0;
	double DR = 2.5;
	double DPS = 0;
	// [[ MODIFY BASE GAME START ]]
	double Shield = 0;
	double MaxShield = 0;
	double ShieldRegen = 0;
	Combatable@ combatable = Combatable();
	// [[ MODIFY BASE GAME END ]]

	Orbital@ master;

	void save(Orbital& obj, SaveFile& file) {
		saveObjectStates(obj, file);

		uint cnt = sections.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file << sections[i];
		file << nextSectionId;

		file << Health;
		file << MaxHealth;
		file << Armor;
		file << MaxArmor;
		file << DR;
		file << contestion;
		file << disabled;
		file << DPS;
		file << obj.usingLabor;
		file << isFree;
		file << master;
		// [[ MODIFY BASE GAME START ]]
		file << Shield;
		file << MaxShield;
		file << ShieldRegen;
		// [[ MODIFY BASE GAME END ]]

		file << cast<Savable>(obj.Resources);
		file << cast<Savable>(obj.Orbit);
		file << cast<Savable>(obj.Statuses);

		if(obj.hasConstruction) {
			file << true;
			file << cast<Savable>(obj.Construction);
		}
		else {
			file << false;
		}

		if(obj.hasLeaderAI) {
			file << true;
			file << cast<Savable>(obj.LeaderAI);
		}
		else {
			file << false;
		}

		if(obj.hasAbilities) {
			file << true;
			file << cast<Savable>(obj.Abilities);
		}
		else {
			file << false;
		}

		if(obj.hasCargo) {
			file << true;
			file << cast<Savable>(obj.Cargo);
		}
		else {
			file << false;
		}

		file << cast<Savable>(obj.Mover);
		// [[ MODIFY BASE GAME START ]]
		combatable.save(file);
		// [[ MODIFY BASE GAME END ]]
	}

	void load(Orbital& obj, SaveFile& file) {
		loadObjectStates(obj, file);

		uint cnt = 0;
		file >> cnt;
		sections.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			@sections[i] = OrbitalSection(file);
		if(sections.length != 0)
			@core = sections[0];
		file >> nextSectionId;

		file >> Health;
		file >> MaxHealth;
		file >> Armor;
		file >> MaxArmor;
		file >> DR;
		if(file >= SV_0014) {
			file >> contestion;
			file >> disabled;
		}
		if(file >= SV_0042) {
			file >> DPS;
			file >> obj.usingLabor;
		}
		if(file >= SV_0068)
			file >> isFree;
		if(file >= SV_0149)
			file >> master;

		// [[ MODIFY BASE GAME START ]]
		file >> Shield;
		file >> MaxShield;
		file >> ShieldRegen;
		// [[ MODIFY BASE GAME END ]]

		file >> cast<Savable>(obj.Resources);
		file >> cast<Savable>(obj.Orbit);
		file >> cast<Savable>(obj.Statuses);

		bool has = false;
		file >> has;
		if(has) {
			obj.activateConstruction();
			file >> cast<Savable>(obj.Construction);
		}

		file >> has;
		if(has) {
			obj.activateLeaderAI();
			file >> cast<Savable>(obj.LeaderAI);
		}

		if(file >= SV_0093) {
			file >> has;
			if(has) {
				obj.activateAbilities();
				file >> cast<Savable>(obj.Abilities);
			}
		}

		if(file >= SV_0125) {
			file >> has;
			if(has) {
				obj.activateCargo();
				file >> cast<Savable>(obj.Cargo);
			}
		}

		if(file >= SV_0108)
			file >> cast<Savable>(obj.Mover);
		else
			obj.maxAcceleration = 0;

		// [[ MODIFY BASE GAME START ]]
		combatable.load(file);
		// [[ MODIFY BASE GAME END ]]
	}

	void makeFree(Orbital& obj) {
		if(isFree)
			return;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.type.maintenance != 0 && obj.owner !is null && obj.owner.valid)
				obj.owner.modMaintenance(-sec.type.maintenance, MoT_Orbitals);
		}
		isFree = true;
	}

	void postInit(Orbital& obj) {
		obj.maxAcceleration = 0;
		obj.hasVectorMovement = true;
		obj.activateLeaderAI();
		obj.leaderInit();
	}

	Orbital@ getMaster() {
		return master;
	}

	bool hasMaster() {
		return master !is null;
	}

	bool isMaster(Object@ obj) {
		return master is obj;
	}

	void setMaster(Orbital@ newMaster) {
		@master = newMaster;
		delta = true;
	}

	void checkOrbit(Orbital& obj) {
		Region@ prevRegion = obj.region;
		if(updateRegion(obj)) {
			Region@ newRegion = obj.region;
			if(icon !is null) {
				if(prevRegion !is null)
					prevRegion.removeStrategicIcon(STRATEGIC_RING, icon);
				if(newRegion !is null)
					newRegion.addStrategicIcon(STRATEGIC_RING, obj, icon);
			}
			for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
				if(sections[i].enabled)
					sections[i].regionChange(obj, prevRegion, newRegion);
			}
			obj.changeResourceRegion(prevRegion, newRegion);
			obj.changeStatusRegion(prevRegion, newRegion);
			@prevRegion = newRegion;
		}

		Region@ reg = obj.region;
		if(reg !is null) {
			Object@ orbObj = reg.getOrbitObject(obj.position);
			if(orbObj !is null)
				obj.orbitAround(orbObj);
			else
				obj.orbitAround(reg.starRadius + obj.radius, reg.position);
			deltaOrbit = true;
		}
		// [[ MODIFY BASE GAME START ]]
		else {
			Object@ orbObj = getOrbitObjectInDeepSpace(obj.position);
			if (orbObj !is null) {
				obj.orbitAround(orbObj);
				deltaOrbit = true;
			}
		}
		// [[ MODIFY BASE GAME END ]]
	}

	void postLoad(Orbital& obj) {
		if(core !is null) {
			auto@ type = core.type;
			@node = cast<OrbitalNode>(bindNode(obj, "OrbitalNode"));
			if(node !is null)
				node.establish(obj, type.id);

			if(type.strategicIcon.valid) {
				@icon = StrategicIconNode();
				if(type.strategicIcon.sheet !is null)
					icon.establish(obj, type.iconSize, type.strategicIcon.sheet, type.strategicIcon.index);
				else if(type.strategicIcon.mat !is null)
					icon.establish(obj, type.iconSize, type.strategicIcon.mat);
				if(obj.region !is null)
					obj.region.addStrategicIcon(STRATEGIC_RING, obj, icon);
			}
		}

		for(uint i = 0, cnt = sections.length; i < cnt; ++i)
			sections[i].makeGraphics(obj, node);

		obj.resourcesPostLoad();
		if(obj.hasLeaderAI)
			obj.leaderPostLoad();
	}

	double get_dps() {
		return DPS;
	}

	double get_efficiency() {
		return clamp(Health / max(1.0, MaxHealth), 0.0, 1.0);
	}

	void modDPS(double mod) {
		DPS += mod;
		deltaHP = true;
	}

	void _write(const Orbital& obj, Message& msg) {
		uint cnt = sections.length;
		msg.writeSmall(cnt);
		for(uint i = 0; i < cnt; ++i)
			msg << sections[i];
		msg << contestion;
		msg << disabled;
		msg << master;
	}

	void _writeHP(const Orbital& obj, Message& msg) {
		msg << Health;
		msg << MaxHealth;
		msg << Armor;
		msg << MaxArmor;
		msg << DR;
		msg << DPS;
	}

	// [[ MODIFY BASE GAME START ]]
	void _writeShields(const Orbital& obj, Message& msg) {
		if (MaxShield > 0) {
			msg.write1();
			msg << MaxShield;
			msg.writeFixed(Shield, 0.f, MaxShield, 16);
		}
		else {
			msg.write0();
		}
	}
	// [[ MODIFY BASE GAME END ]]

	void syncInitial(const Orbital& obj, Message& msg) {
		_write(obj, msg);
		_writeHP(obj, msg);
		// [[ MODIFY BASE GAME START ]]
		_writeShields(obj, msg);
		// [[ MODIFY BASE GAME END ]]
		obj.writeResources(msg);
		obj.writeOrbit(msg);
		obj.writeStatuses(msg);
		obj.writeMover(msg);

		if(obj.hasConstruction) {
			msg.write1();
			obj.writeConstruction(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasLeaderAI) {
			msg.write1();
			obj.writeLeaderAI(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasAbilities) {
			msg.write1();
			obj.writeAbilities(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasCargo) {
			msg.write1();
			obj.writeCargo(msg);
		}
		else {
			msg.write0();
		}
	}

	bool syncDelta(const Orbital& obj, Message& msg) {
		bool used = false;
		if(delta) {
			used = true;
			delta = false;
			msg.write1();
			_write(obj, msg);
		}
		else
			msg.write0();
		if(deltaHP) {
			used = true;
			deltaHP = false;
			msg.write1();
			_writeHP(obj, msg);
		}
		else
			msg.write0();
		// [[ MODIFY BASE GAME START ]]
		if(deltaShields) {
			used = true;
			deltaShields = false;
			msg.write1();
			_writeShields(obj, msg);
		}
		else
			msg.write0();
		// [[ MODIFY BASE GAME END ]]
		if(deltaOrbit) {
			used = true;
			deltaOrbit = false;
			msg.write1();
			obj.writeOrbit(msg);
		}
		else
			msg.write0();

		if(obj.writeResourceDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.hasConstruction && obj.writeConstructionDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.hasLeaderAI && obj.writeLeaderAIDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.hasAbilities && obj.writeAbilityDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.hasCargo && obj.writeCargoDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.writeStatusDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.writeOrbitDelta(msg))
			used = true;
		else
			msg.write0();

		if(obj.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();

		return used;
	}

	void syncDetailed(const Orbital& obj, Message& msg) {
		_write(obj, msg);
		_writeHP(obj, msg);
		// [[ MODIFY BASE GAME START ]]
		_writeShields(obj, msg);
		// [[ MODIFY BASE GAME END ]]
		obj.writeResources(msg);
		obj.writeOrbit(msg);
		obj.writeStatuses(msg);
		obj.writeMover(msg);

		if(obj.hasConstruction) {
			msg.write1();
			obj.writeConstruction(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasLeaderAI) {
			msg.write1();
			obj.writeLeaderAI(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasAbilities) {
			msg.write1();
			obj.writeAbilities(msg);
		}
		else {
			msg.write0();
		}

		if(obj.hasCargo) {
			msg.write1();
			obj.writeCargo(msg);
		}
		else {
			msg.write0();
		}
	}

	void modMaxArmor(double value) {
		MaxArmor += value;
		Armor = clamp(Armor, 0, MaxArmor);
		deltaHP = true;
	}

	void modMaxHealth(double value) {
		MaxHealth += value;
		Health = clamp(Health, 0, MaxHealth);
		deltaHP = true;
	}

	void modDR(double value) {
		DR += value;
		deltaHP = true;
	}

	// [[ MODIFY BASE GAME START ]]
	void modProjectedShield(Orbital& orbital, float regen, float capacity) {
		ShieldRegen += regen;
		MaxShield += capacity;
		deltaShields = true;
	}
	// [[ MODIFY BASE GAME END ]]

	double getValue(Player& pl, Orbital& obj, uint id) {
		double value = 0.0;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].getValue(pl, obj, sec.data[j], id, value))
					return value;
			}
		}
		return 0.0;
	}

	const Design@ getDesign(Player& pl, Orbital& obj, uint id) {
		const Design@ value;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].getDesign(pl, obj, sec.data[j], id, value))
					return value;
			}
		}
		return null;
	}

	Object@ getObject(Player& pl, Orbital& obj, uint id) {
		Object@ value;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].getObject(pl, obj, sec.data[j], id, value))
					return value;
			}
		}
		return null;
	}

	void sendValue(Player& pl, Orbital& obj, uint id, double value) {
		if(!obj.valid || obj.destroying)
			return;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].sendValue(pl, obj, sec.data[j], id, value))
					return;
			}
		}
	}

	void sendDesign(Player& pl, Orbital& obj, uint id, const Design@ value) {
		if(!obj.valid || obj.destroying)
			return;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].sendDesign(pl, obj, sec.data[j], id, value))
					return;
			}
		}
	}

	void sendObject(Player& pl, Orbital& obj, uint id, Object@ value) {
		if(!obj.valid || obj.destroying)
			return;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(!sec.enabled)
				continue;
			for(uint j = 0, jcnt = sec.type.hooks.length; j < jcnt; ++j) {
				if(sec.type.hooks[j].sendObject(pl, obj, sec.data[j], id, value))
					return;
			}
		}
	}

	void triggerDelta() {
		delta = true;
	}

	double get_health(Orbital& orb) {
		double v = Health;
		Empire@ owner = orb.owner;
		if(owner !is null)
			v *= owner.OrbitalHealthMod;
		return v;
	}

	double get_maxHealth(Orbital& orb) {
		double v = MaxHealth;
		Empire@ owner = orb.owner;
		if(owner !is null)
			v *= owner.OrbitalHealthMod;
		return v;
	}

	// [[ MODIFY BASE GAME START ]]
	double get_shield(Orbital& orb) {
		double v = Shield;
		return Shield;
	}

	double get_maxShield(Orbital& orb) {
		return MaxShield;
	}
	// [[ MODIFY BASE GAME END ]]

	double get_armor(Orbital& orb) {
		double v = Armor;
		Empire@ owner = orb.owner;
		if(owner !is null)
			v *= owner.OrbitalArmorMod;
		return v;
	}

	double get_maxArmor(Orbital& orb) {
		double v = MaxArmor;
		Empire@ owner = orb.owner;
		if(owner !is null)
			v *= owner.OrbitalArmorMod;
		return v;
	}

	void addSection(Orbital& obj, uint typeId) {
		auto@ type = getOrbitalModule(typeId);
		if(type is null)
			return;

		OrbitalSection sec(type);
		sec.id = nextSectionId++;
		sections.insertLast(sec);

		if(type.isCore && core is null) {
			@node = cast<OrbitalNode>(bindNode(obj, "OrbitalNode"));
			if(node !is null)
				node.establish(obj, type.id);
			@core = sec;
			obj.orbitSpin(type.spin);
			if(type.isStandalone)
				obj.setImportEnabled(false);

			if(type.strategicIcon.valid) {
				@icon = StrategicIconNode();
				if(type.strategicIcon.sheet !is null)
					icon.establish(obj, type.iconSize, type.strategicIcon.sheet, type.strategicIcon.index);
				else if(type.strategicIcon.mat !is null)
					icon.establish(obj, type.iconSize, type.strategicIcon.mat);
				if(obj.region !is null)
					obj.region.addStrategicIcon(STRATEGIC_RING, obj, icon);
			}

			obj.noCollide = !type.isSolid;
			MaxHealth = type.health;
			MaxArmor = type.armor;

			Health = MaxHealth;
			Armor = MaxArmor;
			if(disabled) {
				Health *= 0.25;
				Armor *= 0.25;
			}
		}

		sec.create(obj);
		if(sec is core && !this.disabled)
			sec.enable(obj);
		else
			sec.enabled = false;
		sec.makeGraphics(obj, node);
		checkSections(obj);
		delta = true;

		if(type.maintenance != 0 && obj.owner !is null && obj.owner.valid && !isFree)
			obj.owner.modMaintenance(type.maintenance, MoT_Orbitals);
	}

	void checkSections(Orbital& obj) {
		reqs.init(obj, direct=true);
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.enabled) {
				if(this.disabled || sec.shouldDisable(obj)) {
					sec.disable(obj);
					delta = true;
					if(sec.type.health != 0 || sec.type.armor != 0) {
						if(sec !is core) {
							deltaHP = true;
							MaxHealth -= sec.type.health;
							Health = min(Health, MaxHealth);
							MaxArmor -= sec.type.armor;
							Armor = min(Armor, MaxArmor);
						}
					}
				}
				else {
					if(!reqs.add(sec.type)) {
						sec.disable(obj);
						delta = true;
						if(sec.type.health != 0 || sec.type.armor != 0) {
							if(sec !is core) {
								deltaHP = true;
								MaxHealth -= sec.type.health;
								Health = min(Health, MaxHealth);
								MaxArmor -= sec.type.armor;
								Armor = min(Armor, MaxArmor);
							}
						}
					}
				}
			}
			else {
				if(!this.disabled && sec.shouldEnable(obj)) {
					if(reqs.add(sec.type)) {
						sec.enable(obj);
						delta = true;
						if(sec.type.health != 0 || sec.type.armor != 0) {
							if(sec !is core) {
								MaxHealth += sec.type.health;
								MaxArmor += sec.type.armor;
								deltaHP = true;
							}
						}
					}
				}
			}
		}
	}

	void getSections() {
		for(uint i = 0, cnt = sections.length; i < cnt; ++i)
			yield(sections[i]);
	}

	bool hasModule(uint typeId) {
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.type.id == typeId)
				return true;
		}
		return false;
	}

	//Remote player-accessible
	void buildModule(Orbital& obj, uint typeId) {
		if(core is null || core.type.isStandalone)
			return;

		auto@ type = getOrbitalModule(typeId);
		if(type is null)
			return;

		if(!type.canBuildOn(obj))
			return;

		if(type.buildCost != 0) {
			if(obj.owner.consumeBudget(type.buildCost) == -1)
				return;
		}

		addSection(obj, typeId);
	}

	void destroyModule(Orbital& obj, int id) {
		if(contestion != 0)
			return;
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.id == id) {
				//Can't destroy the core, silly
				if(sec is core)
					return;

				if(sec.enabled)
					sec.disable(obj);
				sec.destroy(obj);
				if(sec.type.maintenance != 0 && obj.owner !is null && obj.owner.valid && !isFree)
					obj.owner.modMaintenance(-sec.type.maintenance, MoT_Orbitals);
				MaxHealth -= sec.type.health;
				Health = min(Health, MaxHealth);
				MaxArmor -= sec.type.armor;
				Armor = min(Armor, MaxArmor);
				sections.removeAt(i);
				checkSections(obj);
				delta = true;
				deltaHP = true;
				return;
			}
		}
	}

	void scuttle(Orbital& obj) {
		if(contestion != 0)
			return;
		obj.destroy();
	}

	uint get_coreModule() {
		auto@ mod = core;
		if(mod is null)
			return uint(-1);
		return mod.type.id;
	}

	bool get_isStandalone() {
		auto@ mod = core;
		if(mod is null)
			return true;
		return mod.type.isStandalone;
	}

	bool get_isContested() {
		return contestion != 0;
	}

	bool get_isDisabled() {
		return disabled || (core !is null && !core.enabled);
	}

	void setContested(bool value) {
		if(value)
			contestion += 1;
		else
			contestion -= 1;
		delta = true;
	}

	void setDisabled(bool value) {
		disabled = value;
		delta = true;
	}

	void destroy(Orbital& obj) {
		// [[ MODIFY BASE GAME START ]]
		// Added kill credits from combatable
		if(combatable.killCredit !is null && !game_ending) {
			playParticleSystem("ShipExplosion", obj.position, obj.rotation, obj.radius, obj.visibleMask);
			auto@ region = obj.region;
			if (region !is null && combatable.killCredit !is obj.owner) {
				// TODO: Can we infer the actual size of the object here rather
				// than fix it to 250?
				region.grantExperience(combatable.killCredit, 250 * config::EXPERIENCE_GAIN_FACTOR, combatOnly=true);
			}

			// TODO: Can we sum the actual maintenance of the object here rather
			// than fix it to 100?
			combatable.rewardKiller(100, obj.owner, 0.0);
		}

		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.enabled)
				sec.disable(obj);
			sec.destroy(obj);
			if(sec.type.maintenance != 0 && obj.owner !is null && obj.owner.valid && !isFree)
				obj.owner.modMaintenance(-sec.type.maintenance, MoT_Orbitals);
		}
		// [[ MODIFY BASE GAME END ]]

		if(icon !is null) {
			if(obj.region !is null)
				obj.region.removeStrategicIcon(STRATEGIC_RING, icon);
			icon.markForDeletion();
			@icon = null;
		}
		@node = null;

		// [[ MODIFY BASE GAME START ]]
		if(obj.hasCargo)
			obj.destroyCargo();
		// [[ MODIFY BASE GAME END ]]
		leaveRegion(obj);
		obj.destroyObjResources();
		if(obj.hasConstruction)
			obj.destroyConstruction();
		if(obj.hasAbilities)
			obj.destroyAbilities();
		if(obj.hasLeaderAI)
			obj.leaderDestroy();
		if(obj.owner !is null && obj.owner.valid)
			obj.owner.unregisterOrbital(obj);
	}

	bool onOwnerChange(Orbital& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		obj.changeResourceOwner(prevOwner);
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			auto@ sec = sections[i];
			if(sec.enabled)
				sec.ownerChange(obj, prevOwner, obj.owner);
			if(sec.type.maintenance != 0 && !isFree) {
				if(prevOwner !is null && prevOwner.valid)
					prevOwner.modMaintenance(-sec.type.maintenance, MoT_Orbitals);
				if(obj.owner !is null && obj.owner.valid)
					obj.owner.modMaintenance(sec.type.maintenance, MoT_Orbitals);
			}
		}
		if(obj.hasLeaderAI)
			obj.leaderChangeOwner(prevOwner, obj.owner);
		// [[ MODIFY BASE GAME START ]]
		if(obj.hasConstruction) {
			obj.constructionChangeOwner(prevOwner, obj.owner);
			obj.clearRally();
		}
		// [[ MODIFY BASE GAME END ]]
		if(obj.hasAbilities)
			obj.abilityOwnerChange(prevOwner, obj.owner);
		obj.changeStatusOwner(prevOwner, obj.owner);
		if(prevOwner !is null && prevOwner.valid)
			prevOwner.unregisterOrbital(obj);
		if(obj.owner !is null && obj.owner.valid)
			obj.owner.registerOrbital(obj);
		return false;
	}

	float timer = 0.f;
	double prevFleet = 0.0;
	// [[ MODIFY BASE GAME START ]]
	void occasional_tick(Orbital& obj, float time) {
		// [[ MODIFY BASE GAME END ]]
		Region@ prevRegion = obj.region;
		if(updateRegion(obj)) {
			Region@ newRegion = obj.region;
			if(icon !is null) {
				if(prevRegion !is null)
					prevRegion.removeStrategicIcon(STRATEGIC_RING, icon);
				if(newRegion !is null)
					newRegion.addStrategicIcon(STRATEGIC_RING, obj, icon);
			}
			for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
				if(sections[i].enabled)
					sections[i].regionChange(obj, prevRegion, newRegion);
			}
			obj.changeResourceRegion(prevRegion, newRegion);
			obj.changeStatusRegion(prevRegion, newRegion);
			@prevRegion = newRegion;
		}

		if(icon !is null)
			icon.visible = obj.isVisibleTo(playerEmpire);

		// [[ MODIFY BASE GAME START ]]
		// Also take vision from the empire that last hit this orbital, if any, to
		// aide them with tracking this orbital
		if (combatable.killCredit !is null) {
			obj.donatedVision |= combatable.killCredit.mask;
		}
		// [[ MODIFY BASE GAME END ]]

		//Update in combat flags
		bool engaged = obj.engaged;
		// [[ MODIFY BASE GAME START ]]
		combatable.occasional_tick(time, engaged);

		obj.inCombat = combatable.inCombat();
		// [[ MODIFY BASE GAME END ]]
		obj.engaged = false;

		if(engaged && prevRegion !is null)
			prevRegion.EngagedMask |= obj.owner.mask;

		if(node !is null) {
			double rad = 0.0;
			if(obj.hasLeaderAI && obj.SupplyCapacity > 0)
				rad = obj.getFormationRadius();
			if(rad != prevFleet) {
				node.setFleetPlane(rad);
				prevFleet = rad;
			}
		}

		if(obj.hasLeaderAI)
			obj.updateFleetStrength();

		//Order support ships to attack
		// [[ MODIFY BASE GAME START ]]
		if(combatable.inCombat()) {
			// [[ MODIFY BASE GAME END ]]
			if(obj.hasLeaderAI && obj.supportCount > 0) {
				Object@ target = findEnemy(obj, obj, obj.owner, obj.position, 700.0);
				if(target !is null) {
					//Always target the fleet as a whole
					{
						Ship@ othership = cast<Ship>(target);
						if(othership !is null) {
							Object@ leader = othership.Leader;
							if(leader !is null)
								@target = leader;
						}
					}

					//Order a random support to assist
					uint cnt = obj.supportCount;
					if(cnt > 0) {
						uint attackWith = max(1, cnt / 8);
						for(uint i = 0, off = randomi(0,cnt-1); i < attackWith; ++i) {
							Object@ sup = obj.supportShip[(i+off) % cnt];
							if(sup !is null)
								sup.supportAttack(target);
						}
					}
				}
			}
		}
		else {
			@lastHitBy = null;
		}

		// [[ MODIFY BASE GAME START ]]
		//Clear kill credits after short spans of time
		if(combatable.killCredit !is null && !obj.inCombat) {
			@combatable.killCredit = null;
			@lastHitBy = null;
		}
		// [[ MODIFY BASE GAME END ]]

		//Update module requirements
		checkSections(obj);
	}

	vec3d get_strategicIconPosition(const Orbital& obj) {
		if(icon is null)
			return obj.position;
		return icon.position;
	}

	void repairOrbital(Orbital& obj, double amount) {
		double armorMod = 1.0, healthMod = 1.0;
		double armor = Armor, health = Health, maxArmor = MaxArmor, maxHealth = MaxHealth;
		if(obj.owner !is null) {
			armorMod = obj.owner.OrbitalArmorMod;
			healthMod = obj.owner.OrbitalHealthMod;

			armor *= armorMod;
			health *= healthMod;
			maxArmor *= armorMod;
			maxHealth *= healthMod;
		}

		double toArmor = min(maxArmor - armor, amount);
		armor = min(armor + toArmor, maxArmor);
		health = min(health + amount - toArmor, maxHealth);

		deltaHP = true;

		Armor = armor / armorMod;
		Health = health / healthMod;
	}

	// [[ MODIFY BASE GAME START ]]
	void shieldDamage(Orbital& obj, double amount) {
		double newShield = clamp(Shield - amount, 0.0, max(MaxShield, Shield));
		if (Shield != newShield) {
			deltaShields = true;
		}
		Shield = newShield;
	}
	// [[ MODIFY BASE GAME END ]]

	void damage(Orbital& obj, DamageEvent& evt, double position, const vec2d& direction) {
		if(!obj.valid || obj.destroying)
			return;

		double armorMod = 1.0, healthMod = 1.0;
		double armor = Armor, health = Health;
		// [[ MODIFY BASE GAME START ]]
		double shield = Shield;
		double maxShield = MaxShield;
		// [[ MODIFY BASE GAME END ]]
		if(obj.owner !is null) {
			armorMod = obj.owner.OrbitalArmorMod;
			healthMod = obj.owner.OrbitalHealthMod;

			armor *= armorMod;
			health *= healthMod;
		}

		obj.engaged = true;

		// [[ MODIFY BASE GAME START ]]
		double shieldBlock = 0;
		if (maxShield > 0)
			shieldBlock = min(shield * min(shield / maxShield, 1.0), evt.damage);
		else
			shieldBlock = min(shield, evt.damage);

		shield -= shieldBlock;
		evt.damage -= shieldBlock;
		// [[ MODIFY BASE GAME END ]]

		if(armor > 0) {
			evt.damage = max(0.2 * evt.damage, evt.damage - DR);
			double dealArmor = min(evt.damage, armor);
			armor = max(0.0, armor - dealArmor);
			deltaHP = true;
		}

		if(evt.damage > health) {
			evt.damage -= health;
			health = 0.0;
			obj.destroy();

			Empire@ killer;
			if(evt.obj !is null)
				@killer = evt.obj.owner;
			for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
				if(sections[i].enabled)
					sections[i].kill(obj, killer);
			}
			return;
		}

		if(evt.obj !is null) {
			if(lastHitBy !is evt.obj && obj.hasLeaderAI) {
				//Order a random support to block, and another to attack
				uint cnt = obj.supportCount;
				if(cnt > 0) {
					uint ind = randomi(0,cnt-1);

					Object@ sup = obj.supportShip[ind];
					if(sup !is null)
						sup.supportInterfere(lastHitBy, obj);

					if(cnt > 1) {
						@sup = obj.supportShip[ind+1];
						if(sup !is null)
							sup.supportAttack(lastHitBy);
					}
				}
			}

			// [[ MODIFY BASE GAME START ]]
			@combatable.killCredit = evt.obj.owner;
			// [[ MODIFY BASE GAME END ]]
			@lastHitBy = evt.obj;
		}

		health -= evt.damage;
		deltaHP = true;

		Armor = armor / armorMod;
		Health = health / healthMod;
		// [[ MODIFY BASE GAME START ]]
		if (shield != Shield) {
			Shield = shield;
			deltaShields = true;
		}
		// [[ MODIFY BASE GAME END ]]
	}

	// [[ MODIFY BASE GAME START ]]
	void setBuildPct(Orbital& obj, double pct, bool force = true, double initial = 0.01) {
		if (obj.inCombat || combatable.inRecentCombat()) {
			return;
		}
		if (force) {
			Health = (initial + pct * (1 - initial)) * MaxHealth;
			Armor = (initial + pct * (1 - initial)) * MaxArmor;
		} else {
			Health = max(Health, (initial + pct * (1 - initial)) * MaxHealth);
			Armor = max(Armor, (initial + pct * (1 - initial)) * MaxArmor);
		}
		// [[ MODIFY BASE GAME END ]]
		deltaHP = true;
	}

	double tick(Orbital& obj, double time) {
		//Take vision from region
		if(obj.region !is null)
			obj.donatedVision |= obj.region.DonateVisionMask;

		//Tick sections
		for(uint i = 0, cnt = sections.length; i < cnt; ++i) {
			if(sections[i].enabled)
				sections[i].tick(obj, time);
		}

		//Tick construction
		double delay = 0.2;
		if(obj.hasConstruction) {
			obj.constructionTick(time);
			if(obj.hasConstructionUnder(0.2))
				delay = 0.0;
		}

		//Tick resources
		obj.resourceTick(time);

		//Tick orbit
		obj.moverTick(time);

		//Tick status
		obj.statusTick(time);

		//Tick fleet
		if(obj.hasLeaderAI) {
			obj.leaderTick(time);
			obj.orderTick(time);
		}

		//Tick abilities
		if(obj.hasAbilities)
			obj.abilityTick(time);

		//Tick occasional stuff
		// [[ MODIFY BASE GAME START ]]
		timer += float(time);
		if(timer > 1.f) {
			occasional_tick(obj, timer);
			timer = 0.f;
		}
		// [[ MODIFY BASE GAME END ]]

		//Repair
		if(!disabled && ((core !is null && core.type.combatRepair) || !obj.inCombat)) {
			// [[ MODIFY BASE GAME START ]]
			// heal 0.5% per second of max hp if we are really really out of combat
			// and home
			// combined with combat timers of 25 seconds, and a 60 second out of combat
			// timer, this takes 80 seconds longer than vanilla's 5 seconds to kick
			// in at full speed, so will take a total of about 264 seconds, which
			// is a little longer than the vanilla formula that does just over 180
			// seconds. The key part though, is that in-combat and in-recent-combat
			// repair will be much weaker, allowing enemies to keep the damage up even
			// with weapons that have modest cooldowns.
			double recover = 0.005 * (MaxHealth + MaxArmor) * time;
			//double recover = time * ((MaxHealth + MaxArmor) / RECOVERY_TIME);
			if (obj.inCombat || combatable.inRecentCombat()) {
				// [[ MODIFY BASE GAME END ]]
				recover *= COMBAT_RECOVER_RATE;
			}

			if(Health < MaxHealth) {
				double take = min(recover, MaxHealth - Health);
				Health = clamp(Health + take, 0, MaxHealth);
				recover -= take;
				deltaHP = true;
			}
			if(recover > 0 && Armor < MaxArmor) {
				Armor = clamp(Armor + recover, 0, MaxArmor);
				deltaHP = true;
			}
		}

		// [[ MODIFY BASE GAME START ]]
		// Shields tick
		if (MaxShield > 0) {
			if (Shield < MaxShield) {
				Shield = min(Shield + ShieldRegen * time, MaxShield);
				deltaShields = true;
			}
			if (Shield > MaxShield) {
				Shield = MaxShield;
				deltaShields = true;
			}
		} else {
			if (Shield != 0 || ShieldRegen != 0) {
				Shield = 0;
				ShieldRegen = 0;
				deltaShields = true;
			}
		}
		// [[ MODIFY BASE GAME END ]]

		return delay;
	}
};
