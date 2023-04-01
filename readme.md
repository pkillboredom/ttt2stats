## ttt2stats

This Garry's Mod addon stores a variety of events and stats about TTT2 game rounds. Right now it only tracks to the game's sqlite but it should at some point probably also work with mysql. Eventually it will have a companion project-- a react app that displays visualizations and leaderboards derived from this data.

This addon is still under development and no one should probably use it yet, unless you find it abandoned and want to carry it forward.

### Currently Tracking:

- Players
- TTT Rounds
- Damage Taken/Dealt w/ weapon
- Player Deaths
  - Also tracks if death was a headshot, airborne, burn\*, crush\*, explosion*.
- Each player's karma at round start and end.
- Equipment Buys

### Broken/todo

- Need to add new hooks to TTT2.

### Wishlist

- Track Credit awards and transfers (most generous award!)
  - WIP table designed.
  - Requires adding new hooks to TTT2.
    - GiveFoundCredits
    - HandleKillCreditsAward
    - TransferCredits -- sv_shop.lua
- Track Minigames Played
- Track total distance walked by each player in each round.
- Track playermodel changes (also track pm on join?)
- Track RTVs -- take code from PAM
- Track player load times
- Track T Button usages
- Track/Derive death faker successes
- Track/Derive mirror fate successes
- Track/Derive Barnacle successes