@tool
class_name Look
extends RefCounted
## All visual constants (sizes + colors). Values above 1.0 are HDR so they bloom with glow.

const CELL := 84
const GAP := 3
const TILE := [Color(0.20, 0.20, 0.24), Color(1.45, 1.15, 0.45), Color(0.22, 0.12, 0.40)]  # DIM, LIGHT, SHADOW
const UNIT := {
	Unit.Faction.NEUTRAL: Color(1.2, 1.2, 1.5),
	Unit.Faction.LIGHT: Color(1.8, 1.4, 0.5),
	Unit.Faction.SHADOW: Color(0.8, 0.55, 1.4),
}
const UNIT_PLATE := Color(0.07, 0.06, 0.10, 0.9)  # dark disc behind every piece so it reads on lit tiles
const UNIT_PLATE_RADIUS := 0.40                     # fraction of CELL
const ARROW_OUTLINE := Color(0.05, 0.04, 0.08, 0.95)  # dark edge around emitter direction arrows
const ARROW_OUTLINE_WIDTH := 2.0
const BEAM := Color(2.2, 1.9, 1.0, 0.9)
const BEAM_WIDTH := 5.0          # bright core of the beam
const BEAM_GLOW_WIDTH := 26.0    # full quad the beam shader draws core + halo into
const BEAM_IN_DARK := 0.22       # opacity where a corner beam crosses Veil darkness (it passes, but lights nothing)
const HIT_MARK := Color(1.9, 0.7, 2.6)  # dashed violet bars: sides a Blocker / capturable Veil was hit from
const HIT_MARK_WIDTH := 4.0
const HIT_MARK_DASH := 7.0
const ANIM_PLACE := 0.28         # seconds: piece pops in
const ANIM_ROTATE := 0.18        # seconds: quarter-turn spin
const ANIM_CAPTURE := 0.35       # seconds: piece bursts and fades out
const HANDOFF_DELAY := 0.55      # seconds the board stays visible after a move, so the animations can play
const PREVIEW_GHOST := Color(1, 1, 1, 0.6)          # hovered placement / rotation, if legal
const PREVIEW_BAD := Color(1.6, 0.3, 0.3, 0.7)      # hovered placement that would be captured instantly
const PREVIEW_DOOMED := Color(1.9, 0.4, 0.4, 1.0)   # pulse on pieces the hovered move would capture
const BOARD_BASE := Color(0.045, 0.04, 0.065)      # plate under the tiles (shows in the gaps)
const BOARD_RIM := Color(0.85, 0.7, 1.3, 0.7)       # thin glowing edge around the plate
const BOARD_SHADOW := Color(0.0, 0.0, 0.0, 0.16)    # soft drop shadow onto the background, per ring
const BOARD_MARGIN := 6.0                           # plate overhang around the tiles, px
const KEY_OUTLINE := Color(0.55, 0.65, 1.0)
const LABEL := Color(0.7, 0.7, 0.8)

static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
