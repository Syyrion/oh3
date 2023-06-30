local log_name, as_thread = ...
local log = require("log")(log_name)
local sqlite = require("extlibs.sqlite")
local strfun = require("extlibs.sqlite.strfun")
local api = {}

local server_path = "server/"
local db_path = love.filesystem.getSaveDirectory() .. "/" .. server_path .. "server.db"
local replay_path = server_path .. "replays/"
if not love.filesystem.getInfo(server_path) then
    love.filesystem.createDirectory(server_path)
end
if not love.filesystem.getInfo(replay_path) then
    love.filesystem.createDirectory(replay_path)
end
local database = sqlite({
    uri = db_path,
    users = {
        steam_id = { "text", unique = true, primary = true },
        username = { "text", unique = true },
        password_hash = "text",
    },
    scores = {
        steam_id = "text",
        pack = "text",
        level = "text",
        level_options = "text",
        created = { "timestamp", default = strfun.strftime("%s", "now") },
        time = "real",
        score = "real",
        replay_hash = "text",
    },
    login_tokens = {
        steam_id = { "text", unique = true },
        created = { "timestamp", default = strfun.strftime("%s", "now") },
        token = { "text", unique = true, primary = true },
    },
})

---get the replay path
---@return string
function api.get_replay_path()
    return replay_path
end

---remove all login tokens for a user with the given steam id
---@param steam_id string
function api.remove_login_tokens(steam_id)
    database:delete("login_tokens", { where = { steam_id = steam_id } })
end

---add a login token to the database
---@param steam_id string
---@param token any
function api.add_login_token(steam_id, token)
    token = love.data.encode("string", "base64", token)
    database:insert("login_tokens", { steam_id = steam_id, token = token })
end

---check if a user exists in the database
---@param name string
---@return boolean
function api.user_exists_by_name(name)
    return #database:select("users", { where = { username = name } }) > 0
end

---check if a user exists in the database
---@param steam_id string
---@return boolean
function api.user_exists_by_steam_id(steam_id)
    return #database:select("users", { where = { steam_id = steam_id } }) > 0
end

---get the row of a user in the database
---@param name string
---@param steam_id string
---@return table|nil
function api.get_user(name, steam_id)
    local results = database:select("users", { where = { username = name, steam_id = steam_id } })
    if #results == 0 then
        return
    end
    results[1].password_hash = love.data.decode("string", "base64", results[1].password_hash)
    return results[1]
end

---get the row of a user in the database
---@param steam_id string
---@return table|nil
function api.get_user_by_steam_id(steam_id)
    local results = database:select("users", { where = { steam_id = steam_id } })
    if #results == 0 then
        return
    end
    results[1].password_hash = love.data.decode("string", "base64", results[1].password_hash)
    return results[1]
end

---register a new user in the database (returns true on success)
---@param username string
---@param steam_id integer
---@param password_hash string
---@return boolean
function api.register(username, steam_id, password_hash)
    return database:insert("users", {
        steam_id = steam_id,
        username = username,
        password_hash = love.data.encode("string", "base64", password_hash),
    })
end

---save a score into the database and save the replay
---@param time number
---@param steam_id string
---@param pack string
---@param level string
---@param level_options any
---@param score number
---@param hash string?
---@param timestamp integer?
---@return boolean
function api.save_score(time, steam_id, pack, level, level_options, score, hash, timestamp)
    level_options = love.data.encode("string", "base64", level_options)
    local results = database:select("scores", {
        where = {
            steam_id = steam_id,
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    if #results == 0 then
        database:insert("scores", {
            steam_id = steam_id,
            pack = pack,
            level = level,
            level_options = level_options,
            time = time,
            score = score,
            replay_hash = hash,
            created = timestamp,
        })
        return true
    else
        if #results > 1 then
            log("Player has more than one score on the same ranking!")
        end
        if results[1].score > score then
            log("Score is worse than pb, discarding")
            return false
        end
        if results[1].replay_hash then
            -- remove old replay
            local folder = replay_path .. results[1].replay_hash:sub(1, 2) .. "/"
            local path = folder .. results[1].replay_hash
            love.filesystem.remove(path)
            if #love.filesystem.getDirectoryItems(folder) == 0 then
                love.filesystem.remove(folder)
            end
        end
        database:update("scores", {
            where = {
                steam_id = steam_id,
                pack = pack,
                level = level,
                level_options = level_options,
            },
            set = {
                time = time,
                score = score,
                replay_hash = hash,
                created = timestamp or os.time(),
            },
        })
        return true
    end
end

---check if a score is the top score (also returns true if tied with top score)
---@param pack any
---@param level any
---@param level_options any
---@param steam_id any
---@return boolean
function api.is_top_score(pack, level, level_options, steam_id)
    level_options = love.data.encode("string", "base64", level_options)
    local results = database:select("scores", {
        where = {
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    local max_score = -1
    local user_score
    for i = 1, #results do
        max_score = math.max(max_score, results[i].score)
        if results[i].steam_id == steam_id then
            user_score = results[i]
        end
    end
    if user_score then
        return user_score.score == max_score
    else
        return false
    end
end

---get the top scores on a level and the score for the steam id
---@param pack any
---@param level any
---@param level_options any
---@param steam_id any
---@return table
---@return table?
function api.get_leaderboard(pack, level, level_options, steam_id)
    level_options = love.data.encode("string", "base64", level_options)
    local results = database:select("scores", {
        where = {
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    local times = {}
    local scores_by_time = {}
    for i = 1, #results do
        local score = results[i]
        times[#times + 1] = score.score
        if scores_by_time[score.score] == nil then
            scores_by_time[score.score] = { score }
        else
            scores_by_time[score.score][#scores_by_time[score.score] + 1] = score
        end
    end
    table.sort(times)
    local ret = {}
    local user_score
    local time_count = 1
    local last_time
    for i = #times, 1, -1 do
        if times[i] ~= last_time then
            time_count = 1
        end
        local scores_for_time = scores_by_time[times[i]]
        local score = scores_for_time[time_count]
        time_count = time_count + 1
        last_time = times[i]
        local user = api.get_user_by_steam_id(score.steam_id)
        local name = user and user.username or "deleted user"
        ret[#ret + 1] = {
            position = #times - i + 1,
            user_name = name,
            timestamp = score.created,
            value = times[i],
            replay_hash = score.replay_hash,
        }
        if score.steam_id == steam_id then
            user_score = {}
            for k, v in pairs(ret[#ret]) do
                user_score[k] = v
            end
            user_score.position = user_score.position - 1
        end
    end
    return ret, user_score
end

---delete a user with all their scores and replays
---@param steam_id any
function api.delete(steam_id)
    local scores = database:select("scores", { where = { steam_id = steam_id } })
    for i = 1, #scores do
        local score = scores[i]
        local folder = replay_path .. score.replay_hash:sub(1, 2) .. "/"
        local path = folder .. score.replay_hash
        love.filesystem.remove(path)
        if #love.filesystem.getDirectoryItems(folder) == 0 then
            love.filesystem.remove(folder)
        end
    end
    database:delete("scores", { where = { steam_id = steam_id } })
    database:delete("users", { where = { steam_id = steam_id } })
end

if as_thread then
    database:open()
    local run = true
    while run do
        local cmd = love.thread.getChannel("db_cmd"):demand()
        local thread_id = cmd[1]
        table.remove(cmd, 1)
        if cmd[1] == "stop" then
            run = false
        else
            xpcall(function()
                local fn = api[cmd[1]]
                table.remove(cmd, 1)
                local ret = { fn(unpack(cmd)) }
                love.thread.getChannel("db_out" .. thread_id):push(ret)
            end, function(err)
                love.thread.getChannel("db_out" .. thread_id):push({ "error", err })
            end)
        end
    end
    database:close()
else
    function api.open()
        database:open()
    end
    function api.close()
        database:close()
    end
    return api
end
