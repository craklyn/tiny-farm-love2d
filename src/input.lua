-- input.lua: Unified input abstraction for keyboard, gamepad, mouse, and touch

local Input = {}
Input.__index = Input

function Input.new()
    local self = setmetatable({}, Input)
    self.mode = "keyboard"  -- "keyboard", "gamepad", "mouse"
    
    -- Movement state
    self.moveX = 0
    self.moveY = 0
    
    -- Click-to-move target (for mouse/touch mode)
    self.moveTarget = nil  -- {tx, ty} tile coords or nil
    
    -- Button states (pressed this frame)
    self.actionPressed = false
    self.toolPrev = false
    self.toolNext = false
    self.inventoryPressed = false
    self.pausePressed = false
    
    -- Mouse state
    self.mouseScreenX = 0
    self.mouseScreenY = 0
    self.mouseClicked = false
    self.mouseRightClicked = false
    self.scrollDelta = 0

    -- Swipe/drag chain state (touch)
    self.swipeActive = false      -- true while a finger is held and dragging
    self.swipeTileX  = nil        -- current tile under dragging finger
    self.swipeTileY  = nil
    self._swipeMoved = false      -- set when finger moves to a new tile this frame
    self._swipeScreenX = nil
    self._swipeScreenY = nil
    self._touchReleased = false

    -- Gamepad
    self.joystick = nil
    self.deadzone = 0.3
    
    -- Frame event buffers (reset each frame)
    self._pressedKeys = {}
    self._pressedButtons = {}
    self._mouseClickPos = nil
    self._mouseRightClick = false
    self._scrollDelta = 0
    
    return self
end

--- Call from love.keypressed
function Input:onKeyPressed(key)
    self._pressedKeys[key] = true
    self.mode = "keyboard"
end

--- Call from love.gamepadpressed
function Input:onGamepadPressed(joystick, button)
    self.joystick = joystick
    self._pressedButtons[button] = true
    self.mode = "gamepad"
end

--- Call from love.mousepressed
function Input:onMousePressed(x, y, button)
    if button == 1 then
        self._mouseClickPos = { x = x, y = y }
    elseif button == 2 then
        self._mouseRightClick = true
    end
    self.mode = "mouse"
end

--- Call from love.wheelmoved
function Input:onWheelMoved(x, y)
    self._scrollDelta = self._scrollDelta + y
    self.mode = "mouse"
end

--- Call from love.touchpressed
function Input:onTouchPressed(id, x, y)
    self._mouseClickPos = { x = x, y = y }
    self.swipeActive   = false
    self._swipeScreenX = x
    self._swipeScreenY = y
    self.mode = "mouse"
end

--- Call from love.touchmoved
function Input:onTouchMoved(id, x, y, camera)
    self.mode = "mouse"
    local newTX, newTY
    if camera then
        newTX, newTY = camera:screenToTile(x, y)
    end
    -- Only flag a swipe-move when the finger crosses into a new tile
    if newTX and newTY and (newTX ~= self.swipeTileX or newTY ~= self.swipeTileY) then
        self.swipeActive   = true
        self.swipeTileX    = newTX
        self.swipeTileY    = newTY
        self._swipeScreenX = x
        self._swipeScreenY = y
        self._swipeMoved   = true
    end
end

--- Call from love.touchreleased
function Input:onTouchReleased(id, x, y)
    self.swipeActive   = false
    self.swipeTileX    = nil
    self.swipeTileY    = nil
    self._touchReleased = true
end

--- Update input state. Call once per frame at the start of love.update.
-- @param dt number
-- @param camera Camera: for screen-to-tile conversion
function Input:update(dt, camera)
    -- Reset per-frame states
    self.actionPressed = false
    self.toolPrev = false
    self.toolNext = false
    self.inventoryPressed = false
    self.pausePressed = false
    self.mouseClicked = false
    self.mouseRightClicked = false
    self.scrollDelta = 0
    self.moveX = 0
    self.moveY = 0
    self._swipeMoved    = false
    self._touchReleased = false
    
    -- === Keyboard ===
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        self.moveY = self.moveY - 1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        self.moveY = self.moveY + 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        self.moveX = self.moveX - 1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        self.moveX = self.moveX + 1
    end
    
    if self._pressedKeys["space"] or self._pressedKeys["z"] then
        self.actionPressed = true
    end
    if self._pressedKeys["q"] then self.toolPrev = true end
    if self._pressedKeys["e"] or self._pressedKeys["tab"] then self.toolNext = true end
    if self._pressedKeys["i"] then self.inventoryPressed = true end
    if self._pressedKeys["escape"] then self.pausePressed = true end
    
    -- === Gamepad ===
    if self.joystick and self.joystick:isConnected() then
        local lx = self.joystick:getGamepadAxis("leftx") or 0
        local ly = self.joystick:getGamepadAxis("lefty") or 0
        if math.abs(lx) > self.deadzone then
            self.moveX = self.moveX + (lx > 0 and 1 or -1)
        end
        if math.abs(ly) > self.deadzone then
            self.moveY = self.moveY + (ly > 0 and 1 or -1)
        end
        
        -- D-pad
        if self.joystick:isGamepadDown("dpleft") then self.moveX = self.moveX - 1 end
        if self.joystick:isGamepadDown("dpright") then self.moveX = self.moveX + 1 end
        if self.joystick:isGamepadDown("dpup") then self.moveY = self.moveY - 1 end
        if self.joystick:isGamepadDown("dpdown") then self.moveY = self.moveY + 1 end
        
        if self._pressedButtons["a"] then self.actionPressed = true end
        if self._pressedButtons["leftshoulder"] then self.toolPrev = true end
        if self._pressedButtons["rightshoulder"] then self.toolNext = true end
        if self._pressedButtons["y"] then self.inventoryPressed = true end
        if self._pressedButtons["start"] then self.pausePressed = true end
    end
    
    -- Detect newly connected gamepad
    if not self.joystick then
        local joysticks = love.joystick.getJoysticks()
        for _, j in ipairs(joysticks) do
            if j:isGamepad() then
                self.joystick = j
                break
            end
        end
    end
    
    -- === Mouse ===
    self.mouseScreenX, self.mouseScreenY = love.mouse.getPosition()
    
    if self._mouseClickPos then
        self.mouseClicked = true
        -- Convert click position to tile coordinates
        if camera then
            local tx, ty = camera:screenToTile(self._mouseClickPos.x, self._mouseClickPos.y)
            self.clickTileX = tx
            self.clickTileY = ty
        end
    end
    
    if self._mouseRightClick then
        self.mouseRightClicked = true
        self.toolNext = true  -- Right-click cycles tools
    end
    
    self.scrollDelta = self._scrollDelta
    if self._scrollDelta > 0 then
        self.toolNext = true
    elseif self._scrollDelta < 0 then
        self.toolPrev = true
    end
    
    -- Clamp movement to -1..1
    self.moveX = math.max(-1, math.min(1, self.moveX))
    self.moveY = math.max(-1, math.min(1, self.moveY))
    
    -- If keyboard/gamepad provides movement, cancel any mouse move target
    if self.moveX ~= 0 or self.moveY ~= 0 then
        self.moveTarget = nil
        if self.mode ~= "gamepad" then
            self.mode = "keyboard"
        end
    end
    
    -- Clear frame buffers
    self._pressedKeys = {}
    self._pressedButtons = {}
    self._mouseClickPos = nil
    self._mouseRightClick = false
    self._scrollDelta = 0
end

--- Get the tile under the mouse cursor.
-- @param camera Camera
-- @return number|nil, number|nil: tx, ty (1-indexed) or nil if no camera
function Input:getMouseTile(camera)
    if not camera then return nil, nil end
    return camera:screenToTile(self.mouseScreenX, self.mouseScreenY)
end

--- Set a click-to-move target (tile coords).
-- @param tx number: target tile X
-- @param ty number: target tile Y
function Input:setMoveTarget(tx, ty)
    self.moveTarget = { tx = tx, ty = ty }
end

--- Clear the click-to-move target.
function Input:clearMoveTarget()
    self.moveTarget = nil
end

--- Check if there's an active move target.
-- @return boolean
function Input:hasMoveTarget()
    return self.moveTarget ~= nil
end

return Input
