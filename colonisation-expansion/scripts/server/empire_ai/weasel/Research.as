// Research
// --------
// Spends research points to unlock and improve things in the research grid.
//

import empire_ai.weasel.WeaselAI;

// [[ MODIFY BASE GAME START ]]
import empire_ai.weasel.Development;
// [[ MODIFY BASE GAME END ]]

import research;

class Research : AIComponent {
	TechnologyGrid grid;
	array<TechnologyNode@> immediateQueue;
	// [[ MODIFY BASE GAME START ]]
	IDevelopment@ development;
	// [[ MODIFY BASE GAME END ]]

	void save(SaveFile& file) {
		uint cnt = immediateQueue.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file << immediateQueue[i].id;
	}

	void load(SaveFile& file) {
		updateGrid();

		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			int id = 0;
			file >> id;

			for(uint i = 0, cnt = grid.nodes.length; i < cnt; ++i) {
				if(grid.nodes[i].id == id) {
					immediateQueue.insertLast(grid.nodes[i]);
					break;
				}
			}
		}

	}

	// [[ MODIFY BASE GAME START ]]
	void create() {
		@development = cast<IDevelopment>(ai.development);
	}
	// [[ MODIFY BASE GAME END ]]

	void updateGrid() {
		//Receive the full grid from the empire to path on
		grid.nodes.length = 0;

		DataList@ recvData = ai.empire.getTechnologyNodes();
		TechnologyNode@ node = TechnologyNode();
		while(receive(recvData, node)) {
			grid.nodes.insertLast(node);
			@node = TechnologyNode();
		}

		grid.regenBounds();
	}

	double getEndPointWeight(const TechnologyType& tech) {
		//TODO: Might want to make this configurable by data file
		return 1.0;
	}

	bool isEndPoint(const TechnologyType& tech) {
		return tech.cls >= Tech_BigUpgrade;
	}

	double findResearch(int atIndex, array<TechnologyNode@>& path, array<bool>& visited, bool initial = false) {
		if(visited[atIndex])
			return 0.0;
		visited[atIndex] = true;

		auto@ node = grid.nodes[atIndex];
		if(!initial) {
			if(node.bought)
				return 0.0;
			if(!node.hasRequirements(ai.empire))
				return 0.0;

			path.insertLast(node);

			if(isEndPoint(node.type))
				return getEndPointWeight(node.type);
		}

		vec2i startPos = node.position;
		double totalWeight = 0.0;

		array<TechnologyNode@> tmp;
		array<TechnologyNode@> chosen;
		tmp.reserve(20);
		chosen.reserve(20);

		for(uint d = 0; d < 6; ++d) {
			vec2i otherPos = startPos;
			if(grid.doAdvance(otherPos, HexGridAdjacency(d))) {
				int otherIndex = grid.getIndex(otherPos);
				if(otherIndex != -1) {
					tmp.length = 0;
					double w = findResearch(otherIndex, tmp, visited);
					if(w != 0.0) {
						totalWeight += w;
						if(randomd() < w / totalWeight) {
							chosen = tmp;
						}
					}
				}
			}
		}

		for(uint i = 0, cnt = chosen.length; i < cnt; ++i)
			path.insertLast(chosen[i]);
		return max(totalWeight, 0.01);
	}

	void queueNewResearch() {
		if(log)
			ai.print("Attempted to find new research to queue");

		//Update our grid representation
		updateGrid();

		//Find a good path to do
		array<bool> visited(grid.nodes.length, false);

		double totalWeight = 0.0;

		auto@ path = array<TechnologyNode@>();
		auto@ tmp = array<TechnologyNode@>();
		path.reserve(20);
		tmp.reserve(20);

		for(int i = 0, cnt = grid.nodes.length; i < cnt; ++i) {
			if(grid.nodes[i].bought) {
				tmp.length = 0;
				double weight = findResearch(i, tmp, visited, initial=true);
				if(weight != 0.0) {
					totalWeight += weight;
					if(randomd() < weight / totalWeight) {
						auto@ swp = path;
						@path = tmp;
						@tmp = swp;
					}
				}
			}
		}

		if(path.length != 0) {
			for(uint i = 0, cnt = path.length; i < cnt; ++i) {
				if(log)
					ai.print("Queue research: "+path[i].type.name+" at "+path[i].position);
				immediateQueue.insertLast(path[i]);
			}
		}
	}

	// [[ MODIFY BASE GAME START ]]
	/**
	 * We need FTLExtractors unlocked to buy more FTL income
	 * so we should queue this up once we want additional FTL income
	 */
	void queueFTLIncomeIfNeeded() {
		if (ai.empire.FTLExtractorsUnlocked >= 1) {
			// already unlocked
			return;
		}
		if (!development.requestsFTLIncome()) {
			// don't need more FTL income
			return;
		}
		// TODO: work out how to find a specific technology in the grid
		TechnologyNode@ ftlOrbital = grid.getNode(vec2i(-1,2));
		if (ftlOrbital is null) {
			// doesn't seem to be on the map where we expect it to be
			return;
		}
		if (!ftlOrbital.available || ftlOrbital.bought) {
			return;
		}
		if (ftlOrbital.type.ident == "OrbFTLExtractor") {
			// found it!

			for (uint i = 0, cnt = immediateQueue.length; i < cnt; ++i) {
				if (immediateQueue[i].type.ident == "OrbFTLExtractor") {
					// already queued
					return;
				}
			}
			if (log)
				ai.print("researching FTL income orbital because need FTL income");
			// insert into the front of the list due to the priority
			immediateQueue.insertAt(0, ftlOrbital);
		}
	}
	// [[ MODIFY BASE GAME END ]]

	double immTimer = randomd(10.0, 60.0);
	void focusTick(double time) override {
		// [[ MODIFY BASE GAME START ]]
		queueFTLIncomeIfNeeded();
		// [[ MODIFY BASE GAME END ]]

		//Queue some new research if we have to
		if(immediateQueue.length == 0) {
			immTimer -= time;
			if(immTimer <= 0.0) {
				immTimer = 60.0;
				queueNewResearch();
			}
		}
		else {
			immTimer = 0.0;
		}

		//Deal with current queued research
		if(immediateQueue.length != 0) {
			auto@ node = immediateQueue[0];
			if(!receive(ai.empire.getTechnologyNode(node.id), node)) {
				immediateQueue.removeAt(0);
			}
			else if(!node.available || node.bought) {
				immediateQueue.removeAt(0);
			}
			else {
				double cost = node.getPointCost(ai.empire);
				if(cost == 0) {
					//Try it once and then give up
					ai.empire.research(node.id, secondary=true);
					immediateQueue.removeAt(0);

					if(log)
						ai.print("Attempt secondary research: "+node.type.name+" at "+node.position);
				}
				else if(cost <= ai.empire.ResearchPoints) {
					//If we have enough to buy it, buy it
					ai.empire.research(node.id);
					immediateQueue.removeAt(0);

					if(log)
						ai.print("Purchase research: "+node.type.name+" at "+node.position);
				}
			}
		}
	}
};

AIComponent@ createResearch() {
	return Research();
}
