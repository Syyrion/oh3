local list = require("ui.list")
local theme = require("ui.theme")
local image = require("ui.image")
local layout = require("ui.layout")
local background = require("ui.screen.background")
local pop_up = require("ui.overlay.pop_up")

local ease = require("anim.ease")
local signal = require("anim.signal")

local extmath = require("extmath")
local transform = require("transform")
local mouse = require("mouse_button")

-- Title menu

---@type Screen
local wheel = {}
wheel.angle = 0

wheel.text_radius = signal.new_queue(0)
wheel.abs_text_radius = signal.lerp(layout.MAJOR, background.abs_x + background.abs_pivot_radius, wheel.text_radius)

---@type PanelButton
local selection

---Individual main menu buttons
---@class PanelButton:Selectable
---@field a1 number Detection angle 1
---@field a2 number Detection angle 2
---@field condition function Determines whether the mouse cursor angle is correct
---@field radius Queue Radius of selection highlight
---@field text string Text
---@field text_angle number Angle at which text appears
---@field text_radius Signal Distance from background center
---@field text_scale Signal Text scale
---@field text_transform love.Transform Sets the text anchor point to its center
---@field icon love.Image Image that shows up in the center hexagon
---@field icon_centering love.Transform Centers the image
---@field icon_size number Absolute pixel size of the icon (it should be a square).
local PanelButton = {}
PanelButton.__index = PanelButton

function PanelButton:select()
    self.radius:stop()
    self.radius:keyframe(0.15, 0.985, ease.out_sine)
    self.selected = true
end

function PanelButton:deselect()
    self.radius:stop()
    self.radius:keyframe(0.15, 0, ease.out_sine)
    self.selected = false
end

function PanelButton:check_angle(angle)
    return self.condition(angle, self.a1, self.a2)
end

function PanelButton:draw()
    local radius = self.radius()

    if radius ~= 0 then
        local outer_radius = layout.major
        local inner_radius = extmath.lerp(outer_radius, background.abs_pivot_radius(), radius)

        local a1, a2 = self.a1, self.a2
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)
        love.graphics.setColor(theme.background_main_color)
        local a, b, c, d = transform.scale(outer_radius, x1, y1, x2, y2)
        local e, f, g, h = transform.scale(inner_radius, x2, y2, x1, y1)
        love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
    end

    love.graphics.setShader(theme.bicolor_shader)
    theme.bicolor_shader:send(theme.TEXT_COLOR_UNIFORM, theme.background_main_color)
    theme.bicolor_shader:send(theme.TEXT_OUTLINE_COLOR_UNIFORM, theme.text_color)

    local text_radius = self.text_radius()
    local xt, yt = math.cos(self.text_angle) * text_radius, math.sin(self.text_angle) * text_radius
    love.graphics.push()
    love.graphics.translate(xt, yt)
    love.graphics.scale(self.text_scale())
    love.graphics.print(self.text, theme.img_font, self.text_transform)
    love.graphics.pop()

    if self.selected then
        theme.bicolor_shader:send("blue", theme.background_main_color)
        theme.bicolor_shader:send("red", { 0, 0, 0, 0 })
        love.graphics.push()
        love.graphics.scale(2 * background.abs_pivot_radius() / self.icon_size)
        love.graphics.draw(self.icon, self.icon_centering)
        love.graphics.pop()
    end
    love.graphics.setShader()
end

---Creates a new panel button
---@param a1 number
---@param a2 number
---@param condition function
---@param icon_path string
---@param text_angle number
---@param text string
---@param text_radius Signal
---@param text_scale Signal
---@return PanelButton
local function new_panel_button(a1, a2, condition, icon_path, text_angle, text, text_radius, text_scale)
    local newinst = setmetatable({
        selected = false,
        radius = signal.new_queue(0),
        a1 = a1,
        a2 = a2,
        condition = condition,
        text_angle = text_angle,
    }, PanelButton)

    newinst.icon = love.graphics.newImage(icon_path)
    local width, height = newinst.icon:getDimensions()
    newinst.icon_centering = image.get_centering_transform(width, height)
    newinst.icon_size = width

    newinst.text = text
    newinst.text_transform = love.math.newTransform()
    local text_width = theme.img_font:getWidth(text)
    newinst.text_transform:translate(text_width / -2, theme.IMG_FONT_HEIGHT / -2)
    newinst.text_radius = text_radius
    newinst.text_scale = text_scale
    return newinst
end

--[[
    -5pi/6, -3pi/6
    -3pi/6, -pi/6
    pi/6, 3pi/6
    3pi/6, 5pi/6
    5pi/6, -5pi/6
]]

local panels = {}
do
    local function between(angle, a1, a2)
        return a1 < angle and angle < a2
    end
    local function not_between(angle, a1, a2)
        return not (a1 < angle and angle < a2)
    end
    local pi56, pi12, pi16 = 5 * math.pi / 6, math.pi / 2, math.pi / 6

    local play
    do
        local icon = "assets/image/main_menu_icons/play.png"
        local text_radius = signal.lerp(
            layout.MAJOR,
            (layout.RIGHT - background.abs_x + background.abs_pivot_radius) * 0.5,
            wheel.text_radius
        )
        local text_width = theme.img_font:getWidth("PLAY")
        local text_scale = (layout.RIGHT - background.abs_x - background.abs_pivot_radius) * 0.60 / text_width
        play = new_panel_button(-pi16, pi16, between, icon, 0, "PLAY", text_radius, text_scale)
    end

    local exit
    do
        local icon = "assets/image/main_menu_icons/exit.png"
        local text_radius = signal.lerp(
            layout.MAJOR,
            (layout.BOTTOM - background.abs_y + background.abs_pivot_radius) * 0.6,
            wheel.text_radius
        )
        local text_scale = (layout.BOTTOM - background.abs_y - background.abs_pivot_radius)
            * 0.25
            / theme.IMG_FONT_HEIGHT
        exit = new_panel_button(pi16, pi12, between, icon, math.pi / 3, "EXIT", text_radius, text_scale)
    end

    local settings
    do
        local icon = "assets/image/main_menu_icons/settings.png"
        local text_radius =
            signal.lerp(layout.MAJOR, (background.abs_x + background.abs_pivot_radius) * 0.5, wheel.text_radius)
        local text_width = theme.img_font:getWidth("SETTINGS")
        local text_scale = (background.abs_x - background.abs_pivot_radius) * 0.75 / text_width
        settings = new_panel_button(-pi56, pi56, not_between, icon, math.pi, "SETTINGS", text_radius, text_scale)
    end

    play.left = settings
    play.down = exit

    settings.right = play
    settings.down = exit

    exit.left = settings
    exit.right = play
    exit.up = play

    panels.play = play
    panels.exit = exit
    panels.settings = settings

    selection = play
end

---@type boolean
local cursor_is_hovering = false

local function update_cursor_selection(x, y)
    -- Should match the final position of the background center
    local x0, y0 = layout.width * 0.375, layout.center_y
    x, y = x - x0, y - y0
    if extmath.alpha_max_beta_min(x, y) < background.abs_pivot_radius() then
        -- Cursor is in center
    else
        local angle = math.atan2(y, x)
        for _, panel in pairs(panels) do
            if panel:check_angle(angle) then
                cursor_is_hovering = true
                if selection ~= panel then
                    selection:deselect()
                    panel:select()
                    selection = panel
                end
                return
            end
        end
    end
    cursor_is_hovering = false
end

function wheel:open()
    local x, y = love.mouse.getPosition()
    update_cursor_selection(x, y)
    selection:select()
end

function wheel:draw()
    love.graphics.translate(background.abs_x(), background.abs_y())
    love.graphics.rotate(background.angle() + self.angle)
    for _, panel in pairs(panels) do
        panel:draw()
    end
    love.graphics.origin()
end

local exit_confirmation = pop_up.new_pop_up("ARE YOU SURE YOU WANT TO EXIT?", "EXIT", love.event.quit)

local function perform_selection()
    if selection == panels.exit then
        selection:deselect()
        list.emplace_above(exit_confirmation, wheel)
    elseif selection == panels.play then
        -- TODO: level select
        print("play")
    elseif selection == panels.settings then
        -- TODO: settings menu
        print("settings")
    end
end

function wheel:handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" then
        if a == "escape" then
            selection:deselect()
            return "menu_to_title"
        elseif a == "up" or a == "down" or a == "left" or a == "right" then
            local temp = selection[a]
            if not temp then
                return
            end
            selection:deselect()
            temp:select()
            selection = temp
        elseif a == "return" then
            perform_selection()
        end
    -- elseif name == "mousefocus" and not a then
    --     clear_selection()
    elseif name == "mousemoved" then
        update_cursor_selection(a, b)
    elseif name == "mousereleased" then
        if c == mouse.LEFT then
            if not cursor_is_hovering then
                selection:deselect()
                return "menu_to_title"
            end
            perform_selection()
        elseif c == mouse.BUTTON_4 then
            selection:deselect()
            return "menu_to_title"
        end
    end
end

return wheel
