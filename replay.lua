local msgpack = require("extlibs.msgpack.msgpack")

---@class Replay
---@field data table
---@field first_play boolean
---@field seed number
---@field pack_id string
---@field level_id string
local replay = {}
replay.__index = replay

---creates or loads a replay if path is given
---@param path string?
---@return Replay
function replay:new(path)
    local obj = setmetatable({
        data = {
            inputs = {},
        },
    }, replay)
    if path ~= nil then
        obj:_read(path)
    end
    return obj
end

---gets the key state changes (not the key state) for a specified tick
---the table is formatted like this: {<key>, <state>, <key>, <state>, ...}
---nil means that no inputs changed at the time
---@param time number
---@return table?
function replay:get_key_state_changes(time)
    return self.data.inputs[time]
end

---set the level and the settings the game was started with
---@param config table global game settings (containing settings such as black and white mode)
---@param first_play boolean
---@param seed number
---@param pack_id string
---@param level_id string
---@param level_settings table level specific settings (e.g. the difficulty mult in 21)
function replay:set_game_data(config, first_play, seed, pack_id, level_id, level_settings)
    self.seed = seed
    self.pack_id = pack_id
    self.level_id = level_id
    self.first_play = first_play
    self.data.config = config
    self.data.level_settings = level_settings
end

---saves an input into the replay file
---@param key love.KeyConstant
---@param state boolean
---@param time number timestamp (in ticks)
function replay:record_input(key, state, time)
    self.data.inputs[time] = self.data.inputs[time] or {}
    local state_changes = self.data.inputs[time]
    state_changes[#state_changes + 1] = key
    state_changes[#state_changes + 1] = state
end

---saves the replay into a file
---@param path string
function replay:save(path)
    -- the old game's format version was 0, so we call this 1 now
    local header =
        love.data.pack("string", ">BBnzz", "1", self.first_play and 1 or 0, self.seed, self.pack_id, self.level_id)
    local data = msgpack.pack(self.data)
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(love.data.compress("data", "zlib", header .. data, 9))
    file:close()
end

function replay:_read(path)
    local file = love.filesystem.newFile(path)
    file:open("r")
    local data = love.data.decompress("string", "zlib", file:read("data"))
    file:close()
    local version, offset = love.data.unpack(">B", data)
    if version > 1 or version < 1 then
        error("Unsupported replay format version '" .. version .. "'.")
    end
    self.first_play, self.seed, self.pack_id, self.level_id, offset = love.data.unpack(">Bnzz", data, offset)
    self.first_play = self.first_play == 1
    _, self.data = msgpack.unpack(data, offset - 1)
end

return replay