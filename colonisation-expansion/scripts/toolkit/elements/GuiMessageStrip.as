#section game
import elements.BaseGuiElement;
import elements.GuiSprite;
import elements.GuiMarkupText;
import elements.MarkupTooltip;
import notifications;

class GuiMessageStrip : BaseGuiElement {
	uint nextNotify = 0;
	array<Notification@> unhandled;
	array<Notification@> handled;
	array<GuiMarkupText@> items;

	int padding = 2;
	int margin = 7;
	double minGameTime = 0.0;

	GuiMessageStrip(IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
		minGameTime = gameTime;
	}

	void update(Empire& emp) {
		// Update notifications
		uint latest = emp.notificationCount;
		if (latest != nextNotify) {
			receiveNotifications(unhandled, emp.getNotifications(100, nextNotify, false));
			nextNotify = latest;
		}

		uint oldCnt = handled.length;

		// Handle all unhandled
		if (unhandled.length > 0) {
			for (uint i = 0, cnt = unhandled.length; i < cnt; ++i)
				handle(unhandled[i]);
			unhandled.length = 0;
		}

		uint newCnt = handled.length;

		if (newCnt == oldCnt) {
			return;
		}

		updateMessages();
	}

	void updateMessages() {
		// sync items.length to handled.length
		uint oldCnt = items.length;
		uint newCnt = handled.length;

		if (newCnt == oldCnt) {
			return;
		}

		// remove extra items
		for (uint i = newCnt; i < oldCnt; ++i) {
			items[i].remove();
		}
		items.length = newCnt;
		// fill in new ones
		for (uint i = oldCnt; i < newCnt; ++i) {
			@items[i] = GuiMarkupText(this, recti());
		}

		// set positions of items
		int x = padding;
		for (uint i = 0; i < newCnt; ++i) {
			string label = getLabel(handled[i]);
			items[i].text = label;
			items[i].flexHeight = false;
			items[i].fitWidth = true;
			items[i].updateAbsolutePosition();
			int w = items[i].textWidth + margin;
			items[i].rect = recti_area(x, 26, w, 46);
			x += w + padding;
			// TODO: Do something about overflow
			/* if (x > size.w) {
				return;
			} */
		}
	}

	void handle(Notification@ notification) {
		if (n.time <= minGameTime)
			return;
		if (getLabel(notification) != "") {
			handled.insertLast(notification);
		}
	}

	string getLabel(Notification@ notification) {
		// TODO: Only display a custom class of notifications
		return notification.formatEvent();
	}

	int findMessage(int position) {
		int x = padding;
		for (uint i = 0, cnt = items.length; i < cnt; ++i) {
			int w = items[i].textWidth + margin;
			if (position >= x && position <= x + w) {
				return i;
			}
			x += w + padding;
		}
		return -1;
	}

	void clearMessage(const MouseEvent& mevt) {
		int index = findMessage(mevt.x);
		if (index >= 0 && uint(index) < handled.length) {
			handled.removeAt(uint(index));
			updateMessages();
		}
	}

	bool onMouseEvent(const MouseEvent& mevt, IGuiElement@ caller) override {
		if(mevt.type == MET_Button_Down) {
			return true;
		}
		else if(mevt.type == MET_Button_Up) {
			if (mevt.button == 0) {
				// TODO: Left click should also jump camera to object
				clearMessage(mevt);
			} else if(mevt.button == 1) {
				clearMessage(mevt);
			} else if(mevt.button == 2) {
				clearMessage(mevt);
			}
			return true;
		}

		return BaseGuiElement::onMouseEvent(mevt, caller);
	}
};
