local TitleScreen = {}

local AudioManager = require("src.audio_manager")

local titleFont
local promptFont

function TitleScreen.init()
    titleFont = love.graphics.newFont(48)
    promptFont = love.graphics.newFont(14)
end

function TitleScreen.update(dt)
end

function TitleScreen.draw()
    -- Draw background
    love.graphics.clear(51/255, 153/255, 76/255, 1.0)
    
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    -- Draw Title Shadow
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 1)
    local titleText = "Tiny Farm"
    local tw = titleFont:getWidth(titleText)
    love.graphics.print(titleText, (w - tw)/2 + 2, h/2 - 60 + 2)
    
    -- Draw Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(titleText, (w - tw)/2, h/2 - 60)
    
    -- Draw Start Button mock
    love.graphics.setFont(promptFont)
    local promptText = "Tap Anywhere to Start"
    local pw = promptFont:getWidth(promptText)
    love.graphics.print(promptText, (w - pw)/2, h/2 + 20)
end

function TitleScreen.keypressed(key)
    AudioManager.playSfx("click")
    return "game"
end

function TitleScreen.mousepressed(x, y, button)
    AudioManager.playSfx("click")
    return "game"
end

return TitleScreen
