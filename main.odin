package main

import "base:intrinsics"
import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:os"
import "core:time"

// bit layout for a cell
// ┌───┬───┐
// │ 1 │ 4 │
// ├───┼───┤
// │ 2 │ 5 │
// ├───┼───┤
// │ 3 │ 6 │
// └───┴───┘

Pos :: struct {
	x: i32,
	y: i32,
}
Coords :: struct {
	grid:   Pos,
	screen: Pos,
}

Vector2 :: struct {
	x, y: f32,
}
Vector3 :: struct {
	x, y, z: f32,
}

Dimensions :: struct {
	width, height: i32,
}
GridDimensions :: struct {
	width, height: f32,
}

FPS: i64 = 60
aspect_ratio: f32 = 1.33

stop: libc.sig_atomic_t

sigint_handler :: proc "c" (sig: libc.int) {
	prev := intrinsics.atomic_add(&stop, 1)

	if prev > 0 {
		os.exit(int(sig))
	}
}

idx :: proc(pos: Pos, width: i32) -> i32 {
	return pos.y * width + pos.x
}

coord :: proc(idx: i32, width: i32) -> Pos {
	return Pos{x = idx % width, y = idx / width}
}

fill :: proc(m: ^[]rune) {
	for i in 0 ..< len(m) {
		m^[i] = ' '
	}
}

normalize :: proc(v: Vector2, dm: GridDimensions) -> Pos {
	// NOTE: -1..1 -> 0..2 -> 0..1 -> 0..w

	x := (v.x + 1) / 2 * dm.width
	y := (-v.y + 1) / 2 * dm.height
	return Pos{x = i32(x), y = i32(y)}
}

projection :: proc(v: Vector3) -> Vector2 {
	return Vector2{x = v.x / v.z, y = (v.y / v.z) * aspect_ratio}
}

map_projections :: proc(v: []Vector3, points: ^map[Vector2]bool) {
	for p in points {
		delete_key(points, p)
	}
	for i in 0 ..< len(v) {
		pt := projection(v[i])
		points^[pt] = true
	}
}
out_of_bounds :: proc(dm: Dimensions, pos: Pos) -> bool {
	if pos.x < 0 || pos.y < 0 {
		return true
	}
	if pos.x >= dm.width || pos.y >= dm.height {
		return true
	}
	return false
}

map_coords :: proc(coords: Coords, cells: ^[]byte, indices: ^map[i32]bool, dm: Dimensions) {
	if out_of_bounds(dm, coords.screen) {return}
	i := idx(coords.screen, dm.width)

	cells^[i] |= sub_cell(coords.grid)
	indices^[i] = true
}

map_vertices :: proc(
	points: map[Vector2]bool,
	cells: ^[]byte,
	indices: ^map[i32]bool,
	grid_dm: GridDimensions,
	dm: Dimensions,
) {
	for v in points {
		pos := normalize(v, grid_dm)
		map_coords(Coords{grid = pos, screen = grid_to_screen(pos)}, cells, indices, dm)
	}
}
sub_cell :: proc(pos: Pos) -> byte {
	n: u32
	col := pos.x + 1
	row := pos.y + 1

	if col % 2 == 0 {
		n += 3
	}
	m := row % 3

	switch m {
	case 2:
		n += 1
	case 0:
		n += 2
	}
	return 1 << n
}

reset :: proc(indices: ^map[i32]bool, cells: ^[]byte) {
	for idx in indices {
		cells^[idx] = 0
		delete_key(indices, idx)
	}
}

grid_to_screen :: proc(pos: Pos) -> Pos {
	return Pos{x = pos.x / 2, y = pos.y / 3}
}
screen_to_grid :: proc(pos: Pos) -> Pos {
	return Pos{x = pos.x * 2, y = pos.y * 3}
}

translate_z :: proc(start: []Vector3, current: ^[]Vector3, dz: f32) {
	for i in 0 ..< len(start) {
		current^[i].z = start[i].z + dz
	}
}
rotate_xz :: proc(v: Vector3, angle: f16) -> Vector3 {
	x := v.x * f32(math.cos(angle)) - v.z * f32(math.sin(angle))
	z := v.x * f32(math.sin(angle)) + v.z * f32(math.cos(angle))
	return Vector3{x = x, y = v.y, z = z}
}

rotate :: proc(start: []Vector3, current: ^[]Vector3, angle: f16) {
	for i in 0 ..< len(start) {
		v := rotate_xz(start[i], angle)
		current^[i] = v
	}
}


connect_edges :: proc(
	edges: []Edge,
	current: []Vector3,
	cells: ^[]byte,
	indices: ^map[i32]bool,
	grid_dm: GridDimensions,
	dm: Dimensions,
	l: ^Logger,
) {
	for p in edges {
		i, j := p[0], p[1]
		v1, v2 := current[i], current[j]

		p1 := normalize(projection(v1), grid_dm)
		p2 := normalize(projection(v2), grid_dm)
		b := Bresenham {
			start   = p1,
			end     = p2,
			cells   = cells,
			indices = indices,
			dm      = dm,
		}
		bresenham_path(b, l)
	}
}

inc :: proc(idx: int, cap: int) -> int {
	i := idx + 1
	if i >= cap {return 0}
	return i
}

main :: proc() {
	libc.signal(libc.SIGINT, sigint_handler)
	libc.signal(libc.SIGTERM, sigint_handler)

	dm, ok := dimensions()
	if !ok {
		fmt.eprintln("Failed to get terminal size")
		os.exit(1)
	}
	l := log_init(false)
	defer log_close(&l)

	grid_dm := GridDimensions {
		width  = f32(dm.width * 2),
		height = f32(dm.height * 3),
	}
	m := make(map[Pos]bool)
	indices := make(map[i32]bool)
	points := make(map[Vector2]bool)

	defer delete(m)
	defer delete(points)
	defer delete(indices)

	size := dm.width * dm.height
	cells := make([]byte, size)
	frame := make([]rune, size)
	fill(&frame)

	defer delete(cells)
	defer delete(frame)

	clear_screen()
	set_cursor(false)
	defer set_cursor(true)

	shape_idx := 0
	shape := shapes[shape_idx]
	c: u32 = 1

	current := make([]Vector3, len(shape.vertices))
	copy(current, shape.vertices)

	interval := time.Second / time.Duration(FPS)
	dz: f32 = 1
	dt: f32 = 1 / f32(FPS)
	angle: f16 = 0


	for intrinsics.atomic_load(&stop) == 0 {
		defer reset(&indices, &cells)
		defer c += 1

		if c > 300 {
			c = 0
			shape_idx = inc(shape_idx, len(shapes))
			shape = shapes[shape_idx]

			delete(current)
			current = make([]Vector3, len(shape.vertices))
			copy(current, shape.vertices)
		}
		// dz += dt
		angle += math.PI * f16(dt)
		angle = math.mod_f16(angle, 2 * math.PI)

		rotate(shape.vertices, &current, angle)
		translate_z(shape.vertices, &current, dz)

		map_projections(current, &points)
		map_vertices(points, &cells, &indices, grid_dm, dm)
		connect_edges(shape.edges, current, &cells, &indices, grid_dm, dm, &l)

		v := bitmap
		for i in 0 ..< len(cells) {
			frame[i] = v[cells[i]]
		}
		render(frame, dm.width, dm.height)
		time.sleep(interval)
	}
	delete(current)
}
