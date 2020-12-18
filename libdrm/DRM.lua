--luacheck: no max line length
local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("libdrm.xf86drm_ffi")()
local xf86drmMode = require("libdrm.xf86drmMode_ffi")()
--local utils = require("libdrm.test_utils")()


local DRM = {}
function DRM.available(self)
	return drmAvailable() == 1;
end

function DRM.open(self, nodename)
	nodename = nodename or "/dev/dri/card0";
	local flags = bor(O_RDWR, O_CLOEXEC);
	local fd = open(nodename, flags)
	if fd < 0 then
		return false, strerror(ffi.errno());
	end

	return fd;
end


return DRM
