local tileset_lib = require("tileset_lib")
local pxbuf_lib = require("pxbuf_lib")
local font_lib = require("font_lib")
local input_lib = require("input_lib")
local fb_lib = require("fb_lib")

--local time_lib = require("time_lib")
local syscall = require("syscall")
local function gettime()
	--return time_lib.gettime(t.MONOTONIC_RAW)
	return syscall.clock_gettime("monotonic").time
end

local gui_lib = {}

function gui_lib.new()
	local gui = {}

	gui.tilesets = {}
	-- load tileset from a file
	function gui:load_tileset(name, tile_w, tile_h, tileset_path, scale2x)
		if self.tilesets[name] then
			return self.tilesets[name]
		end

		local tileset_file = assert(io.open(tileset_path, "r"))
		local tileset_buf = pxbuf_lib.from_string(tileset_file:read("*a"))
		tileset_file:close()

		if scale2x then
			local scaled_tileset_buf = pxbuf_lib.new(tileset_buf.w, tileset_buf.h)
			tileset_buf:scale_pixelart_2x(scaled_tileset_buf)
			tile_w,tile_h = tile_w*2,tile_h*2
			tileset_buf = scaled_tileset_buf
		end

		local tileset = tileset_lib.new(tileset_buf, tile_w, tile_h)

		self.tilesets[name] = tileset
		return tileset
	end


	gui.fonts = {}
	-- load tileset from a file, and create a font entry based on it
	function gui:load_font(name, tileset_name, mapping, default)
		if self.fonts[name] then
			return self.fonts[name]
		end

		local font_tileset = assert(self.tilesets[tileset_name])
		if not mapping then
			mapping = {}
			for j=33, 126 do
				mapping[j] = j-31
			end
		end

		local font = font_lib.new(font_tileset, mapping)

		self.fonts[name] = font
		if default then
			self.fonts.default = font
		end
		return font
	end


	gui.input_devs = {}
	-- add an input source to the input device list
	function gui:add_input_source(name, dev_path, type)
		local dev = assert(input_lib.new(dev_path))
		local entry = {
			name = name,
			dev_path = dev_path,
			dev = dev,
			type = type
		}
		table.insert(self.input_devs, entry)
		self.input_devs[type] = self.input_devs[type] or {}
		table.insert(self.input_devs[type], entry)
	end


	gui.screen = nil
	function gui:set_output_framebuffer(dev_path)
		local screen = assert(fb_lib.new(dev_path, true))
		local w,h = screen.vinfo.xres, screen.vinfo.yres
		self.screen = screen
		self.mouse.x_max = w
		self.mouse.y_max = h
		self.w = w
		self.h = h
	end


	local now = gettime()
	gui.last = now
	gui.started = now
	gui.dt_smooth = 0
	function gui:draw()
		now = gettime()
		local dt = now - self.last
		self.dt = dt
		self.last = now

		self.dt_smooth = 0.98*self.dt_smooth+0.02*dt

		self.screen.clear(0)
		self:on_draw(dt)
		self.screen.flip()
	end


	gui.mouse = {
		x = 0,
		y = 0,
		x_max = 0,
		y_max = 0,
		lmb = false,
		mmb = false,
		rmb = false,
		x_sens = 1,
		y_sens = 1,
	}
	function gui:handle_mouse_event(ev)
		if (ev.type == input_lib.codes.EV_REL) and (ev.code == input_lib.codes.REL_X) then
			self.mouse.x = math.min(math.max(self.mouse.x + ev.value*self.mouse.x_sens, 0), self.mouse.x_max)
			self:on_mouse_move(self.mouse.x, self.mouse.y)
		elseif (ev.type == input_lib.codes.EV_REL) and (ev.code == input_lib.codes.REL_Y) then
			self.mouse.y = math.min(math.max(self.mouse.y + ev.value*self.mouse.y_sens, 0), self.mouse.y_max)
			self:on_mouse_move(self.mouse.x, self.mouse.y)
		elseif (ev.type == input_lib.codes.EV_KEY) then
		end
	end


	gui.keys = {}
	function gui:handle_keyboard_event(ev)
		if ev.type == input_lib.codes.KEY_DOWN then
			self.keys[ev.code] = true
			self:on_key_down(ev.code)
		elseif ev.type == input_lib.codes.KEY_UP then
			self.keys[ev.code] = nil
			self:on_key_up(ev.code)
		end
	end


	function gui:handle_events()
		for _,input_entry in ipairs(self.input_devs) do
			while input_entry.dev.can_read() do
				local ev = input_entry.dev.read()
				if input_entry.type == "mouse" then
					self:handle_mouse_event(ev)
				elseif input_entry.type == "keyboard" then
					self:handle_keyboard_event(ev)
				end
			end
		end
	end


	-- user callback dummy functions
	function gui:on_mouse_move(x,y)
	end
	function gui:on_mouse_click(x,y)
	end
	function gui:on_key_up(key)
	end
	function gui:on_key_down(key)
	end

	return gui


end

return gui_lib
