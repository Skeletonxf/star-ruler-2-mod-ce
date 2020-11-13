# Colonisation Expansion

This is a mod for Star Ruler 2. It is now growing into a mod that provides many features to make the game feel more rich without drastically changing the gameplay. This mod provides many options to build an empire up vertically (as opposed to building an empire up by taking more systems), as well as the start of a single player campaign, and improved AI code.

## Status

I consider this mod at playable status now. There's still some rough edges but it should be stable and balanced enough to play with.

## Installation

Although you can use GitHub's Download Zip button to download the latest version of this mod I suggest you go to the [releases page](https://github.com/Skeletonxf/star-ruler-2-mod-ce/releases) to download the latest released version. Extract the mod out of the colonisation-expansion folder and place it into the mods folder of a [Star Ruler 2](https://github.com/BlindMindStudios/StarRuler2-Source) installation.

Alternatively you can use [Star Ruler 2 Mod Manager](https://github.com/DaloLorn/SR2ModManager) to install and update this mod.

## Features

### A singleplayer campaign!
Still a work in progress, but there is one puzzle available and more scenarios are in the works.
### Several biome based planet constructions and 'terraforming' options
I'm aiming for a creating a comprehensive set of constructions to terraform planets based on what is already there in terms of biomes and statuses as a replacement to the default game's Terraforming mechanic. 'Terraforming' won't let you turn any planet into anything you like, but it will mostly be additive instead of replacing existing resources. Currently features conversion of less useful biomes into beter ones for buildings to be on, creating a tier 2 resource on certain rock planets, creating a tier 1 resource on rock planets, and blowing up a planet into pieces to obtain an ore resource. You can also melt ice to obtain water, and set your homeworld.
### Food system reworked
This is probably the biggest divergence from vanilla. Food planets are much rarer. Food planets gradually 'forest' the planets they export to, giving each of those planets 3 unexportable food resources over time. Food planets therefore aren't needed to support level 1, 2, and 3 planets long term.
In practise in the early game you start out limited by food much like in vanilla but as the game progresses whenever you need food you can cancel an earlier food export to any planet that has since forested its own food and redirect the food resources to your new planet that needs it. In this way you quite reliably reach a point at which you can always provide food to higher level planets, and if you combine with water comets you can make tier 1 planets self sustaining without imports or maintenance costs.

The AI already understands how to change exports as it gains food and hence works with this rework quite well. I think this system feels much better and also more realistic. As your empire expands being limited by 'food planets' feels a little silly and food planets being as common as they are in vanilla clashes with a lot of expectations about how rare life is.

Also comes with forestry notifications: <img src="screenshots/forestry-notification-levels.png?raw=true" alt="Forestry notifications" height="45px">
### Gas and ice giants
Ice Giants and Gas Giants are intended to be more difficult to colonise than rock planets, but provide useful ways to keep expanding your economy once your borders are constrained.
### Additional subsystems/hulls for low maintence exploration and mining ships
Scouting and mining cost much less in maintence.
#### Mining logistics improvements
Ships ordered to mine can now mine cross systems, and will only stop if you deplete all asteroids known to your empire. Mining asteroid belts is a lot more efficient than in vanilla. You can also queue transfer and dropoff cargo orders if you'll meet the requirements by the time the ship would execute the order. (ie you can order an ore pickup and immediately queue the ore dropoff because you'll have ore to dropoff by the time you need it). Cargo pickups and dropoffs can now be done per cargo type.
### Support ship shields
You can now put shields on supports, and Devout can unlock shrines for supports.
### Tweaks to motherships
Mothership max population scales with ship size and provides labor. Motherships can also use an ability on planets to deal damage to them and gain additional max pop. Note that the max pop for any ship design still avoids creating net positive income as with vanilla for balancing, so to get to net positive income you'll need to consume planets which aren't an infinite resource.
### Dilemma conditions that appear on planets and force you to make hard decisions
There's several of these, and the AI handles the main one. I don't want to spoil them for your first playthough :)
### Completely reworked research grid with similar research grouped together
Research is somewhat easier to rush as you don't have to unlock loads of things you didn't want on the way.
### Exponential scaling of distance build penalties
Just because you have a 300 labor planet shouldn't mean you can build an outpost halfway across the galaxy in less than a second. Now the penalty scales exponentially with the number of hops rather than linearly, so will always outscale the labor production you can produce as the game goes on. This is also much more realistic and encourages researching Gates or having multiple labor centres.
### Massively nerfed ship stat bonuses from research
I found in many games of unmodded Star Ruler my ships were either orders of magnitude stronger than my opponent's or orders of magnitude weaker. Nerfing stat bonuses makes ships much closer in strength even if one empire is ahead in terms of eco/research. To get more powerful ships you actually have to have the economy to field larger ships rather than just stacking multipliers that turn ks of combat strength into Ms of combat strength for free.
### Rebalanced Carpet Bombs
Carpet Bombs can now be directly countered by making certain buildings or orbitals which reduce the effectiveness, but more importantly it is not possible to abuse edge cases in the subsystem variable code to make extremely cheap ships that can delevel tier 2+ planets in seconds.
### Diplomatic Victory
You can snowball your diplomatic strength with Diplomatic Maneuvering if you play your cards right. Senatorial Palaces are now disabled if they leave your owned space. Planets in deep space can now be targeted for annex votes if you can obtain vision of them.
### Attitude tweaks
Attitudes which require maintaining x can no longer go into the negatives (as they will now count progress you made before starting the attitude). Xenophobic no longer requires you put the Outposts in border systems.
### Secret Project overhaul
Secret projects are no longer secret, you will be able to unlock any of them if you meet the unlock requirements as in vanilla. Artifical Moons require building moon bases instead of ring habitats. The Innovation card now grants you random unlocks on the reserach grid, which can let you leapfrog into unexplored areas of the tech tree. Ironically Innovation will never give you a Secret Project anymore.
### Ability to unlock all types of FTL and FTL income orbital from the research grid
For balancing this is a costly research path to go down and provides few other benefits. Each unlock also starts a vote to give the technology to all empires. This makes getting extra FTL technology a tradeoff as you might not keep it exclusive to just you, and then your research points have been wasted on something your opponents got for free.
#### Supplementary new FTL
Jumpdrives can be unlocked for Stations
### FTL Sharing
New treaty clause that shares access of Gates and Fling beacons between signatories.
### Biology traits such as Aquatic or Flying
These traits have positive and negative factors together. New races featuring these traits:
#### Parasite
This trait makes you get only half of the pressure from planetary resources, but allows you to raze planets down to nothing, gaining massively increased resource production while doing so. Includes dedicated AI support.
### Battleworlders
The battleworlders lifestyle makes every planet a battleworld, and lets your empire conquer the galaxy from the comfort of its own planets. No AI support at this time. Inspired by Philip Reeve's Mortal Engines series and Darloth's / Dalo Lorn's Ringworlders. Balancing far from final.
A number of Quality of Life changes to mobile planets in general have also been made, including: planets no longer grant everyone vision of them if they go into deep space, memory of objects are now lost if they leave regions or move around in deep space, and planets can be ordered to attack.
### Improved AI
AI will build moon bases on Gas Giants unless it's playing as Star Children or Ancient and thus doesn't need to. AI can handle having multiple FTL abilities unlocked at once. AI will build FTL income orbitals if it needs more FTL income. AI will seek to counter carpet bombing if it sees an opponent with them (AIs cannot do carpet bombing raids themselves yet). Reworked and improved AI colonising and planet leveling are in progress.
#### Military
The AI will be much more eager to build military flagships when it has spare money than vanilla, and it will prepare designs in advance.
#### Colonisation and Development
Overhaul still work in progress, but the AI will now correctly detect dummy resources.

## Copying and license info
My own AngelScript code in this mod is licensed under the MIT license. Most of the AngelScript code in this repository comes from the source code of Star Ruler 2 by [Blind Mind Studios](https://github.com/BlindMindStudios/StarRuler2-Source) which is also MIT licensed. The assets in Star Ruler 2 were placed under the Creative Commons CC-BY-NC license, which permits free non commercial use. The art assets I've added in this mod are licensed under the Creative Commons [CC-BY license](https://creativecommons.org/licenses/by/4.0/) instead, which permits commercial use just as the MIT license does. I try not to accidently commit any of the CC-BY-NC SR2 assets or derivations of them into this repository. However this mod does include the CC-BY-NC Bromma and Farum shipsets (`data/shipsets/bromma` and `data/shipsets/farum` respectively) released as part of the open sourcing of SR2 as these are not present in the Steam version of the game and cause cross play issues if not modded in to ensure all clients have them.

Some parts of this mod are derived from the MIT licensed code in [Rising Stars](https://github.com/DaloLorn/Rising-Stars) by Dalo Lorn.
