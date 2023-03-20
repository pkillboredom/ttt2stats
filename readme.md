## ttt2stats

This Garry's Mod addon stores a variety of events and stats about TTT2 game rounds. Right now it only tracks to the game's sqlite but it should at some point probably also work with mysql (in 2023? Yes, this is gmod, leave me alone). Eventually it will have a companion project-- a react app that displays visualizations and leaderboards derived from this data.

This addon is still under development and no one should probably use it yet, unless you find it abandoned and want to carry it forward.

### Currently Tracking:

- Players
- TTT Rounds
- Damage Taken/Dealt w/ weapon
- Each player's karma at round start and end.

### Broken/todo

- Winning Team not handled. -- To be tested
- Roles are not being recorded because the game sets them up immediately *prior* to round start. -- To be tested
- Have not tested that prop damage, barrel explosions, etc come correctly or end up as world or some other fallback weapon.

### Wishlist

- Track Equipment Buys -- To be tested
- Track Credit transfers (most generous award!)
- Track total distance walked by each player in each round.
- Track deaths
- Track headshot deaths
- Track airborne deaths
- Track playermodel changes (also track pm on join?)
- Track RTVs
- Track player load times
- Track T Button usages
- Track/Derive death faker successes
- Track/Derive mirror fate successes
- Track/Derive Barnacle successes