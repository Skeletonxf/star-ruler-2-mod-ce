#include "include/map.as"


enum MapSetting {
	M_SystemCount,
	M_SystemSpacing,
	M_Flatten,
};

#section server
from empire import Creeps;

class Coord {
	uint x;
	uint y;

	Coord(uint x, uint y) {
		this.x = x;
		this.y = y;
	}
}
#section all

class LatticeMap : Map {
	vec3d ringworldPosition;

	LatticeMap() {
		super();

		name = locale::LATTICE_MAP;
		description = locale::LATTICE_MAP_DESC;

		sortIndex = -150;

		color = 0x21e43fff;
		//icon = "maps/Clusters/clusters.png"; // TODO
	}

#section client
	void makeSettings() {
		Number(locale::SYSTEM_COUNT, M_SystemCount, DEFAULT_SYSTEM_COUNT, decimals=0, step=10, min=20, halfWidth=true);
		Number(locale::SYSTEM_SPACING, M_SystemSpacing, DEFAULT_SPACING, decimals=0, step=1000, min=MIN_SPACING, halfWidth=true);
		//Toggle(locale::FLATTEN, M_Flatten, true, halfWidth=true);
	}

#section server
	void placeSystems() {
		uint systemCount = uint(getSetting(M_SystemCount, DEFAULT_SYSTEM_COUNT));
		double spacing = modSpacing(getSetting(M_SystemSpacing, DEFAULT_SPACING));
		//bool flatten = getSetting(M_Flatten, 0.0) != 0.0;

		uint emptySystems = systemCount / 20;
		uint totalSystems = 4 + emptySystems + systemCount;

		// Calculate size of grid
		uint width = ceil(sqrt(double(totalSystems)));
		uint height = floor(sqrt(double(totalSystems)));

		// roll randomly till picked all homeworld locations
		array<Coord@> homeworlds;
		while (homeworlds.length < estPlayerCount) {
			uint x = randomi(0, width - 1);
			uint y = randomi(0, height - 1);
			bool tooClose = false;
			// don't spawn in special system
			if (x == width/2 && y == height/2) {
				tooClose = true;
			}
			// don't spawn on edge of map
			if (x == 0 || y == 0 || x == width || y == height) {
				tooClose = true;
			}
			for (uint i = 0, cnt = homeworlds.length; i < cnt && !tooClose; ++i) {
				Coord@ player = homeworlds[i];
				if ((player.x == x || player.x == x + 1 || player.x == x - 1 || player.y == x + 2 || player.x == x - 2)
					&& (player.y == y || player.y == y + 1 || player.y == y - 1 || player.y == y + 2 || player.y == y - 2)) {
					tooClose = true;
				}
			}
			if (!tooClose) {
				homeworlds.insertLast(Coord(x, y));
			}
		}

		array<Coord@> empty;
		while (emptySystems > 0) {
			uint x = randomi(0, width - 1);
			uint y = randomi(0, height - 1);
			bool badLocation = false;
			if ((x == width/2 || x == width/2 - 1 || x == width/2 + 1) && (y == height/2 || y == height/2 - 1 || y == height/2 + 1)) {
				badLocation = true;
			}
			for (uint i = 0, cnt = homeworlds.length; i < cnt && !badLocation; ++i) {
				if (homeworlds[i].x == x && homeworlds[i].y == y) {
					badLocation = true;
				}
			}
			if (!badLocation) {
				empty.insertLast(Coord(x, y));
				emptySystems -= 1;
			}
		}

		array<SystemData@> grid;
		for (uint i = 0; i < width; ++i) {
			for (uint j = 0; j < height; ++j) {
				int x = int(i) - width/2;
				int y = int(j) - height/2;
				// shove alternate rows to the side for hexagonal grid
				vec3d position = vec3d(double(x) * spacing, 0, double(y) * spacing);
				if (i % 2 == 0) {
					position = vec3d(double(x) * spacing, 0, (double(y) + 0.5) * spacing);
				}

				double distanceFromCenter = ((i - width/2) * (i - width/2)) + ((j - height/2) * (j - height/2));
				// take ratio to max possible distance from center, bringing distanceFromCenter into 0 to 1 range
				distanceFromCenter /= double(((width/2 * width/2) + (height/2 * height/2)));
				double quality = 200 * (1 - distanceFromCenter);

				bool homeworld = false;
				for (uint k = 0, cnt = homeworlds.length; k < cnt; ++k) {
					Coord@ player = homeworlds[k];
					if (player.x == i && player.y == j) {
						homeworld = true;
					}
				}

				SystemData@ sys;
				if (i == width/2 && j == height/2) {
					@sys = addSystem(position, code=SystemCode()
						<< "NameSystem(Superbia)"
						<< "MakePlanet(Ringworld, Radius = 550, Conditions = False, Moons = False, Physics = False)"
						<< "    Rename(Superbia Prime)"
						<< "    AddPlanetResource(Water)"
						<< "    AddPlanetResource(Grain)"
						<< "    AddPlanetResource(Grain)"
						<< "    AddPlanetResource(Corinium)"
						<< "    AddPlanetStatus(Ringworld)"
						<< "MakeAsteroid()"
						<< "MakeArtifact()"
						<< "AddRegionStatus(RemnantBlockedColonization)"
						<< "ExpandSystem(1500)"
					);
					ringworldPosition = position;
				} else if (!homeworld && i == width/2 && (j == height/2 - 1)) {
					@sys = addSystem(position, code=SystemCode()
						<< "NameSystem(Avarita)"
						<< "MakeAsteroid()"
						<< "MakeAsteroid()"
						<< "MakeArtifact()"
						<< "MakeArtifact()"
						<< "ExpandSystem(1700)"
					);
				} else if (!homeworld && i == width/2 - 1 && (j == height/2)) {
					@sys = addSystem(position, code=SystemCode()
						<< "NameSystem(Libidine)"
						<< "MakeAsteroid()"
						<< "MakeAsteroid()"
						<< "MakeArtifact()"
						<< "MakeArtifact()"
						<< "ExpandSystem(1600)"
					);
				} else if (!homeworld && i == width/2 + 1 && (j == height/2)) {
					@sys = addSystem(position, code=SystemCode()
						<< "NameSystem(Invidia)"
						<< "MakeAsteroid()"
						<< "MakeAsteroid()"
						<< "MakeArtifact()"
						<< "MakeArtifact()"
						<< "ExpandSystem(1550)"
					);
				} else {
					bool emptySystem = false;
					for (uint k = 0, cnt = empty.length; k < cnt; ++k) {
						if (empty[k].x == i && empty[k].y == j) {
							emptySystem = true;
						}
					}
					if (emptySystem) {
						@sys = addSystem(position, code=SystemCode()
							<< "MakeAsteroid()"
							<< "MakeArtifact()"
							<< "ExpandSystem(1450)"
						);
					} else {
						@sys = addSystem(position, quality=int(quality));
					}
				}

				grid.insertLast(sys);

				if (homeworld) {
					addPossibleHomeworld(sys);
				}
			}
		}

		// link hexagons
		for (uint i = 0; i < width; ++i) {
			for (uint j = 0; j < height; ++j) {
				SystemData@ sys = grid[(i * height) + j];
				if (i > 0) {
					SystemData@ other = grid[((i - 1) * height) + j];
					if (other !is null) {
						addLink(sys, other);
					}
					if (j > 0 && i % 2 == 1) {
						@other = grid[((i - 1) * height) + (j - 1)];
						if (other !is null) {
							addLink(sys, other);
						}
					}
				}
				if (i < width - 1) {
					SystemData@ other = grid[((i + 1) * height) + j];
					if (other !is null) {
						addLink(sys, other);
					}
					if (j > 0 && i % 2 == 1) {
						@other = grid[((i + 1) * height) + (j - 1)];
						if (other !is null) {
							addLink(sys, other);
						}
					}
				}
				if (j > 0) {
					SystemData@ other = grid[(i * height) + (j - 1)];
					if (other !is null) {
						addLink(sys, other);
					}
				}
			}
		}

	}

	bool initialized = false;

	void tick(double time) {
		if(!initialized && !isLoadedSave) {
			initialized = true;
			postInit();
		}
	}

	void postInit() {
		const Design@ guardian = Creeps.getDesign("Superbia Guardian");
		vec3d position = ringworldPosition;
		position.y += 200.0;
		createShip(position, guardian, Creeps, free=true);
	}

#section all
};
