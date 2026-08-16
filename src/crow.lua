local Crow = {}
Crow.__index = Crow

local TILE_SIZE = 16

function Crow.new(startX, startY, targetTX, targetTY)
    local self = setmetatable({}, Crow)
    self.x = startX
    self.y = startY
    self.targetTX = targetTX
    self.targetTY = targetTY
    
    self.state = "flying_in" -- flying_in, eating, flying_away
    self.timer = 0
    
    -- Visual animation
    self.flapTimer = 0
    self.flapState = 0
    
    return self
end

function Crow:update(dt, tilemap, player, entities)
    -- Animation
    self.flapTimer = self.flapTimer + dt
    if self.flapTimer > 0.1 then
        self.flapTimer = 0
        self.flapState = (self.flapState + 1) % 2
    end
    
    -- Spook logic
    local function isSpooked()
        -- Check if player is close
        local dx = player.x - self.x
        local dy = player.y - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < (player.spookRadius or 3 * TILE_SIZE) then
            return true
        end
        
        -- Check if any scarecrows are close
        local myTX = math.floor(self.x / TILE_SIZE) + 1
        local myTY = math.floor(self.y / TILE_SIZE) + 1
        if tilemap:isProtectedByScarecrow(myTX, myTY) then
            return true
        end
        
        -- Check if any entities have spookRadius and are close
        if entities and entities.list then
            for _, ent in ipairs(entities.list) do
                if ent ~= self and ent.spookRadius then
                    local edx = ent.x - self.x
                    local edy = ent.y - self.y
                    local edist = math.sqrt(edx*edx + edy*edy)
                    if edist < ent.spookRadius then
                        return true
                    end
                end
            end
        end
        
        return false
    end
    
    if self.state == "flying_in" then
        if isSpooked() then
            self.state = "flying_away"
            return
        end
        
        local targetX = (self.targetTX - 1) * TILE_SIZE + TILE_SIZE / 2
        local targetY = (self.targetTY - 1) * TILE_SIZE + TILE_SIZE / 2
        
        local speed = 60 * dt
        local dx = targetX - self.x
        local dy = targetY - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist <= speed then
            self.x = targetX
            self.y = targetY
            self.state = "eating"
            self.timer = 5.0 -- Takes 5 seconds to eat a crop
        else
            self.x = self.x + (dx/dist) * speed
            self.y = self.y + (dy/dist) * speed
        end
        
    elseif self.state == "eating" then
        if isSpooked() then
            self.state = "flying_away"
            return
        end
        
        self.timer = self.timer - dt
        if self.timer <= 0 then
            -- Destroy the crop
            local tile = tilemap:getTile(self.targetTX, self.targetTY)
            if tile and (tile.state == "growing" or tile.state == "ready" or tile.state == "seeded") then
                tilemap:setTileState(self.targetTX, self.targetTY, "tilled")
                -- Optional: spawn some particles or sound
                local AudioManager = require("src.audio_manager")
                AudioManager.playSfx("till")
            end
            self.state = "flying_away"
        end
        
    elseif self.state == "flying_away" then
        -- Fly straight up and left
        local speed = 80 * dt
        self.x = self.x - speed
        self.y = self.y - speed
        
        -- Kill if far off screen
        if self.x < -100 or self.y < -100 then
            self.dead = true
        end
    end
end

function Crow:draw()
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    
    -- Draw body
    love.graphics.rectangle("fill", self.x - 4, self.y - 4, 8, 8)
    
    -- Draw wings flapping
    if self.state == "flying_in" or self.state == "flying_away" then
        if self.flapState == 0 then
            -- Wings up
            love.graphics.rectangle("fill", self.x - 10, self.y - 8, 6, 4)
            love.graphics.rectangle("fill", self.x + 4, self.y - 8, 6, 4)
        else
            -- Wings down
            love.graphics.rectangle("fill", self.x - 10, self.y, 6, 4)
            love.graphics.rectangle("fill", self.x + 4, self.y, 6, 4)
        end
    end
    
    -- Draw beak
    love.graphics.setColor(0.9, 0.7, 0.1, 1)
    love.graphics.rectangle("fill", self.x - 2, self.y + 2, 4, 4)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Crow
