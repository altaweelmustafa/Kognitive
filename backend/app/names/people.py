"""The people of What's My Name?: one per portrait in the app's assets/faces.

Each has a fixed, invented identity so a player meets the same person every
time: a name, a profession and one personal detail. `profession_also` lists
other answers that count; `detail_keys` are the words that show the detail was
remembered (any one is enough).
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Person:
    id: str  # portrait file name in the app, without .jpg
    name: str
    profession: str
    detail: str
    profession_also: tuple[str, ...] = ()
    detail_keys: tuple[str, ...] = ()


PEOPLE = (
    Person("008", "Omar", "architect", "collects vinyl records", (), ("vinyl", "records", "music")),
    Person("014", "Clara", "nurse", "runs marathons", (), ("marathon", "running", "runner", "runs")),
    Person("016", "Elin", "teacher", "bakes sourdough bread", ("schoolteacher",), ("bake", "bread", "sourdough", "baking")),
    Person("018", "Felix", "student", "plays the drums", (), ("drum", "drums", "drummer")),
    Person("019", "Nora", "journalist", "afraid of heights", ("reporter", "writer"), ("height", "heights")),
    Person("024", "Marco", "chef", "grows tomatoes", ("cook",), ("tomato", "tomatoes", "garden", "gardening")),
    Person("025", "Maya", "dancer", "speaks four languages", (), ("language", "languages", "polyglot")),
    Person("027", "Freya", "dentist", "loves sailing", (), ("sail", "sailing", "boat", "boats")),
    Person("030", "Hana", "photographer", "has two cats", (), ("cat", "cats")),
    Person("034", "Jade", "pharmacist", "plays chess", ("chemist",), ("chess",)),
    Person("037", "Karim", "pilot", "restores old motorbikes", (), ("motorbike", "motorbikes", "motorcycle", "motorcycles", "bike", "bikes")),
    Person("041", "Bruno", "carpenter", "always cheerful", ("woodworker", "joiner"), ("cheerful", "happy", "cheery", "smiling")),
    Person("042", "Samir", "lawyer", "plays the saxophone", ("attorney", "solicitor"), ("saxophone", "sax")),
    Person("044", "Theo", "barber", "writes poetry", ("hairdresser",), ("poetry", "poem", "poems", "poet")),
    Person("045", "Leo", "programmer", "climbs mountains", ("developer", "coder", "software engineer", "engineer"), ("climb", "climbing", "climbs", "mountain", "mountains")),
    Person("064", "Leila", "doctor", "paints with watercolours", ("physician",), ("paint", "paints", "painting", "watercolour", "watercolor", "watercolours", "watercolors")),
    Person("066", "Yara", "librarian", "very shy", (), ("shy", "quiet")),
    Person("083", "Grace", "florist", "sings in a choir", (), ("choir", "sing", "sings", "singing", "singer")),
    Person("099", "Zoe", "vet", "rides horses", ("veterinarian",), ("horse", "horses", "riding", "rides")),
    Person("104", "Jonas", "electrician", "brews his own beer", (), ("beer", "brew", "brews", "brewing")),
    Person("108", "Hugo", "waiter", "surfs every summer", ("server",), ("surf", "surfs", "surfing", "surfer")),
    Person("113", "Vera", "accountant", "does crosswords", ("bookkeeper",), ("crossword", "crosswords", "puzzle", "puzzles")),
    Person("126", "Alma", "scientist", "loves astronomy", ("researcher",), ("astronomy", "stars", "space", "telescope")),
    Person("127", "Kira", "designer", "practises yoga", ("graphic designer",), ("yoga",)),
    Person("130", "Emil", "mechanic", "plays football", (), ("football", "soccer")),
    Person("132", "Adam", "firefighter", "afraid of spiders", ("fireman",), ("spider", "spiders")),
    Person("134", "Tessa", "baker", "knits scarves", (), ("knit", "knits", "knitting", "scarf", "scarves")),
    Person("135", "Priya", "engineer", "plays the violin", (), ("violin",)),
    Person("137", "Caleb", "farmer", "tells great jokes", (), ("joke", "jokes", "funny", "humour", "humor")),
    Person("172", "Victor", "bus driver", "goes fishing at dawn", ("driver",), ("fish", "fishing", "fishes")),
)

BY_ID = {p.id: p for p in PEOPLE}
