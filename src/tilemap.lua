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
    SCARECROW = "scarecrow",
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
    -- Load spritesheets
    self.tilesetImage = love.graphics.newImage("assets/sprites/sprout_lands/grass.png")
    self.tilesetImage:setFilter("nearest", "nearest")
    self.dirtImage = love.graphics.newImage("assets/sprites/sprout_lands/dirt.png")
    self.dirtImage:setFilter("nearest", "nearest")
    self.cropsImage = love.graphics.newImage("assets/sprites/sprout_lands/crops.png")
    self.cropsImage:setFilter("nearest", "nearest")
    self.furnitureImage = love.graphics.newImage("assets/sprites/sprout_lands/furniture.png")
    self.furnitureImage:setFilter("nearest", "nearest")
    self.chestImage = love.graphics.newImage("assets/sprites/sprout_lands/chest.png")
    self.chestImage:setFilter("nearest", "nearest")
    
    -- Create grass/dirt quads dynamically during draw using BITMASK_MAP
    self.BITMASK_MAP = {
        [0] = {0, 6},   [1] = {0, 5},   [2] = {0, 6},   [3] = {0, 5},   [4] = {1, 6},   [5] = {0, 5},   [6] = {0, 6},   [7] = {0, 5},
        [8] = {0, 6},   [9] = {0, 5},   [10] = {0, 6},  [11] = {0, 5},  [12] = {1, 6},  [13] = {0, 5},  [14] = {0, 6},  [15] = {0, 5},
        [16] = {0, 3},  [17] = {0, 4},  [18] = {0, 3},  [19] = {0, 4},  [20] = {0, 3},  [21] = {0, 4},  [22] = {0, 3},  [23] = {0, 4},
        [24] = {0, 3},  [25] = {0, 4},  [26] = {0, 3},  [27] = {0, 4},  [28] = {1, 6},  [29] = {0, 5},  [30] = {0, 6},  [31] = {0, 5},
        [32] = {0, 6},  [33] = {0, 5},  [34] = {0, 6},  [35] = {0, 5},  [36] = {1, 6},  [37] = {0, 5},  [38] = {0, 6},  [39] = {0, 5},
        [40] = {0, 6},  [41] = {0, 5},  [42] = {0, 6},  [43] = {0, 5},  [44] = {1, 6},  [45] = {0, 5},  [46] = {0, 6},  [47] = {0, 5},
        [48] = {0, 3},  [49] = {0, 4},  [50] = {0, 3},  [51] = {0, 4},  [52] = {0, 3},  [53] = {0, 4},  [54] = {0, 3},  [55] = {0, 4},
        [56] = {0, 6},  [57] = {0, 5},  [58] = {0, 6},  [59] = {0, 5},  [60] = {3, 3},  [61] = {0, 4},  [62] = {3, 3},  [63] = {0, 2},
        [64] = {3, 6},  [65] = {0, 5},  [66] = {3, 6},  [67] = {0, 5},  [68] = {2, 6},  [69] = {2, 6},  [70] = {3, 6},  [71] = {0, 5},
        [72] = {3, 6},  [73] = {0, 5},  [74] = {3, 6},  [75] = {0, 5},  [76] = {2, 6},  [77] = {2, 6},  [78] = {3, 6},  [79] = {2, 6},
        [80] = {3, 6},  [81] = {0, 4},  [82] = {3, 6},  [83] = {0, 4},  [84] = {2, 6},  [85] = {1, 7},  [86] = {3, 6},  [87] = {1, 7},
        [88] = {3, 6},  [89] = {0, 4},  [90] = {3, 6},  [91] = {0, 4},  [92] = {2, 6},  [93] = {1, 7},  [94] = {3, 6},  [95] = {1, 7},
        [96] = {0, 6},  [97] = {0, 5},  [98] = {0, 6},  [99] = {0, 5},  [100] = {1, 6}, [101] = {0, 5}, [102] = {0, 6}, [103] = {0, 5},
        [104] = {0, 6}, [105] = {0, 5}, [106] = {0, 6}, [107] = {0, 5}, [108] = {1, 6}, [109] = {0, 5}, [110] = {0, 6}, [111] = {0, 5},
        [112] = {0, 3}, [113] = {0, 4}, [114] = {0, 3}, [115] = {0, 4}, [116] = {0, 3}, [117] = {0, 4}, [118] = {0, 3}, [119] = {0, 4},
        [120] = {0, 6}, [121] = {0, 5}, [122] = {0, 6}, [123] = {0, 5}, [124] = {3, 3}, [125] = {0, 4}, [126] = {3, 3}, [127] = {2, 2},
        [128] = {0, 6}, [129] = {0, 5}, [130] = {0, 6}, [131] = {0, 5}, [132] = {1, 6}, [133] = {0, 5}, [134] = {0, 6}, [135] = {0, 5},
        [136] = {0, 6}, [137] = {0, 5}, [138] = {0, 6}, [139] = {0, 5}, [140] = {1, 6}, [141] = {0, 5}, [142] = {0, 6}, [143] = {0, 5},
        [144] = {0, 3}, [145] = {0, 4}, [146] = {0, 3}, [147] = {0, 4}, [148] = {0, 3}, [149] = {0, 4}, [150] = {0, 3}, [151] = {0, 4},
        [152] = {0, 3}, [153] = {0, 4}, [154] = {0, 3}, [155] = {0, 4}, [156] = {1, 6}, [157] = {0, 5}, [158] = {0, 6}, [159] = {0, 5},
        [160] = {0, 6}, [161] = {0, 5}, [162] = {0, 6}, [163] = {0, 5}, [164] = {1, 6}, [165] = {0, 5}, [166] = {0, 6}, [167] = {0, 5},
        [168] = {0, 6}, [169] = {0, 5}, [170] = {0, 6}, [171] = {0, 5}, [172] = {1, 6}, [173] = {0, 5}, [174] = {0, 6}, [175] = {0, 5},
        [176] = {0, 3}, [177] = {0, 4}, [178] = {0, 3}, [179] = {0, 4}, [180] = {0, 3}, [181] = {0, 4}, [182] = {0, 3}, [183] = {0, 4},
        [184] = {0, 6}, [185] = {0, 5}, [186] = {0, 6}, [187] = {0, 5}, [188] = {3, 3}, [189] = {0, 4}, [190] = {3, 3}, [191] = {1, 2},
        [192] = {3, 6}, [193] = {0, 5}, [194] = {3, 6}, [195] = {0, 5}, [196] = {2, 6}, [197] = {2, 6}, [198] = {3, 6}, [199] = {0, 5},
        [200] = {3, 6}, [201] = {0, 5}, [202] = {3, 6}, [203] = {0, 5}, [204] = {2, 6}, [205] = {2, 6}, [206] = {3, 6}, [207] = {2, 6},
        [208] = {3, 6}, [209] = {0, 4}, [210] = {3, 6}, [211] = {0, 4}, [212] = {2, 6}, [213] = {1, 7}, [214] = {3, 6}, [215] = {1, 7},
        [216] = {3, 6}, [217] = {0, 4}, [218] = {3, 6}, [219] = {0, 4}, [220] = {2, 6}, [221] = {1, 7}, [222] = {3, 6}, [223] = {1, 7},
        [224] = {0, 6}, [225] = {0, 5}, [226] = {0, 6}, [227] = {0, 5}, [228] = {1, 6}, [229] = {0, 5}, [230] = {0, 6}, [231] = {0, 5},
        [232] = {0, 6}, [233] = {0, 5}, [234] = {0, 6}, [235] = {0, 5}, [236] = {1, 6}, [237] = {0, 5}, [238] = {0, 6}, [239] = {0, 5},
        [240] = {0, 3}, [241] = {0, 4}, [242] = {0, 3}, [243] = {0, 4}, [244] = {0, 3}, [245] = {0, 4}, [246] = {0, 3}, [247] = {0, 4},
        [248] = {0, 6}, [249] = {0, 5}, [250] = {0, 6}, [251] = {0, 5}, [252] = {3, 3}, [253] = {0, 4}, [254] = {3, 3}, [255] = {2, 3}
    }
    
    -- Pre-cache the 256 quads for dirt
    self.fullGrassQuad = love.graphics.newQuad(16, 16, TILE_SIZE, TILE_SIZE, self.tilesetImage:getDimensions())
    self.dirtQuads = {}
    self.wateredDirtQuads = {}
    
    local dw, dh = self.dirtImage:getDimensions()
    for mask = 0, 255 do
        local cx = self.BITMASK_MAP[mask][1]
        local cy = self.BITMASK_MAP[mask][2]
        self.dirtQuads[mask] = love.graphics.newQuad(cx * TILE_SIZE, cy * TILE_SIZE, TILE_SIZE, TILE_SIZE, dw, dh)
        self.wateredDirtQuads[mask] = love.graphics.newQuad((cx + 4) * TILE_SIZE, cy * TILE_SIZE, TILE_SIZE, TILE_SIZE, dw, dh)
    end
    
    -- Create crop quads (4 columns x 3 rows)
    -- Carrots: row 1, Tomato: row 3, Sunflower: row 4 in crops.png
    self.cropQuads = {}
    for _, cropName in ipairs(Crops.ORDER) do
        local row = Crops.TYPES[cropName].spriteRow
        if row then
            self.cropQuads[cropName] = {}
            for stage = 0, 5 do
                self.cropQuads[cropName][stage] = love.graphics.newQuad(
                    stage * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE,
                    self.cropsImage:getDimensions()
                )
            end
        end
    end
    
    -- Create object quads from correct spritesheets
    self.objectDefs = {
        cot = { image = self.furnitureImage, quad = love.graphics.newQuad(0 * 16, 0 * 16, 16, 32, self.furnitureImage:getDimensions()), offsetY = -16 },
        well = { image = self.furnitureImage, quad = love.graphics.newQuad(4 * 16, 0 * 16, 16, 32, self.furnitureImage:getDimensions()), offsetY = -16 },
        shipping_bin = { image = self.chestImage, quad = love.graphics.newQuad(1 * 16, 1 * 16, 16, 16, self.chestImage:getDimensions()), offsetY = 0 },
        seed_box = { image = self.furnitureImage, quad = love.graphics.newQuad(5 * 16, 2 * 16, 16, 32, self.furnitureImage:getDimensions()), offsetY = -16 }
    }
    
    -- Load biomes (obstacles)
    self.biomesImage = love.graphics.newImage("assets/sprites/sprout_lands/biomes.png")
    self.biomesImage:setFilter("nearest", "nearest")
    self.biomeQuads = {
        obstacle_rock = love.graphics.newQuad(5 * 16, 4 * 16, 16, 16, self.biomesImage:getDimensions()),
        obstacle_log  = love.graphics.newQuad(4 * 16, 2 * 16, 16, 16, self.biomesImage:getDimensions()),
        obstacle_weed = love.graphics.newQuad(0 * 16, 0 * 16, 16, 16, self.biomesImage:getDimensions()),
        border        = love.graphics.newQuad(0 * 16, 0 * 16, 16, 16, self.biomesImage:getDimensions())
    }
    
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
    if self.objects[ty] and self.objects[ty][tx] then
        return self.objects[ty][tx]
    end
    -- Check if the tile below has a tall object
    if self.objects[ty+1] and self.objects[ty+1][tx] then
        local objBelow = self.objects[ty+1][tx]
        if objBelow == "cot" or objBelow == "well" or objBelow == "seed_box" then
            return objBelow
        end
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
    local obj = self:getObject(tx, ty)
    if obj and obj ~= "egg" then
        return false
    end
    return true
end

--- Check if a tile is within the radius of a scarecrow.
-- @param tx number
-- @param ty number
-- @return boolean
function Tilemap:isProtectedByScarecrow(tx, ty)
    local radius = 5
    for sy = math.max(1, ty - radius), math.min(self.HEIGHT, ty + radius) do
        for sx = math.max(1, tx - radius), math.min(self.WIDTH, tx + radius) do
            if self:getObject(sx, sy) == "scarecrow" then
                -- Check Euclidean distance
                local dx = sx - tx
                local dy = sy - ty
                if math.sqrt(dx*dx + dy*dy) <= radius then
                    return true
                end
            end
        end
    end
    return false
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
function Tilemap:advanceDay(weather)
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
            
            if weather == "rainy" and (tile.state == "tilled" or tile.state == "seeded" or tile.state == "growing") then
                tile.wateredToday = true
            end
        end
    end
end

--- Draw only base tiles (grass and dirt).
function Tilemap:drawBaseTiles()
    for ty = 1, self.HEIGHT do
        for tx = 1, self.WIDTH do
            local tile = self.tiles[ty][tx]
            local px = (tx - 1) * TILE_SIZE
            local py = (ty - 1) * TILE_SIZE
            
            -- Draw Grass background always
            -- Just draw full grass for the base
            love.graphics.draw(self.tilesetImage, self.fullGrassQuad, px, py)
            
            -- Draw Tilled Dirt if applicable
            local state = tile.state
            if state == "tilled" or state == "seeded" or state == "growing" or state == "ready" then
                -- Calculate 8-way bitmask for dirt
                local mask = 0
                local function isDirt(nx, ny)
                    local ntile = self:getTile(nx, ny)
                    if not ntile then return false end
                    local s = ntile.state
                    return s == "tilled" or s == "seeded" or s == "growing" or s == "ready"
                end
                
                local cn = ty > 1 and isDirt(tx, ty-1)
                local ce = tx < self.WIDTH and isDirt(tx+1, ty)
                local cs = ty < self.HEIGHT and isDirt(tx, ty+1)
                local cw = tx > 1 and isDirt(tx-1, ty)
                local cne = ty > 1 and tx < self.WIDTH and isDirt(tx+1, ty-1)
                local cse = ty < self.HEIGHT and tx < self.WIDTH and isDirt(tx+1, ty+1)
                local csw = ty < self.HEIGHT and tx > 1 and isDirt(tx-1, ty+1)
                local cnw = ty > 1 and tx > 1 and isDirt(tx-1, ty-1)

                if cn then mask = mask + 1 end
                if cn and ce and cne then mask = mask + 2 end
                if ce then mask = mask + 4 end
                if ce and cs and cse then mask = mask + 8 end
                if cs then mask = mask + 16 end
                if cs and cw and csw then mask = mask + 32 end
                if cw then mask = mask + 64 end
                if cw and cn and cnw then mask = mask + 128 end
                
                if tile.wateredToday then
                    love.graphics.draw(self.dirtImage, self.wateredDirtQuads[mask], px, py)
                else
                    love.graphics.draw(self.dirtImage, self.dirtQuads[mask], px, py)
                end
            end
        end
    end
end

--- Queue crops and objects for Y-sorted rendering.
function Tilemap:queueEntities(renderQueue)
    for ty = 1, self.HEIGHT do
        for tx = 1, self.WIDTH do
            local tile = self.tiles[ty][tx]
            local px = (tx - 1) * TILE_SIZE
            local py = (ty - 1) * TILE_SIZE
            
            -- Queue crops
            local state = tile.state
            if state == "seeded" or state == "growing" or state == "ready" then
                table.insert(renderQueue, {
                    y = py, -- Base Y for sorting
                    draw = function()
                        local visualStage = Crops.getVisualStage(tile.cropType, tile.growthStage)
                        local cropQuad = self.cropQuads[tile.cropType]
                        if cropQuad and cropQuad[visualStage] then
                            love.graphics.draw(self.cropsImage, cropQuad[visualStage], px, py)
                        end
                    end
                })
            end
            
            -- Queue obstacles
            if state == "border" or state == "obstacle_rock" or state == "obstacle_log" or state == "obstacle_weed" then
                if self.biomeQuads[state] then
                    table.insert(renderQueue, {
                        y = py,
                        draw = function()
                            love.graphics.draw(self.biomesImage, self.biomeQuads[state], px, py)
                        end
                    })
                end
            end
            
            -- Queue objects
            local obj = self:getObject(tx, ty)
            if obj == "egg" then
                table.insert(renderQueue, {
                    y = py,
                    draw = function()
                        -- Shadow
                        love.graphics.setColor(0, 0, 0, 0.4)
                        love.graphics.ellipse("fill", px + 8, py + 12, 4, 2)
                        -- Egg
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.ellipse("fill", px + 8, py + 10, 3, 4)
                    end
                })
            elseif obj == "scarecrow" then
                table.insert(renderQueue, {
                    y = py,
                    draw = function()
                        -- Stick pole
                        love.graphics.setColor(0.6, 0.4, 0.2, 1)
                        love.graphics.rectangle("fill", px + 6, py - 4, 4, 16)
                        
                        -- Arms (cross)
                        love.graphics.rectangle("fill", px - 2, py + 2, 20, 3)
                        
                        -- Body (shirt)
                        love.graphics.setColor(0.3, 0.4, 0.8, 1)
                        love.graphics.rectangle("fill", px + 2, py + 1, 12, 10)
                        
                        -- Head (pumpkin/hay)
                        love.graphics.setColor(0.9, 0.8, 0.4, 1)
                        love.graphics.circle("fill", px + 8, py - 2, 5)
                        
                        -- Hat
                        love.graphics.setColor(0.4, 0.3, 0.2, 1)
                        love.graphics.rectangle("fill", px + 1, py - 6, 14, 2)
                        love.graphics.rectangle("fill", px + 4, py - 10, 8, 4)
                        
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                })
            else
                local objDef = self.objectDefs[obj]
                if objDef then
                    table.insert(renderQueue, {
                        y = py, -- Objects have height
                        draw = function()
                            love.graphics.draw(objDef.image, objDef.quad, px, py + (objDef.offsetY or 0))
                        end
                    })
                end
            end
        end
    end
end

return Tilemap
