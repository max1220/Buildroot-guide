#!/usr/bin/env luajit
local pxbuf = require("pxbuf_lib")
local imlib = require("imlib2")

local rgba = false
local filepath = arg[1]
if arg[1] == "--rgba" then
	rgba = true
	filepath = arg[2]
end
local img = imlib.image.load(filepath)
local w,h = img:get_width(), img:get_height()
local buf = pxbuf.new(w,h)
for y=0, h-1 do
	for x=0, w-1 do
		local p = img:get_pixel(x,y)
		buf.set_px(x,y,p.red,p.green,p.blue,p.alpha)
	end
end
io.write(buf:to_string(rgba))
