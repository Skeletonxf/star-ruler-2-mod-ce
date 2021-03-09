// TODO: This is extremely expensive compared to getting object orbits for regions
// Need some kind of deep space objects manager that can loop through only deep space planets
Object@ getOrbitObjectInDeepSpace(vec3d destPoint) {
	Object@ orbit;
	double closestDist = INFINITY;
	for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
		Empire@ empire = getEmpire(i);
		// don't filter out emp == empire, we want to track ally + self
		if (empire.valid && empire.major) {
			Planet@ closest = empire.getClosestPlanet(destPoint);
			if (closest !is null) {
				double distance = destPoint.distanceToSQ(closest.position);
				if ((distance < closest.OrbitSize * closest.OrbitSize) && (distance < closestDist)) {
					closestDist = distance;
					@orbit = closest;
				}
			}
		}
	}
	return orbit;
}
