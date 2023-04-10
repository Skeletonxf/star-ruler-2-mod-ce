#include "include/map.as"

enum MapSetting {
	M_SystemCount,
	M_SystemSpacing,
	M_Flatten,
};

#section server
class ContrailBucket {
	array<ContrailSystem@> systems;
}

class ContrailSystem {
	double angle;
	double distance;
	vec3d position;

	ContrailSystem(double angle, double distance, vec3d position) {
		this.angle = angle;
		this.distance = distance;
		this.position = position;
	}
}
#section all

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
		vec3d galaxyDirection = unitVector(galaxyAngle);
		// We'll place a 'spine' of 1/4 of the total system count along the
		// galaxy angle in a line, so half of this is the approximate radius
		// The spine will use slightly more than 100% spacing, so we get a good
		// length (as other systems fill in the gaps the spacing should trend
		// back to specified).
		double galaxyRadius = (systemCount / 8.0) * spacing * 1.3;
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

		// Initalise buckets to track placed stars so we can avoid placing stars
		// too close together
		array<ContrailBucket@> buckets;
		uint bucketCount = 3 + (systemCount / 20);
		for (uint i = 0; i < bucketCount; ++i) {
			buckets.insertLast(ContrailBucket());
		}

		double maxAngleDelta = 1.4;
		double baseDistance = 5.0 * spacing;

		// Place spine
		double angleDelta = 0.0;
		uint spineCount = systemCount / 4;
		for (uint i = 1; i < spineCount; ++i) {
			double fraction = double(i) / double(spineCount);
			// Keep angle within 1.6 radians each direction but let it vary a
			// bit along each star in the spine
			angleDelta = fractionToAngleFactor(fraction) * randomd(-maxAngleDelta, maxAngleDelta) * 0.25;
			double angle = galaxyAngle + angleDelta;
			double distance = baseDistance + (i * spacing * 1.3);
			vec3d position = blackHolePosition + (unitVector(angle) * distance);
			SystemData@ sys = addSystem(position);
			// TODO: Pick homeworlds properly
			addPossibleHomeworld(sys);

			ContrailBucket@ b = buckets[bucket(bucketCount, distance, galaxyRadius)];
			b.systems.insertLast(ContrailSystem(angle, distance, position));
		}

		// Place all the other systems to fill out the spine
		angleDelta = 0.0;
		for (uint i = spineCount; i < systemCount; ++i) {
			bool foundSpot = false;
			uint failures = 0;
			double baseFraction = double(i - spineCount) / double(systemCount - spineCount);
			while (!foundSpot) {
				// bias the fraction towards 0
				double fraction = pow(baseFraction, 4.5);
				angleDelta = fractionToAngleFactor(fraction) * randomd(-maxAngleDelta, maxAngleDelta);
				double angle = galaxyAngle + angleDelta;
				// Calculate distance based off fraction to align systems within the existing spine
				double distance = baseDistance + ((galaxyRadius * (2.0 + randomd(0.01, -0.01))) * fraction);
				vec3d position = blackHolePosition + (unitVector(angle) * distance);
				uint bClosest = bucket(bucketCount, distance, galaxyRadius);
				bool tooClose = false;
				for (uint b = uint(max(int(bClosest - 1), 0)); b < min(bClosest + 1, bucketCount - 1) && !tooClose; ++b) {
					ContrailBucket@ bucket = buckets[b];
					for (uint s = 0; s < bucket.systems.length && !tooClose; ++s) {
						ContrailSystem@ sPos = bucket.systems[s];
						if (sPos.position.distanceTo(position) < (spacing * 0.9)) {
							tooClose = true;
						}
					}
				}
				if (tooClose) {
					failures += 1;
					if (failures % 4 == 3) {
						// reroll position completely if struggling
						baseFraction = randomd(0.0, 1.0);
					}
				} else {
					foundSpot = true;
					SystemData@ sys = addSystem(position);
					ContrailBucket@ b = buckets[bucket(bucketCount, distance, galaxyRadius)];
					b.systems.insertLast(ContrailSystem(angle, distance, position));
				}
			}
			print("Failures for i " + string(i) + " : " + string(failures));
		}

		// TODO: Systems bordering the black hole should be nebulae
		// TODO: Reserve 10% of the systems to fill in the largest gaps
	}

	vec3d unitVector(double angle, double elevation = 0.0) {
		return vec3d(cos(angle), elevation, sin(angle));
	}

	double clamp(double angle, double maxAngle) {
		return max(min(angle, maxAngle), -maxAngle);
	}

	// Keep factor in 0-1 range but reduce exponentially as fraction increases
	// to reduce variation of stars furthest away from black hole
	double fractionToAngleFactor(double fraction) {
		return pow(1 - fraction, 2.2);
	}

	double bucket(uint buckets, double distance, double galaxyRadius) {
		double fraction = (distance / (2 * galaxyRadius));
		double fractionalBucket = buckets * fraction;
		return max(min(uint(floor(fractionalBucket)), buckets - 1), 0);
	}
#section all
}
