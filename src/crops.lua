-- crops.lua: Crop type definitions and growth logic

local Crops = {}

-- Crop definitions: daysToGrow, sellPrice, seedPrice, stages, unlockRequirement
Crops.TYPES = {
    wheat = {
        name = "Wheat",
        daysToGrow = 3,
        sellPrice = 15,
        seedPrice = 5,
        stages = 5,  -- 0=seed, 1, 2, 3, 4=ready
        unlockRequirement = nil,  -- always available
        spriteRow = 0,
    },
    tomato = {
        name = "Tomato",
        daysToGrow = 5,
        sellPrice = 30,
        seedPrice = 10,
        stages = 5,
        unlockRequirement = { crop = "wheat", count = 1 },
        spriteRow = 1,
    },
    egg = {
        name = "Egg",
        sellPrice = 10,
    },
    scarecrow = {
        name = "Scarecrow",
        seedPrice = 50,
        isObject = true,
        stages = 1,
        unlockRequirement = nil,
        spriteRow = 4, -- Placeholder or actual if we have a sprite
    },
}

-- Order for UI display / seed selection
Crops.ORDER = { "wheat", "tomato", "scarecrow", "egg" }

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
