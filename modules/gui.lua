--= Gui functions ==========--

local umath = require("modules/umath")

local gamegui = {}

gamegui.COLOR_GREEN = Color.new(0, 24, 0)   -- softer green
gamegui.COLOR_RED = Color.new(24, 0, 0)     -- softer red
gamegui.COLOR_BLUE = Color.new(0, 0, 24)    -- softer blue
gamegui.COLOR_BLACK = Color.new(4, 4, 4)    -- near-black, not pure black
gamegui.COLOR_WHITE = Color.new(31, 31, 31) -- white color
gamegui.COLOR_GOLD = Color.new(31, 24, 0)   -- gold color

function gamegui.draw_bar(x, y, w, h, percent, bgColor, color, scrn)
    -- Draw a bar with a percentage fill
    local fillWidth = umath.Floor(w * percent)
    screen.drawFillRect(scrn, x, y, x + w, y + h, bgColor) -- draw background
    screen.drawFillRect(scrn, x, y, x + fillWidth, y + h, color) -- draw filled part
end

function gamegui.draw_bar_text(x, y, w, h, percent, bgColor, color, scrn, text)
    -- Draw a bar with a percentage fill and text
    local fillWidth = umath.Floor(w * percent)
    screen.drawFillRect(scrn, x, y, x + w, y + h, bgColor) -- draw background
    screen.drawFillRect(scrn, x, y, x + fillWidth, y + h, color) -- draw filled part
    -- draw text on top of the bar, anchor it to the left side
    screen.print(scrn, x + 2, y + 2, text, gamegui.COLOR_WHITE) -- draw text in white color
end

return gamegui
