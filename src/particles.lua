-- particles.lua: Particle effect definitions using love.graphics.newParticleSystem

local Particles = {}
Particles.__index = Particles

function Particles.new()
    local self = setmetatable({}, Particles)
    self.systems = {}     -- Active particle system instances
    self.templates = {}   -- Reusable particle system templates
    self.particleImage = nil
    return self
end

function Particles:init()
    local imgData = love.image.newImageData(2, 2)
    imgData:mapPixel(function() return 1, 1, 1, 1 end)
    self.particleImage = love.graphics.newImage(imgData)
    self.particleImage:setFilter("nearest", "nearest")
    
    -- Dirt burst (tilling)
    self.templates.dirt = function(x, y)
        local ps = love.graphics.newParticleSystem(self.particleImage, 20)
        ps:setParticleLifetime(0.3, 0.6)
        ps:setEmissionRate(0)
        ps:setSpeed(20, 50)
        ps:setSpread(math.pi * 2)
        ps:setLinearAcceleration(0, 30, 0, 60)
        ps:setColors(
            0.7, 0.5, 0.3, 1,    -- brown start
            0.55, 0.4, 0.2, 0    -- fade out
        )
        ps:setSizes(1.5, 0.5)
        ps:setPosition(x, y)
        ps:emit(12)
        return ps
    end
    
    -- Water splash (watering)
    self.templates.water = function(x, y)
        local ps = love.graphics.newParticleSystem(self.particleImage, 15)
        ps:setParticleLifetime(0.2, 0.5)
        ps:setEmissionRate(0)
        ps:setSpeed(15, 35)
        ps:setSpread(math.pi * 0.8)
        ps:setDirection(-math.pi / 2)  -- upward
        ps:setLinearAcceleration(0, 40, 0, 60)
        ps:setColors(
            0.4, 0.7, 0.9, 1,    -- light blue
            0.3, 0.6, 0.85, 0    -- fade
        )
        ps:setSizes(1.2, 0.3)
        ps:setPosition(x, y)
        ps:emit(10)
        return ps
    end
    
    -- Harvest sparkle
    self.templates.harvest = function(x, y)
        local ps = love.graphics.newParticleSystem(self.particleImage, 20)
        ps:setParticleLifetime(0.4, 0.8)
        ps:setEmissionRate(0)
        ps:setSpeed(10, 30)
        ps:setSpread(math.pi * 2)
        ps:setLinearAcceleration(0, -10, 0, -20)  -- float up
        ps:setColors(
            1, 0.9, 0.3, 1,      -- golden yellow
            1, 0.8, 0.2, 0       -- fade
        )
        ps:setSizes(2, 0.5)
        ps:setSpin(0, math.pi * 2)
        ps:setPosition(x, y)
        ps:emit(15)
        return ps
    end
    
    -- Chop/clear debris
    self.templates.chop = function(x, y)
        local ps = love.graphics.newParticleSystem(self.particleImage, 15)
        ps:setParticleLifetime(0.3, 0.5)
        ps:setEmissionRate(0)
        ps:setSpeed(25, 60)
        ps:setSpread(math.pi * 1.5)
        ps:setDirection(-math.pi / 2)
        ps:setLinearAcceleration(0, 50, 0, 80)
        ps:setColors(
            0.6, 0.45, 0.25, 1,  -- wood brown
            0.5, 0.35, 0.15, 0   -- fade
        )
        ps:setSizes(1.5, 0.8)
        ps:setPosition(x, y)
        ps:emit(10)
        return ps
    end
end

--- Emit a particle effect.
-- @param effectType string: "dirt", "water", "harvest", "chop"
-- @param x number: world X position
-- @param y number: world Y position
function Particles:emit(effectType, x, y)
    local template = self.templates[effectType]
    if template then
        local ps = template(x, y)
        table.insert(self.systems, ps)
    end
end

--- Update all active particle systems.
-- @param dt number
function Particles:update(dt)
    for i = #self.systems, 1, -1 do
        local ps = self.systems[i]
        ps:update(dt)
        -- Remove finished systems
        if ps:getCount() == 0 then
            table.remove(self.systems, i)
        end
    end
end

--- Draw all active particle systems.
function Particles:draw()
    for _, ps in ipairs(self.systems) do
        love.graphics.draw(ps)
    end
end

return Particles
