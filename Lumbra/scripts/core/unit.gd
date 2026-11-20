@tool
class_name Unit
extends RefCounted
## Base unit. Facing: 0=N, 1=E, 2=S, 3=W. Rotating = +1 (90 degrees clockwise).

enum Faction { NEUTRAL, LIGHT, SHADOW }
enum Kind { EMITTER, MIRROR, PRISM, BLOCKER, VEIL }

const NAMES := ["Emitter", "Mirror", "Prism", "Blocker", "Veil"]
const HINTS := ["fires a beam", "bends beams", "splits beams", "stops light", "darkens 3x3"]
const FACTION_NAMES := ["Neutral", "Light", "Shadow"]

var kind: Kind
var faction: Faction
var facing: int = 0
var permanent := false   # corner emitters: cannot be moved, rotated or captured
var dual := false        # fires `facing` AND `facing + 1` (corner emitters: both edges)

func _init(k: Kind, f: Faction, face := 0, perm := false, is_dual := false) -> void:
	kind = k
	faction = f
	facing = face
	permanent = perm
	dual = is_dual

static func faction_for_kind(k: Kind) -> Faction:
	match k:
		Kind.EMITTER, Kind.MIRROR, Kind.PRISM:
			return Faction.LIGHT
		_:
			return Faction.SHADOW

func copy() -> Unit:
	return Unit.new(kind, faction, facing, permanent, dual)

func rotate_cw() -> void:
	facing = (facing + 1) % 4

## Directions in which an Emitter fires.
func emit_dirs() -> Array[int]:
	var out: Array[int] = [facing]
	if dual:
		out.append((facing + 1) % 4)
	return out

## Mirror: even facing = "/", odd facing = "\".
func reflect(d: int) -> int:
	return d ^ 1 if facing % 2 == 0 else 3 - d

## Prism: if facing is perpendicular to the incoming beam -> beam continues
## straight AND branches toward `facing`. If facing is parallel -> beam splits
## into both perpendicular directions (no straight output).
func prism_outputs(d: int) -> Array[int]:
	if (facing - d + 4) % 2 == 1:
		return [d, facing]
	return [(d + 1) % 4, (d + 3) % 4]

func short_label() -> String:
	return ["E", "M", "P", "B", "V"][kind]
