local log = require("log")(...)
local args = require("args")
local json = require("extlibs.json.jsonc")
local translate_and_compile_shader = require("compat.game21.assets.shader_compat")

local loaded_packs = {}
local pack_path = "packs21/"
local metadata_pack_json_map = {}
local pack_id_json_map = {}
local folder_pack_json_map = {}
local sound_mapping = {
    ["beep.ogg"] = "click.ogg",
    ["difficultyMultDown.ogg"] = "difficulty_mult_down.ogg",
    ["difficultyMultUp.ogg"] = "difficulty_mult_up.ogg",
    ["gameOver.ogg"] = "game_over.ogg",
    ["levelUp.ogg"] = "level_up.ogg",
    ["openHexagon.ogg"] = "open_hexagon.ogg",
    ["personalBest.ogg"] = "personal_best.ogg",
    ["swapBlip.ogg"] = "swap_blip.ogg",
}
local audio_path = "assets/audio/"
local cached_sounds = {}
local loaded_fonts = {}
local loaded_images = {}
local audio_module, sound_volume, music_volume

local assets = {
    pack_ids = {},
}

function assets._build_pack_id(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

local function decode_json(str, filename)
    -- not a good way but hardcoding some known cases
    str = str:gsub(": 00 }", ": 0 }")
    str = str:gsub(", 00", ", 0")
    str = str:gsub("%[00,", "%[0,")
    str = str:gsub("055%]", "55%]")
    -- remove multiline comments
    while str:find("/*", 0, true) and str:find("*/", 0, true) do
        local cstart = str:find("/*", 0, true)
        local cend = str:find("*/", 0, true)
        str = str:sub(1, cstart - 1) .. str:sub(cend + 2)
    end
    -- replace control characters in strings
    local offset = 0
    local strings = {}
    while true do
        local start_quote = str:find('"', offset)
        if start_quote == nil then
            break
        end
        offset = start_quote + 1
        local end_quote = str:find('"', offset)
        if end_quote == nil then
            break
        end
        offset = end_quote + 1
        local contents = str:sub(start_quote + 1, end_quote - 1)
        if contents:find("\n") then
            strings[#strings + 1] = contents
            contents = contents:gsub("\n", "\\n"):gsub("\r", "\\r")
            strings[#strings + 1] = contents
            str = str:sub(1, start_quote) .. contents .. str:sub(end_quote)
            offset = str:find('"', start_quote + 1) + 1
        end
    end
    -- catch decode errors
    return xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. filename .. "': " .. msg)
    end, str)
end

local function file_ext_read_iter(dir, ending)
    local files = love.filesystem.getDirectoryItems(dir)
    local index = 0
    return function()
        index = index + 1
        if index > #files then
            return
        end
        while files[index]:sub(-#ending) ~= ending do
            index = index + 1
            if index > #files then
                return
            end
        end
        local contents = love.filesystem.read(dir .. "/" .. files[index])
        if contents == nil then
            error("Failed to read " .. dir .. "/" .. files[index])
        else
            return contents, files[index]
        end
    end
end

function assets.init(data, audio, config)
    audio_module = audio
    sound_volume = config.get("sound_volume")
    music_volume = config.get("music_volume")
    local pack_folders = love.filesystem.getDirectoryItems(pack_path)
    for i = 1, #pack_folders do
        local folder = pack_path .. pack_folders[i]
        -- check if valid pack
        local files = love.filesystem.getDirectoryItems(folder)
        local function check_file(file)
            local is_in = false
            for j = 1, #files do
                if files[j] == file then
                    is_in = true
                end
            end
            if not is_in then
                error("Invalid pack " .. folder .. ", " .. file .. " does not exist!")
            end
        end
        check_file("pack.json")
        check_file("Scripts")

        local pack_json_contents = love.filesystem.read(folder .. "/pack.json")
        if pack_json_contents == nil then
            error("Failed to load pack.json")
        end
        local decode_success, pack_json = decode_json(pack_json_contents)
        if decode_success then
            pack_json.pack_id =
                assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name, pack_json.version)
            local index_pack_id = assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name)
            assets.pack_ids[#assets.pack_ids + 1] = index_pack_id
            pack_json.pack_name = pack_folders[i]
            metadata_pack_json_map[index_pack_id] = pack_json
            pack_id_json_map[pack_json.pack_id] = pack_json
            folder_pack_json_map[folder] = pack_json

            data.register_pack(pack_json.pack_id, pack_json.name, 21)

            -- level data has to be loaded here for level selection purposes
            pack_json.levels = {}
            for contents, filename in file_ext_read_iter(folder .. "/Levels", ".json") do
                local success, level_json = decode_json(contents, filename)
                if success then
                    level_json.difficultyMults = level_json.difficultyMults or {}
                    local has1 = false
                    for j = 1, #level_json.difficultyMults do
                        if level_json.difficultyMults[j] == 1 then
                            has1 = true
                            break
                        end
                    end
                    if not has1 then
                        level_json.difficultyMults[#level_json.difficultyMults + 1] = 1
                    end
                    data.register_level(pack_json.pack_id, level_json.id, level_json.name, {
                        difficulty_mult = level_json.difficultyMults,
                    })
                    pack_json.levels[level_json.id] = level_json
                end
            end
        end
    end
end

function assets.get_pack_from_metadata(disambiguator, author, name)
    return assets.get_pack_from_id(assets._build_pack_id(disambiguator, author, name))
end

function assets.get_pack_from_id(id)
    local pack = metadata_pack_json_map[id]
    if pack == nil then
        -- try again with full id map
        pack = pack_id_json_map[id]
        if pack == nil then
            error("Pack with id '" .. id .. "' not found.")
        end
    end
    return assets.get_pack(pack.pack_name)
end

function assets.get_pack(name)
    if loaded_packs[name] == nil then
        local folder = pack_path .. name

        local pack_data = {
            path = folder,
        }

        -- pack metadata
        pack_data.pack_json = folder_pack_json_map[folder]
        if pack_data.pack_json == nil then
            error(folder .. " doesn't exist or is not a valid pack!")
        end

        -- move the table to its proper place
        pack_data.levels = pack_data.pack_json.levels
        pack_data.pack_json.levels = nil

        pack_data.pack_id = pack_data.pack_json.pack_id
        if pack_data.pack_json.dependencies ~= nil then
            for i = 1, #pack_data.pack_json.dependencies do
                local dependency = pack_data.pack_json.dependencies[i]
                local index_pack_id =
                    assets._build_pack_id(dependency.disambiguator, dependency.author, dependency.name)
                local pack_json = metadata_pack_json_map[index_pack_id]
                if pack_json == nil then
                    error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.pack_id .. "'.")
                end
                -- fix recursive dependencies
                if pack_json.pack_name ~= name then
                    assets.get_pack(pack_json.pack_name)
                end
            end
        end

        log("Loading '" .. pack_data.pack_id .. "' assets")

        if not args.headless then
            -- music
            pack_data.music = {}
            for contents, filename in file_ext_read_iter(folder .. "/Music", ".json") do
                local success, music_json = decode_json(contents, filename)
                if success then
                    local json_based_filename = filename:gsub("%.json", ".ogg")
                    music_json.file_name = music_json.file_name or json_based_filename
                    if music_json.file_name:sub(-4) ~= ".ogg" then
                        music_json.file_name = music_json.file_name .. ".ogg"
                    end
                    if not love.filesystem.getInfo(music_json.file_name) then
                        music_json.file_name = json_based_filename
                    end
                    if
                        not pcall(function()
                            music_json.source = audio_module.new_stream(folder .. "/Music/" .. music_json.file_name)
                            music_json.source.looping = true
                            music_json.source.volume = music_volume
                        end)
                    then
                        log("Error: failed to load '" .. music_json.file_name .. "'")
                    end
                    pack_data.music[music_json.id] = music_json
                end
            end

            -- shaders
            pack_data.shaders = {}
            for code, filename in file_ext_read_iter(folder .. "/Shaders", ".frag") do
                pack_data.shaders[filename] = translate_and_compile_shader(code, filename)
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_ext_read_iter(folder .. "/Styles", ".json") do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
        end

        -- sounds
        pack_data.sounds = love.filesystem.getDirectoryItems(folder .. "/Sounds")
        pack_data.cached_sounds = {}

        loaded_packs[name] = pack_data
    end
    return loaded_packs[name]
end

function assets.get_sound(id)
    id = sound_mapping[id] or id
    if cached_sounds[id] == nil then
        cached_sounds[id] = audio_module.new_static(audio_path .. id)
        cached_sounds[id].volume = sound_volume
    end
    return cached_sounds[id]
end

function assets.get_pack_sound(pack, id)
    if pack.cached_sounds[id] == nil then
        pack.cached_sounds[id] = audio_module.new_static(pack.path .. "/Sounds/" .. id)
        pack.cached_sounds[id].volume = sound_volume
    end
    return pack.cached_sounds[id]
end

function assets.get_font(name, size)
    if loaded_fonts[name] == nil then
        loaded_fonts[name] = {}
    end
    if loaded_fonts[name][size] == nil then
        loaded_fonts[name][size] = love.graphics.newFont("assets/font/" .. name, size)
    end
    return loaded_fonts[name][size]
end

function assets.get_image(name)
    if loaded_images[name] == nil then
        loaded_images[name] = love.graphics.newImage("assets/image/" .. name)
    end
    return loaded_images[name]
end

return assets
