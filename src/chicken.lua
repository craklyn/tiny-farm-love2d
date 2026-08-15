local Chicken = {}
Chicken.__index = Chicken

local Pathfinding = require("src.pathfinding")

function Chicken.new(tx, ty)
    local self = setmetatable({}, Chicken)
    self.tx = tx
    self.ty = ty
    
    self.x = (tx - 1) * 16
    self.y = (ty - 1) * 16
    
    self.state = "idle"
    self.timer = math.random() * 2
    
    self.path = nil
    self.pathIndex = 1
    
    return self
end

function Chicken:update(dt, tilemap)
    if self.state == "idle" then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            local reachable = Pathfinding.getReachableTiles(tilemap, self.tx, self.ty)
            if #reachable > 0 then
                local target = reachable[math.random(1, #reachable)]
                self.path = Pathfinding.findPath(tilemap, self.tx, self.ty, target.x, target.y)
                if self.path and #self.path > 0 then
                    self.state = "moving"
                    self.pathIndex = 1
                else
                    self.timer = math.random(1, 3)
                end
            else
                self.timer = math.random(1, 3)
            end
        end
    elseif self.state == "moving" then
        if not self.path or self.pathIndex > #self.path then
            self.state = "idle"
            self.timer = math.random(2, 5)
            return
        end
        
        local target = self.path[self.pathIndex]
        local targetX = (target.tx - 1) * 16
        local targetY = (target.ty - 1) * 16
        
        local speed = 20 * dt
        local dx = targetX - self.x
        local dy = targetY - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist <= speed then
            self.x = targetX
            self.y = targetY
            self.tx = target.tx
            self.ty = target.ty
            self.pathIndex = self.pathIndex + 1
        else
            self.x = self.x + (dx/dist) * speed
            self.y = self.y + (dy/dist) * speed
        end
    end
end

function Chicken:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.x + 4, self.y + 4, 8, 8)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", self.x + 6, self.y + 2, 4, 2)
    love.graphics.setColor(1, 0.5, 0, 1)
    love.graphics.rectangle("fill", self.x + 6, self.y + 6, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
end

function Chicken:onNewDay(tilemap)
    -- Lay an egg (guaranteed for now so the player can find it)
    local tx, ty = self.tx, self.ty
    if not tilemap.objects[ty][tx] then
        tilemap.objects[ty][tx] = "egg"
    end
end

return Chicken
