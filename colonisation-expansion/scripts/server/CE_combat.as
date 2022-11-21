from combat import DamageTypes, ExplDamage;

void ApplyBoringMissileDoT(Event& evt, double DPS, double Duration, double Damage) {
	TimedEffect te(ET_BoringMissileOverTime, Duration);
	te.effect.value0 = DPS * double(evt.efficiency) * double(evt.partiality);
	@te.event.obj = evt.obj;
	@te.event.target = evt.target;
	te.event.partiality = evt.partiality;
	te.event.source_index = evt.source_index;
	te.event.custom1 = evt.direction.radians();

	evt.target.addTimedEffect(te);

	ExplDamage(evt, Damage);
}

void BoringMissileDamage(Event& evt, double DPS) {
	double angle = (randomd(evt.custom1 - 0.5*pi, evt.custom1 + 0.5*pi) + twopi) % twopi;
	vec2d direction = vec2d(1.0, 0.0).rotate(angle);
	vec3d impact(direction.x, 0.0, direction.y);

	DamageEvent dmg;
	dmg.damage = DPS * evt.time;
	dmg.partiality = evt.partiality * evt.time;
	dmg.pierce = 0.0;
	dmg.impact = impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Explosive;

	evt.target.damage(dmg, -1.0, direction);
	// boring missiles grant vision of their targets while the tick is applied
	evt.target.donatedVision |= evt.obj.owner.mask;
}
