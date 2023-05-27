local extmath = require("extmath")
local ease = require("anim.ease")
local list = require("ui.list")
local signal = require("anim.signal")

local screen = require("ui.screen")

local timeline = signal.new_queue()

local animate = {
    running = false,
}

local function clear()
    animate.running = false
end

function animate.set_for(seconds)
    animate.running = true
    timeline:wait(seconds)
    timeline:call(clear)
end

function animate.title_to_menu()
    do
        -- Title leaves screen and gets removed
        screen.title.position:fast_forward()
        screen.title.pass = true
        screen.title.position:keyframe(0.25, -0.1, ease.out_back)
        screen.title.position:call(function()
            list.remove(screen.title)
        end)
    end
    do
        -- Insert menu buttons under title
        list.emplace_top(screen.wheel, 1)
    end
    do
        screen.background.x:fast_forward()
        screen.background.pivot_radius:fast_forward()

        screen.background.x:keyframe(0.25, 0.35, ease.out_back)
        screen.background.pivot_radius:keyframe(0.3, 0.2, ease.out_back)

        screen.background.radian_speed:set_immediate_value(0)
        local angle = screen.background.angle()
        local target = angle + math.pi
        target = target - target % (extmath.tau / 3) + math.pi / 6
        screen.background.angle:keyframe(0.25, target, ease.out_back)
    end
end

function animate.menu_to_title()
    do
        screen.title.position:fast_forward()
        screen.title.pass = false
        list.emplace_top(screen.title)
        screen.title.position:keyframe(0.25, 0.25, ease.out_back)
    end
    do
        screen.background.x:fast_forward()
        screen.background.pivot_radius:fast_forward()
        screen.background.x:keyframe(0.25, 0.5, ease.out_sine)
        screen.background.pivot_radius:keyframe(0.25, 0.1, ease.out_sine)

        screen.background.angle:fast_forward()
        screen.background.radian_speed:set_immediate_value(4 * extmath.tau)
        screen.background.radian_speed:keyframe(0.25, math.pi / 2)
    end
end

function animate.open_settings() end

function animate.close_settings() end

return animate