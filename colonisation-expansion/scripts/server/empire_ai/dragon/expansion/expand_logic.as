enum ExpandType {
	// Level up homeworld (ie early game)
	LevelingHomeworld,
	// Find a homeworld (ie lost all our planets or started the game as Star Children)
	LookingForHomeworld,
	// We levelled up our homeworld (or something else) and now we want to
	// seek out scalable and level 3 planets and level them up
	Expanding,
};

ExpandType convertToExpandType(uint type) {
	switch (type) {
		case LevelingHomeworld:
			return LevelingHomeworld;
		case LookingForHomeworld:
			return LookingForHomeworld;
		case Expanding:
			return Expanding;
	}
	return Expanding;
}
