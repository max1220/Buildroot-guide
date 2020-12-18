local pxbuf_lib = require("pxbuf_lib")

local tileset_lib = {}



-- create a new tileset(a grid of images)
function tileset_lib.new(tileset_buf, tile_w, tile_h)
	local tileset = {}
	tileset.tile_w = tile_w
	tileset.tile_h = tile_h
	tileset.tileset_buf = tileset_buf

	-- copy tile content to a seperate pixel buffer
	local function make_tile(offset_x, offset_y)
		local tile_buf = pxbuf_lib.new(tile_w, tile_h)
		tileset_buf:copy_rect(tile_buf, 0,0, tile_w, tile_h, offset_x, offset_y)
		return tile_buf
	end

	-- create a new tile pixel buffer for every tile in the tileset pixel buffer
	local i = 1
	for y=0, tileset_buf.h-tile_h, tile_h do
		for x=0, tileset_buf.w-tile_w, tile_w do
			tileset[i] = make_tile(x,y)
			i = i + 1
		end
	end

	-- draw a tile by it's id
	function tileset:draw_tile(tile_id, target_buf, offset_x,offset_y, alpha)
		local tile_buf = self[tile_id]
		if alpha then
			tile_buf:copy_rect_alpha(target_buf, offset_x,offset_y)
		else
			tile_buf:copy_rect(target_buf, offset_x,offset_y)
		end
	end

	return tileset
end



return tileset_lib
