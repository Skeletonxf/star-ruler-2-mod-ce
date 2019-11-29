# Colonisation Expansion

This is a mod for Star Ruler 2. I started this aiming to make planets feel more unique by providing several dillemas and surface modifying options based on their biomes. It is now growing into a mod that provides many features to make the game feel more rich without drastically changing the gameplay.

## Status

I consider this mod at alpha status now. There's still many rough edges but it should be stable and balanced enough to play with. Mechanoid still needs some love for handling the main dillema this mod adds.

## Features

- Several biome based planet constructions
- Food system reworked
  - This is probably the main/biggest/only divergence from vanilla
  - Food planets are much rarer
  - Food planets gradually 'forest' the planets they export to, giving each of those planets 3 unexportable food resources over time. Food planets therefore aren't needed to support level 1, 2, and 3 planets long term.
  - In practise in the early game you start out limited by food much like in vanilla but as the game progresses whenever you need food you can cancel an earlier food export to any planet that has since forested its own food and redirect the food resources to your new planet that needs it. In this way you quite reliably reach a point at which you can always provide food to higher level planets, and if you combine with water comets you can make tier 1 planets self sustaining without imports or maintenance costs.
  - The AI already understands how to change exports as it gains food and hence works with this rework quite well. It won't pickup excess Forestation cargo and divert to a new planet, but in practise I don't think this is something players will/need to do.
  - I think this system feels much better and also more realistic. As your empire expands being limited by 'food planets' feels a little silly and food planets being as common as they are in vanilla clashes with a lot of expectations about how rare life is.
  - Forestry notifications: <img src="screenshots/forestry-notification-levels.png?raw=true" alt="Forestry notifications" height="45px">

- Gas giants
- Additional subsystems/hulls for low maintence exploration ships
- Tweaks to motherships to make their max pop scale with size
- Dilemma conditions that appear on planets and force you to make hard decisions
- Completely reworked research grid with similar research grouped together
  - From games with my empire set to the AI I think the AI explores this tree pretty well even though the algorithm is aimless
  - Some (1 right now but planning more) duplicates of research unlocks appear in easier to get positions which are randomised from a pool (eg a random FTL unlock before all the hurdles and all of them after) to make exploring the research tree each game both predictable (can always get each thing the normal way) and also with some randomness to keep things interesting.
- Massively nerfed ship stat bonuses from research
  - I found in many games of unmodded Star Ruler my ships were either orders of magnitude stronger than my opponent's or orders of magnitude weaker. Nerfing stat bonuses makes ships much closer in strength even if one empire is ahead in terms of eco/research. To get more powerful ships you actually have to have the economy to field larger ships rather than just stacking multipliers that turn ks of combat strength into Ms of combat strength for free. I haven't done any full playthroughs yet so balance is very far from final.
- Ability to unlock all types of FTL and FTL income orbital from the research grid
  - For balancing this is a costly research path to go down and provides few other benefits. Each unlock also starts a vote to give the technology to all empires. This makes getting extra FTL technology a tradeoff as you might not keep it exclusive to just you, and then your research points have been wasted on something your opponents got for free.
- Supplementary new FTL
  - Jumpdrives for Stations
- Biology traits such as Aquatic or Flying
- New race featuring the Celestial biology trait that makes every planet able to be a battleworld (at great cost to your budget)
  - I recommend playing Celestial with the Terrestrial or Extragalactic lifestyles and with Slipstreams or Gates as your FTL
    - I'd like to add user interface improvements to make it easier to select multiple planets at once, as when every planet can be given move orders it is a bit of a pain to do them individually or after holding CTRL and selecting everything first.
- Improved AI
  - AI can handle the main dillema this mod adds
  - AI will build moon bases on Gas Giants unless it's playing as Star Children or Ancient and thus doesn't need to
  - AI can handle having multiple FTL abilities unlocked at once
    - Many more improvements on AI FTL usage planned
  - AI will build FTL income orbitals if it needs more FTL income
- Not planned for alpha release
  - Colonisation ships similar to Motherships for other races
  - Mechanoid support for main dillema
  - AI code to build orbitals like Outposts and Stations
  - Teach AI to scuttle unneeded FTL income orbitals
  - Prevent dillemas occuring multiple times
  - Teach Mechanoid AI to use FTL Breeder Reactors
  - Motherstation hull for StarChildren (granting positive income but requiring sacrifice of a planet for balance?)
  - StarChildren transfering of pop from Mothership -> Mothership
  - Make autoexplore continue to work after all systems have been visited once
- Long term plans
  - A campaign that doubles as an extended tutorial
    - I will rename all the existing races and tweak them rather than trying to build on established lore I don't know
    - If you can't tell from reading this README I like playing as StarChildren a lot. I believe Rising Stars already started working on a campaign with the Mono? I think the best way for this is to start the player with a Terrestrial empire, introduce 1 AI and then once they get the hang of some basics have the AI suicide by destroying the system's black hole, prompting campaign episode #2 where your race evacuates on a hastily created mothership and drops down in a larger galaxy to discover more threats
  - Rather than adding lots of new complexity to the game I would like to focus on improving the AI to utilise existing tech
    - Things players can do but AI just doesn't right now
      - Create stations at all??
      - Attempt to achieve the influence victory themselves??
      - Fling battle stations
      - Create battleworlds
      - Use/design Motherships well
      - Move asteroids and other resources around with tractor beams
      - Mine asteroids for ore
      - Use slipstreams to speed up colony ships
      - Attack enemy territory that doesn't border AI's owned systems
      - Recognise that it can't win a fair 1v1 flagship fight with another empire and instead spam loads of cheap siege ships to atack every system possible at once
      - Carpet bomb enemy planets (especially vs Mechanoid)
      - Use the tractor beam on Motherships to drag around an Outpost - hey presto my mothership can always fire its weapons and if the outpost gets shot down the labor cost to build a new one is low enough to queue up immediately
      - Use gates to coordinate suprise attacks on an enemy (the AI is already good at doing rapid attacks with Hyperdrives/Jumpdrives/Fling but gates and slipstreams aren't used as well here)
      - Immediately seek to destroy a player's Senatorial Palace if they start one of the Galatic votes that can achieve the influence victory
