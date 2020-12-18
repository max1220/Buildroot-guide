local ffi = require("ffi")



ffi.cdef([[
typedef struct {
        int64_t tv_sec;
        int32_t tv_nsec;
} timespec_t;

enum {
    CLOCK_REALTIME,
    CLOCK_MONOTONIC,
    CLOCK_PROCESS_CPUTIME_ID,
    CLOCK_THREAD_CPUTIME_ID,
    CLOCK_MONOTONIC_RAW,
    CLOCK_REALTIME_COARSE,
    CLOCK_MONOTONIC_COARSE,
    CLOCK_BOOTTIME,
    CLOCK_REALTIME_ALARM,
    CLOCK_BOOTTIME_ALARM
};

//int clock_gettime(int32_t clockid, timespec_t * tp);
//int nanosleep(timespec_t* req, timespec_t * rem);
int clock_gettime(int32_t clockid, void* tp);
int nanosleep(timespec_t* req, void* rem);

static const int NS_IN_S = 1000000000;
]])
local C = ffi.C



local time = {}

-- common clock values
time.REALTIME = C.CLOCK_REALTIME
time.MONOTONIC = C.CLOCK_MONOTONIC
time.MONOTONIC_RAW = C.CLOCK_MONOTONIC_RAW
time.BOOTTIME = C.CLOCK_BOOTTIME



-- Gets current time in seconds. clock is the system timer used(see man clock_gettime)
function time.gettime(clock)
	local t = ffi.new("timespec_t")
	if C.clock_gettime(clock or C.CLOCK_MONOTONIC_RAW, t) == 0 then
		return tonumber(t.tv_sec) + (t.tv_nsec/C.NS_IN_S)
    end
end



-- sleep for specified timeout(in seconds). Uses nanosleep
function time.sleep(timeout)
	local t = ffi.new("timespec_t")
	t.tv_sec = math.floor(timeout)
	t.tv_nsec = (timeout%1)*C.NS_IN_S
	return C.nanosleep(t, nil)
end



return time
