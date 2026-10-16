# Gebeta rulesets

Gebeta (ገበጣ) has **regional variants** — pit counts (6×2 vs 6×3), capture
details, and opening customs differ by area (Tigray, Eritrea, konso, café
Addis…). No authoritative rules exist online, so the engine implements one
well-documented ruleset and **Mattathias is the final arbiter**.

## v1: "Classic" — the implemented ruleset

The widely played **12-pit / 4-seed** configuration, Oware-lineage:

- **Board:** 2 rows × 6 pits, 4 seeds in each pit (48 total). You own the
  row in front of you; no end stores — captures go to a side pile.
- **Sow:** pick up *all* seeds from one of your non-empty pits and drop
  one per pit moving forward (wrapping 11 → 0). On a full lap you skip
  the pit you lifted from.
- **Capture 1:** if the last seed lands in the *opponent's* row and that
  pit then holds **exactly 2 or 3**, take the seeds — then keep walking
  **backward** while pits hold 2 or 3, taking those too.
- **Capture 2 (fallback):** if capture 1 didn't happen and the last seed
  lands on *your own* pit holding 2 or 3, take just that pit.
- **Starvation rules:**
  - A move that would leave your opponent with **zero seeds** (after
    captures) is illegal — unless it's your only move, in which case it's
    forced.
  - If the opponent is already empty, you **must** give them seeds: any
    move whose sow never reaches their row is illegal.
- **Passing:** no legal move → pass. Two consecutive passes end the game.
- **Stalemate cap:** 50 plies without any capture ends the game (standard
  in digital Oware; prevents infinite cycling). Scores stand.
- **Win:** capture **more than 24 of 48** seeds. Exactly 24–24 is a draw.

Implemented in `lib/features/game/domain/game_engine.dart` — one file to
change for a variant.

## Variants deliberately deferred

- **3-row Tigray board** (6×3 + the "race" opening phase described by
  Board & Pieces' Gabata entry)
- **Stores** instead of side captures
- Best-of-3 / point-rally scoring used in some Tigray tournaments

## TODO — rules review with Mattathias

- [ ] Confirm 12-pit/4-seed matches how you play
- [ ] Confirm the 2-or-3 capture rule (vs. "capture only pairs", or
      "capture any size")
- [ ] Confirm the backward chain direction
- [ ] Confirm whether the no-capture fallback (rule 2) exists in your
      circles — some groups drop it
- [ ] Opening custom: some players toss to decide who starts; others let
      the elder start. Engine randomizes the starter by default.
