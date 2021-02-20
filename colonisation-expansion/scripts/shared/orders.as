enum OrderType {
	OT_Attack,
	OT_Goto,
	OT_Hyperdrive,
	OT_Move,
	OT_PickupOrder,
	OT_Capture,
	OT_Scan,
	OT_Refresh,
	OT_Fling,
	OT_OddityGate,
	OT_Slipstream,
	OT_Ability,
	OT_AutoExplore,
	OT_Wait,
	OT_Jumpdrive,
	// [[ MODIFY BASE GAME START ]]
	OT_Cargo,
	OT_AutoMine,
	OT_AutoSupply,
	OT_Chase,
	OT_ConsumePlanet,
	OT_Loop,
	// [[ MODIFY BASE GAME END ]]
	OT_INVALID
};

bool isFTLOrder(uint type) {
	return type == OT_Hyperdrive || type == OT_Slipstream || type == OT_Fling || type == OT_Jumpdrive;
}

class OrderDesc : Serializable {
	uint type;
	bool hasMovement;
	vec3d moveDestination;
	// [[ MODIFY BASE GAME START ]]
	// Extra info for the clients so they can present cargo
	// order options smartly. This is a bit of a hack because
	// it's quite a waste to pass this for every non cargo
	// order.
	int cargoId = -1;
	bool isPickup = false;
	bool isDropoff = false;
	// [[ MODIFY BASE GAME END ]]

	void write(Message& msg) {
		msg << uint(type);
		if(hasMovement) {
			msg.write1();
			msg << moveDestination;
		}
		else {
			msg.write0();
		}
		// [[ MODIFY BASE GAME START ]]
		msg << cargoId;
		msg << isPickup;
		msg << isDropoff;
		// [[ MODIFY BASE GAME END ]]
	}

	void read(Message& msg) {
		msg >> type;
		hasMovement = msg.readBit();
		if(hasMovement)
			msg >> moveDestination;
		// [[ MODIFY BASE GAME START ]]
		msg >> cargoId;
		msg >> isPickup;
		msg >> isDropoff;
		// [[ MODIFY BASE GAME END ]]
	}
};
