-- tilemap.lua: Tile grid data structure, state machine, and rendering

local Crops = require("src.crops")

local Tilemap = {}
Tilemap.__index = Tilemap

local TILE_SIZE = 16

-- Map dimensions
Tilemap.WIDTH = 32
Tilemap.HEIGHT = 20

-- Tile state constants
Tilemap.STATES = {
    BORDER = "border",
    OBSTACLE_ROCK = "obstacle_rock",
    OBSTACLE_LOG = "obstacle_log",
    OBSTACLE_WEED = "obstacle_weed",
    CLEARED = "cleared",
    TILLED = "tilled",
    SEEDED = "seeded",
    GROWING = "growing",
    READY = "ready",
}

-- Fixed object types (non-farmable special tiles)
Tilemap.OBJECTS = {
    COT = "cot",
    SHIPPING_BIN = "shipping_bin",
    WELL = "well",
    SEED_BOX = "seed_box",
}

-- Fixed object positions (tile coords, 1-indexed)
Tilemap.OBJECT_POSITIONS = {
    { type = "cot",          tx = 3,  ty = 2 },
    { type = "shipping_bin", tx = 5,  ty = 2 },
    { type = "well",         tx = 7,  ty = 2 },
    { type = "seed_box",     tx = 9,  ty = 2 },
}

function Tilemap.new()
    local self = setmetatable({}, Tilemap)
    self.tiles = {}        -- 2D array: tiles[ty][tx]
    self.objects = {}      -- objects[ty][tx] = object type string or nil
    self.spriteBatch = nil
    self.tilesetImage = nil
    self.tileQuads = {}
    self.cropsImage = nil
    self.cropQuads = {}
    self.objectsImage = nil
    self.objectQuads = {}
    return self
end

--- Initialize the tilemap with obstacles and fixed objects.
function Tilemap:init()
    -- Load spritesheet
    self.tilesetImage = love.graphics.newImage("assets/sprites/tiles.png")
    self.tilesetImage:setFilter("nearest", "nearest")
    self.cropsImage = love.graphics.newImage("assets/sprites/crops.png")
    self.cropsImage:setFilter("nearest", "nearest")
    self.objectsImage = love.graphics.newImage("assets/sprites/objects.png")
    self.objectsImage:setFilter("nearest", "nearest")
    
    -- Create tile quads (8 columns x 1 row)
    local tileNames = { "border", "obstacle_rock", "obstacle_log", "obstacle_weed",
                        "cleared", "tilled", "watered_tilled", "grass" }
    for i, name in ipairs(tileNames) do
        self.tileQuads[name] = love.graphics.newQuad(
            (i - 1) * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE,
            self.tilesetImage:getDimensions()
        )
    end
    
    -- Create crop quads (4 columns x 3 rows)
    for _, cropName in ipairs(Crops.ORDER) do
        self.cropQuads[cropName] = {}
        local row = Crops.TYPES[cropName].spriteRow
        for stage = 0, 3 do
            self.cropQuads[cropName][stage] = love.graphics.newQuad(
                stage * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE,
                self.cropsImage:getDimensions()
            )
        end
    end
    
    -- Create object quads (4 columns x 1 row)
    local objNames = { "cot", "shipping_bin", "well", "seed_box" }
    for i, name in ipairs(objNames) do
        self.objectQuads[name] = love.graphics.newQuad(
            (i - 1) * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE,
            self.objectsImage:getDimensions()
        )
    end
    
    -- Initialize tile grid
    self.objects = {}
    for ty = 1, self.HEIGHT do
        self.tiles[ty] = {}
        self.objects[ty] = {}
        for tx = 1, self.WIDTH do
            if ty == 1 or ty == self.HEIGHT or tx == 1 or tx == self.WIDTH then
                -- Border tiles
                self.tiles[ty][tx] = self:_createTile("border")
            else
                -- Interior: randomly place obstacles on ~60% of tiles
                if math.random() < 0.6 then
                    local obstacleTypes = { "obstacle_rock", "obstacle_log", "obstacle_weed" }
                    local chosen = obstacleTypes[math.random(#obstacleTypes)]
                    self.tiles[ty][tx] = self:_createTile(chosen)
                else
                    self.tiles[ty][tx] = self:_createTile("cleared")
                end
            end
        end
    end
    
    -- Place fixed objects (overwrite tiles at those positions)
    for _, obj in ipairs(self.OBJECT_POSITIONS) do
        self.tiles[obj.ty][obj.tx] = self:_createTile("cleared")
        self.objects[obj.ty][obj.tx] = obj.type
        -- Also clear surrounding tiles for accessibility
        for dy = -1, 1 do
            for dx = -1, 1 do
                local nx, ny = obj.tx + dx, obj.ty + dy
                if nx >= 2 and nx <= self.WIDTH - 1 and ny >= 2 and ny <= self.HEIGHT - 1 then
                    if not self.objects[ny][nx] then
                        self.tiles[ny][nx] = self:_createTile("cleared")
                    end
                end
            end
        end
    end
    
    -- Ensure player spawn area (around cot) is clear
    for dy = 0, 2 do
        for dx = 0, 10 do
            local tx, ty = 2 + dx, 2 + dy
            if tx <= self.WIDTH - 1 and ty <= self.HEIGHT - 1 then
                if not self.objects[ty][tx] then
                    self.tiles[ty][tx] = self:_createTile("cleared")
                end
            end
        end
    end
end

--- Create a new tile data table.
function Tilemap:_createTile(state)
    return {
        state = state,
        cropType = nil,
        growthStage = 0,
        wateredToday = false,
    }
end

--- Get tile data at position.
-- @param tx number: tile column (1-indexed)
-- @param ty number: tile row (1-indexed)
-- @return table|nil: tile data
function Tilemap:getTile(tx, ty)
    if ty >= 1 and ty <= self.HEIGHT and tx >= 1 and tx <= self.WIDTH then
        return self.tiles[ty][tx]
    end
    return nil
end

--- Get the object at a position (if any).
-- @param tx number
-- @param ty number
-- @return string|nil: object type
function Tilemap:getObject(tx, ty)
    if self.objects[ty] then
        return self.objects[ty][tx]
    end
    return nil
end

--- Check if a tile is walkable.
-- @param tx number
-- @param ty number
-- @return boolean
function Tilemap:isWalkable(tx, ty)
    local tile = self:getTile(tx, ty)
    if not tile then return false end
    local state = tile.state
    -- Border and obstacles block movement
    if state == "border" then return false end
    if state == "obstacle_rock" or state == "obstacle_log" or state == "obstacle_weed" then
        return false
    end
    return true
end

--- Set tile state with validation.
-- @param tx number
-- @param ty number
-- @param newState string
-- @param cropType string|nil
function Tilemap:setTileState(tx, ty, newState, cropType)
    local tile = self:getTile(tx, ty)
    if not tile then return end
    tile.state = newState
    if cropType ~= nil then
        tile.cropType = cropType
    end
    if newState == "cleared" then
        tile.cropType = nil
        tile.growthStage = 0
        tile.wateredToday = false
    elseif newState == "tilled" then
        tile.cropType = nil
        tile.growthStage = 0
        tile.wateredToday = false
    elseif newState == "seeded" then
        tile.growthStage = 0
        tile.wateredToday = false
    end
end

--- Mark a tile as watered today.
function Tilemap:waterTile(tx, ty)
    local tile = self:getTile(tx, ty)
    if tile and (tile.state == "seeded" or tile.state == "growing") then
        tile.wateredToday = true
    end
end

--- Advance all crops by one day (called during sleep).
function Tilemap:advanceDay()
    for ty = 1, self.HEIGHT do
        for tx = 1, self.WIDTH do
            local tile = self.tiles[ty][tx]
            if tile.wateredToday and (tile.state == "seeded" or tile.state == "growing") then
                tile.growthStage = tile.growthStage + 1
                if tile.state == "seeded" then
                    tile.state = "growing"
                end
                -- Check if crop is ready
                if Crops.isReady(tile.cropType, tile.growthStage) then
                    tile.state = "ready"
                end
            end
            tile.wateredToday = false
        end
    end
end

--- Draw the tilemap.
-- @param camera Camera (unused directly - camera transform is already applied)
function Tilemap:draw()
    -- Draw base tiles
    for ty = 1, self.HEIGHT do
        for tx = 1, self.WIDTH do
            local tile = self.tiles[ty][tx]
            local px = (tx - 1) * TILE_SIZE
            local py = (ty - 1) * TILE_SIZE
            
            -- Choose tile quad based on state
            local quadName = tile.state
            if tile.state == "seeded" or tile.state == "growing" or tile.state == "ready" then
                -- Draw tilled soil underneath crops
                if tile.wateredToday then
                    quadName = "watered_tilled"
                else
                    quadName = "tilled"
                end
            elseif tile.state == "tilled" and tile.wateredToday then
                quadName = "watered_tilled"
            end
            
            local quad = self.tileQuads[quadName]
            if quad then
                love.graphics.draw(self.tilesetImage, quad, px, py)
            end
            
            -- Draw crops on top
            if tile.state == "seeded" or tile.state == "growing" or tile.state == "ready" then
                local visualStage = Crops.getVisualStage(tile.cropType, tile.growthStage)
                local cropQuad = self.cropQuads[tile.cropType]
                if cropQuad and cropQuad[visualStage] then
                    love.graphics.draw(self.cropsImage, cropQuad[visualStage], px, py)
                end
            end
            
            -- Draw objects
            local obj = self:getObject(tx, ty)
            if obj and self.objectQuads[obj] then
                love.graphics.draw(self.objectsImage, self.objectQuads[obj], px, py)
            end
        end
    end
end

return Tilemap
