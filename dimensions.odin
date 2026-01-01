package main

import "core:c"

foreign import libc "system:c"

when ODIN_OS == .Darwin {
	TIOCGWINSZ :: 0x40087468
} else when ODIN_OS == .Linux {
	TIOCGWINSZ :: 0x5413
}

winsize :: struct {
	ws_row:    c.ushort,
	ws_col:    c.ushort,
	ws_xpixel: c.ushort,
	ws_ypixel: c.ushort,
}

foreign libc {
	ioctl :: proc(fd: c.int, request: c.ulong, #c_vararg args: ..any) -> c.int ---
}

dimensions :: proc() -> (dm: Dimensions, ok: bool) {
	ws: winsize

	result := ioctl(1, TIOCGWINSZ, &ws)

	if result == -1 {
		return Dimensions{}, false
	}
	return Dimensions{width = i32(ws.ws_col), height = i32(ws.ws_row)}, true
}
