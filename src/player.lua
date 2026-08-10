-- player.lua: Player entity with movement, facing, inventory, and action execution

local Tools = require("src.tools")
local Crops = require("src.crops")

local Player = {}
Player.__index = Player

local TILE_SIZE = 16
local MOVE_SPEED = 3 * TILE_SIZE  -- 3 tiles per second in world pixels

function Player.new(startTX, startTY)
    local self = setmetatable({}, Player)
    -- Position in world pixels (center of tile)
    self.x = (startTX - 1) * TILE_SIZE + TILE_SIZE / 2
    self.y = (startTY - 1) * TILE_SIZE + TILE_SIZE / 2
    
    -- Facing direction: "down", "up", "left", "right"
    self.facing = "down"
    
    -- Animation
    self.walkFrame = 0     -- 0, 1, 2 (idle, walk1, walk2)
    self.walkTimer = 0
    self.isMoving = false
    self.isActing = false
    self.actionTimer = 0
    self.ACTION_DURATION = 0.35  -- seconds of action animation lock
    
    -- Stats
    self.energy = 20
    self.maxEnergy = 20
    self.gold = 0
    self.day = 1
    
    -- Inventory
    self.selectedTool = 1  -- index into Tools.LIST
    self.selectedSeedType = "carrot"  -- which seed to plant when using Seeds tool
    self.wateringCanCharges = 8
    self.maxWateringCanCharges = 8
    
    self.seeds = {
        carrot = 5,
        tomato = 0,
        sunflower = 0,
    }
    
    self.crops = {
        carrot = 0,
        tomato = 0,
        sunflower = 0,
    }
    
    self.harvestCounts = {
        carrot = 0,
        tomato = 0,
        sunflower = 0,
    }
    
    -- Shipping bin contents
    self.shippingBin = {
        carrot = 0,
        tomato = 0,
        sunflower = 0,
    }
    
    -- Click-to-move
    self.moveTargetX = nil
    self.moveTargetY = nil
    
    -- Spritesheet
    self.spriteImage = nil
    self.spriteQuads = {}  -- [direction][frame]
    
    return self
end

function Player:loadSprites()
    self.spriteImage = love.graphics.newImage("assets/sprites/player.png")
    self.spriteImage:setFilter("nearest", "nearest")
    
    local directions = { "down", "up", "left", "right" }
    for row, dir in ipairs(directions) do
        self.spriteQuads[dir] = {}
        for col = 0, 3 do
            self.spriteQuads[dir][col] = love.graphics.newQuad(
                col * TILE_SIZE, (row - 1) * TILE_SIZE,
                TILE_SIZE, TILE_SIZE,
                self.spriteImage:getDimensions()
            )
        end
    end
end

--- Get the tile coordinates the player is currently on.
-- @return number, number: tx, ty (1-indexed)
function Player:getTilePos()
    local tx = math.floor(self.x / TILE_SIZE) + 1
    local ty = math.floor(self.y / TILE_SIZE) + 1
    return tx, ty
end

--- Get the tile coordinates the player is facing.
-- @return number, number: tx, ty (1-indexed)
function Player:getFacingTile()
    local tx, ty = self:getTilePos()
    if self.facing == "up" then ty = ty - 1
    elseif self.facing == "down" then ty = ty + 1
    elseif self.facing == "left" then tx = tx - 1
    elseif self.facing == "right" then tx = tx + 1
    end
    return tx, ty
end

--- Update player movement and animation.
-- @param dt number: delta time
-- @param input Input: input state
-- @param tilemap Tilemap: for collision checking
function Player:update(dt, input, tilemap)
    -- Action animation lock
    if self.isActing then
        self.actionTimer = self.actionTimer - dt
        if self.actionTimer <= 0 then
            self.isActing = false
        end
        return  -- Can't move during action
    end
    
    local dx, dy = 0, 0
    
    -- Check for click-to-move
    if input.mode == "mouse" and input.mouseClicked then
        -- Check if click is on an adjacent tile (perform action) or far tile (move toward it)
        local ptx, pty = self:getTilePos()
        local ctx, cty = input.clickTileX, input.clickTileY
        if ctx and cty then
            local adx = math.abs(ctx - ptx)
            local ady = math.abs(cty - pty)
            if adx <= 1 and ady <= 1 and not (adx == 0 and ady == 0) then
                -- Adjacent tile: face it and try action
                if ctx > ptx then self.facing = "right"
                elseif ctx < ptx then self.facing = "left"
                elseif cty > pty then self.facing = "down"
                elseif cty < pty then self.facing = "up"
                end
                input.actionPressed = true
                self.moveTargetX = nil
                self.moveTargetY = nil
            else
                -- Far tile: set move target
                self.moveTargetX = (ctx - 1) * TILE_SIZE + TILE_SIZE / 2
                self.moveTargetY = (cty - 1) * TILE_SIZE + TILE_SIZE / 2
            end
        end
    end
    
    -- Movement from keyboard/gamepad
    if input.moveX ~= 0 or input.moveY ~= 0 then
        dx = input.moveX
        dy = input.moveY
        self.moveTargetX = nil
        self.moveTargetY = nil
    elseif self.moveTargetX and self.moveTargetY then
        -- Click-to-move: move toward target
        local tdx = self.moveTargetX - self.x
        local tdy = self.moveTargetY - self.y
        local dist = math.sqrt(tdx * tdx + tdy * tdy)
        if dist < 2 then
            self.moveTargetX = nil
            self.moveTargetY = nil
        else
            dx = tdx / dist
            dy = tdy / dist
        end
    end
    
    -- Apply movement
    self.isMoving = (dx ~= 0 or dy ~= 0)
    
    if self.isMoving then
        -- Normalize diagonal movement
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dx = dx / len
            dy = dy / len
        end
        
        -- Update facing direction (prefer the axis with more movement)
        if math.abs(dx) > math.abs(dy) then
            self.facing = dx > 0 and "right" or "left"
        elseif dy ~= 0 then
            self.facing = dy > 0 and "down" or "up"
        end
        
        -- Calculate new position
        local newX = self.x + dx * MOVE_SPEED * dt
        local newY = self.y + dy * MOVE_SPEED * dt
        
        -- Tile collision check (check target tile)
        local newTX = math.floor(newX / TILE_SIZE) + 1
        local newTY = math.floor(newY / TILE_SIZE) + 1
        local curTX = math.floor(self.x / TILE_SIZE) + 1
        local curTY = math.floor(self.y / TILE_SIZE) + 1
        
        -- Try X movement
        if newTX ~= curTX then
            if tilemap:isWalkable(newTX, curTY) then
                self.x = newX
            end
        else
            self.x = newX
        end
        
        -- Try Y movement
        if newTY ~= curTY then
            if tilemap:isWalkable(curTX, newTY) then
                self.y = newY
            end
        else
            self.y = newY
        end
        
        -- Walk animation
        self.walkTimer = self.walkTimer + dt
        if self.walkTimer >= 0.15 then
            self.walkTimer = 0
            self.walkFrame = (self.walkFrame % 2) + 1  -- alternate between 1 and 2
        end
    else
        self.walkFrame = 0
        self.walkTimer = 0
    end
    
    -- Tool cycling
    if input.toolNext then
        self.selectedTool = (self.selectedTool % #Tools.LIST) + 1
    end
    if input.toolPrev then
        self.selectedTool = ((self.selectedTool - 2) % #Tools.LIST) + 1
    end
end

--- Try to perform the current tool's action on the facing tile.
-- @param tilemap Tilemap
-- @param particles Particles: for visual effects
-- @return string|nil: action performed, or nil
function Player:tryAction(tilemap, particles)
    if self.isActing then return nil end
    
    local tx, ty = self:getFacingTile()
    
    -- Check for special objects first
    local ptx, pty = self:getTilePos()
    local obj = tilemap:getObject(ptx, pty)
    
    -- Check adjacent tile for objects too
    local adjObj = tilemap:getObject(tx, ty)
    
    -- Shipping bin: sell crops
    if obj == "shipping_bin" or adjObj == "shipping_bin" then
        return self:_doSell()
    end
    
    -- Well: refill watering can
    if obj == "well" or adjObj == "well" then
        return self:_doRefill()
    end
    
    -- Seed box: opens shop (handled by main.lua state)
    if obj == "seed_box" or adjObj == "seed_box" then
        return "open_shop"
    end
    
    -- Cot: sleep (handled by main.lua state)
    if obj == "cot" or adjObj == "cot" then
        return "sleep"
    end
    
    -- Regular tile action
    local tile = tilemap:getTile(tx, ty)
    if not tile then return nil end
    
    local action = Tools.getAction(self.selectedTool, tile.state)
    if not action then return nil end
    
    local cost = Tools.getEnergyCost(action)
    if self.energy < cost then return nil end
    
    -- Special checks
    if action == "water" and self.wateringCanCharges <= 0 then
        return nil
    end
    if action == "plant" and self.seeds[self.selectedSeedType] <= 0 then
        return nil
    end
    
    -- Execute action
    self.energy = self.energy - cost
    self.isActing = true
    self.actionTimer = self.ACTION_DURATION
    
    if action == "clear_weed" or action == "clear_log" or action == "clear_rock" then
        tilemap:setTileState(tx, ty, "cleared")
        if particles then particles:emit("chop", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
    elseif action == "till" then
        tilemap:setTileState(tx, ty, "tilled")
        if particles then particles:emit("dirt", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
    elseif action == "plant" then
        tilemap:setTileState(tx, ty, "seeded", self.selectedSeedType)
        self.seeds[self.selectedSeedType] = self.seeds[self.selectedSeedType] - 1
    elseif action == "water" then
        tilemap:waterTile(tx, ty)
        self.wateringCanCharges = self.wateringCanCharges - 1
        if particles then particles:emit("water", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
    elseif action == "harvest" then
        local cropType = tile.cropType
        if cropType then
            self.crops[cropType] = (self.crops[cropType] or 0) + 1
            self.harvestCounts[cropType] = (self.harvestCounts[cropType] or 0) + 1
            tilemap:setTileState(tx, ty, "cleared")
            if particles then particles:emit("harvest", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
        end
    end
    
    return action
end

function Player:_doSell()
    local soldAnything = false
    for cropType, count in pairs(self.crops) do
        if count > 0 then
            self.shippingBin[cropType] = (self.shippingBin[cropType] or 0) + count
            self.crops[cropType] = 0
            soldAnything = true
        end
    end
    return soldAnything and "sell" or nil
end

function Player:_doRefill()
    if self.wateringCanCharges < self.maxWateringCanCharges then
        self.wateringCanCharges = self.maxWateringCanCharges
        return "refill"
    end
    return nil
end

--- Process the shipping bin overnight (convert to gold).
function Player:processShippingBin()
    for cropType, count in pairs(self.shippingBin) do
        local def = Crops.TYPES[cropType]
        if def and count > 0 then
            self.gold = self.gold + count * def.sellPrice
        end
        self.shippingBin[cropType] = 0
    end
end

--- Reset energy and watering can for a new day.
function Player:startNewDay()
    self.energy = self.maxEnergy
    self.wateringCanCharges = self.maxWateringCanCharges
    self.day = self.day + 1
end

--- Buy a seed from the shop.
-- @param seedType string
-- @return boolean: true if purchase succeeded
function Player:buySeed(seedType)
    local def = Crops.TYPES[seedType]
    if not def then return false end
    if self.gold < def.seedPrice then return false end
    if not Crops.isSeedUnlocked(seedType, self.harvestCounts) then return false end
    
    self.gold = self.gold - def.seedPrice
    self.seeds[seedType] = (self.seeds[seedType] or 0) + 1
    return true
end

--- Cycle the selected seed type (for the Seeds tool).
function Player:cycleSeedType()
    local currentIdx = 1
    for i, name in ipairs(Crops.ORDER) do
        if name == self.selectedSeedType then
            currentIdx = i
            break
        end
    end
    -- Find next unlocked seed type
    for offset = 1, #Crops.ORDER do
        local idx = ((currentIdx - 1 + offset) % #Crops.ORDER) + 1
        local seedType = Crops.ORDER[idx]
        if Crops.isSeedUnlocked(seedType, self.harvestCounts) and self.seeds[seedType] > 0 then
            self.selectedSeedType = seedType
            return
        end
    end
end

--- Draw the player sprite.
function Player:draw()
    if not self.spriteImage then return end
    
    local frame = self.walkFrame
    if self.isActing then
        frame = 3  -- Action/swing frame
    end
    
    local quad = self.spriteQuads[self.facing]
    if quad and quad[frame] then
        love.graphics.draw(
            self.spriteImage, quad[frame],
            self.x - TILE_SIZE / 2, self.y - TILE_SIZE / 2
        )
    end
end

return Player
