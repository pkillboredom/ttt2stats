## ttt2stats

This Garry's Mod addon stores a variety of events and stats about TTT2 game rounds. Eventually it will have two companion projects-- a blazor wasm static web app and a .net api. Both are private but will be public after I implement auth.

This addon currently requires my fork of TTT2.

This addon is still under development and no one should probably use it yet, unless you find it abandoned and want to carry it forward.

### Currently Tracking:

- Players
- TTT Rounds
- Damage Taken/Dealt w/ weapon
- Player Deaths
  - Also tracks if death was a headshot, airborne, burn, crush\, explosion.
- Each player's karma at round start and end.
- Equipment Buys

### Todo:
 
- Add Single Round all events view.
- Add Credit Transaction view next to kills/deaths view in round tab.
- Ignore negative world damage from env_fire? Occurs during molotov attacks and seems to not actually affect player health.
- Buffer player damage for env_fire such that:
  - Taking consecuitive burn damage from a single attacker...
  - Should display in the damage long as a single attack, so long as...
  - No other attackers, victims, or weapons occur server wide, in which case the burn damage will be flushed to SQL...
  - ...such that the combat log is not overrun with molotov spam. 

### Wishlist:

- Track Minigames Played
- Track total distance walked by each player in each round.
- Track playermodel changes (also track pm on join?)
- Track RTVs -- take code from PAM
- Track player load times
- Track T Button usages
- Track/Derive death faker successes
- Track/Derive mirror fate successes
- Track/Derive Barnacle successes