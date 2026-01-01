package main

import "core:fmt"
import "core:math"

Bresenham :: struct {
	start:   Pos,
	end:     Pos,
	cells:   ^[]byte,
	indices: ^map[i32]bool,
	dm:      Dimensions,
}

bresenham_path :: proc(b: Bresenham, l: ^Logger) {
	mag_x: i32 = math.abs(b.end.x - b.start.x)
	mag_y: i32 = math.abs(b.end.y - b.start.y)

	log(l, fmt.tprintf("%d <-> %d", mag_x, mag_y))

	if mag_x >= mag_y {
		bresenham_path_x(b, l)
	} else {bresenham_path_y(b, l)}
}

bresenham_path_y :: proc(b: Bresenham, l: ^Logger) {
	p0, p1 := b.start, b.end

	if p0.y > p1.y {
		tmp := p0
		p0 = p1
		p1 = tmp
	}
	dx_diff := p1.x - p0.x
	dx: i32 = abs(dx_diff)
	dy: i32 = abs(p1.y - p0.y)
	D := (2 * dx) - dy

	dir: i32 = 1
	if dx_diff < 0 {dir = -1}

	x := p0.x
	for y := p0.y; y < p1.y; y += 1 {
		pos := Pos {
			x = x,
			y = y,
		}
		coords := Coords {
			screen = grid_to_screen(pos),
			grid   = pos,
		}
		map_coords(coords, b.cells, b.indices, b.dm)

		if D > 0 {
			x += dir
			D -= (2 * dy)
		}
		D += (2 * dx)
	}
}

bresenham_path_x :: proc(b: Bresenham, l: ^Logger) {
	p0, p1 := b.start, b.end

	if p0.x > p1.x {
		tmp := p0
		p0 = p1
		p1 = tmp
	}
	dy_diff := p1.y - p0.y

	dx: i32 = abs(p1.x - p0.x)
	dy: i32 = abs(dy_diff)
	D := (2 * dy) - dx

	dir: i32 = 1
	if dy_diff < 0 {dir = -1}

	y := p0.y
	for x := p0.x; x < p1.x; x += 1 {
		pos := Pos {
			x = x,
			y = y,
		}
		coords := Coords {
			screen = grid_to_screen(pos),
			grid   = pos,
		}
		map_coords(coords, b.cells, b.indices, b.dm)

		if D > 0 {
			y += dir
			D -= (2 * dx)
		}
		D += (2 * dy)
	}
}
