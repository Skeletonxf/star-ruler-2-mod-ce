#section game
import elements.BaseGuiElement;
import elements.GuiSprite;
import elements.GuiMarkupText;
import elements.MarkupTooltip;
import notifications;
import notifications.notifications;

class GuiMessageStrip : BaseGuiElement {
	uint nextNotify = 0;
	array<Notification@> unhandled;
	array<Notification@> handled;
	array<GuiMarkupText@> items;
	GuiMarkupText@ overflow;

	int padding = 2;
	int margin = 17;
	double minGameTime = 0.0;

	GuiMessageStrip(IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
		minGameTime = gameTime;
		@overflow = GuiMarkupText(this, recti());
		overflow.flexHeight = false;
		overflow.expandWidth = true;
	}

	void update(Empire& emp) {
		// Update notifications
		uint latest = emp.notificationCount;
		if (latest != nextNotify) {
			receiveNotifications(unhandled, emp.getNotifications(100, nextNotify, false));
			nextNotify = latest;
		}

		bool needsUpdate = unhandled.length != 0;

		if (!needsUpdate) {
			return;
		}

		// Handle all unhandled
		if (unhandled.length > 0) {
			for (uint i = 0, cnt = unhandled.length; i < cnt; ++i)
				handle(unhandled[i]);
			unhandled.length = 0;
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

		toggleOverflowIndicator(false);

		// try to draw forwards, so everything is positioned nicely
		bool overflow = false;
		int x = padding;
		for (uint i = 0; i < newCnt; ++i) {
			string label = getLabel(handled[i]);
			items[i].text = label;
			items[i].flexHeight = false;
			items[i].expandWidth = true;
			items[i].visible = true;
			items[i].updateAbsolutePosition();
			int w = items[i].textWidth + margin;
			items[i].rect = recti_area(x, 27, w, 47);
			x += w + padding;
			if (x > size.width) {
				overflow = true;
			}
		}

		if (overflow) {
			// draw backwards so most recent stay visible
			int x = size.width - padding;
			for (uint index = newCnt; index > 0; --index) {
				uint i = index - 1;
				items[i].visible = true;
				items[i].updateAbsolutePosition();
				int w = items[i].textWidth + margin;
				items[i].rect = recti_area(x - w, 27, x, 47);
				x -= w + padding;
				if (x < 0) {
					items[i].visible = false;
				}
			}
			toggleOverflowIndicator(true);
		}
	}

	void toggleOverflowIndicator(bool show) {
		if (show) {
			overflow.text = "...";
			overflow.visible = true;
		} else {
			overflow.text = "";
			overflow.visible = false;
		}
		overflow.updateAbsolutePosition();
		int w = overflow.textWidth + margin;
		overflow.rect = recti_area(0, 27, w, 47);
	}

	void handle(Notification@ notification) {
		if (notification.time <= minGameTime)
			return;
		if (getLabel(notification) != "") {
			string newLabel = getLabel(notification);
			for (uint i = 0, cnt = handled.length; i < cnt; ++i) {
				if (getLabel(handled[i]) == newLabel) {
					// we already had this notification from earlier, remove
					// the old one
					handled.removeAt(i);
					updateMessages();
					break;
				}
			}
			handled.insertLast(notification);
		}
	}

	string getLabel(Notification@ notification) {
		if(notification.get_type() != NT_Message)
			return ""; // ignore other classes of notifications
		return notification.formatEvent();
	}

	int findMessage(int position) {
		int x = padding;
		for (uint i = 0, cnt = items.length; i < cnt; ++i) {
			if (!items[i].visible)
				continue;
			int w = items[i].textWidth + margin;
			if (position >= x && position <= x + w) {
				return i;
			}
			x += w + padding;
		}
		return -1;
	}

	void clearMessage(const MouseEvent& mevt, bool goTo = false) {
		int index = findMessage(mevt.x);
		if (index < 0) {
			return;
		}
		uint i = uint(index);
		if (i < handled.length) {
			if (goTo) {
				gotoNotification(handled[i]);
			}
			handled.removeAt(i);
			updateMessages();
		}
	}

	bool onMouseEvent(const MouseEvent& mevt, IGuiElement@ caller) override {
		if(mevt.type == MET_Button_Down) {
			return true;
		}
		else if(mevt.type == MET_Button_Up) {
			if (mevt.button == 0) {
				clearMessage(mevt, goTo = true);
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
