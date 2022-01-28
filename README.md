# Colonisation Expansion

*Become a type II civilisation as you engineer the galaxy to your whims, or die trying*

This is a mod for Star Ruler 2. It is now growing into a mod that provides many features to make the game feel more rich without drastically changing the gameplay. This mod provides many options to build an empire up vertically (as opposed to building an empire up by taking more systems), as well as the start of a single player campaign, and improved AI code.

## Status

I consider this mod at playable status now. It should be stable and balanced enough to play with.

## Installation

Although you can use GitHub's Download Zip button to download the latest version of this mod, for the latest release version go to the [tags page](https://github.com/Skeletonxf/star-ruler-2-mod-ce/tags). Extract the mod out of the colonisation-expansion folder and place it into the mods folder of a [Star Ruler 2](https://github.com/BlindMindStudios/StarRuler2-Source) installation.

Alternatively you can use [Star Ruler 2 Mod Manager](https://github.com/DaloLorn/SR2ModManager) to install and update this mod.

Note: as with most mods, nearly every commit and almost every release is a save compatible breaking change, so typically you would not want to update your copy of CE until you have finished playing a game with it.

## Features

### A singleplayer campaign!
Still a work in progress, but there are two scenarios available and more scenarios are in the works.
### Several biome based planet constructions and 'terraforming' options
I'm aiming for a creating a comprehensive set of constructions to terraform planets based on what is already there in terms of biomes and statuses as a replacement to the default game's Terraforming mechanic. 'Terraforming' won't let you turn any planet into anything you like, but it will mostly be additive instead of replacing existing resources. Currently features conversion of less useful biomes into better ones for buildings to be on, creating a tier 2 resource on certain rock planets, creating a tier 1 resource on rock planets, and blowing up a planet into pieces to obtain an ore resource. You can also melt ice to obtain water, and set your homeworld.
### Food system reworked
This is probably the biggest divergence from vanilla. Food planets are much rarer. Food planets gradually 'forest' the planets they export to, giving each of those planets 3 unexportable food resources over time. Food planets therefore aren't needed to support level 1, 2, and 3 planets long term.
In practise in the early game you start out limited by food much like in vanilla but as the game progresses whenever you need food you can cancel an earlier food export to any planet that has since forested its own food and redirect the food resources to your new planet that needs it. In this way you quite reliably reach a point at which you can always provide food to higher level planets, and if you combine with water comets you can make tier 1 planets self sustaining without imports or maintenance costs.

The AI already understands how to change exports as it gains food and hence works with this rework quite well. I think this system feels much better and also more realistic. As your empire expands being limited by 'food planets' feels a little silly and food planets being as common as they are in vanilla clashes with a lot of expectations about how rare life is.
### Gas and ice giants
Ice Giants and Gas Giants are intended to be more difficult to colonise than rock planets, but provide useful ways to keep expanding your economy once your borders are constrained.
### Additional subsystems/hulls for low maintenance exploration and mining ships
Scouting and mining cost much less in maintenance.
#### Mining logistics improvements
Ships ordered to automatically mine can now mine cross systems, and will only stop if you deplete all asteroids known to your empire. Mining asteroid belts is a lot more efficient than in vanilla. You can also queue transfer and dropoff cargo orders if you'll meet the requirements by the time the ship would execute the order. You can order an ore pickup and immediately queue the ore dropoff because you'll have ore to dropoff by the time you need it. Cargo pickups and dropoffs can now be done per cargo type. Orders can also be setup to infinitely loop, so you can automate hauling of ore with ease. Cargo can also be picked up in specific quantities instead of as much as possible, letting you transport exactly what you need. Destroyed objects holding cargo will drop the cargo as asteroids, allowing you to steal from enemies if you attack their supply lines.
#### Multi tractor beam
Did you want to steal LOADS of asteroids from your enemies at once? What about relocate one of your planets without building a Planetary Thruster? This subsystem is for you.
#### Tractor beam formula
Tractor beams actually scale in strength when you put them on bigger ships, so a big ship can always tractor around a small ship. Vanilla was based on acceleration so a medium ship quickly reached enough mass that no ship could have enough acceleration to be able to tractor it.
### Support ship shields
You can now put shields on supports, and Devout can unlock shrines for supports.
### Shield projectors
You can now build ships with a shield subsystem that applies to the shield to the ship's target, letting you put shields on allied planets, stars, stations and orbitals.
### Dilemma conditions that appear on planets and force you to make hard decisions
There's several of these, and the AI handles the main one. I don't want to spoil them for your first playthough :)
### Completely reworked research grid with similar research grouped together
Research is somewhat easier to rush as you don't have to unlock loads of things you didn't want on the way.
### Exponential scaling of distance build penalties
Just because you have a 300 labor planet shouldn't mean you can build an outpost halfway across the galaxy in less than a second. Now the penalty scales exponentially with the number of hops rather than linearly, so will always outscale the labor production you can produce as the game goes on. This is also much more realistic and encourages researching Gates or having multiple labor centres.
### Massively nerfed ship stat bonuses from research
I found in many games of unmodded Star Ruler my ships were either orders of magnitude stronger than my opponent's or orders of magnitude weaker. Nerfing stat bonuses makes ships much closer in strength even if one empire is ahead in terms of eco/research. To get more powerful ships you actually have to have the economy to field larger ships rather than just stacking multipliers that turn ks of combat strength into Ms of combat strength for free.
### Rebalanced Carpet Bombs
Carpet Bombs can now be directly countered by applying shields to planets which reduce the effectiveness, but more importantly it is not possible to abuse edge cases in the subsystem variable code to make extremely cheap ships that can delevel tier 2+ planets in seconds. Mechanoid planets generate extremely weak shields which will heavily reduce the effectiveness of carpet bombs while the shields are up. The shields won't mean anything against a Gravitron Condensor, but in the early game Mono won't have to worry so much about losing all their population to cheap carpet bombers.
### Counters to Gravitron Condensors
Gravitron Condensors now have a ramp up time which caues them to deal less than 100% damage when they start firing at a new target. Players can also unlock Shield Projectors to project a shield onto stars and planets to protect them from Gravitron attacks.
### Railgun Impulse
The keystone of vanilla that removed pierce from Railguns and replaced it with impulses is now a modifier, so can be applied to only the ships you want it on. Among other uses, these can be used to punch a shield projector away from its target to break the sheild so you can get back to blowing up the opponent's star.
### Warheads
Warheads will no longer automatically fire at the nearest worthless enemy scout, they have to be manually fired.
### Rebalanced hulls
The Titan and Collosus hulls are much more viable than vanilla, and the Destroyer hull is nerfed. Other hulls have slight tweaks to make them fit niches more strongly, and in particular the Carrier hull is the biggest beneficiary of the added local defense generation from support command subsystems.
### Diplomatic Victory
You can snowball your diplomatic strength with Diplomatic Maneuvering if you play your cards right. Senatorial Palaces are now disabled if they leave your owned space. Planets in deep space can now be targeted for annex votes if you can obtain vision of them.
### Attitude tweaks
Attitudes which require maintaining x of something can no longer go into the negatives (as they will now count progress you made before starting the attitude). Xenophobic no longer requires you put the Outposts in border systems.
### Secret Project overhaul
Secret projects are no longer secret, you will be able to unlock any of them if you meet the unlock requirements as in vanilla. Artifical Moons require building moon bases instead of ring habitats. The Innovation card now grants you random unlocks on the reserach grid, which can let you leapfrog into unexplored areas of the tech tree. Ironically Innovation will never give you a Secret Project anymore.
### Designable Flare Bombs
The Flare Bomb is a player designable subsystem now, so you can field flare bomb ships that are sufficiently armoured.
### Ability to unlock all types of FTL and FTL income orbital from the research grid
For balancing this is a costly research path to go down and provides few other benefits. Each unlock also starts a vote to give the technology to all empires. This makes getting extra FTL technology a tradeoff as you might not keep it exclusive to just you, and then your research points have been wasted on something your opponents got for free.
#### Supplementary new FTL
Jumpdrives can be unlocked for Stations
### FTL Sharing
New treaty clause that shares access of Gates and Fling beacons between signatories.
### Colonise interstellar space
A number of tweaks to planets in deep space make it much more viable to hide away a few key worlds from prying eyes deep into the unlit cosmos. You'd better ensure you have enough energy production to keep the lights on!
### UI and Usability tweaks
You now get notifications from hostile actions like someone trying to gravitron condensor your planets. Some new notifications also go to a message strip which provides key low urgency information.
Ships can be ordered to keep distance from their targets, which allows for mobile salvo type designs to excel at combat.
Ships can also chase a target, which can be used to hunt down enemies or fly your own ships together in a formation.
Ships can also loop their orders infinitely which makes scouting more automatable.
A number of tweaks have also been made to the Quickbar and Planets Tab to expose more useful information to players. First players can now keep better track of all their Replicators. Nylli and Mono players can keep much better track of their population. Players can also now easily check which planets they can still make moon bases at and where their ore is.
In singleplayer, if the last game you played was with a compatible version of the mod, you can restore the settings of the previous lobby with a single click.
### Notable tweaks to lifestyles
#### Mechanoid
The cost to build 1 billion population is flat, so it becomes more affordable as the game goes on and your empire expands instead of less.
#### Star Children
Mothership max population scales with ship size and provides labor. Exploits that allowed for printing money with retrofitted motherships are removed. Carefully designed large motherships can become very cost effective as motherships now become more cost effective as they get bigger.
#### Ancient
Ancient empires are no longer incapable of producing pressure of non primary resources on planets, and are allowed to unlock and build Planetary Thrusters.
### Biology traits
These traits have positive and negative factors together. New races featuring these traits:
#### Aquatic
Planets need an additional water resource and one less food resource. A subtle change but it has a large impact on your trade links.
#### Parasite
This trait makes you get only half of the pressure from planetary resources, but allows you to raze planets down to nothing, gaining massively increased resource production while doing so. Includes dedicated AI support.
#### Flying
You just can't convince your avian friends that plate armour is worth it. However, Gas giants are easier to colonise.
### Battleworlders
The battleworlders lifestyle makes every planet a battleworld, and lets your empire conquer the galaxy from the comfort of its own planets. No AI support at this time. Inspired by Philip Reeve's Mortal Engines series and Darloth's / Dalo Lorn's Ringworlders. Balancing far from final.
A number of Quality of Life changes to mobile planets in general have also been made, including: planets no longer grant everyone vision of them if they go into deep space, memory of objects are now lost if they leave regions or move around in deep space, planets can be ordered to attack, and planets in deep space can be seiged or annexed.
### Frostkin
The frostkin lifestyle denounces starlight based technology and replaces it with life in deep space, destruction of stars, and thermal regulators that buff your entire fleet. A number of quality of life changes to planets outside of regions in general have also been made. It is now possible to import resources to planets in deep space with an unlockable building, and build orbitals/stations around a planet's orbit even when it is in deep space.
### Improved AI
The AI can build moon bases, and all FTL income/storage buildings. The AI can make use of multiple FTL abilities unlocked at once. If it wants to travel to an FTL jammed system, it will FTL to just outside the region.
#### Military
The AI will be much more eager to build military flagships when it has spare money than vanilla, and it will prepare designs in advance. It makes use of more subsystems in its designs when it unlocks them such as Fleet Computers and Simulators.
#### Colonisation and Development
What's stronger than a weasel? A dragon!

The gradually being released Dragon AI features completely overhauled colonisation and development code. It is much less prone to colonising itself into debt, uses non Terrestial colonisation methods better, and makes smarter decisions about acquiring resources to level planets. It is much harder for it to get boxed in, as it makes use of outposts to expand through systems that the weasel AI would get stuck at.
##### Race specific improvements
###### Mechanoid
Non Mechanoid dragon AIs also can now use Unobtanium. The dragon Mechanoid AI also actually works.
###### Star Children
The colonisation logic for dragon Star Children AIs was overhauled and should now show off the true speed a skilled Star Children player can colonise at.
###### Extragalactic
Heralds AIs will make good use of Expedite Relocation to colonise faster.
#### Diplomacy
The AI can now make a Senatorial Palace if it becomes Senate Leader.
### Improvements ported from other mods
#### Non exclusive hulls from Rising Stars by Dalo Lorn
#### Readable Global Toolbar tooltips from Industrial Revolution by scitor
#### Civilian ship navigation improvements from Industrial Revolution by scitor
#### Lateral thrust from New Movement Physics by Darloth
#### Some miscellaneous exploit fixes from Rising Stars by Dalo Lorn

## Copying and license info
My own AngelScript code in this mod is licensed under the MIT license. Most of the AngelScript code in this repository comes from the source code of Star Ruler 2 by [Blind Mind Studios](https://github.com/BlindMindStudios/StarRuler2-Source) which is also MIT licensed. The assets in Star Ruler 2 were placed under the Creative Commons CC-BY-NC license, which permits free non commercial use. The art assets I've added in this mod are licensed under the Creative Commons [CC-BY license](https://creativecommons.org/licenses/by/4.0/) instead, which permits commercial use just as the MIT license does. I try not to accidently commit any of the CC-BY-NC SR2 assets or derivations of them into this repository. However this mod does include the CC-BY-NC Bromma and Farum shipsets (`data/shipsets/bromma` and `data/shipsets/farum` respectively) released as part of the open sourcing of SR2 as these are not present in the Steam version of the game and cause cross play issues if not modded in to ensure all clients have them.

Some parts of this mod are derived from the MIT licensed code in [Rising Stars](https://github.com/DaloLorn/Rising-Stars) by Dalo Lorn. Also contains some parts from the MIT licensed code by scitor in [Industrial Revolution](https://github.com/scitor/SR2-IndustrialRevolution), and portions of the MIT licensed code by Darloth in [New Movement Physics](https://github.com/darloth/SR2-NewMovement).
