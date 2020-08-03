import menus;
import saving;
import dialogs.MessageDialog;
import dialogs.QuestionDialog;
import dialogs.InputDialog;
import elements.GuiMarkupText;
import settings.game_settings;
from irc_window import LinkableMarkupText;
import icons;
// Reuse the scenario loading code Blind Mind wrote, and present the scenarios
// with this custom GUI code
import campaign;

class ScenarioAction : MenuAction {
	const CampaignScenario@ scenario;

	ScenarioAction(const CampaignScenario@ scenario) {
		super(scenario.picture, scenario.name, 0);
		@this.scenario = scenario;
	}

	void draw(GuiListbox@ ele, uint flags, const recti& absPos) override {
		color = colors::White;
		MenuAction::draw(ele, flags, absPos);

		int h = absPos.height;
		recti iPos = recti_area(vec2i(absPos.botRight.x-h-80+8, absPos.topLeft.y+10), vec2i(h-18, h-18));
		recti tPos = recti_area(vec2i(absPos.botRight.x-80, absPos.topLeft.y+2), vec2i(78, h-2));
		const Font@ ft = ele.skin.getFont(FT_Bold);
		if(scenario.completed) {
			icons::Strength.draw(iPos);
			ft.draw(pos=tPos, text=locale::SCENARIO_COMPLETED, stroke=colors::Black, color=colors::Green);
		}
		else {
			icons::Explore.draw(iPos);
			ft.draw(pos=tPos, text=locale::SCENARIO_INCOMPLETED, stroke=colors::Black, color=colors::Green);
		}
	}

	int opCmp(const ScenarioAction@ other) const {
		// TODO
		return 0;
	}
};

bool inOpenPage = false;
class CampaignMenu : MenuBox {
	ScenarioBox box;
	int prevSelected = -1;
	array<ScenarioAction@> actions;

	CampaignMenu() {
		super();
		items.alignment.bottom.pixels = 40;
	}

	void buildMenu() {
		title.text = "Campaign";
		selectable = true;
		items.required = true;

		if(inOpenPage)
			items.addItem(MenuAction(Sprite(spritesheet::MenuIcons, 10), locale::MENU_CONTINUE_MAIN, 0));
		else
			items.addItem(MenuAction(Sprite(spritesheet::MenuIcons, 11), locale::MENU_BACK, 0));

		string sel = "";
		if(prevSelected >= 1 && uint(prevSelected-1) < actions.length)
			sel = actions[prevSelected-1].scenario.name;
		actions.length = 0;

		uint scenarios = getCampaignScenarioCount();
		for (uint i = 0, cnt = scenarios; i < cnt; ++i) {
			ScenarioAction action(getCampaignScenario(i));
			actions.insertLast(action);
		}

		actions.sortAsc();
		for(uint i = 0, cnt = actions.length; i < cnt; ++i) {
			actions[i].value = int(i+1);
			if(actions[i].scenario.name == sel)
				prevSelected = i;
			items.addItem(actions[i]);
		}
		if(prevSelected < 1)
			prevSelected = 1;
		if(items.selected < 1)
			items.selected = min(prevSelected, items.itemCount-1);
		update();
	}

	void update() {
		if(items.selected < 1 || uint(items.selected-1) >= actions.length)
			return;
		auto@ scenario = actions[items.selected-1].scenario;
		if(scenario !is null)
			box.update(scenario);
	}

	bool onGuiEvent(const GuiEvent& event) {
		if(event.type == GUI_Clicked) {
		}
		return MenuBox::onGuiEvent(event);
	}

	void onSelected(const string& name, int value) {
		if(value == 0) {
			switchToMenu(main_menu, false);
			inOpenPage = false;

			return;
		}
		else {
			prevSelected = value;
			items.selected = value;
			update();
		}
	}

	void animate(MenuAnimation type) {
		if(type == MAni_LeftOut || type == MAni_RightOut)
			showDescBox(null);
		MenuBox::animate(type);
	}

	void completeAnimation(MenuAnimation type) {
		if(type == MAni_LeftShow || type == MAni_RightShow)
			showDescBox(box);
		MenuBox::completeAnimation(type);
	}

	void draw() {
		/* for(uint i = 0, cnt = actions.length; i < cnt; ++i)
			actions[i].tex.stream(); */
		MenuBox::draw();
	}
};

void startScenario(string mapName) {
	// TODO: start the scenario
	GameSettings settings;
	settings.defaults();
	settings.galaxies[0].map_id = mapName;

	Message msg;
	settings.write(msg);
	startNewGame(msg);
}

class ConfirmStart : QuestionDialogCallback {
	string mapName;

	ConfirmStart(string mapName) {
		// TODO: pass the scenario into here
		this.mapName = mapName;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			startScenario(mapName);
	}
};

class ScenarioBox : DescBox {
	const CampaignScenario@ scenario;
	GuiPanel@ descPanel;
	GuiSprite@ picture;
	GuiMarkupText@ description;
	GuiButton@ playButton;

	ScenarioBox() {
		super();

		@picture = GuiSprite(this, Alignment(Left, Top+44, Right, Top+144));

		@descPanel = GuiPanel(this, Alignment(Left+16, Top+154, Right-16, Bottom-50));
		@description = LinkableMarkupText(descPanel, recti_area(0,0,100,100));
		description.fitWidth = true;

		@playButton = GuiButton(this, Alignment(Left+0.5f-100, Bottom-50, Left+0.5f+100, Bottom-8));
		playButton.font = FT_Subtitle;
		playButton.visible = false;

		updateAbsolutePosition();
		updateAbsolutePosition();
	}

	void update(const CampaignScenario@ scenario) {
		@this.scenario = scenario;
		title.text = scenario.name;
		picture.desc = scenario.picture;
		string descText;
		descText += scenario.description;
		playButton.visible = true;
		playButton.disabled = false;

		playButton.color = colors::Green;
		playButton.buttonIcon = icons::Explore;
		playButton.text = "Start";

		description.text = makebbLinks(descText);
		updateAbsolutePosition();
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		if(evt.type == GUI_Clicked && evt.caller is playButton) {
			if(game_running)
				question(locale::PROMPT_SANDBOX, ConfirmStart(scenario.mapName));
			else
				startScenario(scenario.mapName);
			return true;
		}
		return DescBox::onGuiEvent(evt);
	}
};

void init() {
	@campaign_menu = CampaignMenu();
}

void postInit() {
}
