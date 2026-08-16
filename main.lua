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
local Entities = require("src.entities")
local Chicken = require("src.chicken")
local Pathfinding = require("src.pathfinding")

local AudioManager = require("src.audio_manager")
local TitleScreen  = require("src.title_screen")

local Crow = require("src.crow")

-- Game state
local gameState = "title"  -- "title", "playing"
local camera, input, tilemap, player, particles, dayCycle, hud, uiMenus

local DEBUG_MODE = true

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
    
    Entities.init()
    local reachable = Pathfinding.getReachableTiles(tilemap, 3, 3)
    if #reachable > 0 then
        local rt = reachable[love.math.random(1, #reachable)]
        Entities.add(Chicken.new(rt.x, rt.y))
    else
        Entities.add(Chicken.new(3, 4))
    end
    
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
    
    if DEBUG_MODE then
        player.gold = 9999
        player.seeds.scarecrow = 5
        
        -- Plant a row of wheat and tomato at every growth stage
        local startX = 12
        local startY = 4
        
        -- Clear area
        for y = startY, startY + 3 do
            for x = startX, startX + 7 do
                tilemap:setTileState(x, y, "tilled")
            end
        end
        
        -- Row 1: Wheat
        for i = 0, 5 do
            tilemap:setTileState(startX + i, startY, "seeded", "wheat")
            tilemap:getTile(startX + i, startY).growthStage = i
            if i >= Crops.TYPES["wheat"].daysToGrow then
                tilemap:getTile(startX + i, startY).state = "ready"
            elseif i > 0 then
                tilemap:getTile(startX + i, startY).state = "growing"
            end
        end
        
        -- Row 2: Tomato
        for i = 0, 5 do
            tilemap:setTileState(startX + i, startY + 2, "seeded", "tomato")
            tilemap:getTile(startX + i, startY + 2).growthStage = i
            if i >= Crops.TYPES["tomato"].daysToGrow then
                tilemap:getTile(startX + i, startY + 2).state = "ready"
            elseif i > 0 then
                tilemap:getTile(startX + i, startY + 2).state = "growing"
            end
        end
        
        -- Skip title screen for quick testing
        gameState = "playing"
    end
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
        uiMenus:update(dt)
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
    
    Entities.update(dt, tilemap, player)

    -- === Check for queued results from pathfinding-triggered actions ===
    if player._queuedResult then
        local result = player._queuedResult
        player._queuedResult = nil
        if result == "sleep" then
            dayCycle:setDayDisplay(player.day + 1)
            dayCycle:startSleep(function()
                player:startNewDay()
                tilemap:advanceDay(player.weather)
                Entities.onNewDay(tilemap)
                player:processShippingBin()
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
                player:startNewDay()
                tilemap:advanceDay(player.weather)
                Entities.onNewDay(tilemap)
                player:processShippingBin()
            end)
        elseif action == "open_shop" then
            uiMenus:open("shop", player)
        elseif action then
            -- Check milestones after any action
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
    particles:update(dt, player, camera)
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
    Entities.queueRender(renderQueue)
    
    -- Assign insert order to guarantee stable sorting and prevent Z-fighting
    for i, entity in ipairs(renderQueue) do
        entity.insertOrder = i
    end
    
    -- Sort entities by Y coordinate, falling back to insertOrder
    table.sort(renderQueue, function(a, b)
        if a.y == b.y then
            return a.insertOrder < b.insertOrder
        end
        return a.y < b.y
    end)
    
    -- Draw sorted entities
    for _, entity in ipairs(renderQueue) do
        entity.draw()
    end
    
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
        if key == "1" then player.selectedSeedType = "wheat"
        elseif key == "2" and Crops.isSeedUnlocked("tomato", player.harvestCounts) then 
            player.selectedSeedType = "tomato"
        elseif key == "3" and Crops.isSeedUnlocked("scarecrow", player.harvestCounts) then 
            player.selectedSeedType = "scarecrow"
        end
    end
    
    -- Debug hotkeys
    if DEBUG_MODE and key == "c" then
        -- Spawn crow targeting a random crop
        local targets = {}
        for ty = 1, tilemap.HEIGHT do
            for tx = 1, tilemap.WIDTH do
                local tile = tilemap:getTile(tx, ty)
                if tile and (tile.state == "growing" or tile.state == "ready" or tile.state == "seeded") then
                    table.insert(targets, {tx = tx, ty = ty})
                end
            end
        end
        if #targets > 0 then
            local target = targets[math.random(1, #targets)]
            local startX, startY = -32, -32
            Entities.add(Crow.new(startX, startY, target.tx, target.ty))
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

function love.mousepressed(x, y, button, istouch, presses)
    if istouch then return end
    if gameState == "title" then
        local newState = TitleScreen.mousepressed(x, y, button)
        if newState == "playing" then
            gameState = "playing"
            input.hasClick = false
            input.swipeActive = false
        end
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
        local newState = TitleScreen.mousepressed(x, y, 1)
        if newState == "playing" then
            gameState = "playing"
            input.hasClick = false
            input.swipeActive = false
        end
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
