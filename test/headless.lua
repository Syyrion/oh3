package.preload["extlibs.sqlite"] = loadfile("extlibs/sqlite/init.lua")
package.preload["compat.game192"] = loadfile("compat/game192/init.lua")
package.preload["compat.game21"] = loadfile("compat/game21/init.lua")
package.preload["compat.game21.assets"] = loadfile("compat/game21/assets/init.lua")
package.preload["compat.game21.lua_runtime"] = loadfile("compat/game21/lua_runtime/init.lua")
local game_handler = require("game_handler.init")
local global_config = require("global_config")
local config = require("config")

describe("headless games", function()
    local versions = {
        [21] = {
            pack = "ohvrvanilla_vittorio_romeo_cube",
            level = "pointless",
            settings = { difficulty_mult = 1 },
        },
        [192] = {
            pack = "VeeDefault",
            level = "VeeDefault_easy",
            settings = { difficulty_mult = 1 },
        },
    }
    global_config.init(config, game_handler.profile)
    game_handler.init(config)
    for version, level_data in pairs(versions) do
        it("can be run and replayed to get the same score again", function()
            game_handler.set_version(version)
            game_handler.record_start(level_data.pack, level_data.level, level_data.settings)
            game_handler.run_until_death()
            game_handler.get_replay():save("test_replay")
            local score = game_handler.get_score()
            game_handler.replay_start("test_replay")
            game_handler.run_until_death()
            assert.is.equal(game_handler.get_score(), score)
        end)
    end
end)
