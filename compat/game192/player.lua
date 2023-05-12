local extra_math = require("compat.game21.math")
local set_color = require("compat.game21.color_transform")
local utils = require("compat.game192.utils")

local player = {}

local hue
local angle
local size
local speed
local focus_speed
local pos
local last_pos
local tmp_pos
local dead
local color
local cap_vertices

function player.reset()
    hue = 0
    angle = 0

    -- TODO: get from config
    size = 7.3
    speed = 9.45
    focus_speed = 4.625

    pos = {0, 0}
    last_pos = {0, 0}
    tmp_pos = {0, 0}
    dead = false
    color = {0, 0, 0, 0}
    cap_vertices = {}
end

function player.update(frametime, radius, movement, focus)
    last_pos[1] = pos[1]
    last_pos[2] = pos[2]
    local current_speed = speed
    local last_angle = angle
    if focus then
        current_speed = focus_speed
    end
    angle = angle + current_speed * movement * frametime
    local rad_angle = math.rad(angle)
    tmp_pos[1], tmp_pos[2] = math.cos(rad_angle) * radius, math.sin(rad_angle) * radius
    local p_left_check_x, p_left_check_y = extra_math.get_orbit(tmp_pos, rad_angle - 0.5 * math.pi, 0.01)
    local p_right_check_x, p_right_check_y = extra_math.get_orbit(tmp_pos, rad_angle + 0.5 * math.pi, 0.01)
    -- TODO: for each wall: if overlop check right/left then angle = last angle and then check pos overlap and ded stuff
    pos[1], pos[2] = tmp_pos[1], tmp_pos[2]
end

local function draw_pivot(sides, radius, main_quads)
    local div = 360 / sides
    local p_radius = radius * 0.75
    local distance2 = 5 + p_radius
    local cos, sin = math.cos, math.sin
    for i = 0, sides - 1 do
        local p_angle = div * i
        local angle0 = math.rad(p_angle - div * 0.5)
        local angle1 = math.rad(p_angle + div * 0.5)
        local p1_x, p1_y = cos(angle0) * p_radius, sin(angle0) * p_radius
        local p2_x, p2_y = cos(angle1) * p_radius, sin(angle1) * p_radius
        local p3_x, p3_y = cos(angle1) * distance2, sin(angle1) * distance2
        local p4_x, p4_y = cos(angle0) * distance2, sin(angle0) * distance2
        main_quads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, 255, 255, 255, 255)
        cap_vertices[i * 2 + 1] = p1_x
        cap_vertices[i * 2 + 2] = p1_y
    end
end

local function draw_death_effect()
    -- TODO
end

function player.draw(style, sides, radius, main_quads, black_and_white)
    draw_pivot(sides, radius, main_quads)
    if dead then
        draw_death_effect()
    end
    color[1], color[2], color[3], color[4] = style.get_main_color()
    if black_and_white then
        color[1], color[2], color[3] = 255, 255, 255
    end
    if dead then
        utils.get_color_from_hue(hue / 255, color)
    end
    local rad = math.rad
    local p_left_x, p_left_y = extra_math.get_orbit(pos, rad(angle - 100), size + 3)
    local p_right_x, p_right_y = extra_math.get_orbit(pos, rad(angle + 100), size + 3)
    local x, y = extra_math.get_orbit(pos, rad(angle), size)
    -- TODO: possibly make some kind of dynamic mix mesh so this can be cleaner?
    main_quads:add_quad(x, y, x, y, p_left_x, p_left_y, p_right_x, p_right_y, unpack(color))
end

-- have to actually draw later because of 3d
function player.draw_cap(sides, style, black_and_white)
    local r, g, b, a = style.get_second_color()
    if black_and_white then
        r, g, b, a = 0, 0, 0, 0
    end
    set_color(r, g, b, a)
    love.graphics.polygon("fill", unpack(cap_vertices, 1, sides * 2))
end

return player
