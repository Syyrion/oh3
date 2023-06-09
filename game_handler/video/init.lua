local ffi = require("ffi")

ffi.cdef([[
int start_encoding(const char* file, const int width, const int height, const int framerate, const int sample_rate);
int get_audio_frame_size();
int supply_audio_data(const void* audio_data);
int supply_video_data(const void* video_data);
void stop_encoding();
]])

local clib
local os = love.system.getOS()
if os == "OS X" or os == "iOS" then
    clib = ffi.load("lib/libencode.dylib")
elseif os == "Windows" then
    clib = ffi.load("lib/libencode.dll")
elseif os == "Linux" or os == "Android" then
    clib = ffi.load("lib/libencode.so")
end
local api = {}

---start encoding a video file
---@param filename string
---@param width integer
---@param height integer
---@param framerate integer
---@param sample_rate integer
function api.start(filename, width, height, framerate, sample_rate)
    if width % 2 == 1 or height % 2 == 1 then
        error("width and height must be a multiple of 2.")
    end
    if clib.start_encoding(filename, width, height, framerate, sample_rate) ~= 0 then
        error("Failed to initialize ffmpeg.")
    end
    api.audio_frame_size = clib.get_audio_frame_size()
end

---add a video frame
---@param imagedata love.ImageData
function api.supply_video_data(imagedata)
    if clib.supply_video_data(imagedata:getFFIPointer()) ~= 0 then
        error("Failed sending video frame.")
    end
    -- prevent memory leak
    imagedata:release()
end

---add an audio frame
---@param audiodata love.SoundData
function api.supply_audio_data(audiodata)
    if clib.supply_audio_data(audiodata:getFFIPointer()) ~= 0 then
        error("Failed sending audio frame.")
    end
end

---stop encoding the video
function api.stop()
    clib.stop_encoding()
end

return api
