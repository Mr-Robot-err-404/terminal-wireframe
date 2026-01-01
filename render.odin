package main

import "core:fmt"
import "core:strings"

clear_screen :: proc() {
	fmt.print("\x1b[2J")
}

start_of_line :: proc(row: i32) -> string {
	return fmt.tprintf("\x1b[%d;1H", row)
}

render :: proc(frame: []rune, w, h: i32) {
	builder: strings.Builder
	defer delete(builder.buf)

	for y: i32 = 0; y < h; y += 1 {
		strings.write_string(&builder, start_of_line(y + 1))

		for x: i32 = 0; x < w; x += 1 {
			i := idx(Pos{x = x, y = y}, w)
			strings.write_rune(&builder, frame[i])
		}
	}
	fmt.print(strings.to_string(builder))
}

set_cursor :: proc(show: bool) {
	if show {
		fmt.print("\x1b[?25h")
		return
	}
	fmt.print("\x1b[?25l")
}
