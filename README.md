# Colonisation Expansion

This is a mod for Star Ruler 2. I started this aiming to make planets feel more unique by providing several dillemas and surface modifying options based on their biomes. It is now growing into a mod that provides many features to make the game feel more rich without drastically changing the gameplay.

## Status

I consider this mod at playable status now. There's still many rough edges but it should be stable and balanced enough to play with.

## Installation

Although you can use GitHub's Download Zip button to download the latest version of this mod I suggest you go to the [releases page](https://github.com/Skeletonxf/star-ruler-2-mod-ce/releases) to download the latest released version. Extract the mod out of the colonisation-expansion folder and place it into the mods folder of a [Star Ruler 2](https://github.com/BlindMindStudios/StarRuler2-Source) installation.

## Features

### Several biome based planet constructions and 'terraforming'<sup>1</sup> options
### Food system reworked
This is probably the main/biggest/only divergence from vanilla. Food planets are much rarer. Food planets gradually 'forest' the planets they export to, giving each of those planets 3 unexportable food resources over time. Food planets therefore aren't needed to support level 1, 2, and 3 planets long term.
In practise in the early game you start out limited by food much like in vanilla but as the game progresses whenever you need food you can cancel an earlier food export to any planet that has since forested its own food and redirect the food resources to your new planet that needs it. In this way you quite reliably reach a point at which you can always provide food to higher level planets, and if you combine with water comets you can make tier 1 planets self sustaining without imports or maintenance costs.

The AI already understands how to change exports as it gains food and hence works with this rework quite well. It won't pickup excess Forestation cargo and divert to a new planet, but in practise I don't think this is something players will/need to do.
I think this system feels much better and also more realistic. As your empire expands being limited by 'food planets' feels a little silly and food planets being as common as they are in vanilla clashes with a lot of expectations about how rare life is.

Also comes with forestry notifications: <img src="screenshots/forestry-notification-levels.png?raw=true" alt="Forestry notifications" height="45px">
### Gas and ice giants
Still in need of more variety, and making the construction of moon bases more essential.
### Additional subsystems/hulls for low maintence exploration and mining ships
### Tweaks to motherships
Mothership max population scales with ship size and provides labor. Motherships can also use an ability on planets to deal damage to them and gain additional max pop. Note that the max pop for any ship design still avoids creating net positive income as with vanilla for balancing, so to get to net positive income you'll need to consume planets which aren't an infinite resource.
### Dilemma conditions that appear on planets and force you to make hard decisions
There's sevearl of these, and the AI handles the main one. I don't want to spoil them for your first playthough :)
### Completely reworked research grid with similar research grouped together
From games with my empire set to the AI I think the AI explores this tree pretty well even though the algorithm is aimless
### Exponential scaling of distance build penalties
Just because you have a 300 labor planet shouldn't mean you can build an outpost halfway across the galaxy in less than a second. Now the penalty scales exponentially with the number of hops rather than linearly, so will always outscale the labor production you can produce as the game goes on. This is also much more realistic and encourages researching Gates or having multiple labor centres.
### Massively nerfed ship stat bonuses from research
I found in many games of unmodded Star Ruler my ships were either orders of magnitude stronger than my opponent's or orders of magnitude weaker. Nerfing stat bonuses makes ships much closer in strength even if one empire is ahead in terms of eco/research. To get more powerful ships you actually have to have the economy to field larger ships rather than just stacking multipliers that turn ks of combat strength into Ms of combat strength for free. I have only done a few full playthroughs yet so balance is very far from final.
### Ability to unlock all types of FTL and FTL income orbital from the research grid
For balancing this is a costly research path to go down and provides few other benefits. Each unlock also starts a vote to give the technology to all empires. This makes getting extra FTL technology a tradeoff as you might not keep it exclusive to just you, and then your research points have been wasted on something your opponents got for free.
#### Supplementary new FTL
Jumpdrives can be unlocked for Stations
### Biology traits such as Aquatic or Flying
These traits have positive and negative factors together. New races featuring these traits.
#### Parasite
This trait makes you get only half of the pressure from planetary resources, but allows you to raze planets down to nothing, gaining massively increased resource production while doing so. I've added special AI support for this trait, and while the AI code still needs improvements it's playable.
### Battleworlders
The battleworlders lifestyle makes every planet a battleworld, and lets your empire conquer the galaxy from the comfort of its own planets. No AI support at this time. Inspired by Philip Reeve's Mortal Engines series and Dalo Lorn's Ringworlders.
### Improved AI
AI will build moon bases on Gas Giants unless it's playing as Star Children or Ancient and thus doesn't need to. AI can handle having multiple FTL abilities unlocked at once. AI will build FTL income orbitals if it needs more FTL income

*****

- 1 I'm aiming for a creating a comprehensive set of constructions to terraform planets based on what is already there as a replacement to the default game's Terraforming mechanic.
