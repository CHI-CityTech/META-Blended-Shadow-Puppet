@tool
class_name Rules
extends RefCounted
## Every gameplay number lives here. Tweak balance without touching logic.

const START_HAND := 3
const MAX_HAND := 5
const CAPTURE_LIMIT := 5     # units lost before a side is defeated
const BROKEN_VEILS_COUNT := false  # do Veils broken by beams count toward CAPTURE_LIMIT?
const TERRITORY_WIN := 22    # inner tiles of your element (60% of the inner 36; the edge ring doesn't count)
const ZONE_TURNS := 3        # own turns holding every key tile
const FINAL_TURNS := 6       # turns played after both decks are empty (3 each), then the tile count decides
const TURN_LIMIT := 80       # hard cap: after this turn the tile count decides
const KEY_TILES: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]  # D5 E5 D4 E4

# [Unit.Kind, copies]
const LIGHT_DECK := [[Unit.Kind.EMITTER, 2], [Unit.Kind.MIRROR, 5], [Unit.Kind.PRISM, 3]]
const SHADOW_DECK := [[Unit.Kind.BLOCKER, 5], [Unit.Kind.VEIL, 5]]
