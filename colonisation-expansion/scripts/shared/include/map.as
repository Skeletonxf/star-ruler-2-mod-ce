#priority init 1501
import maps;

const int DEFAULT_SYSTEM_COUNT = 60;

// [[ MODIFY BASE GAME START ]]
// increase the spacing to accomodate gas giants
const double DEFAULT_SPACING = 12000.0;
const double MIN_SPACING = 10000.0;
// [[ MODIFY BASE GAME END ]]

void init() {
	auto@ mapClass = getClass("Map");
	for(uint i = 0, cnt = THIS_MODULE.classCount; i < cnt; ++i) {
		auto@ cls = THIS_MODULE.classes[i];
		if(cls !is mapClass && cls.implements(mapClass))
			cls.create();
	}
}
