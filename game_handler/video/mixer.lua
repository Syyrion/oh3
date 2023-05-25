local ffi = require("ffi")
local mixer = {}
local mux
local chunk
local read_bytes = 0
local playing_decoders = {}
local chunk_size
local sample_count
local bytes_per_sample = 2

function mixer.set_muxer(muxer)
    mux = muxer
    chunk_size = mux.get_audio_buffer_size()
    sample_count = chunk_size / bytes_per_sample
    chunk = love.data.newByteData(chunk_size)
end

function mixer.load_file(file)
    local decoder = love.sound.newDecoder(file, mux.get_audio_buffer_size())
    if decoder:getBitDepth() ~= 16 then
        error("only 16 bit samples are supported")
    end
    if decoder:getSampleRate() ~= 44100 then
        error("only sample rates of 44100 are supported")
    end
    if decoder:getChannelCount() ~= 2 then
        error("only stereo sound is supported")
    end
    return decoder
end

function mixer.play(decoder)
    playing_decoders[#playing_decoders+1] = decoder
end

function mixer.update(seconds)
    local to_read = seconds * 44100 * 2 * bytes_per_sample
    local target = ffi.cast("uint16_t*", chunk:getFFIPointer())
    while to_read > read_bytes do
        for i = 0, sample_count - 1 do
            target[i] = 0
        end
        for i = #playing_decoders, 1, -1 do
            local to_mix_chunk = playing_decoders[i]:decode()
            if to_mix_chunk == nil then
                table.remove(playing_decoders, i)
            else
                local to_mix = ffi.cast('uint16_t*', to_mix_chunk:getFFIPointer())
                for j = 0, to_mix_chunk:getSize() / bytes_per_sample - 1 do
                    target[j] = target[j] + to_mix[j]
                end
            end
        end
        mux.supply_audio(chunk)
        read_bytes = read_bytes + chunk_size
    end
end

return mixer
