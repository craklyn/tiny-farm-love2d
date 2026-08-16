-- player.lua: Player entity with movement, facing, inventory, and action execution

local Tools        = require("src.tools")
local Crops        = require("src.crops")
local AudioManager = require("src.audio_manager")
local Pathfinding  = require("src.pathfinding")
local ActionRouter = require("src.action_router")

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
    self.weather = "sunny"
    
    self.spookRadius = 3 * TILE_SIZE
    
    -- Inventory
    self.selectedTool = 1  -- index into Tools.LIST
    self.selectedSeedType = "wheat"  -- which seed to plant when using Seeds tool
    self.wateringCanCharges = 8
    self.maxWateringCanCharges = 8
    
    self.seeds = {
        wheat = 5,
        tomato = 0
    }
    
    self.crops = {
        wheat = 0,
        tomato = 0
    }
    
    self.harvestCounts = {
        wheat = 0,
        tomato = 0
    }
    
    -- Shipping bin contents
    self.shippingBin = {
        wheat = 0,
        tomato = 0
    }
    
    -- Click-to-move (legacy pixel target, now replaced by path queue)
    self.moveTargetX = nil
    self.moveTargetY = nil

    self.path = {}
    -- Action to execute automatically on arrival at path destination
    -- { toolIndex, action, targetTX, targetTY, seedType }
    self.pendingAction = nil

    -- Tap-destination visual: { tx, ty, timer }
    self.tapIndicator = nil
    self.TAP_INDICATOR_DURATION = 0.6
    
    self.dragToolIndex = -1

    -- Spritesheet
    self.spriteImage = nil
    self.spriteQuads = {}  -- [direction][frame]
    
    return self
end

function Player:loadSprites()
    self.spriteImage = love.graphics.newImage("assets/sprites/sprout_lands/characters.png")
    self.spriteImage:setFilter("nearest", "nearest")
    
    local directions = { "down", "up", "left", "right" }
    for row, dir in ipairs(directions) do
        self.spriteQuads[dir] = {}
        for col = 0, 3 do
            self.spriteQuads[dir][col] = love.graphics.newQuad(
                col * 48, (row - 1) * 48,
                48, 48,
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
-- @param dt      number  delta time
-- @param input   Input   input state
-- @param tilemap Tilemap for collision & pathfinding
function Player:update(dt, input, tilemap)
    -- ── Tap-indicator timer ───────────────────────────────────────────────
    if self.tapIndicator then
        self.tapIndicator.timer = self.tapIndicator.timer - dt
        if self.tapIndicator.timer <= 0 then
            self.tapIndicator = nil
        end
    end

    -- ── Action animation lock ─────────────────────────────────────────────
    if self.isActing then
        self.actionTimer = self.actionTimer - dt
        if self.actionTimer <= 0 then
            self.isActing = false
        end
        return  -- Can't move during action
    end

    local dx, dy = 0, 0

    -- ── Touch/mouse tap → pathfind ────────────────────────────────────────
    local targetTX, targetTY = nil, nil
    local isDrag = false
    local isNewTap = false

    if input.mode == "mouse" then
        if input.mouseClicked and input.clickTileX and input.clickTileY then
            targetTX, targetTY = input.clickTileX, input.clickTileY
            isNewTap = true
        elseif input.swipeActive and input._swipeMoved and input.swipeTileX and input.swipeTileY then
            targetTX, targetTY = input.swipeTileX, input.swipeTileY
            isDrag = true
        end
    end

    if targetTX and targetTY then
        local ptx, pty = self:getTilePos()
        
        if isNewTap then
            self.path = {}
            self.pendingAction = nil
            self.tapIndicator = nil
        end
        
        local dragIntent = isDrag and self.dragToolIndex or nil
        local resolved = ActionRouter.resolve(tilemap, self, targetTX, targetTY, ptx, pty, isDrag, dragIntent)

        if isNewTap then
            if resolved then
                self.dragToolIndex = resolved.toolIndex
            else
                self.dragToolIndex = -1
            end
        end

        local goalTX, goalTY = targetTX, targetTY
        local newPath = Pathfinding.findPath(tilemap, ptx, pty, goalTX, goalTY)
        if newPath then
            self.path = newPath
            local finalStep = newPath[#newPath]
            local indTX = finalStep and finalStep.tx or targetTX
            local indTY = finalStep and finalStep.ty or targetTY
            
            local r, g, b = ActionRouter.getCursorColor(tilemap, self, targetTX, targetTY)
            self.tapIndicator = { tx = indTX, ty = indTY, timer = self.TAP_INDICATOR_DURATION, r = r, g = g, b = b }

            if resolved then
                if #newPath == 0 then
                    local dist = math.abs(ptx - targetTX) + math.abs(pty - targetTY)
                    if dist <= 1 then
                        local pa = {
                            toolIndex = resolved.toolIndex,
                            action    = resolved.action,
                            targetTX  = resolved.targetTX,
                            targetTY  = resolved.targetTY,
                            seedType  = resolved.seedType,
                        }
                        local faceDX = pa.targetTX - ptx
                        local faceDY = pa.targetTY - pty
                        if faceDX ~= 0 or faceDY ~= 0 then
                            if math.abs(faceDX) >= math.abs(faceDY) then
                                self.facing = faceDX > 0 and "right" or "left"
                            else
                                self.facing = faceDY > 0 and "down" or "up"
                            end
                        end
                        self:_executeResolvedAction(pa, tilemap, nil)
                    end
                    self.pendingAction = nil
                else
                    self.pendingAction = {
                        toolIndex = resolved.toolIndex,
                        action    = resolved.action,
                        targetTX  = resolved.targetTX,
                        targetTY  = resolved.targetTY,
                        seedType  = resolved.seedType,
                    }
                end
            else
                self.pendingAction = nil
            end
        else
            self.path = {}
            self.pendingAction = nil
            self.tapIndicator = nil
        end
    end

    -- ── Keyboard / gamepad movement (cancels path) ────────────────────────
    if input.moveX ~= 0 or input.moveY ~= 0 then
        dx = input.moveX
        dy = input.moveY
        self.path = {}
        self.pendingAction = nil
        self.moveTargetX = nil
        self.moveTargetY = nil
    elseif #self.path > 0 then
        -- ── Follow waypoint path ──────────────────────────────────────────
        local wp = self.path[1]
        local wpWorldX = (wp.tx - 1) * TILE_SIZE + TILE_SIZE / 2
        local wpWorldY = (wp.ty - 1) * TILE_SIZE + TILE_SIZE / 2
        local tdx = wpWorldX - self.x
        local tdy = wpWorldY - self.y
        local dist = math.sqrt(tdx * tdx + tdy * tdy)

        if dist < 2 then
            -- Arrived at this waypoint, move to next
            table.remove(self.path, 1)
            if #self.path == 0 then
                -- Path finished — execute pending action if any
                if self.pendingAction then
                    local pa = self.pendingAction
                    self.pendingAction = nil
                    -- Face the target tile
                    local myTX, myTY = self:getTilePos()
                    local faceDX = pa.targetTX - myTX
                    local faceDY = pa.targetTY - myTY
                    if math.abs(faceDX) >= math.abs(faceDY) then
                        self.facing = faceDX > 0 and "right" or "left"
                    else
                        self.facing = faceDY > 0 and "down" or "up"
                    end
                    -- Trigger the action
                    self:_executeResolvedAction(pa, tilemap, nil)
                end
            end
        else
            dx = tdx / dist
            dy = tdy / dist
        end
    elseif self.moveTargetX and self.moveTargetY then
        -- Legacy pixel target (kept for gamepad compatibility)
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

    -- ── Apply movement ────────────────────────────────────────────────────
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
        
        -- Tile collision check
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
            self.walkFrame = (self.walkFrame + 1) % 4
        end
    else
        self.walkFrame = 0
        self.walkTimer = 0
    end
    
    -- ── Tool cycling (keyboard/gamepad only) ──────────────────────────────
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
    
    -- Scarecrow: collect it back into inventory
    if obj == "scarecrow" then
        self.seeds["scarecrow"] = (self.seeds["scarecrow"] or 0) + 1
        tilemap.objects[ptx][pty] = nil
        AudioManager.playSfx("harvest")
        return "collect"
    elseif adjObj == "scarecrow" then
        self.seeds["scarecrow"] = (self.seeds["scarecrow"] or 0) + 1
        tilemap.objects[tx][ty] = nil
        AudioManager.playSfx("harvest")
        return "collect"
    end
    
    -- Regular tile action
    local tile = tilemap:getTile(tx, ty)
    if not tile then return nil end
    
    local action = Tools.getAction(self.selectedTool, tile.state)
    if not action then return nil end
    
    local cost = Tools.getEnergyCost(action)
    if self.energy <= 0 then return nil end
    
    -- Special checks
    if action == "water" and self.wateringCanCharges <= 0 then
        return nil
    end
    if action == "plant" and (not self.seeds[self.selectedSeedType] or self.seeds[self.selectedSeedType] <= 0) then
        return nil
    end
    
    -- Execute action
    self.energy = math.max(0, self.energy - cost)
    self.isActing = true
    self.actionTimer = self.ACTION_DURATION
    
    if action == "clear_weed" or action == "clear_log" or action == "clear_rock" then
        tilemap:setTileState(tx, ty, "cleared")
        if particles then particles:emit("chop", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
        AudioManager.playSfx("till")
    elseif action == "till" then
        tilemap:setTileState(tx, ty, "tilled")
        if particles then particles:emit("dirt", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
        AudioManager.playSfx("till")
    elseif action == "plant" then
        local def = Crops.TYPES[self.selectedSeedType]
        if def and def.isObject then
            tilemap.objects[ty][tx] = self.selectedSeedType
        else
            tilemap:setTileState(tx, ty, "seeded", self.selectedSeedType)
        end
        self.seeds[self.selectedSeedType] = self.seeds[self.selectedSeedType] - 1
    elseif action == "water" then
        tilemap:waterTile(tx, ty)
        self.wateringCanCharges = self.wateringCanCharges - 1
        if particles then particles:emit("water", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
        AudioManager.playSfx("water")
    elseif action == "harvest" then
        local cropType = tile.cropType
        if cropType then
            self.crops[cropType] = (self.crops[cropType] or 0) + 1
            self.harvestCounts[cropType] = (self.harvestCounts[cropType] or 0) + 1
            tilemap:setTileState(tx, ty, "cleared")
            if particles then particles:emit("harvest", (tx - 1) * TILE_SIZE + 8, (ty - 1) * TILE_SIZE + 8) end
            AudioManager.playSfx("harvest")
        end
    end
    
    return action
end

--- Execute a pre-resolved action (called when player arrives via pathfinding).
-- @param pa         table   pendingAction table from ActionRouter
-- @param tilemap    Tilemap
-- @param particles  Particles|nil
function Player:_executeResolvedAction(pa, tilemap, particles)
    local action = pa.action
    local tx, ty = pa.targetTX, pa.targetTY

    -- Special object interactions
    if action == "sleep" then
        -- Signal to main.lua via a queued result
        self._queuedResult = "sleep"
        return
    end
    if action == "collect" then
        if tilemap.objects[ty] and tilemap.objects[ty][tx] == "egg" then
            tilemap.objects[ty][tx] = nil
            self.crops["egg"] = (self.crops["egg"] or 0) + 1
            AudioManager.playSfx("harvest")
        elseif tilemap.objects[ty] and tilemap.objects[ty][tx] == "scarecrow" then
            tilemap.objects[ty][tx] = nil
            self.seeds["scarecrow"] = (self.seeds["scarecrow"] or 0) + 1
            AudioManager.playSfx("harvest")
        end
        return
    end
    if action == "open_shop" then
        self._queuedResult = "open_shop"
        return
    end
    if action == "sell" then
        self:_doSell()
        return
    end
    if action == "refill" then
        self:_doRefill()
        return
    end

    -- Tile-based actions
    local tile = tilemap:getTile(tx, ty)
    if not tile then return end

    local cost = Tools.getEnergyCost(action)
    if self.energy <= 0 then return end

    if action == "water" and self.wateringCanCharges <= 0 then return end

    local seedType = pa.seedType or self.selectedSeedType
    if action == "plant" and (not self.seeds[seedType] or self.seeds[seedType] <= 0) then return end

    -- Equip tool, deduct energy & play animation lock
    if pa.toolIndex then
        self.selectedTool = pa.toolIndex
    end
    self.energy = math.max(0, self.energy - cost)
    self.isActing = true
    self.actionTimer = self.ACTION_DURATION

    if action == "clear_weed" or action == "clear_log" or action == "clear_rock" then
        tilemap:setTileState(tx, ty, "cleared")
        if particles then particles:emit("chop", (tx-1)*TILE_SIZE+8, (ty-1)*TILE_SIZE+8) end
        AudioManager.playSfx("till")
    elseif action == "till" then
        tilemap:setTileState(tx, ty, "tilled")
        if particles then particles:emit("dirt", (tx-1)*TILE_SIZE+8, (ty-1)*TILE_SIZE+8) end
        AudioManager.playSfx("till")
    elseif action == "plant" then
        local def = Crops.TYPES[seedType]
        if def and def.isObject then
            if not tilemap.objects[ty][tx] then
                tilemap.objects[ty][tx] = seedType
                self.seeds[seedType] = self.seeds[seedType] - 1
            end
        else
            tilemap:setTileState(tx, ty, "seeded", seedType)
            self.seeds[seedType] = self.seeds[seedType] - 1
        end
    elseif action == "water" then
        tilemap:waterTile(tx, ty)
        self.wateringCanCharges = self.wateringCanCharges - 1
        if particles then particles:emit("water", (tx-1)*TILE_SIZE+8, (ty-1)*TILE_SIZE+8) end
        AudioManager.playSfx("water")
    elseif action == "harvest" then
        local cropType = tile.cropType
        if cropType then
            self.crops[cropType] = (self.crops[cropType] or 0) + 1
            self.harvestCounts[cropType] = (self.harvestCounts[cropType] or 0) + 1
            tilemap:setTileState(tx, ty, "cleared")
            if particles then particles:emit("harvest", (tx-1)*TILE_SIZE+8, (ty-1)*TILE_SIZE+8) end
            AudioManager.playSfx("harvest")
        end
    end
end

function Player:_doSell()
    local AudioManager = require("src.audio_manager")
    local soldAnything = false
    local totalEarned = 0
    for cropType, count in pairs(self.crops) do
        if count > 0 then
            local def = Crops.TYPES[cropType]
            if def then
                totalEarned = totalEarned + count * (def.sellPrice or 5)
                self.harvestCounts[cropType] = (self.harvestCounts[cropType] or 0) + count
            end
            self.crops[cropType] = 0
            soldAnything = true
        end
    end
    
    if soldAnything then
        self.gold = self.gold + totalEarned
        AudioManager.playSfx("harvest")
        return "sell"
    end
    return nil
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
    if math.random() < 0.2 then
        self.weather = "rainy"
    else
        self.weather = "sunny"
    end
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
        local def = Crops.TYPES[seedType]
        -- Only cycle to crops that are plantable seeds
        if def and def.seedPrice then
            if Crops.isSeedUnlocked(seedType, self.harvestCounts) and (self.seeds[seedType] or 0) > 0 then
                self.selectedSeedType = seedType
                return
            end
        end
    end
end

--- Queue the player for Y-sorted rendering.
-- Also queues the tap-destination indicator if active.
function Player:queueRender(renderQueue)
    -- Tap indicator: pulsing green diamond at destination
    if self.tapIndicator then
        local ind = self.tapIndicator
        local progress = 1 - (ind.timer / self.TAP_INDICATOR_DURATION)
        local alpha = 0.9 - progress * 0.7
        local scale = 0.5 + progress * 0.5
        local wx = (ind.tx - 1) * TILE_SIZE + TILE_SIZE / 2
        local wy = (ind.ty - 1) * TILE_SIZE + TILE_SIZE / 2
        table.insert(renderQueue, {
            y = wy - 100,  -- Always below everything
            draw = function()
                love.graphics.setColor(ind.r or 0.3, ind.g or 1, ind.b or 0.4, alpha)
                love.graphics.push()
                love.graphics.translate(wx, wy)
                love.graphics.rotate(math.pi / 4)
                local s = 5 * scale
                love.graphics.rectangle("fill", -s, -s, s * 2, s * 2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.pop()
            end
        })
    end

    if not self.spriteImage then return end

    local frame = self.walkFrame
    if self.isActing then
        frame = 3  -- Action/swing frame
    end
    
    local quad = self.spriteQuads[self.facing]
    if quad and quad[frame] then
        table.insert(renderQueue, {
            y = self.y,
            draw = function()
                -- Draw 48x48 sprite centered. Offset by -24, -32 so feet align with TILE_SIZE center
                love.graphics.draw(
                    self.spriteImage, quad[frame],
                    self.x - 24, self.y - 32
                )
            end
        })
    end
end

return Player
