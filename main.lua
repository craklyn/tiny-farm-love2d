-- main.lua: Tiny Farm - Entry point
-- Wires all game systems together: load, update, draw, input routing

local Camera       = require("src.camera")
local Input        = require("src.input")
local Tilemap      = require("src.tilemap")
local Player       = require("src.player")
local Particles    = require("src.particles")
local DayCycle     = require("src.day_cycle")
local HUD          = require("src.hud")
local UIMenus      = require("src.ui_menus")
local Tools        = require("src.tools")
local Crops        = require("src.crops")
local ActionRouter = require("src.action_router")

local AudioManager = require("src.audio_manager")
local TitleScreen  = require("src.title_screen")

-- Game state
local gameState = "title"  -- "title", "playing"
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
    
    AudioManager.init()
    TitleScreen.init()
end

function love.update(dt)
    if gameState == "title" then
        TitleScreen.update(dt)
        return
    end

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
    
    -- Player movement & path following
    player:update(dt, input, tilemap)

    -- === Check for queued results from pathfinding-triggered actions ===
    if player._queuedResult then
        local result = player._queuedResult
        player._queuedResult = nil
        if result == "sleep" then
            dayCycle:setDayDisplay(player.day + 1)
            dayCycle:startSleep(function()
                tilemap:advanceDay()
                player:processShippingBin()
                player:startNewDay()
            end)
        elseif result == "open_shop" then
            uiMenus:open("shop", player)
        end
    end

    -- === Keyboard/gamepad Action button ===
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

    -- === Swipe-chain: apply action to each new tile the finger enters ===
    if input.swipeActive and input._swipeMoved then
        local stx, sty = input.swipeTileX, input.swipeTileY
        local ptx, pty = player:getTilePos()
        local resolved = ActionRouter.resolve(tilemap, player, stx, sty, ptx, pty)
        -- Only chain-able actions (no sleep/shop/sell during swipe)
        local chainable = { water = true, plant = true, till = true, harvest = true,
                            clear_weed = true, clear_log = true, clear_rock = true }
        if resolved and chainable[resolved.action] then
            -- Immediately face the target tile (no pathfinding during swipe)
            local fdx = stx - ptx
            local fdy = sty - pty
            if math.abs(fdx) >= math.abs(fdy) then
                player.facing = fdx > 0 and "right" or "left"
            else
                player.facing = fdy > 0 and "down" or "up"
            end
            player:_executeResolvedAction(resolved, tilemap, particles)
            hud:checkMilestones(player)
        end
    end

    -- Seed type cycling when Seeds tool active (keyboard)
    local currentTool = Tools.LIST[player.selectedTool]
    if currentTool and currentTool.name == "Seeds" then
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
    if gameState == "title" then
        TitleScreen.draw()
        return
    end

    -- === World rendering (in camera space) ===
    camera:apply()
    
    -- Draw base tiles (grass, dirt)
    tilemap:drawBaseTiles()
    
    -- Y-Sort Render Queue for crops, objects, and player
    local renderQueue = {}
    tilemap:queueEntities(renderQueue)
    player:queueRender(renderQueue)
    
    -- Sort entities by Y coordinate
    table.sort(renderQueue, function(a, b)
        return a.y < b.y
    end)
    
    -- Draw sorted entities
    for _, entity in ipairs(renderQueue) do
        entity.draw()
    end
    
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
    if gameState == "title" then
        gameState = TitleScreen.keypressed(key)
        return
    end

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
    if gameState == "title" then
        -- Map gamepad buttons to generic keypress for title screen
        gameState = TitleScreen.keypressed("return")
        return
    end

    input:onGamepadPressed(joystick, button)
    
    if uiMenus:isOpen() then
        uiMenus:onGamepadPressed(button)
    end
end

function love.mousepressed(x, y, button)
    if gameState == "title" then
        gameState = TitleScreen.mousepressed(x, y, button)
        if gameState == "game" then input.hasClick = false end
        return
    end

    -- Seed pill tap: cycle seed type
    if button == 1 and hud.seedPillBounds then
        local b = hud.seedPillBounds
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            player:cycleSeedType()
            AudioManager.playSfx("click")
            return  -- Consume tap
        end
    end

    -- Menu mouse handling
    if uiMenus:isOpen() and button == 1 then
        local result = uiMenus:onMouseClick(x, y, player)
        if result == "quit" then
            love.event.quit()
        end
        return -- Consume the click
    end

    input:onMousePressed(x, y, button)
end

function love.wheelmoved(x, y)
    if gameState == "title" then return end
    input:onWheelMoved(x, y)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    if gameState == "title" then
        gameState = TitleScreen.mousepressed(x, y, 1)
        return
    end

    -- Seed pill tap
    if hud.seedPillBounds then
        local b = hud.seedPillBounds
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            player:cycleSeedType()
            AudioManager.playSfx("click")
            return
        end
    end

    -- Menu tap
    if uiMenus:isOpen() then
        local result = uiMenus:onMouseClick(x, y, player)
        if result == "quit" then love.event.quit() end
        return
    end

    input:onTouchPressed(id, x, y)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if gameState ~= "game" then return end
    if uiMenus:isOpen() then return end
    input:onTouchMoved(id, x, y, camera)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if gameState ~= "game" then return end
    input:onTouchReleased(id, x, y)
end
