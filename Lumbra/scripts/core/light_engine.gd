@tool
class_name LightEngine
extends RefCounted
## Stateless illumination solver, recomputed from scratch after every action.
##
## Beam rules
##  - Emitters fire from their tile (corner emitters: both inward edges, full range).
##  - A beam dies the moment it enters a tile inside a Veil's darkness zone (the full 3x3
##    around the Veil, including its own tile), and records
##    its direction against every Veil whose zone that tile belongs to.
##    Exception: beams fired straight from a corner emitter pass through darkness (and record nothing).
##  - Empty tile: lit. Mirror / Prism: lit, beam re-emitted. Emitter / Veil: lit, beam ends.
##  - Blocker: beam ends (tile not lit), casts a shadow ray behind it, and records the
##    incoming direction. Beams from 2+ different directions shatter the Blocker.
##  - A shadow ray stops at the first lit tile: a beam crossing it cuts the shadow off.
##
## Tile state: veiled -> SHADOW, else lit -> LIGHT, else blocker-cast -> SHADOW, else DIM.

enum Tile { DIM, LIGHT, SHADOW }
const VEIL_RADIUS := 1

class Result:
	var lit := PackedByteArray()
	var veiled := PackedByteArray()
	var cast := PackedByteArray()
	var state := PackedByteArray()
	var crush := {}            # blocker cell index -> true (hit from 2+ directions)
	var hits := {}             # blocker cell index -> {direction: true} (for the hit-side markers)
	var veil_hits := {}        # veil cell index -> {direction: true} (beams that entered its zone)
	var segments: Array = []   # [Vector2i from, Vector2i to] for drawing beams

	func tile_at(c: Vector2i) -> int:
		return state[c.y * BoardState.SIZE + c.x]

static func _blank(n: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(n)
	a.fill(0)
	return a

static func compute(board: BoardState) -> Result:
	var n := BoardState.SIZE * BoardState.SIZE
	var r := Result.new()
	r.lit = _blank(n)
	r.veiled = _blank(n)
	r.cast = _blank(n)
	r.state = _blank(n)

	var queue: Array = []  # entries: [origin cell, direction]
	var veils: Array[Vector2i] = []
	for cell in board.all_cells():
		var src := board.get_unit(cell)
		if src == null:
			continue
		if src.kind == Unit.Kind.EMITTER:
			r.lit[board.idx(cell)] = 1
			for d in src.emit_dirs():
				queue.append([cell, d])
		elif src.kind == Unit.Kind.VEIL:
			veils.append(cell)
			for dy in range(-VEIL_RADIUS, VEIL_RADIUS + 1):
				for dx in range(-VEIL_RADIUS, VEIL_RADIUS + 1):
					var zc := cell + Vector2i(dx, dy)
					if board.in_bounds(zc):
						r.veiled[board.idx(zc)] = 1

	var visited := {}
	var hits := {}  # blocker cell index -> {direction: true}
	var shadow_rays: Array = []  # [blocker cell, direction]; cast after all beams are traced
	while not queue.is_empty():
		var beam: Array = queue.pop_back()
		var origin: Vector2i = beam[0]
		var d: int = beam[1]
		var key := Vector3i(origin.x, origin.y, d)
		if visited.has(key):
			continue
		visited[key] = true

		var pos := origin
		var src := board.get_unit(origin)
		var corner := src != null and src.permanent  # corner emitter beams ignore darkness
		while true:
			var nxt := pos + BoardState.DIRS[d]
			if not board.in_bounds(nxt):
				break
			if r.veiled[board.idx(nxt)] == 1 and not corner:
				for v in veils:
					var off := nxt - v
					if absi(off.x) <= VEIL_RADIUS and absi(off.y) <= VEIL_RADIUS:
						var vi := board.idx(v)
						if not r.veil_hits.has(vi):
							r.veil_hits[vi] = {}
						r.veil_hits[vi][d] = true
				break  # darkness extinguishes the beam
			pos = nxt
			var u := board.get_unit(pos)
			if u == null:
				r.lit[board.idx(pos)] = 1
				continue
			if u.kind == Unit.Kind.BLOCKER:
				var bi := board.idx(pos)
				if not hits.has(bi):
					hits[bi] = {}
				hits[bi][d] = true
				shadow_rays.append([pos, d])
				break
			r.lit[board.idx(pos)] = 1
			if u.kind == Unit.Kind.MIRROR:
				queue.append([pos, u.reflect(d)])
			elif u.kind == Unit.Kind.PRISM:
				for nd in u.prism_outputs(d):
					queue.append([pos, nd])
			break
		if pos != origin:
			r.segments.append([origin, pos])

	# Lit tiles are final only now, so shadow rays are cast after tracing.
	for sr in shadow_rays:
		var sd: int = sr[1]
		var ray: Vector2i = sr[0] + BoardState.DIRS[sd]
		while board.in_bounds(ray) and r.lit[board.idx(ray)] == 0:
			r.cast[board.idx(ray)] = 1
			ray += BoardState.DIRS[sd]

	r.hits = hits
	for bi in hits:
		if hits[bi].size() > 1:
			r.crush[bi] = true

	for i in n:
		if r.veiled[i] == 1:
			r.state[i] = Tile.SHADOW
		elif r.lit[i] == 1:
			r.state[i] = Tile.LIGHT
		elif r.cast[i] == 1:
			r.state[i] = Tile.SHADOW
		else:
			r.state[i] = Tile.DIM
	return r

## Light units must stand on LIGHT tiles. Veils die on LIGHT tiles, or break when beams enter
## their darkness from two different directions.
## Blockers die only when crushed by beams from two different directions.
static func find_violations(board: BoardState, r: Result) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in board.all_cells():
		var u := board.get_unit(cell)
		if u == null or u.permanent or u.faction == Unit.Faction.NEUTRAL:
			continue
		var t := r.tile_at(cell)
		if u.faction == Unit.Faction.LIGHT:
			if t != Tile.LIGHT:
				out.append(cell)
		elif u.kind == Unit.Kind.BLOCKER:
			if r.crush.has(board.idx(cell)):
				out.append(cell)
		elif t == Tile.LIGHT:
			out.append(cell)
		elif u.kind == Unit.Kind.VEIL:
			if r.veil_hits.get(board.idx(cell), {}).size() > 1:
				out.append(cell)
	return out

## Territory: only the inner 6x6 counts. The edge ring is lit by the corner emitters from the start.
static func count_tiles(r: Result, tile: int) -> int:
	var c := 0
	for y in range(1, BoardState.SIZE - 1):
		for x in range(1, BoardState.SIZE - 1):
			if r.state[y * BoardState.SIZE + x] == tile:
				c += 1
	return c
