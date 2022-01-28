# TODO List

This is primarily intended as a developer focused project planning list, rather than something to read. I'm making it public because it's easier for me to keep track of if its in the repository, and it still has some value as a 'where CE is going' indicator.

- Bug list / issues to fix
  - Port interdict movement fixes to mod pack once stress tested in a few multiplayer games
  - Stress test teaching of dummy resources to the AI
    - Can unhack Ancient AI components and CP once sure fully working (I think it properly tracks dummy resource changes now?)
  - Review the AI's limitation on scouts being only 2, and make this more flexible
  - Review the War.as's limitation of only attacking border systems, and make this more flexible
    - Thanks Illyia
  - Expansion AI Component
    - Teach AI to track what types of resources it can colonise to do level chaining with so it knows when to stop trying to finish a focus it can't
      - Act on this info to reproritise level chains
    - Teach AI to free up resources by using constructions like Melt Ice
    - Teach AI to deliberately colonise morphics and fulrate when it has a planet to export them to
    - AI still seems to be making megafarms it has no need for
    - Add a proper isBuilding method that also checks if the AI is in the process of building a building instead of just if its in the request queue and fix everywhere I called this thinking that's what isBuilding already does
    - Implement custom ColonizeAbility interface for Ancient AI empires
      - Make AI idle Replicators that aren't building anything go colonise something rather than just sit around being useless
    - Make AI destroy buildings it no longer needs
      - Particularly Megafarms and Hydrogenators
    - Possibly teach the AI to recognise useless planets and either terraform them or replace them with outposts / better colonies in the same system
      - Particularly relevant for a Mechanoid empire that never finds Cremlin Firns or Nitrous Oxide, as claiming useless food/water planets to expand borders is great early/mid game, but costs 50k per system to not replace with outposts late game.
    - Revisit if the Ancient AI should avoid making moon bases when it doesn't have enough space for a building
      - Should determine if the moon base would solve the space issue rather than just never doing it
  - Make AI consolidate labor at one shipyard, not multiple
    - The AI can build shipyards for both labor consolidation and staging bases, need to ensure it doesn't build two in the same region
    - May want to make the AI build supply depots instead of shipyards at staging bases too
  - Make AI able to use the abilties on senatorial palaces and allondium worlds
    - Use the introduced ability AI hooks
  - Teach AI to sublight out of jammed regions before FTLing rather than always defaulting to sublight if it starts in a jammed system
  - Make War.as AI detect when a system is protected due to an Outpost/Temple and make it only commit one ship to take out the orbital instead of all of its seiging ships (since at the moment they all give up on the capture and then all detect the enemy orbital via findEnemy)
  - Auto researching an FTL unlock should not trigger the vote for the FTL unlock
  - Consider how much if any of the patched First empire stat buffs to port to the AI's heuristics for ship design
  - Possibly make the defense grids provide an effectiveness boost to supports in orbit of the planet
  - Move mass/repair/supply calaculations into a definitions file of helper functions
    - LeaderAI getSlowestSupportAccel
    - Support cap hook
    - LeaderAI leaderInit
    - Ship constructible support supply free
  - Make some analog to the SupportStation artifact player designable/buildable
  - Update the combat timer code for Orbitals to match the updated code for Ships
  - Teach AI to protect against carpet bombs with shield projectors
  - Make message strip clear notifications when swapping empires
  - Make auto import refresh when resources on already colonised planets become available
  - Make nebulae griefing not work while the planet is in combat.
  - Add better UI for when attempting to export/import resources and you can't
  - Investigate what happens to civilian trade ships when target is in deep space
  - Fix bug where ordering a battleworld to transfer resources onto another one causes the other one to abort its current movement commands
    - This seems to be a more general vanilla bug with casting an ability on something which is already casting the same ability, can also reproduce with two shield projector ships
  - Teach AI to not put comets on worlds being razed
  - Prevent AI from deliberately researching/building FTL extractors if they have FTL breeders already unlocked
  - Increase the resolution of the Helium 3 icon to make it clearer
  - Fix map generation bugs with galaxy mirroring and gas/ice giants
  - Make the AI work out who is attacking its stars instead of assuming anyone with a presence in the system is
  - Investigate issues with Mechanoid AI being able to build gates
  - Make the AI's search for things to colonise when it has no systems more robust - Star Children should still be able to recover while they have Motherships but the current code will attempt to recolonise its home system or just give up.
  - Investigate stored labor being drained by time based constructions

- Frostkin
  - AI support
    - Abandon worlds if unable to build lighting systems on them (Star Children only) or in a lot of energy debt
  - Grant energy when destroying stars
  - `safe double get_starTemperature() const;` is not actually synced to the updated Server value for shadow RegionObjects now that star temperature can change
    - Also appears as though this value is not needed on the client side anyway other than for distinguishing black holes, but should probably work out the best way to sync this rather than leave a potential bug for the future.
  - Race icon, description, page
  - Balancing

- Not planned for any time soon
  - Colonisation ships similar to Motherships for other races
  - AI code to build orbitals like Stations
  - Teach AI to scuttle unneeded FTL income orbitals
  - Consider what to do about the Star Children being locked out of a lot of things only available as buildings
    - Vanilla buildings that Star Children have no equivalents of
      - Megafarms, Hydrogenators, Research Complexes, Mueseums, Labor Storage, Space Elevator
    - Buildings that Star Children already don't need or have alternatives to
      - FTL Storage, Megacities, Planetary Thruster
  - Consider making carpet bombing able to destroy tiles via the SurfaceGrid's destroyRandomTile method
  - Fix adding local asteroid field not applying asteroid graphics (think this was in community patch already)
  - Get the AI to play invasion properly
  - Stellar Lifting to obtain protoplanets directly
  - Teach AI to scout nebulae properly
  - Make Star Children habitats and uplifted planets interact a little better
  - Fix visual bug causing Drugs to appear to be filling the Light class requirement for planet levelling when they are not, probably related to dummy resources
    - This is a vanilla bug that seems to be due to drugs on the client side not refreshing when the resource they were previously filling is provided and the drug switches to providing a different resource server side
  -  Fix vanilla bug making planets that vision was obtained of through the Space Program trait erronously appear as level 255 until scouted
  - Make the random FTL unlock certain to not unlock the one you get from the vote (no idea what order they currently run in, or how to control the order)
  - Some kind of tech stealing / reverse engineering mechanic to reduce snowballing a little
  - Provide a benefit for being the most supportive empire on FTL votes when all FTL tech is already unlocked
  - Retest if WhileConsumingCargo still needs to use gameTime directly now that the status tick time bug has been fixed
  - Investigate why/how to change all planet resources being enabled/disabled based on the primary resource (which tends to be the most difficult to enable)
    - Easiest to reproduce by adding local asteroid fields to native tier 2/3 planets
    - Potentially an exploit here too by putting scalables on tier 3 planets, does the tier 3 resource get enabled because the primary becomes scalable?
  - Should buildings like Refineries only work based on the primary resource? This could change to an invalid one after construction with local asteroid field and expose molten core.
  - Wormhole network revamp
    - Control hubs spawn automatically as before with some kind of wormhole like graphic around level 2 and higher planets (up to 3 per system)
    - Can select a wormhole network hub and order it to open a wormhole at a target destination
    - Opened wormhole behaves similarly to a slipstream and closes automatically after some time
    - Opened wormhole is ONE WAY, can only use to travel to the wormhole network hub not the other direction
  - Make quickbar width configurable
  - The AI should hold back its faster ships so that the slower ones catch up before it brings the group into combat so that on large maps and sublight/gates AI they don't get split up from different travel speeds.

- Long term plans
  - Designable Beacons
    - The entire master/slave system, sharing of labor, and related mechanics are hardcoded to just work on Orbitals
      Need to change the signature of a few OrbitalScript methods
      ```
      safe bool hasMaster();
      safe bool isMaster(Object@ obj);
      Orbital@ getMaster();
      void setMaster(Orbital@ orb);
      ```
      Ideally find out a way to force set the model + icon for designed racial stations so they can't be hidden from other players by looking like just another station
      Need to update pretty much every hook the Beacon orbital uses to work with non orbital masters
      Work out how to make the purchase menu GUI usable for something that requires 4 types of cargo to build
  - Improving the AI
    - Things players can do but AI just doesn't right now
      - Create stations at all
      - Attempt to achieve the influence victory themselves
      - Fling battle stations
      - Mine asteroids for ore
      - Move asteroids and other resources around with tractor beams
      - Create battleworlds
      - Use slipstreams to speed up colony ships
      - Attack enemy territory that doesn't border AI's owned systems
      - Carpet bomb enemy planets
      - Use gates to coordinate surprise attacks on an enemy (the AI is already good at doing rapid attacks with Hyperdrives/Jumpdrives/Fling but gates and slipstreams aren't used as well here)
      - Immediately seek to destroy a player's Senatorial Palace if they start one of the Galatic votes that can achieve the influence victory
  - Sight range and seeable range should be based on the edge to edge distance of two ships, factoing in the radius of both
