local syscall = require("syscall")
local ffi = require("ffi")
local codes = require("input_event_codes")

local input_lib = {}

function input_lib.new(inputdev)
	local input = {}
	input.dev = inputdev

	ffi.cdef([[
		// see linux/input.h
		typedef struct {
		        int64_t tv_sec;
		        int32_t tv_usec;
		} timeval;

		typedef struct {
			struct timeval time;
			uint16_t type;
			uint16_t code;
			int32_t value;
		} input_event;
	]])

	local inputfd,err = syscall.open(inputdev, "rdwr")
	if not inputfd then
		return nil, "Can't open input device: " .. tostring(err)
	end
	input.fd = inputfd

	function input.can_read()
		local ready = syscall.select({readfds = { inputfd } }, 0)
		if ready and (#ready.readfds>0) then
			return true
		end
	end

	function input.read()
		local ev = ffi.new("input_event")
		local nb, _err = inputfd:read(ev, ffi.sizeof(ev))
		if not nb then
			return nil, _err
		end
		return ev
	end

	return input
end

input_lib.codes = codes

return input_lib
