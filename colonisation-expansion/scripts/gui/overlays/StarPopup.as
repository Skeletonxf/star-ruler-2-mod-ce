import overlays.Popup;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiProgressbar;
import elements.MarkupTooltip;
import icons;
from overlays.ContextMenu import openContextMenu;

class StarPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	Star@ obj;
	double lastUpdate = -INFINITY;

	GuiSprite@ defIcon;

	GuiProgressbar@ health;
	// [[ MODIFY BASE GAME START ]]
	GuiSprite@ shieldIcon;
	GuiProgressbar@ shield;
	GuiText@ temperature;
	// [[ MODIFY BASE GAME END ]]

	StarPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(150, 110);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, Alignment(Left+4, Top+25, Right-4, Bottom-4));

		@defIcon = GuiSprite(this, Alignment(Left+4, Top+25, Width=40, Height=40));
		defIcon.desc = icons::Defense;
		setMarkupTooltip(defIcon, locale::TT_IS_DEFENDING);
		defIcon.visible = false;

		// [[ MODIFY BASE GAME START ]]
		@health = GuiProgressbar(this, Alignment(Left+8, Top+28, Right-8, Top+50));
		health.visible = true;

		@shield = GuiProgressbar(health, Alignment(Left, Bottom-7, Right, Bottom));
		shield.noClip = true;
		shield.tooltip = locale::SHIELD_STRENGTH;
		shield.textHorizAlign = 0.78;
		shield.textVertAlign = 1.55;
		shield.visible = false;
		shield.frontColor = Color(0x429cffff);
		shield.backColor = Color(0x59a8ff20);
		shield.font = FT_Small;

		auto@ healthIcon = GuiSprite(health, Alignment(Left-8, Top-9, Left+24, Bottom-8), icons::Health);
		healthIcon.noClip = true;

		@shieldIcon = GuiSprite(health, Alignment(Right-22, Top, Width=22, Height=22), icons::Shield);
		shieldIcon.visible = false;

		@temperature = GuiText(this, Alignment(Left+4, Bottom-20, Right-8, Bottom));
		temperature.horizAlign = 1.0;
		temperature.font = FT_Detail;
		// [[ MODIFY BASE GAME END ]]

		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return Obj.isStar;
	}

	void set(Object@ Obj) {
		@obj = cast<Star>(Obj);
		@objView.object = Obj;
		// [[ MODIFY BASE GAME START ]]
		if (obj.maxShield > 0) {
			shield.visible = true;
			shieldIcon.visible = true;
			health.textHorizAlign = 0.3;
			health.textVertAlign = 0.25;
		}
		else {
			shield.visible = false;
			shieldIcon.visible = false;
			health.textHorizAlign = 0.5;
			health.textVertAlign = 0.5;
		}
		// [[ MODIFY BASE GAME END ]]
		lastUpdate = -INFINITY;
	}

	Object@ get() {
		return obj;
	}

	void draw() {
		Popup::updatePosition(obj);
		recti bgPos = AbsolutePosition;

		uint flags = SF_Normal;
		SkinStyle style = SS_GenericPopupBG;
		if(isSelectable && Hovered)
			flags |= SF_Hovered;

		Color col;
		Region@ reg = obj.region;
		if(reg !is null) {
			Empire@ other = reg.visiblePrimaryEmpire;
			if(other !is null)
				col = other.color;
		}

		skin.draw(style, flags, bgPos, col);
		if(obj.owner !is null && obj.owner.flag !is null) {
			obj.owner.flag.draw(
				objView.absolutePosition.aspectAligned(1.0, horizAlign=1.0, vertAlign=1.0),
				obj.owner.color * Color(0xffffff30));
		}
		BaseGuiElement::draw();
	}

	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is objView) {
					dragging = false;
					if(!dragged) {
						switch(evt.value) {
							case OA_LeftClick:
								emitClicked(PA_Select);
								return true;
							case OA_RightClick:
								openContextMenu(obj);
								return true;
							case OA_MiddleClick:
							case OA_DoubleClick:
								if(isSelectable)
									emitClicked(PA_Select);
								else
									emitClicked(PA_Manage);
								return true;
						}
					}
				}
			break;
		}
		return Popup::onGuiEvent(evt);
	}

	void update() {
		if(frameTime - 0.2 < lastUpdate)
			return;

		lastUpdate = frameTime;
		const Font@ ft = skin.getFont(FT_Normal);

		defIcon.visible = playerEmpire.isDefending(obj.region);

		//Update name
		name.text = obj.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		// Update temperature
		temperature.text = string(floor(obj.temperature)) + " K";
		// [[ MODIFY BASE GAME START ]]
		// [[ MODIFY BASE GAME START ]]
		//Update health
		health.progress = obj.Health / obj.MaxHealth;
		health.frontColor = colors::Red.interpolate(colors::Green, health.progress);
		health.text = standardize(obj.Health)+" / "+standardize(obj.MaxHealth);
		health.visible = true;

		float curshield = obj.shield;
		float maxshield = max(obj.maxShield, 0.00);

		if (maxshield > 0) {
			shield.visible = true;
			shieldIcon.visible = true;
			health.textHorizAlign = 0.3;
			health.textVertAlign = 0.25;
		}
		else {
			shield.visible = false;
			shieldIcon.visible = false;
			health.textHorizAlign = 0.5;
			health.textVertAlign = 0.5;
		}

		if(shield.visible)
			health.text = standardize(obj.Health);
		// [[ MODIFY BASE GAME END ]]

		//Update shield display
		if (shield.visible) {
			shield.progress = min(curshield / maxshield, 1.0);
			shield.text = standardize(curshield, true);
			shield.tooltip = locale::SHIELD_STRENGTH+": "+standardize(curshield)+" / "+standardize(maxshield);
		}
		// [[ MODIFY BASE GAME END ]]

		Popup::update();
		Popup::updatePosition(obj);
	}
};
