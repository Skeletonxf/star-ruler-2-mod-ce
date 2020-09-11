import orders.Order;
import cargo;
import saving;

// Credit to Dalo Lorn for providing the starting point of this cargo order
// system

tidy class CargoOrder : Order {
    Object@ target;
    int cargoId = -1;
    bool pickup;
    int moveId = -1;

    CargoOrder(Object@ targ, int id, bool pickup) {
        @target = targ;
        cargoId = id;
        this.pickup = pickup;
    }

    CargoOrder(SaveFile& file) {
        Order::load(file);
        file >> target;
        file >> cargoId;
        file >> pickup;
        file >> moveId;
    }

    void save(SaveFile& file) {
        Order::save(file);
        file << target;
        file << cargoId;
        file << pickup;
        file << moveId;
    }

    string get_name() {
        string cargoName = getCargoType(cargoId).name;
        string opType = pickup ? locale::ABL_PICKUP_SPECIFIC_CARGO : locale::ABL_TRANSFER_SPECIFIC_CARGO;
        return format(opType, cargoName);
    }

    bool get_hasMovement() {
        return true;
    }

    vec3d getMoveDestination(const Object& obj) {
        if(target !is null) return target.position;
        else return vec3d();
    }

    OrderType get_type() {
        return OT_Cargo;
    }

    OrderStatus tick(Object& obj, double time) {
        if (!obj.hasMover || !obj.hasCargo || target is null || !target.hasCargo || target.owner !is obj.owner) {
            return OS_COMPLETED;
        }

        const CargoType@ type = getCargoType(cargoId);
        Object@ src = pickup ? target : obj;
        Object@ dest = pickup ? obj : target;
        if(type is null || type.storageSize > dest.cargoCapacity - dest.cargoStored || src.getCargoStored(cargoId) < 0.001)
            return OS_COMPLETED;

        double range = 100 + obj.radius + target.radius;
        double distance = obj.position.distanceToSQ(target.position);
        if(distance >= range*range) {
            obj.moveTo(target, moveId, range * 0.95, enterOrbit = false);
        }
        else {
            src.transferCargoTo(cargoId, dest);
            if(moveId != -1) {
                moveId = -1;
                obj.stopMoving(false, false);
            }
            return OS_COMPLETED;
        }
        return OS_BLOCKING;
    }
}
