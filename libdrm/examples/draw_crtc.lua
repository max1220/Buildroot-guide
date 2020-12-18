local ffi = require("ffi")
local bit = require("bit")
local bor, band, lshift = bit.bor, bit.band, bit.lshift
local DRMCard = require("libdrm.DRMCard")


local function RGB(r,g,b)
	return band(0xFFFFFF, bor(lshift(r, 16), lshift(g, 8), b))
end
local function h_line(fb, x,y,count,color)
	local startOffset = (y*fb.Pitch)+(x*(fb.BitsPerPixel/8));
	local ptr = ffi.cast("uint8_t *", fb.DataPtr)+ startOffset;
	for i=0, count-1 do
		ffi.cast("uint32_t *", ptr)[i] = color;
	end
end
local function rect(fb, x1,y1, width, height, color)
	for row=y1, y1+height-1 do
		h_line(fb, x1, row, width, color);
	end
end

local card = DRMCard()
--local framebuffer = card:getDefaultFrameBuffer()
local framebuffer = card:getFirstFrameBuffer()
framebuffer.DataPtr = framebuffer:getDataPtr()
print(("fb: bpp=%d, depth=%d, pitch=%d"):format(framebuffer.BitsPerPixel, framebuffer.Depth, framebuffer.Pitch))
local rand = math.random
local function draw()
	local x,y = rand(0,framebuffer.Width), rand(0,framebuffer.Height)
	local color = RGB(rand(0,255), rand(0,255), rand(0,255))
	local w = math.random(1, (framebuffer.Width-2)-x)
	local h = math.random(1, (framebuffer.Height-2)-y)
	rect(framebuffer, x, y, w, h, color)
end

while true do
	draw()
end
