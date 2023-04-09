#include "include/map.as"

enum MapSetting {
	M_SystemCount,
	M_SystemSpacing,
	M_Flatten,
};

class ContrailMap : Map {
	ContrailMap() {
		super();

		name = locale::CONTRAIL_MAP;
		description = locale::CONTRAIL_MAP_DESC;

		sortIndex = -149;

		color = 0xd252ffff; // TODO
		// icon = "maps/Dumbbell/dumbbell.png"; // TODO
	}

#section client
	void makeSettings() {
		Number(locale::SYSTEM_COUNT, M_SystemCount, DEFAULT_SYSTEM_COUNT, decimals=0, step=10, min=10, halfWidth=true);
		Number(locale::SYSTEM_SPACING, M_SystemSpacing, DEFAULT_SPACING, decimals=0, step=1000, min=MIN_SPACING, halfWidth=true);
		Toggle(locale::FLATTEN, M_Flatten, true, halfWidth=true);
	}

#section server
	void placeSystems() {
		uint systemCount = uint(getSetting(M_SystemCount, DEFAULT_SYSTEM_COUNT));
		double spacing = modSpacing(getSetting(M_SystemSpacing, DEFAULT_SPACING));
		bool flatten = getSetting(M_Flatten, 0.0) != 0.0;
		bool mirror = false;

		// Pick angle
		double galaxyAngle = randomd(3.14, -3.14);
		// Generate unit vector in direction
		vec3d galaxyDirection = vec3d(cos(galaxyAngle), 0, sin(galaxyAngle));
		double galaxyRadius = (systemCount / 3) * spacing;
		print(galaxyAngle);
		print(galaxyDirection);

		// Place black hole at one end
		const SystemType@ blackHoleType = getSystemType("CoreBlackhole");
		if (blackHoleType is null) {
			print("Black hole type does not exist");
			return;
		}
		vec3d blackHolePosition = galaxyDirection * (galaxyRadius * -1);
		addSystem(blackHolePosition, sysType=blackHoleType.id);

		for (uint i = 1; i < systemCount; ++i) {
			double fraction = double(i) / double(systemCount);
			// Reduce variation from galaxy angle as stars get further away
			// TODO: Don't allow the angle to massively jump between neighbouring stars
			double angle = galaxyAngle + (pow((1 - fraction), 1.5) * (randomd(1.6, -1.6) + randomd(0.2, -0.2)));
			// Place stars near the black hole more closely together
			// TODO: Try to respect spacing as much as possible here
			// TODO: This is kinda built for single file lines whereas we should aim for several systems at
			// the same distance but different angles
			double distance = (galaxyRadius * (2 + randomd(0.01, -0.01))) * (pow(fraction, 3.0) + 0.05);
			vec3d direction = vec3d(cos(angle), 0, sin(angle));
			vec3d position = blackHolePosition + (direction * distance);
			print(i);
			print(position);
			// TODO: Pick a new spot if too close to an existing system
			SystemData@ sys = addSystem(position);
			// TODO: Pick homeworlds properly
			addPossibleHomeworld(sys);
		}
	}
#section all
}
