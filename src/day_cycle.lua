-- day_cycle.lua: Day transition with fade animation and overnight processing

local DayCycle = {}
DayCycle.__index = DayCycle

function DayCycle.new()
    local self = setmetatable({}, DayCycle)
    self.state = "idle"  -- "idle", "fading_out", "hold", "fading_in"
    self.alpha = 0       -- 0 = transparent, 1 = fully black
    self.timer = 0
    
    -- Phase durations
    self.FADE_OUT_TIME = 0.5
    self.HOLD_TIME = 0.5
    self.FADE_IN_TIME = 0.5
    
    -- Callback to execute during hold phase
    self.onNewDay = nil
    self._newDayFired = false
    
    return self
end

--- Start the sleep/day transition.
-- @param onNewDay function: callback to execute during hold (advance crops, process gold, etc.)
function DayCycle:startSleep(onNewDay)
    if self.state ~= "idle" then return end
    self.state = "fading_out"
    self.timer = 0
    self.alpha = 0
    self.onNewDay = onNewDay
    self._newDayFired = false
end

--- Check if a transition is currently active.
-- @return boolean
function DayCycle:isActive()
    return self.state ~= "idle"
end

--- Update the day cycle animation.
-- @param dt number
function DayCycle:update(dt)
    if self.state == "idle" then return end
    
    self.timer = self.timer + dt
    
    if self.state == "fading_out" then
        self.alpha = math.min(1, self.timer / self.FADE_OUT_TIME)
        if self.timer >= self.FADE_OUT_TIME then
            self.state = "hold"
            self.timer = 0
        end
    elseif self.state == "hold" then
        self.alpha = 1
        -- Fire new day callback once during hold
        if not self._newDayFired and self.onNewDay then
            self.onNewDay()
            self._newDayFired = true
        end
        if self.timer >= self.HOLD_TIME then
            self.state = "fading_in"
            self.timer = 0
        end
    elseif self.state == "fading_in" then
        self.alpha = 1 - math.min(1, self.timer / self.FADE_IN_TIME)
        if self.timer >= self.FADE_IN_TIME then
            self.state = "idle"
            self.alpha = 0
            self.onNewDay = nil
        end
    end
end

--- Draw the fade overlay (should be drawn LAST, on top of everything).
function DayCycle:draw()
    if self.alpha <= 0 then return end
    love.graphics.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw "Day X" text during hold phase
    if self.state == "hold" and self.alpha >= 0.9 then
        local font = love.graphics.getFont()
        local text = "Day " .. (self._dayDisplay or "?")
        local tw = font:getWidth(text)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, 
            love.graphics.getWidth() / 2 - tw / 2,
            love.graphics.getHeight() / 2 - font:getHeight() / 2
        )
    end
end

--- Set the day number for display during transition.
-- @param day number
function DayCycle:setDayDisplay(day)
    self._dayDisplay = day
end

return DayCycle
