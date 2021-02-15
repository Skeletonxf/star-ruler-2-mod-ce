import orders.Order;
import resources;
import attributes;
import ftl;

tidy class LoopOrder : Order {
	bool isLoop;

	LoopOrder(bool isLoop) {
		this.isLoop = isLoop;
	}

	LoopOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> isLoop;
	}

	void save(SaveFile& msg) override {
		Order::save(msg);
		msg << isLoop;
	}

	OrderType get_type() override {
		return OT_Loop;
	}

	string get_name() override {
		return "Loop";
	}

	void updateLooping(Object& obj, bool isLoop) {
		obj.setLooping(isLoop);
	}

	bool cancel(Object& obj) override {
		updateLooping(obj, false);
		return true;
	}

	bool get_hasMovement() override {
		return false;
	}

	OrderStatus tick(Object& obj, double time) override {
		updateLooping(obj, isLoop);
		return OS_COMPLETED;
	}
};
