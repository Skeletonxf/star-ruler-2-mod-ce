import empire_ai.weasel.Colonization;
import empire_ai.weasel.Planets;
import empire_ai.weasel.Resources;
from empire_ai.dragon.expansion.resource_value import RaceResourceValuation, ResourceValuationOwner, DefaultRaceResourceValuation, ResourceValuator, PlanetValuables;

class PotentialColonizeSource : PotentialColonize {
	// Existing parent class fields, these are needed because
	// other AI components use them
	//Planet@ pl;
	//const ResourceType@ resource;
	//double weight = 0;
	PlanetValuables@ valuables;

	PotentialColonizeSource(Planet@ planet, ResourceValuator& valuation) {
		@valuables = PlanetValuables(planet);
		// weight is NOT based on resources, we will frequently loop through
		// potential colonize sources for the best choice to meet a spec,
		// and hence this is for breaking ties given a spec
		// we also scale this by distance to our border, to favor expanding
		// our border at times
		weight = valuables.getGenericValue(valuation);
		@resource = getResource(planet.primaryResourceType);
		@pl = planet;
	}

	void save(SaveFile& file) {
		file << pl;
		if (resource !is null) {
			file.write1();
			file.writeIdentifier(SI_Resource, resource.id);
		} else {
			file.write0();
		}
		file << weight;
	}

	// only for deserialisation
	PotentialColonizeSource() {}

	void load(SaveFile& file) {
		file >> pl;
		if (file.readBit())
			@resource = getResource(file.readIdentifier(SI_Resource));
		file >> weight;
		@valuables = PlanetValuables(pl);
	}

	bool canMeet(ResourceSpec@ spec) {
		// TODO: Should probably just check if the spec is met by this planet
		// for all specs that aren't for import instead of special casing
		if (spec.type == RST_Level_Minimum_Or_Class) {
			return valuables.meets(spec);
		}
		return valuables.canExportToMeet(spec);
	}
}

// A container for potentialColonizations, with some lazy calculated cached data
// for slightly more efficient querying
class PotentialColonizationsSummary {
	array<PotentialColonize@> potentialColonizations;


	uint get_length() {
		return potentialColonizations.length;
	}

	void reset() {
		potentialColonizations.length = 0;
		// TODO: Reset cache
	}

	void add(PotentialColonizeSource@ p) {
		potentialColonizations.insertLast(p);
	}

	PotentialColonizeSource@ get(uint i) {
		// no bounds checks because we only use this for indexing as if we
		// were indexing the array inside us
		return cast<PotentialColonizeSource>(potentialColonizations[i]);
	}

	void save(SaveFile& file) {
		uint cnt = potentialColonizations.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			(cast<PotentialColonizeSource>(potentialColonizations[i])).save(file);
		}
	}

	void load(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		potentialColonizations.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			PotentialColonizeSource@ p = PotentialColonizeSource();
			p.load(file);
			@potentialColonizations[i] = p;
		}
	}
}
