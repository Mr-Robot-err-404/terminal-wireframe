package main

import "core:fmt"
import "core:os"

Logger :: struct {
	handle:  os.Handle,
	enabled: bool,
}
Path := "render.log"

log_init :: proc(enabled: bool) -> Logger {
	if !enabled {return Logger{}}

	handle, err := os.open(Path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	if err != 0 {
		return Logger{}
	}
	return Logger{handle = handle, enabled = true}
}

log :: proc(logger: ^Logger, msg: string) {
	if !logger.enabled {
		return
	}
	data := fmt.tprintf("%s\n", msg)
	os.write_string(logger.handle, data)
}

log_close :: proc(logger: ^Logger) {
	if logger.enabled {
		os.close(logger.handle)
	}
}
