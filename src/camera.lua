-- camera.lua: Simple camera with smooth follow and map clamping

local Camera = {}
Camera.__index = Camera

local TILE_SIZE = 16
local SCALE = 3  -- Render scale (16px tiles displayed at 48px)

function Camera.new(mapWidth, mapHeight, screenWidth, screenHeight)
    local self = setmetatable({}, Camera)
    self.x = 0
    self.y = 0
    self.scale = SCALE
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
    self.smoothness = 8  -- Higher = snappier follow
    return self
end

--- Update camera to follow a target position with smooth lerp.
-- @param dt number: delta time
-- @param targetX number: world pixel X to follow
-- @param targetY number: world pixel Y to follow
function Camera:update(dt, targetX, targetY)
    -- Target: center the target on screen
    local goalX = targetX * self.scale - self.screenWidth / 2
    local goalY = targetY * self.scale - self.screenHeight / 2

    -- Smooth follow
    local t = 1 - math.exp(-self.smoothness * dt)
    self.x = self.x + (goalX - self.x) * t
    self.y = self.y + (goalY - self.y) * t

    -- Clamp to map bounds with safe margins for HUD occlusion avoidance
    local SAFE_MARGIN_TOP = 120
    local SAFE_MARGIN_BOTTOM = 80
    local maxX = self.mapWidth * TILE_SIZE * self.scale - self.screenWidth
    local maxY = self.mapHeight * TILE_SIZE * self.scale - self.screenHeight
    
    self.x = math.max(0, math.min(self.x, maxX))
    self.y = math.max(-SAFE_MARGIN_TOP, math.min(self.y, maxY + SAFE_MARGIN_BOTTOM))
end

--- Apply camera transform before drawing world objects.
function Camera:apply()
    love.graphics.push()
    love.graphics.scale(self.scale)
    love.graphics.translate(-self.x / self.scale, -self.y / self.scale)
end

--- Remove camera transform after drawing world objects.
function Camera:release()
    love.graphics.pop()
end

--- Convert screen coordinates to world tile coordinates.
-- @param sx number: screen X
-- @param sy number: screen Y
-- @return number, number: tile column, tile row (1-indexed)
function Camera:screenToTile(sx, sy)
    local worldX = (sx + self.x) / self.scale
    local worldY = (sy + self.y) / self.scale
    local tx = math.floor(worldX / TILE_SIZE) + 1
    local ty = math.floor(worldY / TILE_SIZE) + 1
    return tx, ty
end

--- Convert tile coordinates to screen coordinates (center of tile).
-- @param tx number: tile column (1-indexed)
-- @param ty number: tile row (1-indexed)
-- @return number, number: screen X, screen Y
function Camera:tileToScreen(tx, ty)
    local worldX = (tx - 1) * TILE_SIZE + TILE_SIZE / 2
    local worldY = (ty - 1) * TILE_SIZE + TILE_SIZE / 2
    local sx = worldX * self.scale - self.x
    local sy = worldY * self.scale - self.y
    return sx, sy
end

--- Get the tile size in screen pixels.
function Camera:getTileScreenSize()
    return TILE_SIZE * self.scale
end

--- Get the raw tile size in world pixels.
function Camera:getTileSize()
    return TILE_SIZE
end

return Camera
