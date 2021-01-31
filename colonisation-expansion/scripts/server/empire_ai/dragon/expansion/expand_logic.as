enum ExpandType {
	// Level up homeworld (ie early game)
	LevelingHomeworld,
	// Find a homeworld (ie lost all our planets or started the game as Star Children)
	LookingForHomeworld,
	// We found a homeworld and just need to colonise it
	WaitingForHomeworld,
	// We levelled up our homeworld (or something else) and now we want to
	// seek out scalable and level 3 planets and level them up
	// NOT IN USE YET
	Expanding,
};

ExpandType convertToExpandType(uint type) {
	switch (type) {
		case LevelingHomeworld:
			return LevelingHomeworld;
		case LookingForHomeworld:
			return LookingForHomeworld;
		case WaitingForHomeworld:
			return WaitingForHomeworld;
		case Expanding:
			return Expanding;
	}
	return Expanding;
}
