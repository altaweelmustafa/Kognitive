# Kognitiv backend

FastAPI + SQLite. Accounts, Chess Puzzles (Lichess puzzle API, no key needed), Sudoku (generated here) and the Library.

```
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
.venv/bin/python -m pytest
```

API docs: http://localhost:8000/docs

| Endpoint | Purpose |
|---|---|
| `GET /chess/puzzles/daily` | Today's Lichess puzzle, cached per UTC day |
| `GET /chess/puzzles/next` | Another puzzle for practice |
| `POST /chess/puzzles/{id}/moves` | Check a move `{step, move}`; returns the opponent's reply |
| `GET /chess/puzzles/{id}/hint?step=` | Squares of the move to find |
| `POST /chess/puzzles/{id}/attempts` | Store a result (solved, mistakes, hints, duration) |
| `GET /sudoku/puzzles/daily` | Today's Sudoku (medium), the same for everyone on a UTC day |
| `GET /sudoku/puzzles/next?difficulty=` | A new puzzle: `easy`, `medium` or `hard` |
| `POST /sudoku/puzzles/{id}/attempts` | Store a result |
| `GET /sudoku/puzzles/saves`, `PUT /sudoku/puzzles/{id}/save` | A player's unfinished games |
| `POST /auth/signup`, `/auth/verify`, `/auth/resend`, `/auth/login`, `/auth/logout` | Accounts |
| `GET /me`, `PATCH /me`, `GET /me/activity` | Profile, days played, streak |
| `GET /library/articles`, `GET /library/articles/{id}` | Library |
| `POST /games/memory-matrix/results` | Store a Memory Matrix session (8 rounds); returns the score |
| `POST /games/towers-of-stockholm/results` | Store a Towers of Stockholm session (5 puzzles); returns the score |
| `GET /games/points-of-thought/level` | The level to play next (carries over between sessions) |
| `GET /games/apothecary/level`, `POST /games/apothecary/results` | Apothecary: colours to start with; store a session (3 puzzles) |
| `GET /games/whats-my-name/session`, `POST .../answer`, `.../finish` | What's My Name?: today's new people and reviews; judge a typed answer; close and score the day |
| `POST /games/quick-math/results` | Store a Quick Math run; returns the player's best |
| `POST /games/points-of-thought/results` | Store a Points of Thought session (one round); returns the score |
| `GET /me/performance` | Per-domain level, forecast and trend; overall KPI and history |
| `GET /session/today`, `GET /session/tomorrow` | The day's four games and why each was picked |

Storing a result or a save needs a logged-in player (`Authorization: Bearer <token>`).

Env: `KOGNITIV_ALLOW_REPLAYS` (testing switch, on by default: session games can be replayed the same day; set to `0` for once a day), `KOGNITIV_DB` (database path), `KOGNITIV_CONTENT` (articles folder), `LICHESS_TOKEN` (optional), `SMTP_*` (below).

## Adding a Library article

Put a Markdown file in `content/library/`. The file name becomes its address, so
use lowercase words and dashes: `sleep-well.md`.

```
---
title: Sleep Well
category: best-practices     # foods | to-do | to-avoid | best-practices
summary: One line shown on the card.
order: 60                    # optional; lower comes first
---
Your article, in **Markdown**: headings, lists, links, quotes.
```

Then run `scripts/deploy_backend.sh`. No app update is needed. To remove an
article, delete the file on the server too (deploying only adds and replaces).

## Verification emails

Until email is set up, the sign-up code is handed back to the app and shown on
the code screen. To send real emails from a Gmail account:

1. Turn on 2-Step Verification for that Google account.
2. Create an App Password at https://myaccount.google.com/apppasswords.
3. On the server, create `~/apps/kognitiv/kognitiv.env`:

   ```
   SMTP_USER=you@gmail.com
   SMTP_PASSWORD=the 16-character app password
   ```

4. `chmod 600 ~/apps/kognitiv/kognitiv.env && sudo systemctl restart kognitiv-backend`

From then on codes are emailed and no longer shown in the app.

## Hosted

Runs on `debian-hp` as the systemd service `kognitiv-backend`, listening on the
Tailscale address only: http://100.105.90.110:8000. Code is in
`~/apps/kognitiv/backend`, the database in `~/apps/kognitiv/kognitiv.db`.

Redeploy with `scripts/deploy_backend.sh`. Logs: `journalctl -u kognitiv-backend -f`.

## Scores, trends and the daily session

- **Score:** Memory Matrix gives 100 points per tile recalled, averaged over
  the 8 rounds (a flawless 8 → 15 run scores 1150).
  Towers of Stockholm gives each solved puzzle its optimal move count times
  optimal / moves made, averaged over 5 puzzles and scaled so a perfect
  3-4-5-6-7 run scores 1000.
  What's My Name? scores 1000 times the share of the day's typed answers that
  were right; its people and SM-2 schedule are in `app/names/`.
  Apothecary gives each solved puzzle 200 per colour, times par / pours (at
  most 1), averaged over 3 puzzles.
  Points of Thought is one round worth 500 + 100 per level, times the share
  of points delivered; its level carries over between sessions.
- **Domain level (KPI):** the average of a domain's last three days played.
  Overall is the average across domains that have been played.
- **Trend and forecast** (`app/brain/model.py`): under 3 days, no claim;
  3 to 9 days, a straight-line fit; 10 days or more, ARIMA(1,1,1) with drift on
  the last 30 days. A domain is "improving" or "declining" only when the
  estimated change per day is clearly non-zero (one-sided 5% test).
- **Session** (`app/brain/service.py`): Memory and Attention always, plus the
  two other domains that need it most: no data first, then declining, plateau,
  improving, and the lower forecast among equals. Domains whose games aren't
  built yet only get a slot when no playable domain is left. Decided once per UTC day from
  everything played before that day.
