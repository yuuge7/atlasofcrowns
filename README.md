# Atlas of Crowns

A turn-based grand strategy game for Android phones, played on a map of
Europe and the Mediterranean. Start in August 1914 with the Great War under
way, or in today's Europe at peace. Choose a nation, raise armies, build
forts, research, make alliances, march across 327 provinces and hold enough
of the map to win. Every other nation is played by the AI, and all of them
move at the same moment when the turn ends.

<p>
  <img src="docs/screenshots/menu.png" width="200" alt="Title screen over the 1914 map">
  <img src="docs/screenshots/choose-nation.png" width="200" alt="Choosing a scenario, a nation and the game settings">
  <img src="docs/screenshots/map.png" width="200" alt="The game map with army counters, forts and a march under way">
</p>
<p>
  <img src="docs/screenshots/attack.png" width="200" alt="Ordering an attack on a fort, with the odds shown">
  <img src="docs/screenshots/diplomacy.png" width="200" alt="The diplomatic map under fog of war">
  <img src="docs/screenshots/research.png" width="200" alt="Research in army and industry">
</p>

## Contents

- [Features](#features)
- [Install](#install)
- [How to play](#how-to-play)
- [Build from source](#build-from-source)
- [Project layout](#project-layout)
- [Working on the code](#working-on-the-code)
- [Rebuilding the map](#rebuilding-the-map)
- [Releases and versioning](#releases-and-versioning)
- [Release signing](#release-signing)
- [Contributing](#contributing)
- [Credits and licence](#credits-and-licence)

## Features

- **Two real maps.** Europe, with the Middle East and North Africa: 327
  provinces cut from Natural Earth data and redrawn to the borders of 1914.
  North America, from Alaska to Panama: 256 provinces built from the US
  counties and the provinces and states of its neighbours, never crossing a
  state line, with the Great Lakes as seas of their own.
- **Seven scenarios.**
  - *The Great War* (August 1914): 23 nations, the wars of that month
    already declared, the Entente and the Central Powers bound by treaty.
  - *Road to war* (July 1936): the Spanish Civil War has just begun, and
    the Axis, the Anschluss, Munich, the Molotov–Ribbentrop pact and the
    invasions of 1939–41 follow on their dates if they still can.
  - *Europe today* (January 2026): 58 nations at peace, NATO bound together
    and the AI slow to start wars.
  - *The American Revolution* (July 1776): thirteen colonies against the
    Crown; Spain and France join later. West of the mountains the land
    belongs to its own nations, and beyond them lies unclaimed land.
  - *The Civil War* (April 1861): Union against Confederacy, with Britain,
    Spain and Mexico watching.
  - *Fifty states* (January 2026): every US state and Canadian province a
    nation of its own.
  - *North America today* (January 2026): the continent at peace.
- **History, if it still fits.** Scripted wars, alliances and pacts happen
  on their dates, as long as the game still looks enough like history for
  them to make sense. A player's nation is never pushed into a war; it is
  offered the alliance instead.
- **Unclaimed land.** Some scenarios leave land no nation rules. No war is
  needed to take it, but its people fight back hard, and settling it takes
  time.
- **Simultaneous turns.** Everyone's orders resolve at once. Reinforcements
  arrive before attacks, and an army that marches away no longer defends.
  Each turn then plays out on the map: armies march, ships sail, battles
  flare up, before the new position shows.
- **Across the sea.** 26 named sea zones. From the coast an army can sail
  in one turn to any coast on the same sea or the next one, and land at
  three quarters of its strength.
- **Alliances, pacts and relations.** Propose an alliance, accept one, leave
  one; declare war on a nation and its allies declare war on you in the same
  turn. Every nation feels something about you, from -100 to +100: send
  envoys and gifts to win it over, sign a non-aggression pact to keep a
  neighbour quiet while you fight elsewhere, or guarantee a small nation's
  independence and go to war with whoever attacks it. At war, call your
  allies to arms; they may call on you too.
- **Peace on terms.** Ask for nothing, for reparations (a quarter of the
  loser's income for two years) or for vassalage. A vassal pays tribute,
  fights its overlord's wars and may one day declare its independence.
- **Events.** Harvests, epidemics, fires, railways, border incidents and
  state visits come by chance; strikes, refugees and inventors ask you how
  to answer.
- **Forts and development.** Build a fort or a fortress in a province, or
  develop it for more income.
- **Research.** Put a share of the income into army technology (every unit
  fights harder) or industry (every province yields more).
- **Conquest has a price.** Taken land yields half its income at first and
  may revolt while its garrison is weak, back to its old owner or as a
  fallen nation risen again.
- **Long marches.** Send an army to any of your provinces, however far; it
  walks there on its own, one province a turn.
- **Map modes.** Political, diplomatic (allies, enemies, truces, pacts),
  relations (how each nation feels about you) and economic.
- **Statistics.** Provinces, armies and income of the leading powers over
  the whole game, as charts you can read month by month.
- **Flags** for every nation of both scenarios, drawn in code.
- **Your game, your rules.** Win with 30%, 40%, 60%, 75% or all of the map,
  or set no victory and play on for as long as you like. A turn can be a
  month, a season or a year, so a game can run for centuries. Three
  difficulties: on Easy the AI earns 80%, leaves you alone for your first
  three years and looks for other prey first; on Hard it earns 125% and
  comes for you as for anyone. Fog of war, random events.
- **Any nation can win.** Small nations survive by alliances, pacts,
  guarantees and calls to arms, and grow through vassals and their allies'
  wars. `tool/underdog.dart` measures it: played by the AI itself, Italy
  wins 1914 in about one game in six and Colorado wins Fifty states in one
  in five, and small nations such as Sweden in 1936 sometimes reach victory.
- **Nations with a temper.** Each scenario sets how warlike every nation
  is: in 1936 most of Europe wants peace and keeps its treaties, and the
  great war comes as history brings it; Spain in 1776 and the neighbours of
  the fifty states rarely start wars of their own.
- **An AI for every nation.** It holds its fronts, attacks what it can
  overwhelm (overland or from the sea), gathers its army when it cannot,
  seeks allies against a shared threat, signs pacts to cover a flank, courts
  the powers that worry it, garrisons its conquests, builds, researches,
  demands terms when winning, sues for peace when a war goes nowhere and
  grows bolder the longer it sits idle.
- **Readable combat.** The sheet shows what a province defends with and the
  odds of the attack you are about to order.
- **Saves.** The game saves itself every turn; manual saves on top.
- **Built for one hand.** Portrait only, map edge to edge, End turn under the
  right thumb.

Not in the game yet: fleets and naval battles, trading provinces at the
peace table, sound, a world map.

## Install

Download the latest `AtlasOfCrowns-v*.apk` from the
[Releases](../../releases/latest) page and open it on an Android phone
(Android 7.0 or newer). The phone will ask once for permission to install
apps from your browser or file manager.

Every release is signed with the same key, so a newer one installs over an
older one and keeps your saved games.

## How to play

1. **Pick a scenario and a nation** by tapping it on the map, open the game
   settings to choose the victory, the length of a turn, the difficulty, fog
   of war and random events, and start.
2. **Give orders.** Tap one of your provinces to recruit, build or move its
   units: to a neighbouring province, or to any province of yours further off
   for a march of several turns. Moving into a province of a nation you are
   at war with is an attack. Blue arrows are marches, red arrows attacks.
   Tap a foreign province for war, peace and alliances, and its Diplomacy
   button for envoys, gifts and pacts. The flask opens research, the globe
   the list of powers and the statistics, the layers button the map modes.
3. **End the turn.** All nations move at once, battles are fought, and the
   dispatches tell you what happened.

| Rule | In short |
|---|---|
| Recruiting | 4 gold per unit. A province raises up to 2 plus its income each turn. New units defend at once and march from the next turn. |
| Upkeep | Every 4 units cost 1 gold a turn. An empty treasury makes units desert. |
| Movement | One province a turn, across a border or a strait marked with a dotted line. From the coast, a turn's sail to any coast on the same sea or the next; the troops land at 75% strength. |
| Battle | Attackers must beat the defenders plus the province's militia, multiplied by 1.5 for being dug in, 0.5 more per fort level and 0.5 more in a capital. Army technology adds 5% per level to either side. Each side then rolls 15% up or down. The loser is destroyed. |
| Diplomacy | Tap a foreign province to declare war on its owner; the border opens the turn after, and the owner's allies join at once. Peace needs both sides and is followed by a truce of 8 turns. An alliance needs both sides too. |
| Peace terms | A peace offer can ask for reparations (25% of the loser's income for 24 turns) or vassalage (20% of its income for good, and its wars are the overlord's). Peace is signed when one side accepts what the other asks. |
| Relations | From -100 to +100. War sours them, alliances warm them, peace lets them drift back to 0. An envoy gives +8 for half the receiver's income; a gift of a turn of their income gives +10, at most +30. At +60 a nation accepts an alliance even without a common enemy. |
| Pacts | A non-aggression pact needs both sides and lasts 36 turns: neither may declare war on the other, nor join a war against it through an alliance. |
| Guarantees | One-sided: the guarantor joins any war declared on the guaranteed nation, which is not bound to the guarantor's wars. It ends if the two go to war. |
| Call to arms | At war, ask your allies to join; each decides for itself, by how it feels about you and the odds. The call stands for three turns. |
| Events | Each turn a nation has about one chance in six that something happens, more at war. A choice is answered with the next turn's orders; no answer takes the course that costs nothing. |
| Building | One project per province a turn. A fort level costs 40 gold times the level and 1 gold a turn; a province falls with one level less. Development adds 1 income for 20 gold, 15 more for each further level, up to 5. |
| Research | A share of income (0 to 50%) goes into army or industry. A level costs 2 turns of income times the level reached. Army: +5% strength a level. Industry: +4% income a level. |
| Conquest | Land taken from its owner at the start yields 50% of its income, rising to all of it over 24 turns. Until then, held with fewer units than its militia, it may revolt. |
| Unclaimed land | Taken without a war by moving in; its people defend it four times as hard as a militia. |
| Winning | Hold the chosen share of all provinces, your vassals' included, or play with no victory at all. Lose your last province and the game is over. |

The same rules are in the game under **How to play**.

## Build from source

### What you need

| Tool | Version | Needed for |
|---|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) | 3.47 or newer (Dart 3.13) | everything |
| Android SDK | platform 36, build-tools 36 | building and running |
| JDK | 17 or newer (21 is what CI uses) | the Android build |
| Git | any recent | getting the code |
| Node.js | 20 or newer | only to rebuild the map |
| Python + Pillow | 3.10 or newer | only to redraw the launcher icon |

Android Studio installs the SDK, a JDK and an emulator in one go. Run
`flutter doctor` afterwards and fix what it reports.

### First run

```sh
git clone <repository-url> atlasofcrowns
cd atlasofcrowns
flutter pub get
flutter test          # under a minute; plays eight 300-turn AI games among other things
flutter run           # on a connected phone or a running emulator
```

That is all. The map and scenario are checked in under `assets/`, so Node is
not needed to build the app, and no signing key is needed either: a clone
without one signs release builds with the debug key (see
[Release signing](#release-signing)).

To produce an APK:

```sh
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

### Handy tools

| Command | What it does |
|---|---|
| `flutter analyze` | Static analysis. Must report no issues. |
| `flutter test` | Rules, saves, map geometry, camera, UI flows, headless games. |
| `dart run tool/underdog.dart 1914 SER,BUL 12` | Plays the listed nations in the player's seat with the AI, over 12 seeds, and reports how often each survives and wins. Further arguments: turns, win share, difficulty. |
| `dart run tool/sim.dart 300 1` | Plays AI against AI for 300 turns with seed 1 and prints the standings. Use it to judge a balance change. Further arguments: win share, report interval, scenario, and `events` or anything else to switch random events on or off (`dart run tool/sim.dart 300 1 0.95 25 america1776 events`). |
| `tool/emu.sh install release` | Builds the APK and installs it over adb. |
| `tool/emu.sh start` / `shot f.png` / `tap x y` / `log` | Drives the installed app on an emulator or phone. Run `tool/emu.sh` alone for the full list. |

`tool/emu.sh` is a Bash script; on Windows run it from Git Bash.

## Project layout

```
lib/
  engine/     The rules, in plain Dart. No Flutter imports.
    world.dart      static data: provinces, nations, the scenario
    state.dart      everything that changes; a save file is this as JSON
    orders.dart     what a nation asks for in one turn
    resolve.dart    resolves one turn for every nation at once
    happenings.dart events by chance: harvests, strikes, inventors...
    events.dart     what a turn reports: events and every move made
    ai.dart         plans a turn for an AI nation
    game.dart       world + state, and the questions the UI and the AI ask
    rules.dart      every tunable number of the game
    rng.dart        seeded random numbers; the state is saved with the game
  map/        Province geometry, camera (pan and zoom), painters, MapView
  game/       GameController: the player's orders, selection and input mode
  data/       Asset loading and the save files
  ui/         Screens and sheets: province, diplomacy, research,
              statistics, dispatches; flags.dart draws every flag
  theme.dart  Colours, fonts and text styles
assets/
  map/europe.json         Europe: province shapes, adjacency, sea zones  (generated)
  map/america.json        North America, the same                       (generated)
  scenarios/1914.json     The Great War: nations, owners, income, wars,
                          alliances, forts, technology, history          (generated)
  scenarios/1936.json     Road to war, on the European provinces         (generated)
  scenarios/modern.json   Europe today, on the same provinces            (generated)
  scenarios/america*.json the North American scenarios                   (generated)
  scenarios/index.json    the scenarios the game offers, in order        (generated)
  fonts/                  Old Standard, Barlow Condensed
tool/
  map/        Node pipeline that generates the JSON files above
  ci/         version numbering for releases
  icon/       draws the launcher icon
  sim.dart    headless balance runs
  emu.sh      build, install and drive the app over adb
test/
  engine/     rules, determinism, headless games
  app/        geometry, camera, controller, saves, widget flows
.github/workflows/
  release.yml   every push to main becomes a signed release
  checks.yml    analysis and tests on every pull request
```

## Working on the code

Four rules keep the game testable. A change that breaks one of them will
break a test.

1. **The engine stays pure.** Nothing in `lib/engine` imports Flutter or
   `dart:ui`. That is what lets a whole game run in a unit test.
2. **The engine is deterministic.** The same seed and the same orders give
   the same game. All randomness goes through the `Rng` passed down from
   `Game.endTurn`; never use `dart:math`'s `Random` or the clock there, and
   sort before iterating a `Set` or `Map` when the order affects the result.
3. **Orders are requests.** The resolver checks every order against the rules
   and drops what is not allowed. The UI may check first, but the engine
   never trusts it.
4. **Saves must keep loading.** A new field in `GameState` needs a default in
   `GameState.fromJson`, and a new field in `Orders` one in `Orders.fromJson`.

Where to make common changes:

| To change | Look at |
|---|---|
| A number: costs, combat bonus, truce length, AI caution | `lib/engine/rules.dart` |
| How a turn resolves | `lib/engine/resolve.dart`, tests in `test/engine/resolve_test.dart` |
| How the AI plays | `lib/engine/ai.dart`, then `dart run tool/sim.dart` over several seeds |
| Who owns what in 1914, province names, colours, starting wars and alliances, forts, technology, history, sea links | `tool/map/config/scenario_1914.mjs`, then rebuild the map |
| 1936 and Europe today: nations, colours, alliances, development, names, history | `tool/map/config/scenario_1936.mjs`, `scenario_modern.mjs`, then rebuild the map |
| The North American map: window, province counts, sea zones, straits | `tool/map/config/america_map.mjs`, then `node build_map.mjs --map=america` |
| The North American scenarios | `tool/map/config/america_*.mjs` (`america_states.mjs` holds the states and their flags) |
| How the map is drawn | `lib/map/map_painters.dart`, `lib/map/map_scene.dart` |
| A screen or sheet | `lib/ui/` |
| Colours and type | `lib/theme.dart` |

After a change to rules or AI, run a few seeds of
`dart run tool/sim.dart 300 <seed> 0.95` and check that the game still moves:
the test suite fails if nothing changes hands for 60 turns.

After a change to the UI, look at it on a device. `adb` cannot pinch, so
zooming is covered by a widget test instead.

## Rebuilding the map

Only needed when changing borders, merges, names or the scenario.

```sh
cd tool/map
npm install
```

Download these datasets from
[Natural Earth](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/)
(or directly from `https://naciscdn.org/naturalearth/10m/cultural/` and
`.../10m/physical/`) and unzip each into its own folder:

| Dataset | Unzip into | Needed for |
|---|---|---|
| `ne_10m_admin_1_states_provinces.zip` | `tool/map/raw/admin1/` | both maps |
| `ne_10m_populated_places_simple.zip` | `tool/map/raw/places/` | both maps |
| `ne_10m_admin_2_counties.zip` | `tool/map/raw/counties/` | North America |
| `ne_10m_lakes.zip` (physical) | `tool/map/raw/lakes/` | North America |

Then:

```sh
node build_map.mjs                  # Europe; add --fresh after changing the map window
node build_map.mjs --map=america    # North America
```

For Europe the script clips the data to the game window, assigns every unit
its 1914 owner, merges about two thousand units into 327 provinces, never
across a 1914 border and, but for a few small territories, never across a
modern one, simplifies the outlines, works out adjacency, and writes
`assets/map/europe.json` and the 1914, 1936 and modern scenarios. So later
borders fit the same provinces; the few provinces that mix two countries at
this scale are assigned by hand in each scenario's config.

For North America it takes the US counties and the admin-1 units of
Canada, Mexico, Central America and the Caribbean, cuts Canada's huge
provinces on a grid, erases the big lakes, merges everything into 256
provinces that never cross a state, province or country, and writes
`assets/map/america.json` and its four scenarios. Each run also rewrites
`assets/scenarios/index.json` with every scenario on disk. Both render
previews and province lists to `tool/map/out/` (`out/america/`); look at them
before committing.

Province ids are positions in the generated file. Changing how provinces are
merged changes the map's build id, and saves made on the old map are then
refused rather than loaded wrongly.

## Releases and versioning

Every push to `main` is published automatically by
[`.github/workflows/release.yml`](.github/workflows/release.yml):

1. analysis and the full test suite run; a failure stops the release;
2. the next version is worked out;
3. the APK is built with that version and signed with the release key;
4. a GitHub release named **Atlas of Crowns v1.4** (for example) is created
   with `AtlasOfCrowns-v1.4.apk` attached and notes generated from the
   commits.

Versions have the form `v<major>.<n>`:

- `<major>` is the first number of `version:` in `pubspec.yaml`. It is the
  only number set by hand. Raise it to start a new line: `2.0.0` makes the
  next release `v2.0`.
- `<n>` is one more than the highest existing `v<major>.<n>` tag, starting at
  0. The first release is `v1.0`, the next `v1.1`, then `v1.2`, and so on.

No version is ever reused. Releases are published one at a time, and the
workflow fails rather than touch a release that already exists. Each build
also gets an Android version code (`major x 10000 + n`) that only grows, so a
phone always accepts a newer release over an older one and never the reverse.

Nothing is committed back to the repository, so your local branch never falls
behind because of a release.

Before the first push, add the two secrets described below, or the workflow
stops at "Restore the signing key".

## Release signing

Android only installs an update over an app that was signed with the same
key. The project therefore has one release key, and it is deliberately **not**
in the repository.

Two files, both in the project root next to `pubspec.yaml`, both ignored by
git:

| File | What it is |
|---|---|
| `atlasofcrowns-release.jks` | the keystore holding the key (alias `atlasofcrowns`) |
| `key.properties` | the keystore's password and alias, read by `android/app/build.gradle.kts` |

When both are present, `flutter build apk --release` signs with the release
key. When they are absent, as in any fresh clone, the release build falls
back to the debug key: the app runs normally, but it cannot be installed over
an official release (uninstall that first).

### For contributors

You do not need the key. Build, run and test as described above. Official
releases are signed by the workflow.

### For the maintainer

**Back the two files up now**, somewhere that is not this repository: a
password manager that stores attachments, an encrypted drive, an offline USB
stick. If they are lost, no future version can update the app on anyone's
phone; if they leak, anyone can publish an "update" in the project's name.

**To build signed releases on another machine,** copy both files into the
project root there. Nothing else has to be configured. To confirm the key
arrived intact, compare its fingerprint with the one in the workflow file:

```sh
keytool -list -v -keystore atlasofcrowns-release.jks -alias atlasofcrowns
# SHA256 must read 9A:DA:F7:E2:C2:28:13:83:64:6B:E9:5E:4E:D8:D4:58:84:E1:8C:F0:2F:31:1B:21:44:0B:30:1E:D1:66:49:22
```

**To let GitHub sign releases,** add two repository secrets under
*Settings > Secrets and variables > Actions*:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | the keystore file, base64-encoded on one line |
| `KEYSTORE_PASSWORD` | the value of `storePassword` in `key.properties` |

From Git Bash in the project root, this puts the first value on the
clipboard:

```sh
base64 -w0 atlasofcrowns-release.jks | clip      # macOS: base64 -i ... | pbcopy   Linux: ... | xclip -sel clip
```

Or, with the [GitHub CLI](https://cli.github.com/), set both without copying
anything by hand:

```sh
base64 -w0 atlasofcrowns-release.jks | gh secret set KEYSTORE_BASE64
sed -n 's/^storePassword=//p' key.properties | tr -d '\n' | gh secret set KEYSTORE_PASSWORD
```

The workflow checks the keystore's fingerprint before building and refuses a
key that is not the release key.

## Contributing

Changes are welcome: new scenarios, rules, a smarter AI, interface work.

1. Fork the repository and create a branch from `main`.
2. Make the change. Add or update tests for anything in `lib/engine`.
3. Run `flutter analyze` and `flutter test`; both must pass. For rules or AI
   changes, include what `tool/sim.dart` showed before and after.
4. Open a pull request that says what changed and why. The same checks run
   there automatically.

Keep to the four rules under [Working on the code](#working-on-the-code),
match the style of the code around your change, and keep generated files
(`assets/map`, `assets/scenarios`) in the same commit as the configuration
change that produced them.

For anything large, such as navies, a new map or a new subsystem, open an
issue first so the design can be agreed before the work is done.

## Credits and licence

- Map data: [Natural Earth](https://www.naturalearthdata.com/), public domain.
- Fonts: [Old Standard](https://fonts.google.com/specimen/Old+Standard+TT) and
  [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed), SIL
  Open Font License 1.1. The licence texts are in `assets/fonts/`.
- Built with [Flutter](https://flutter.dev/).

The project's own code does not carry a licence yet. Until one is added, the
usual copyright rules apply: you may read and fork it on GitHub, but other
uses need the author's permission.
