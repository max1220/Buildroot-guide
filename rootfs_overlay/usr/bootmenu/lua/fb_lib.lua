local syscall = require("syscall")
local ffi = require("ffi")
local bit = require("bit")
local pxbuf_lib = require("pxbuf_lib")

local fb_lib = {}

function fb_lib.new(fbdev, backbuffer)
	local fb = {}
	fb.dev = fbdev

	ffi.cdef([[
		// see include/uapi/linux/fb.h
		static const int FBIOGET_VSCREENINFO = 	0x4600;
		static const int FBIOPUT_VSCREENINFO = 	0x4601;
		static const int FBIOGET_FSCREENINFO = 	0x4602;
		static const int FBIOGET_CON2FBMAP = 	0x460F;
		static const int FBIOPUT_CON2FBMAP = 	0x4610;
		static const int FBIOBLANK = 			0x4611;
		static const int FBIO_WAITFORVSYNC = 	0x40044620;
		static const int FBIOPAN_DISPLAY = 		0x4606;

		struct fb_bitfield {
			uint32_t offset;			/* beginning of bitfield */
			uint32_t length;			/* length of bitfield */
			uint32_t msb_right;			/* != 0 : Most significant bit is right */
		};

		struct fb_con2fbmap {
			uint32_t console;
			uint32_t framebuffer;
		};

		struct fb_var_screeninfo {
			uint32_t xres;				/* visible resolution */
			uint32_t yres;
			uint32_t xres_virtual;		/* virtual resolution */
			uint32_t yres_virtual;
			uint32_t xoffset;			/* offset from virtual to visible resolution */
			uint32_t yoffset;
			uint32_t bits_per_pixel;	/* bits in each pixel */
			uint32_t grayscale;			/* 0 = color, 1 = grayscale, >1 = FOURCC */
			struct fb_bitfield red;		/* bitfield in fb mem if true color, else only length is significant */
			struct fb_bitfield green;
			struct fb_bitfield blue;
			struct fb_bitfield transp;	/* transparency */
			uint32_t nonstd;			/* != 0 Non standard pixel format */
			uint32_t activate;			/* see FB_ACTIVATE_*		*/
			uint32_t height;			/* height of picture in mm    */
			uint32_t width;				/* width of picture in mm     */
			uint32_t accel_flags;		/* (OBSOLETE) see fb_info.flags */

			/* Timing: All values in pixclocks, except pixclock (of course) */
			uint32_t pixclock;			/* pixel clock in ps (pico seconds) */
			uint32_t left_margin;		/* time from sync to picture	*/
			uint32_t right_margin;		/* time from picture to sync	*/
			uint32_t upper_margin;		/* time from sync to picture	*/
			uint32_t lower_margin;
			uint32_t hsync_len;			/* length of horizontal sync	*/
			uint32_t vsync_len;			/* length of vertical sync	*/
			uint32_t sync;				/* see FB_SYNC_*		*/
			uint32_t vmode;				/* see FB_VMODE_*		*/
			uint32_t rotate;			/* angle we rotate counter clockwise */
			uint32_t colorspace;		/* colorspace for FOURCC-based modes */
			uint32_t reserved[4];		/* Reserved for future compatibility */
		};

		struct fb_fix_screeninfo {
			char id[16];				/* identification string eg "TT Builtin" */
			unsigned long smem_start;	/* Start of frame buffer mem(physical address) */
			uint32_t smem_len;			/* Length of frame buffer mem */
			uint32_t type;				/* see FB_TYPE_* */
			uint32_t type_aux;			/* Interleave for interleaved Planes */
			uint32_t visual;			/* see FB_VISUAL_* */
			uint16_t xpanstep;			/* zero if no hardware panning */
			uint16_t ypanstep;			/* zero if no hardware panning */
			uint16_t ywrapstep;			/* zero if no hardware ywrap */
			uint32_t line_length;		/* length of a line in bytes */
			unsigned long mmio_start;	/* Start of Memory Mapped I/O(physical address)*/
			uint32_t mmio_len;			/* Length of Memory Mapped I/O */
			uint32_t accel;				/* Indicate to driver which specific chip/card we have */
			uint16_t capabilities;		/* see FB_CAP_* */
			uint16_t reserved[2];		/* Reserved for future compatibility */
		};
	]])
	local C = ffi.C

	local fbfd,err = syscall.open(fbdev, "rdwr")
	if not fbfd then
		return nil, "Can't open framebuffer: " .. tostring(err)
	end
	fb.fd = fbfd

	local finfo = ffi.new("struct fb_fix_screeninfo")
	assert(fbfd:ioctl(C.FBIOGET_FSCREENINFO, finfo))
	fb.finfo = finfo
	local vinfo = ffi.new("struct fb_var_screeninfo")
	assert(fbfd:ioctl(C.FBIOGET_VSCREENINFO, vinfo))
	fb.vinfo = vinfo
	fb.w = vinfo.xres
	fb.h = vinfo.yres
	local len = vinfo.xres*vinfo.yres*vinfo.bits_per_pixel/8

	if double_buffer then
		vinfo.yres_virtual = vinfo.yres_virtual*2
		assert(fbfd:ioctl(C.FBIOPUT_VSCREENINFO, ffi.cast("void*", vinfo)))
		len = len * 2
	end
	fb.len = len

	local mem = assert(syscall.mmap(0, len, "read, write", "shared", fbfd, 0))
	fb.mem = mem
	local mem_u8 = ffi.cast("uint8_t*", mem)

	local int_0 = ffi.new("int[1]", 0)
	function fb.wait_vsync()
		return fbfd:ioctl(C.FBIO_WAITFORVSYNC, int_0)
	end

	function fb.put_vinfo()
		return fbfd:ioctl(C.FBIOPUT_VSCREENINFO, ffi.cast("void*", vinfo))
	end


	--[[
	function fb.pan(xoffset, yoffset)
		vinfo.xoffset = xoffset or vinfo.xoffset
		vinfo.yoffset = yoffset or vinfo.yoffset
		return fbfd:ioctl(C.FBIOPAN_DISPLAY, ffi.cast("void*", vinfo))
	end
	]]

	function fb.flip()
		if double_buffer then
			--[[
			buf_primary, buf_secondary = buf_secondary, buf_primary
			if buf_primary == mem then
				return fb.pan(0,0)
			else
				return fb.pan(0,vinfo.yres)
			end
			]]
			if vinfo.yoffset == 0 then
				vinfo.yoffset = vinfo.yres
			else
				vinfo.yoffset = 0
			end
			return fb.put_vinfo()
		end
	end

	function fb.blank()
		return fbfd:ioctl(C.FBIOBLANK, 0)
	end

	function fb.dump()
		return ffi.string(mem_u8)
	end

	local function get_px_16bpp_rgb565(x,y)
		local i = y*vinfo.xres*2+x*2
		local byte_a, byte_b = mem_u8[i], mem_u8[i+1]
		local r = bit.band(byte_a, 0xF8)
		local g = bit.lshift(bit.band(byte_a, 0x07), 5) + bit.rshift(bit.band(byte_b, 0xE0), 3)
		local b = bit.lshift(bit.band(byte_b, 0x1F), 3)
		return r,g,b
	end

	local function get_px_24bpp_rgb(x,y)
		local i = y*vinfo.xres*3+x*3
		local r,g,b = mem_u8[i], mem_u8[i+1], mem_u8[i+2]
		return r,g,b
	end

	local function get_px_32bpp_rgba(x,y)
		local i = y*vinfo.xres*4+x*4
		local r,g,b,a = mem_u8[i], mem_u8[i+1], mem_u8[i+2], mem_u8[i+3]
		return r,g,b,a
	end

	function fb.get_px(x,y)
		-- TODO: check byte order assumptions etc.
		if vinfo.bits_per_pixel == 16 then
			return get_px_16bpp_rgb565(x,y)
		elseif vinfo.bits_per_pixel == 24 then
			return get_px_24bpp_rgb(x,y)
		elseif vinfo.bits_per_pixel == 24 then
			return get_px_32bpp_rgba(x,y)
		end
	end

	local function set_px_16bpp_rgb565(x,y,r,g,b)
		local i = y*vinfo.xres*2+x*2
		local byte_a = bit.bor(bit.band(r, 0xF8), bit.rshift(g, 5))
		local byte_b = bit.bor(bit.lshift(bit.band(g, 0x07), 5), bit.band(b, 0x1F))
		mem_u8[i] = byte_a
		mem_u8[i+1] = byte_b
	end

	local function set_px_24bpp_rgb(x,y,r,g,b)
		x,y,r,g,b = math.floor(x),math.floor(y),math.floor(r),math.floor(g),math.floor(b)
		if (x<0) or (y<0) or (x>=vinfo.xres) or (y>=vinfo.yres) then
			return
		end
		local i = y*vinfo.xres*3+x*3
		mem_u8[i] = r
		mem_u8[i+1] = g
		mem_u8[i+2] = b
	end

	local function set_px_32bpp_rgba(x,y,r,g,b,a)
		local i = y*vinfo.xres*4+x*4
		mem_u8[i] = r
		mem_u8[i+1] = g
		mem_u8[i+2] = b
		mem_u8[i+3] = a
	end

	function fb.set_px(x,y, r,g,b,a)
		-- TODO: check byte order assumptions etc.
		if vinfo.bits_per_pixel == 16 then
			return set_px_16bpp_rgb565(x,y, r,g,b)
		elseif vinfo.bits_per_pixel == 24 then
			return set_px_24bpp_rgb(x,y, r,g,b)
		elseif vinfo.bits_per_pixel == 32 then
			return set_px_32bpp_rgba(x,y, r,g,b,a)
		end
	end

	function fb.clear(c)
		ffi.fill(mem, len, c)
	end

	fb.to_string = pxbuf_lib.to_string
	fb.copy_rect = pxbuf_lib.copy_rect
	fb.copy_rect_alpha = pxbuf_lib.copy_rect_alpha

	return fb
end

return fb_lib
