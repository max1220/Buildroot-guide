#!/usr/bin/lua
local time_lib = require("time_lib")
local pxbuf_lib = require("pxbuf_lib")
local tileset_lib = require("tileset_lib")
local font_lib = require("font_lib")
local fb_lib = require("fb_lib")
local input_lib = require("input_lib")

-- load tileset from a file, and create a font based on it
local tileset_file = assert(io.open("/usr/bootmenu/data/tileset.pxba", "r"))
local tileset_buf = pxbuf_lib.from_string(tileset_file:read("*a"))
tileset_file:close()
local tileset = tileset_lib.new(tileset_buf, 7, 9)
local mapping = {}
for j=33, 126 do
	mapping[j] = j-31
end
local font = font_lib.new(tileset, mapping)

-- open the framebuffer, create a pixel buffer for the screen
local screen = assert(fb_lib.new("/dev/fb0", true))
local w,h = screen.w, screen.h

-- open input devices
local kbd = input_lib.new("/dev/input/event1")
local mouse = input_lib.new("/dev/input/event2")


local cursor_x, cursor_y = 0,0
local rel_scale = 1
local start = time_lib.gettime()
local last = start
local dt,running
local function draw()
	screen.clear(0)

	font.draw_string(("FPS: %.2f"):format(1/dt), screen, 0,0)
	font.draw_string(("Running: %d"):format(running), screen, 0,10)
	font.draw_string(("Cursor: %d %d"):format(cursor_x, cursor_y), screen, 0,20)

	tileset:draw_tile(96, screen, math.floor(cursor_x),math.floor(cursor_y), true)
	tileset:draw_tile(97, screen, math.floor(cursor_x),math.floor(cursor_y)+9, true)
end
local function handle_input()
	while kbd.can_read() do
		local ev = kbd.read()
	end
	while mouse.can_read() do
		local ev = mouse.read()
		if (ev.type == input_lib.codes.EV_REL) and (ev.code == input_lib.codes.REL_X) then
			cursor_x = math.min(math.max(cursor_x + ev.value*rel_scale, 0), w)
		elseif (ev.type == input_lib.codes.EV_REL) and (ev.code == input_lib.codes.REL_Y) then
			cursor_y = math.min(math.max(cursor_y + ev.value*rel_scale, 0), h)
		end
	end
end
print("yres_virtual", screen.vinfo.yres_virtual)
while true do
	local now = time_lib.gettime()
	running = now-start
	dt = now-last
	last = now

	--handle_input()
	--draw()

	assert(screen.flip())
end
