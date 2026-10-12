"""SM-2 spaced repetition, as in SuperMemo 2.

A card has a repetition count, an ease factor and an interval in days. A good
answer (quality 3 or more) lengthens the interval: 1 day, then 6, then the
last interval times the ease. A poor one starts the card again tomorrow.
"""

from dataclasses import dataclass

START_EASE = 2.5
MIN_EASE = 1.3

# Answer quality on SM-2's 0-5 scale.
EXACT, TYPO, WRONG = 5, 4, 2


@dataclass
class Card:
    repetitions: int = 0
    ease: float = START_EASE
    interval: int = 0  # days


def review(card: Card, quality: int) -> Card:
    if quality < 3:
        repetitions, interval = 0, 1
    else:
        interval = 1 if card.repetitions == 0 else 6 if card.repetitions == 1 else round(card.interval * card.ease)
        repetitions = card.repetitions + 1
    ease = card.ease + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
    return Card(repetitions, max(MIN_EASE, ease), interval)
