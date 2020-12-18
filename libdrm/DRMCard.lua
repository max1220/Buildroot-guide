local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("libdrm.xf86drm_ffi")()
local xf86drmMode = require("libdrm.xf86drmMode_ffi")

local libc = require("libdrm.libc")


--local utils = require("libdrm.test_utils")()


local DRMCardConnector = require("libdrm.DRMCardConnector")




local debug_print = function()end
-- uncomment below for debug prints
debug_print = print



local function openDRMCard(nodename)
	nodename = nodename or "/dev/dri/card0";
	local flags = bor(libc.O_RDWR, libc.O_CLOEXEC);
	local fd = libc.open(nodename, flags)
	if fd < 0 then
		return false, libc.strerror(ffi.errno());
	end

	return fd;
end


local DRMCard = {}
setmetatable(DRMCard, {
	__call = function(self, ...)
		return self:new(...)
	end,
})

local DRMCard_mt = {
	__index = DRMCard;
}

function DRMCard.init(self, fd)
	local obj = {
		Handle = fd;
		Connectors = {};
	}
	setmetatable(obj, DRMCard_mt)

	obj:prepare();

	return obj;
end

function DRMCard.new(self, cardname)
	local fd, err = openDRMCard(cardname);

	if not fd then
		return false, err;
	end

	return self:init(fd);
end

function DRMCard.getBusId(self)
	local id = drmGetBusid(self.Handle);
	if id == nil then
		return "UNKNOWN"
	end

	return ffi.string(id);
end

function DRMCard.getVersion(self)
	local ver =  drmGetVersion(self.Handle); -- drmVersionPtr
	ffi.gc(ver, drmFreeVersion);

	return ver;
end

function DRMCard.getLibVersion(self)
	local ver =  drmGetLibVersion(self.Handle); -- drmVersionPtr
	ffi.gc(ver, drmFreeVersion);

	return ver;
end

--[[
typedef struct _drmStats {
    unsigned long count;	     /**< Number of data */
    struct {
	unsigned long value;	     /**< Value from kernel */
	const char    *long_format;  /**< Suggested format for long_name */
	const char    *long_name;    /**< Long name for value */
	const char    *rate_format;  /**< Suggested format for rate_name */
	const char    *rate_name;    /**< Short name for value per second */
	int           isvalue;       /**< True if value (vs. counter) */
	const char    *mult_names;   /**< Multiplier names (e.g., "KGM") */
	int           mult;          /**< Multiplier value (e.g., 1024) */
	int           verbose;       /**< Suggest only in verbose output */
    } data[15];
} drmStatsT;
--]]



function DRMCard.getStats(self)
	local stats = ffi.new("drmStatsT");
	local res = drmGetStats(self.Handle, stats);
	if res ~= 0 then
		return false;
	end

--print("DRMCard:getStats, count: ", tonumber(stats.count));

	local tbl = {}
	local counter = tonumber(stats.count)
	while counter > 0 do
		local idx = counter - 1;
		local entry = {
			Value = stats.data[idx].value;

			LongFormat = libc.stringvalue(stats.data[idx].long_format);
			LongName = libc.stringvalue(stats.data[idx].long_format);
			RateFormat = libc.stringvalue(stats.data[idx].long_format);
			RateName = libc.stringvalue(stats.data[idx].long_format);
			MultiplierName = libc.stringvalue(stats.data[idx].long_format);
			MultiplierValue = stats.data[idx].mult;
			IsValue = stats.data[idx].isvalue;
			Verbose = stats.data[idx].verbose;
		}

		table.insert(tbl, entry);

		counter = counter - 1;
	end

	return tbl
end

function DRMCard.hasDumbBuffer(self)
	local has_dumb_p = ffi.new("uint64_t[1]");
	local res = drmGetCap(self.Handle, DRM_CAP_DUMB_BUFFER, has_dumb_p)

	if res ~= 0 then
		return false, "EOPNOTSUPP"
	end

	return has_dumb_p[0] ~= 0;
end

function DRMCard.getConnector(self, id)
	return DRMCardConnector(self.Handle, id)
end

--[[
typedef struct _drmModeRes {

  int count_fbs;
  uint32_t *fbs;

  int count_crtcs;
  uint32_t *crtcs;

  int count_connectors;
  uint32_t *connectors;

  int count_encoders;
  uint32_t *encoders;

  uint32_t min_width, max_width;
  uint32_t min_height, max_height;
} drmModeRes, *drmModeResPtr;
--]]
function DRMCard.prepare(self)

--	struct modeset_dev *dev;

	-- retrieve resources */
	local res = xf86drmMode.drmModeGetResources(self.Handle);
	if (res == nil) then
		return false, libc.strerror();
	end

	ffi.gc(res, xf86drmMode.drmModeFreeResources)

	self.Resources = {}

	debug_print("Connectors: ", res.count_connectors);
	debug_print("CRTCs: ", res.count_crtcs);
	debug_print("FBs: ", res.count_fbs);
	debug_print("Encoders: ", res.count_encoders);
	debug_print("Min Size: ", res.min_width, res.min_height);
	debug_print("Max Size: ", res.max_width, res.max_height);

	-- iterate all the connectors
	local count = res.count_connectors;
	while (count > 0 ) do
		local idx = count-1;

		local conn, err = self:getConnector(res.connectors[idx])
		if conn ~= nil then
			table.insert(self.Connectors, conn);
		end

		count = count - 1;
	end

--[[
	-- iterate all connectors
	for (i = 0; i < res.count_connectors; ++i) {
		-- create a device structure */
		dev = malloc(sizeof(*dev));
		memset(dev, 0, sizeof(*dev));
		dev.conn = conn.connector_id;

		-- call helper function to prepare this connector */
		ret = modeset_setup_dev(fd, res, conn, dev);
		if (ret) then
			if (ret != -ENOENT) {
				errno = -ret;
				fprintf(stderr, "cannot setup device for connector %u:%u (%d): %m\n",
					i, res.connectors[i], errno);
			}
			free(dev);
			continue;
		end
	}
--]]

	return true;
end

-- iterate through the various connectors, returning
-- the ones that are actually connected.
function DRMCard.connections(self)
	local function iter(param, idx)
		local connection = nil;

		if idx > #self.Connectors then
			return connection;
		end

		while idx <= #self.Connectors do
			if self.Connectors[idx].Connection == ffi.C.DRM_MODE_CONNECTED and self.Connectors[idx].ModeCount > 0 then
				break
			end
			idx = idx + 1
		end

		if idx > #self.Connectors then
			return nil
		end

		return idx+1, self.Connectors[idx]
	end

	return iter, self, 1
end

function DRMCard.getDefaultConnection(self)
	for _, connection in self:connections() do
		return connection
	end
	return nil
end

function DRMCard.getFirstFrameBuffer(self)
	for _, connection in self:connections() do
		debug_print("***connection:", connection)
		debug_print("***encoder:", connection.Encoder)
		for k,v in pairs(connection.Encoder) do
			debug_print("***  encoder:", k,v)
		end
		debug_print("***crt:", connection.Encoder.CrtController)
		--debug_print("***connection:", connection.Encoder.CrtController.FrameBuffer)
		if connection.Encoder and connection.Encoder.CrtController and connection.Encoder.CrtController.FrameBuffer then
			local framebuffer = connection.Encoder.CrtController.FrameBuffer
			debug_print("***Got framebuffer:", framebuffer, connection)
			return framebuffer, connection
		end
	end
	debug_print("***No connection found!")
end

function DRMCard.getDefaultFrameBuffer(self)
	local defaultCon = self:getDefaultConnection()
	debug_print("defaultCon", defaultCon)
	local defaultEnco = defaultCon.Encoder
	debug_print("defaultEnco", defaultEnco)
	local defaultCrlCont = defaultEnco.CrtController
	debug_print("defaultCrlCont", defaultCrlCont)
	local defaultFb = defaultCrlCont.FrameBuffer
	debug_print("defaultFb", defaultFb)
	return defaultFb
end

function DRMCard.getEncoder(self, id)
	local enc = drmModeGetEncoder(self.Handle, id);

	if enc == nil then return false, "could not create encoder" end

	ffi.gc(enc, drmModeFreeEncoder)

	return DRMEncoder:init(enc)
end

function DRMCard.print(self)
	print("Supports Mode Setting: ", self:supportsModeSetting())
	for _, connector in ipairs(self.Connectors) do
		print("---- Connector ----")
		connector:print()
	end

end

function DRMCard.supportsModeSetting(self)
	local res = xf86drmMode.drmCheckModesettingSupported(self:getBusId());
	return res == 1;
end

return DRMCard
