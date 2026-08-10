-- main.lua: Tiny Farm - Entry point
-- Wires all game systems together: load, update, draw, input routing

local Camera = require("src.camera")
local Input = require("src.input")
local Tilemap = require("src.tilemap")
local Player = require("src.player")
local Particles = require("src.particles")
local DayCycle = require("src.day_cycle")
local HUD = require("src.hud")
local UIMenus = require("src.ui_menus")
local Tools = require("src.tools")
local Crops = require("src.crops")

-- Game state
local gameState = "playing"  -- "playing", "menu"
local camera, input, tilemap, player, particles, dayCycle, hud, uiMenus

function love.load()
    -- Pixel art rendering: disable smoothing
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Set up a pixel font style
    local font = love.graphics.newFont(14)
    love.graphics.setFont(font)
    
    -- Set random seed
    math.randomseed(os.time())
    
    -- Initialize systems
    input = Input.new()
    
    tilemap = Tilemap.new()
    tilemap:init()
    
    -- Player starts near the cot (tile 3,3)
    player = Player.new(3, 3)
    player:loadSprites()
    
    camera = Camera.new(Tilemap.WIDTH, Tilemap.HEIGHT,
        love.graphics.getWidth(), love.graphics.getHeight())
    
    particles = Particles.new()
    particles:init()
    
    dayCycle = DayCycle.new()
    
    hud = HUD.new()
    hud:init()
    
    uiMenus = UIMenus.new()
end

function love.update(dt)
    -- Update input
    input:update(dt, camera)
    
    -- Day cycle animation (runs regardless of game state)
    dayCycle:update(dt)
    
    -- HUD updates (toasts)
    hud:update(dt)
    
    if dayCycle:isActive() then
        -- During sleep transition, don't process gameplay
        return
    end
    
    if uiMenus:isOpen() then
        -- Menu input handling
        local result = uiMenus:handleInput(input, player)
        if result == "quit" then
            love.event.quit()
        end
        return
    end
    
    -- === Gameplay ===
    
    -- Pause menu
    if input.pausePressed then
        uiMenus:open("pause")
        return
    end
    
    -- Inventory
    if input.inventoryPressed then
        uiMenus:open("inventory", player)
        return
    end
    
    -- Player movement
    player:update(dt, input, tilemap)
    
    -- Action
    if input.actionPressed and not player.isActing then
        local action = player:tryAction(tilemap, particles)
        
        if action == "sleep" then
            -- Start day transition
            dayCycle:setDayDisplay(player.day + 1)
            dayCycle:startSleep(function()
                -- Overnight processing
                tilemap:advanceDay()
                player:processShippingBin()
                player:startNewDay()
            end)
        elseif action == "open_shop" then
            uiMenus:open("shop", player)
        elseif action then
            -- Check milestones after any action
            hud:checkMilestones(player)
        end
    end
    
    -- Seed type cycling (when Seeds tool is selected)
    local currentTool = Tools.LIST[player.selectedTool]
    if currentTool and currentTool.name == "Seeds" then
        -- Use inventory key to cycle seed type when Seeds tool is active
        -- Or auto-select the seed type that has stock
        if input.inventoryPressed then
            player:cycleSeedType()
        end
    end
    
    -- Update camera to follow player
    camera:update(dt, player.x, player.y)
    
    -- Update particles
    particles:update(dt)
end

function love.draw()
    -- === World rendering (in camera space) ===
    camera:apply()
    
    -- Draw tilemap (ground + crops + objects)
    tilemap:draw()
    
    -- Draw player
    player:draw()
    
    -- Draw particles
    particles:draw()
    
    camera:release()
    
    -- === UI rendering (in screen space) ===
    hud:draw(player, tilemap, camera, input)
    
    -- Menus
    uiMenus:draw(player)
    
    -- Day transition overlay (always on top)
    dayCycle:draw()
    
    -- Debug info (bottom-right, tiny)
    if false then  -- Set to true for debug
        love.graphics.setColor(1, 1, 1, 0.5)
        local tx, ty = player:getTilePos()
        local ftx, fty = player:getFacingTile()
        local info = string.format("Pos: %d,%d  Facing: %d,%d  Mode: %s", tx, ty, ftx, fty, input.mode)
        love.graphics.print(info, 5, love.graphics.getHeight() - 20)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- === Input Callbacks ===

function love.keypressed(key)
    input:onKeyPressed(key)
    
    -- Menu navigation
    if uiMenus:isOpen() then
        uiMenus:onKeyPressed(key)
    end
    
    -- Seed type cycling with number keys when Seeds tool is active
    local currentTool = Tools.LIST[player.selectedTool]
    if currentTool and currentTool.name == "Seeds" and not uiMenus:isOpen() then
        if key == "1" then player.selectedSeedType = "carrot"
        elseif key == "2" and Crops.isSeedUnlocked("tomato", player.harvestCounts) then 
            player.selectedSeedType = "tomato"
        elseif key == "3" and Crops.isSeedUnlocked("sunflower", player.harvestCounts) then 
            player.selectedSeedType = "sunflower"
        end
    end
end

function love.gamepadpressed(joystick, button)
    input:onGamepadPressed(joystick, button)
    
    if uiMenus:isOpen() then
        uiMenus:onGamepadPressed(button)
    end
end

function love.mousepressed(x, y, button)
    input:onMousePressed(x, y, button)
    
    -- Menu mouse handling
    if uiMenus:isOpen() and button == 1 then
        local result = uiMenus:onMouseClick(x, y, player)
        if result == "quit" then
            love.event.quit()
        end
    end
end

function love.wheelmoved(x, y)
    input:onWheelMoved(x, y)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    input:onTouchPressed(id, x, y)
end
