-- crops.lua: Crop type definitions and growth logic

local Crops = {}

-- Crop definitions: daysToGrow, sellPrice, seedPrice, stages, unlockRequirement
Crops.TYPES = {
    carrot = {
        name = "Carrot",
        daysToGrow = 3,
        sellPrice = 15,
        seedPrice = 5,
        stages = 4,  -- 0=seed, 1=sprout, 2=leafy, 3=ready
        unlockRequirement = nil,  -- always available
        spriteRow = 0,
    },
    tomato = {
        name = "Tomato",
        daysToGrow = 5,
        sellPrice = 30,
        seedPrice = 10,
        stages = 4,
        unlockRequirement = { crop = "carrot", count = 1 },
        spriteRow = 1,
    },
    sunflower = {
        name = "Sunflower",
        daysToGrow = 7,
        sellPrice = 50,
        seedPrice = 20,
        stages = 4,
        unlockRequirement = { crop = "tomato", count = 1 },
        spriteRow = 2,
    },
}

-- Order for UI display / seed selection
Crops.ORDER = { "carrot", "tomato", "sunflower" }

--- Check if a crop at the given growth stage is ready to harvest.
-- @param cropType string: key in TYPES
-- @param growthStage number: current growth stage (0-indexed)
-- @return boolean
function Crops.isReady(cropType, growthStage)
    local def = Crops.TYPES[cropType]
    if not def then return false end
    return growthStage >= def.daysToGrow
end

--- Get the visual stage index (0–3) for sprite rendering.
-- Maps the continuous growth counter to one of 4 visual stages.
-- @param cropType string
-- @param growthStage number: days of growth completed
-- @return number: 0, 1, 2, or 3
function Crops.getVisualStage(cropType, growthStage)
    local def = Crops.TYPES[cropType]
    if not def then return 0 end
    if growthStage <= 0 then return 0 end  -- seed
    if Crops.isReady(cropType, growthStage) then return 3 end  -- ready
    -- Map intermediate stages proportionally
    local progress = growthStage / def.daysToGrow
    if progress < 0.5 then return 1 end  -- sprout
    return 2  -- mid-growth
end

--- Check if a seed type is unlocked based on harvest history.
-- @param seedType string
-- @param harvestCounts table: { carrot = N, tomato = N, sunflower = N }
-- @return boolean
function Crops.isSeedUnlocked(seedType, harvestCounts)
    local def = Crops.TYPES[seedType]
    if not def then return false end
    if not def.unlockRequirement then return true end
    local req = def.unlockRequirement
    return (harvestCounts[req.crop] or 0) >= req.count
end

return Crops
