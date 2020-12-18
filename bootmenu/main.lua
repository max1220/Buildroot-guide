#!/usr/bin/lua
local gui_lib = require("gui_lib")

local gui = gui_lib.new()

-- TODO: create a config file for this
gui:load_tileset("font_tileset", 7, 9, "/usr/bootmenu/data/font_tileset.pxba")
gui:load_tileset("font_tileset_2x", 7, 9, "/usr/bootmenu/data/font_tileset.pxba", true)
gui:load_tileset("gfx_tileset", 8, 8, "/usr/bootmenu/data/gfx_tileset.pxba")
gui:load_tileset("gfx_tileset_2x", 8, 8, "/usr/bootmenu/data/gfx_tileset.pxba", true)
gui:load_font("font_7x9", "font_tileset", nil, true)
gui:load_font("font_14x18", "font_tileset_2x", nil, true)

-- TODO: search /sys for info instead of hardcoded paths
gui:add_input_source("QEMU keyboard", "/dev/input/event1", "keyboard")
gui:add_input_source("QEMU mouse", "/dev/input/event2", "mouse")
gui:set_output_framebuffer("/dev/fb0")


local pixels = {}

function gui:on_mouse_click(x,y)
	print("click",x,y)
	table.insert(pixels, {x,y})
end
function gui:on_mouse_move(x,y)
end
function gui:on_key_up(key)
end
function gui:on_key_down(key)
end
function gui:on_draw(dt)
	local screen = self.screen
	local gfx_tiles = self.tilesets["gfx_tileset"]
	local font = self.fonts.font_7x9
	local font_lg = self.fonts.font_14x18

	if debug then
		for k,v in pairs(pixels) do
			screen.set_px(math.floor(v[1]), math.floor(v[2]), 255,0,255,255)
		end

		local i = 0
		font.draw_string(("FPS: %.2f"):format(1/dt), screen, 0,0); i=i+10;
		font.draw_string(("FPS(smooth): %.2f"):format(1/self.dt_smooth), screen, 0,i); i=i+10;
		font.draw_string(("Garbage: %.2f"):format(collectgarbage("count")), screen, 0,i); i=i+10;
		font.draw_string(("Date: %s"):format(os.date()), screen, 0,i); i=i+10;
		font.draw_string(("Cursor: %d %d"):format(self.mouse.x, self.mouse.y), screen, 0,i); i=i+10;
		i=i+10
		font.draw_string("Keys:", screen, 0,i); i=i+10;
		for k,v in pairs(self.keys) do
			if v then
				font.draw_string(("Key: %d"):format(k), screen, 0,i)
				i = i + 10
			end
		end

		i=i+10
		font.draw_string("Hello World!", screen, 0,i); i=i+10;
		font.draw_string("abcdefghijklmnopqrstuvwxyz", screen, 0,i); i=i+10;
		font.draw_string("ABCDEFGHIJKLMNOPQRSTUVWXYZ", screen, 0,i); i=i+10;

		i=i+10
		--font_lg.draw_string("Hello World!", screen, 0,i); i=i+20;
		--font_lg.draw_string("abcdefghijklmnopqrstuvwxyz", screen, 0,i); i=i+20;
		--font_lg.draw_string("ABCDEFGHIJKLMNOPQRSTUVWXYZ", screen, 0,i); i=i+20;

		--for j=1, #gfx_tiles do
			--gfx_tiles:draw_tile(j, screen, j*(gfx_tiles.tile_w+1), i)
		--end
	end

	collectgarbage()

	-- draw mouse cursor
	local mx,my = math.floor(self.mouse.x), math.floor(self.mouse.y)
	gfx_tiles.tileset_buf:copy_rect_alpha(screen, mx,my, 16,24,0,0)
end

local run = true
while run do
	gui:handle_events()
	gui:draw()
end
