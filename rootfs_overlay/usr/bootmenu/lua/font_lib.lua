local font_lib = {}

function font_lib.new(tileset, mapping)
	local font = {}

	font.tileset = tileset
	font.mapping = mapping
	font.char_w = tileset.tile_w
	font.char_h = tileset.tile_h

	-- draw a single character
	function font.draw_character(char, target_buf, offset_x, offset_y)
		local byte = char
		if type(byte) == "string" then
			byte = char:byte()
		end
		if byte == 32 then -- ignore space
			return
		elseif (byte < 33) or (byte > 126) then -- ignore out-of-range
			return
		end
		local tile_id = assert(mapping[byte], "byte:"..byte)
		tileset:draw_tile(tile_id, target_buf, offset_x,offset_y, true)
	end

	-- draw a string using the font
	function font.draw_string(str, target_buf, offset_x, offset_y)
		local cx = offset_x
		for i=1, #str do
			font.draw_character(str:byte(i), target_buf, cx, offset_y)
			cx = cx + tileset.tile_w
		end
	end

	return font
end

return font_lib
