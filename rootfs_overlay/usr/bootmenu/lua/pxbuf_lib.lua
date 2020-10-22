local ffi = require("ffi")

local pxbuf_lib = {}



-- create a new basic rgba pixel buffer
function pxbuf_lib.new(w,h)
	local len = w*h*4
	local mem = ffi.new("uint8_t[?]", len)

	local buf = {}
	buf.w = w
	buf.h = h
	buf.len = len
	buf.mem = mem

	function buf.get_px(x,y)
		local i = (y*w+x)*4
		if i<0 or i>=len then
			return nil
		end
		return mem[i], mem[i+1], mem[i+2], mem[i+3]
	end

	function buf.set_px(x,y,r,g,b,a)
		local i = (y*w+x)*4
		if i<0 or i>=len then
			return
		end
		mem[i] = r
		mem[i+1] = g
		mem[i+2] = b
		mem[i+3] = a
		return true
	end

	function buf.clear(c)
		ffi.fill(mem, len, c)
	end

	buf.to_string = pxbuf_lib.to_string
	buf.copy_rect = pxbuf_lib.copy_rect
	buf.copy_rect_alpha = pxbuf_lib.copy_rect_alpha

	return buf
end



-- copy a rectangular region from one pixel buffer to another
function pxbuf_lib.copy_rect(origin_buf, target_buf, target_x,target_y, w,h, origin_x,origin_y)
	-- TODO: line-fastpath using ffi.copy
	w,h = tonumber(w) or origin_buf.w, tonumber(h) or origin_buf.h
	target_x, target_y = tonumber(target_x) or 0, tonumber(target_y) or 0
	origin_x, origin_y = tonumber(origin_x) or 0, tonumber(origin_y) or 0

	-- fastpath
	if (target_x==0) and (target_x==0) and
	(origin_x==0) and (origin_y==0) and
	(origin_buf.w==w) and (origin_buf.h==h) and
	(origin_buf.w==target_buf.w) and (origin_buf.h==target_buf.h) then
		ffi.copy(target_buf, origin_buf, origin_buf.len)
		return
	end

	for cy=0, h-1 do
		for cx=0, w-1 do
			local r,g,b,a = origin_buf.get_px(cx+origin_x, cy+origin_y)
			if r then
				target_buf.set_px(cx+target_x, cy+target_y, r,g,b,a)
			end
		end
	end
end



-- copy a rectangular region from one pixel buffer to another, perform alpha blending
function pxbuf_lib.copy_rect_alpha(origin_buf, target_buf, target_x,target_y, w,h, origin_x,origin_y)
	w,h = tonumber(w) or origin_buf.w, tonumber(h) or origin_buf.h
	target_x, target_y = tonumber(target_x) or 0, tonumber(target_y) or 0
	origin_x, origin_y = tonumber(origin_x) or 0, tonumber(origin_y) or 0
	for cy=0, h-1 do
		for cx=0, w-1 do
			local nr,ng,nb,na = origin_buf.get_px(cx+origin_x, cy+origin_y)
			local pr,pg,pb,pa = target_buf.get_px(cx+target_x, cy+target_y)
			if na==255 then
				target_buf.set_px(cx+target_x, cy+target_y, nr,ng,nb,255)
			elseif (na==0) and pr then
				target_buf.set_px(cx+target_x, cy+target_y, pr,pg,pb,255)
			elseif nr and pr then
				local mix = na/255
				local imix = 1-mix
				local r = nr*mix+pr*imix
				local g = ng*mix+pg*imix
				local b = nb*mix+pb*imix
				target_buf.set_px(cx+target_x, cy+target_y, r,g,b,255)
			end
		end
	end
end



-- copy a rectangular region from one pixel buffer to another, scale using nearest neighbor scaling
function pxbuf_lib.scale_nearest(origin_buf, target_buf, target_x,target_y, origin_w,origin_h, origin_x,origin_y, scale_x, scale_y)
	origin_w,origin_h = tonumber(origin_w) or origin_buf.w, tonumber(origin_h) or origin_buf.h
	scale_x, scale_y = tonumber(scale_x) or 0, tonumber(scale_y) or 0
	target_x, target_y = tonumber(target_x) or 0, tonumber(target_y) or 0
	origin_x, origin_y = tonumber(origin_x) or 0, tonumber(origin_y) or 0

	for cy=0, origin_h-1 do
		for cx=0, origin_w-1 do
			local r,g,b,a = origin_buf.get_px(cx+origin_x, cy+origin_y)
			if r then
				target_buf.set_px(cx+target_x, cy+target_y, r,g,b,a)
			end
		end
	end
end



-- save a pixel buffer to a string
-- first 4 bytes are magic bytes "PXBF"
-- next 2 bytes are width as an little endian unsigned 16-bit integer
-- next 2 bytes are height as an little endian unsigned 16-bit integer
-- next byte is the pixel format(0=32bpp RGBA, 1=24bpp RGB)
-- next is raw pixel data(size depends on pixel format)
function pxbuf_lib.to_string(buf, rgba)
	local function to_uint16(num)
		local rem = num % 256
		return string.char(rem, (num - rem)/256)
	end

	local str = {}
	local function write(s)
		str[#str+1] = s
	end

	write("PXBF")
	write(to_uint16(buf.w))
	write(to_uint16(buf.h))
	write(string.char(rgba and 0 or 1))

	if rgba then
		write(ffi.string(buf.mem, buf.len))
	else
		local px_data = {}
		for i=0, buf.len-4, 4 do
			px_data[#px_data+1] = string.char(buf.mem[i], buf.mem[i+1], buf.mem[i+2])
		end
		write(table.concat(px_data))
	end

	return table.concat(str)
end



-- load a pixel buffer from a string
-- format see pxbuf_lib.to_string
function pxbuf_lib.from_string(data)
	local magic_data = data:sub(1, 4)
	if magic_data ~= "PXBF" then
		return nil, "magic header is wrong: '"..tostring(magic_data):gsub("%c", function(n) return "\\"..n:byte() end).."'"
	end

	local width = data:byte(5)+data:byte(6)*256
	local height = data:byte(7)+data:byte(8)*256
	local format = data:byte(9)
	local px_data = data:sub(10)

	local buf = pxbuf_lib.new(width, height)

	if not ((format==0) or (format==1)) then
		return nil, "Unknown pixel format: " .. tostring(format)
	end
	local bytes_per_pixel = (format==0) and 4 or 3
	if #px_data ~= width*height*bytes_per_pixel then
		return nil, "pixel data size is wrong: " .. #px_data
	end
	local i = 1
	for y=0, height-1 do
		for x=0, width-1 do
			local r,g,b,a = px_data:byte(i, i+bytes_per_pixel-1)
			buf.set_px(x,y,r,g,b,(format==0) and a or 255)
			i = i + bytes_per_pixel
		end
	end

	return buf
end



-- simple correctness check
-- lua5.1 -e "require('pxbuf_lib').test()"
-- luajit -e "require('pxbuf_lib').test()"
-- TODO: Also check copy_rect
function pxbuf_lib.test()
	local function pack(...)
		return {...}
	end
	local function to_str(arg_t, skip_first)
		local new_t = {}
		for i=(skip_first and 2 or 1), #arg_t do
			new_t[skip_first and i-1 or i] = tostring(arg_t[i])
		end
		return table.concat(new_t, ",")
	end

	local total, ok = 0,0
	local function expect(name, f, expected, ...)
		local ret = pack(pcall(f, ...))
		total = total + 1
		if #ret == #expected then
			for k,v in ipairs(ret) do
				if expected[k] ~= v then
					print("Failed", name, "got:", to_str(ret, true))
					return
				end
			end
			print("Ok", name)
			ok = ok + 1
			return ret
		end
		print("Failed", name, "got:", to_str(ret, true))
	end

	local buf = pxbuf_lib.new(10,10)
	buf.name = "pxbuf.new(10,10)"
	local function expect_buf(name, expected, ...)
		local test_str = ("%s.%s(%s) == %s"):format(buf.name or tostring(buf), name, to_str({...}), to_str(expected, true))
		return expect(test_str, buf[name], expected, ...)
	end

	expect_buf("get_px", {true}, -1,0)
	expect_buf("get_px", {true}, 0,-1)
	expect_buf("get_px", {true}, -1,-1)
	expect_buf("get_px", {true}, 0,10)

	expect_buf("set_px", {true}, -1,0)
	expect_buf("set_px", {true}, 0,-1)
	expect_buf("set_px", {true}, -1,-1)
	expect_buf("set_px", {true}, 0,10)

	for y=0, buf.h-1 do
		for x=0, buf.w-1 do
			expect_buf("get_px", {true, 0,0,0,0}, x,y)
		end
	end

	expect_buf("set_px", {true, true}, 0,0, 1, 2, 3, 4)
	expect_buf("get_px", {true, 1, 2, 3, 4}, 0,0)
	expect_buf("set_px", {true, true}, 7,9, 5, 6, 7, 8)
	expect_buf("get_px", {true, 5,6,7,8}, 7,9)

	for y=0, buf.h-1 do
		for x=0, buf.w-1 do
			expect_buf("set_px", {true, true}, x,y, x%256, 0, y%256, 0)
			expect_buf("get_px", {true, x%256, 0, y%256, 0}, x,y)
		end
	end

	local data_8x8_rgba = "PXBF" .. string.char(8,0,8,0,0)..("\1\2\3\4"):rep(8*8)
	buf = pxbuf_lib.from_string(data_8x8_rgba)
	buf.name = "pxbuf.from_string(data_8x8_rgba)"
	for y=0, buf.h-1 do
		for x=0, buf.w-1 do
			expect_buf("get_px", {true, 1,2,3,4}, x,y)
		end
	end
	expect("pxbuf.to_string(buf, true)", function()
		return pxbuf_lib.to_string(buf, true) == data_8x8_rgba
	end, {true, true})


	local data_8x8_rgb = "PXBF" .. string.char(8,0,8,0,1)..("\1\2\3"):rep(8*8)
	buf = pxbuf_lib.from_string(data_8x8_rgb, true)
	buf.name = "pxbuf.from_string(data_8x8_rgb, true)"
	for y=0, buf.h-1 do
		for x=0, buf.w-1 do
			expect_buf("get_px", {true, 1,2,3,255}, x,y)
		end
	end
	expect("pxbuf.to_string(buf)", function()
		return buf.to_string(buf) == data_8x8_rgb
	end, {true, true})

	print(("="):rep(80))
	print("Total:", total)
	print("Ok:", ok)
	if total==ok then
		print("All tests passed")
	end
end



return pxbuf_lib
