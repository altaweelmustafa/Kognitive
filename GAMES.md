# Kognitiv games

Five cognitive domains, twelve games. Nine are built; three are planned.

The catalog lives in two places that must stay in step:
`lib/data/games.dart` (app) and `backend/app/brain/catalog.py` (backend).

## At a glance

| Game | Domain | Status | In daily session | Feeds the KPI |
|---|---|---|---|---|
| Memory Matrix | Memory | Built | Yes | Yes |
| Suit Recall | Memory | Planned | Yes | – |
| What's My Name? | Memory | Built | Yes | Yes |
| Odd One Out | Attention | Planned | Yes | – |
| Points of Thought | Attention | Built | Yes | Yes |
| 24 Game | Reasoning & Logic | Planned | Yes | – |
| Sudoku | Reasoning & Logic | Built | No, play any day | No |
| Quick Math | Reasoning & Logic | Built | No, play any day | No |
| Apothecary | Planning | Built | Yes | Yes |
| Chess Puzzles | Planning | Built | No, play any day | No |
| Towers of Stockholm | Flexibility | Built | Yes | Yes |
| Suit Sort (WCST) | Flexibility | Planned | Yes | – |

**Daily session:** four games. Memory and Attention are always in; the other
two slots go to the domains that need it most (see `backend/README.md`).
A session game counts once per day.

## Memory

### Memory Matrix — built
A 5×5 grid lights up some tiles for 1.5 seconds; the player then taps them from
memory.
- 8 rounds, starting at 8 tiles.
- A perfect round adds a tile; a wrong tap ends the round and removes one.
- **Score:** 100 points per tile recalled, averaged over the rounds. A flawless
  8 → 15 run scores 1150.
- Code: `lib/games/memory_matrix/`

### Suit Recall — planned
Hold a growing run of card suits in mind.

### What's My Name? — built
A face-name memory game with spaced repetition.
- **Every day:** five new people, each a real photo with a name, a profession
  and one personal detail. Each is studied for 6 seconds.
- **Then a test, by typing:** a face and a question ("What is this person's
  name?" / "What do they do?" / "Tell me one thing about them."). No multiple
  choice. Each new person is asked all three. Case, punctuation and small
  typos are forgiven; the detail needs only its key word.
- **Then reviews:** people met on earlier days come back on an SM-2 schedule,
  one question each, at most 20 a day. Right on the first try pushes the next
  review out (1 day, 6 days, then longer); wrong brings them back tomorrow.
- People and their identities are fixed, so the pool builds into a lasting
  "social memory". Who they are and how answers are judged lives on the
  backend (`backend/app/names/`); review answers are never sent to the app.
- **Score:** 1000 times the share of the day's answers that were right.
- 30 people in all, so new faces run out after six days; after that it is
  reviews only. The source set has 102 portraits if more are wanted.
- The Memory slot of the daily session alternates between this and Memory
  Matrix: whichever was played less recently.
- Faces: Face Research Lab London Set (CC BY 4.0); see
  `assets/faces/ATTRIBUTION.md`.
- Code: `lib/games/names/`

## Attention

### Odd One Out — planned
Spot the card that breaks the pattern.

### Points of Thought — built
Inspired by Lumosity's Train of Thought. Numbered, coloured points drop in at
the top one after another and roll down branching lines. Each junction has a
toggle: tap it to send points left or right; a point goes the way the toggle is
set when it gets there. Deliver each point to the target with its colour and
number. The next point is shown waiting at the top.
- One round of 10 points per session.
- Eight levels: 3 to 6 targets, and points from every 5 seconds down to
  every 2.3. A new player starts on level 2 (4 targets, every 4.5 seconds).
  A point takes about 7 seconds from top to target.
- The level carries over between sessions: deliver 9 or 10 points and the
  next session is a level harder; fewer than 7 and it is a level easier.
- **Score:** 500 + 100 per level, times the share of points delivered:
  700 for a clean round on level 2, up to 1300 on level 8.
- Formerly "Train of Thought".
- Code: `lib/games/points/`

## Reasoning & Logic

### 24 Game — planned
Combine four cards to make exactly 24.

### Sudoku — built, outside the session
Classic 9×9 Sudoku, generated on the backend with exactly one solution.
- A daily puzzle (Medium, the same for everyone) plus practice puzzles at
  Easy (42 clues), Medium (34) or Hard (28).
- Wrong digits turn red at once; notes, undo, erase and hints.
- Unfinished games are saved to the account and can be continued.
- Results are stored but not scored into the KPI.
- Code: `lib/games/sudoku/`, `backend/app/sudoku/`

### Quick Math — built, outside the session
One sum at a time with 60 seconds on the clock.
- Type the answer on the keypad; it is checked as soon as enough digits are
  typed. Right or wrong, the next sum comes straight away.
- Sums get harder with every few correct answers: small additions and
  subtractions first, then times tables, then larger numbers and division.
- The result is the number of correct answers. Any number of runs a day.
- Your Brain shows the best run, runs played and overall accuracy. Not scored
  into the KPI.
- Code: `lib/games/math/`

## Planning

### Apothecary — built
A liquid-sorting puzzle (formerly "Magic Sort"). Bottles hold four units of
coloured liquid each; pour between them until every bottle holds one colour.
- Tap a bottle to lift it, tap another to pour. Liquid pours only onto the
  same colour or into an empty bottle, and only as much as fits.
- 3 to 8 colours, always with two spare bottles: ten bottles at the top.
- 3 puzzles a session. Each shows a par: the pours in a reference solution
  found by search (not always the shortest possible).
- Solve within a quarter of par and the next puzzle has one more colour; skip
  one and it has one fewer. The colour count carries over between sessions;
  a new player starts at 4.
- Undo, Restart and Skip. Undo and Restart don't give pours back.
- **Score:** each solved puzzle is worth 200 per colour, times par / pours
  (at most 1), averaged over the three. Clean solves of 4, 5 and 6 colours
  score 1000.
- Built with Flame: bottles lift, tilt and pour, and the liquid stays level
  and sloshes as the glass moves.
- Code: `lib/games/apothecary/`

### Chess Puzzles — built, outside the session
The Lichess daily puzzle, then as many more as the player likes.
- Moves are checked on the backend; the solution never reaches the app.
- Tap or drag to move; a two-step hint.
- Results are stored but not scored into the KPI.
- Code: `lib/games/chess/`, `backend/app/chess/`

## Flexibility

### Towers of Stockholm — built
The Tower of London with frost. Three pegs hold 3, 2 and 1 balls; rebuild the
goal picture in as few moves as possible.
- **The trick:** one colour is frozen and cannot move. After every move the
  frost passes to the next colour, always in the same order.
- 5 puzzles, the first solvable in 3 moves. A perfect solve makes the next one
  move longer; anything else, one move shorter. Each puzzle allows 4 spare moves.
- **Score:** each solved puzzle is worth its optimal move count times
  optimal / moves made, scaled so a perfect 3-4-5-6-7 run scores 1000.
- Formerly "Rule-Switch Sort".
- Code: `lib/games/towers/`

### Suit Sort (WCST) — planned
A card version of the Wisconsin Card Sorting Test. The player sorts cards onto
piles by a hidden rule (suit, colour or number) and is only told "right" or
"wrong". After a run of correct sorts the rule changes without warning, and the
player has to notice and switch.
