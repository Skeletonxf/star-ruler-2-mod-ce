#section game
import elements.BaseGuiElement;
import elements.GuiSprite;
import elements.GuiText;
import elements.MarkupTooltip;
import notifications;

/* class GuiMessageStripItem : BaseGuiElement {
	GuiText@ text;

	GuiMessageStripItem(Notification@ notification, IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
		int padding = 2;
		const Font@ ft = skin.getFont(FT_Normal);
		int x = padding
		int s = size.height-padding-padding;
		int w = ft.getDimension("test").x + 3;
		@text = GuiText(this, Alignment(), "test");
		print("created item");
		text.color = Color(0xddddddff);
	}
} */

class GuiMessageStrip : BaseGuiElement {
	uint nextNotify = 0;
	array<Notification@> unhandled;
	array<Notification@> handled;
	array<GuiText@> items;
	/* array<GuiSprite@> icons;
	array<GuiText@> values; */

	int padding = 2;

	GuiMessageStrip(IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
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

		// TODO: Notification culling
		uint newCnt = handled.length;

		if (newCnt == oldCnt) {
			return;
		}

		for(uint i = newCnt; i < oldCnt; ++i) {
			items[i].remove();
		}
		items.length = newCnt;
		//handled.length = newCnt;
		for(uint i = oldCnt; i < newCnt; ++i) {
			@items[i] = GuiText(this, recti());
		}

		const Font@ ft = skin.getFont(FT_Normal);
		int x = padding;
		int s = size.height;
		for (uint i = 0; i < newCnt; ++i) {
			string label = getLabel(handled[i]);
			int w = ft.getDimension(label).x + 3;
			items[i].text = label;
			items[i].rect = recti_area(x, 8, w, s+8);
			x += w + padding;
		}
	}

	void handle(Notification@ notification) {
		/* if(n.time <= 0) // minGameTime
			return; */
		if (getLabel(notification) != "") {
			handled.insertLast(notification);
		}
	}

	string getLabel(Notification@ notification) {
		// TODO: Only display notifications which are a custom class
		return notification.formatEvent();
		/*
		auto@ n = cast<GenericNotification>(notification);
		if (n !is null) {
			return n.desc;
		}
		// TODO: case over the other types
		return "TODO"; */
	}
};
