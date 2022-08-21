#section game
import elements.BaseGuiElement;
import elements.MarkupTooltip;
import statuses;
// [[ MODIFY BASE GAME START ]]
import util.formatting;
// [[ MODIFY BASE GAME END ]]

export GuiStatusBox;
export updateStatusBoxes;

class GuiStatusBox : BaseGuiElement {
	Status status;
	Object@ fromObject;
	// [[ MODIFY BASE GAME START ]]
	MarkupTooltip@ lazyTooltip;
	// [[ MODIFY BASE GAME END ]]

	GuiStatusBox(IGuiElement@ parent) {
		super(parent, recti());
		// [[ MODIFY BASE GAME START ]]
		@lazyTooltip = addLazyMarkupTooltip(this, width=350);
		// [[ MODIFY BASE GAME END ]]
	}

	GuiStatusBox(IGuiElement@ parent, const recti& pos) {
		super(parent, pos);
		// [[ MODIFY BASE GAME START ]]
		@lazyTooltip = addLazyMarkupTooltip(this, width=350);
		// [[ MODIFY BASE GAME END ]]
		updateAbsolutePosition();
	}

	void update(const Status& other) {
		status = other;
	}

	string get_tooltip() {
		// [[ MODIFY BASE GAME START ]]
		if (status.type.showDuration) {
			int index = fromObject.getStatusEffectOfType(status.type.id);
			if (index != -1) {
				double duration = fromObject.get_statusEffectDuration(index);
				if (duration > 0) {
					lazyTooltip.LazyUpdate = true;
					return status.getTooltip(valueObject=fromObject) + "\nDuration: " + format(locale::TIME_S, toString(duration, 0));
				}
			}
			lazyTooltip.LazyUpdate = false;
			return status.getTooltip(valueObject=fromObject);
		} else {
			lazyTooltip.LazyUpdate = false;
		}
		// [[ MODIFY BASE GAME END ]]
		return status.getTooltip(valueObject=fromObject);
	}

	void draw() {
		(spritesheet::ResourceIconsSmallMods+0).draw(AbsolutePosition, status.type.color);
		status.type.icon.draw(AbsolutePosition.padded(2));

		if(!status.type.unique && status.stacks > 1) {
			skin.getFont(FT_Bold).draw(
				pos=AbsolutePosition.padded(0,0,0,5),
				horizAlign=1.0,
				vertAlign=1.0,
				text=format("x$1", toString(status.stacks)),
				stroke=colors::Black,
				color=status.type.color);
		}

		BaseGuiElement::draw();
	}
};

void updateStatusBoxes(IGuiElement@ parent, array<Status>& statuses, array<GuiStatusBox@>& boxes, Object@ fromObject = null) {
	uint prevCnt = boxes.length, cnt = statuses.length;
	for(uint i = cnt; i < prevCnt; ++i)
		boxes[i].remove();
	boxes.length = cnt;
	for(uint i = 0; i < cnt; ++i) {
		auto@ icon = boxes[i];
		if(icon is null) {
			@icon = GuiStatusBox(parent);
			@boxes[i] = icon;
		}
		@icon.fromObject = fromObject;
		icon.update(statuses[i]);
	}
}
