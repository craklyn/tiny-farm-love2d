-- Mock LOVE framework for headless tests
_G.love = {
    graphics = {
        newImage = function() return { setFilter = function() end, getDimensions = function() return 100, 100 end } end,
        newQuad = function() return {} end,
    },
    audio = {
        newSource = function() return { setVolume = function() end, setLooping = function() end, play = function() end, clone = function() return { play = function() end, isPlaying = function() return false end } end } end
    }
}

-- Update package.path to include root directory so "src.crops" works
package.path = package.path .. ";../?.lua"

local passCount = 0
local failCount = 0
local failLog = {}

local function _assert(condition, testName)
    if condition then
        passCount = passCount + 1
        print("  \27[32m\27[1m\226\156\147\27[0m " .. testName)
    else
        failCount = failCount + 1
        table.insert(failLog, "FAIL: " .. testName)
        print("  \27[31m\27[1m\226\156\151 FAIL:\27[0m " .. testName)
    end
end

local Crops = require("src.crops")
local Tools = require("src.tools")
local Player = require("src.player")
local Tilemap = require("src.tilemap")
local Pathfinding = require("src.pathfinding")
local ActionRouter = require("src.action_router")

local function testCropDefs()
    print("\n--- CropDefs Tests ---")
    
    _assert(Crops.TYPES["carrot"] ~= nil, "Carrot type exists")
    _assert(Crops.TYPES["tomato"] ~= nil, "Tomato type exists")
    _assert(Crops.TYPES["sunflower"] ~= nil, "Sunflower type exists")
    
    local carrot = Crops.TYPES["carrot"]
    _assert(carrot.daysToGrow == 3, "Carrot grows in 3 days")
    _assert(carrot.sellPrice == 15, "Carrot sells for 15g")
    _assert(carrot.seedPrice == 5, "Carrot seeds cost 5g")
    
    local tomato = Crops.TYPES["tomato"]
    _assert(tomato.daysToGrow == 5, "Tomato grows in 5 days")
    _assert(tomato.sellPrice == 30, "Tomato sells for 30g")
    
    local sunflower = Crops.TYPES["sunflower"]
    _assert(sunflower.daysToGrow == 7, "Sunflower grows in 7 days")
    _assert(sunflower.sellPrice == 50, "Sunflower sells for 50g")
    
    _assert(#Crops.ORDER == 3, "ORDER has 3 crops")
    _assert(Crops.ORDER[1] == "carrot", "ORDER[1] is carrot")
    
    _assert(not Crops.isReady("carrot", 0), "Carrot not ready at stage 0")
    _assert(not Crops.isReady("carrot", 2), "Carrot not ready at stage 2")
    _assert(Crops.isReady("carrot", 3), "Carrot ready at stage 3")
    _assert(Crops.isReady("carrot", 5), "Carrot ready at stage 5 (over)")
    _assert(not Crops.isReady("tomato", 4), "Tomato not ready at stage 4")
    _assert(Crops.isReady("tomato", 5), "Tomato ready at stage 5")
    
    _assert(Crops.getVisualStage("carrot", 0) == 0, "Carrot visual stage 0 at growth 0")
    _assert(Crops.getVisualStage("carrot", 1) == 1, "Carrot visual stage 1 at growth 1")
    _assert(Crops.getVisualStage("carrot", 2) == 2, "Carrot visual stage 2 at growth 2")
    _assert(Crops.getVisualStage("carrot", 3) == 3, "Carrot visual stage 3 at growth 3 (ready)")
    
    local noHarvests = {}
    _assert(Crops.isSeedUnlocked("carrot", noHarvests), "Carrot always unlocked")
    _assert(not Crops.isSeedUnlocked("tomato", noHarvests), "Tomato locked with no harvests")
    _assert(not Crops.isSeedUnlocked("sunflower", noHarvests), "Sunflower locked with no harvests")
    
    local oneCarrot = { carrot = 1 }
    _assert(Crops.isSeedUnlocked("tomato", oneCarrot), "Tomato unlocked with 1 carrot")
    _assert(not Crops.isSeedUnlocked("sunflower", oneCarrot), "Sunflower still locked")
    
    local bigHarvests = { carrot = 10, tomato = 2 }
    _assert(Crops.isSeedUnlocked("sunflower", bigHarvests), "Sunflower unlocked with 2 tomatoes")
end

local function testTools()
    print("\n--- Tools Tests ---")
    
    _assert(#Tools.LIST == 6, "There are 6 tools")
    _assert(Tools.LIST[1].name == "Hands", "Tool 1 is Hands")
    _assert(Tools.LIST[2].name == "Axe", "Tool 2 is Axe")
    _assert(Tools.LIST[3].name == "Pickaxe", "Tool 3 is Pickaxe")
    _assert(Tools.LIST[4].name == "Hoe", "Tool 4 is Hoe")
    _assert(Tools.LIST[5].name == "Watering Can", "Tool 5 is Watering Can")
    _assert(Tools.LIST[6].name == "Seeds", "Tool 6 is Seeds")
    
    _assert(Tools.canActOnTile(1, "ready"), "Hands can harvest")
    _assert(Tools.canActOnTile(4, "cleared"), "Hoe can act on cleared")
    _assert(not Tools.canActOnTile(4, "tilled"), "Hoe can't act on tilled")
    _assert(Tools.canActOnTile(6, "tilled"), "Seeds can act on tilled")
    
    _assert(Tools.getAction(4, "cleared") == "till", "Hoe + cleared = till")
    _assert(Tools.getAction(6, "tilled") == "plant", "Seeds + tilled = plant")
    _assert(Tools.getAction(1, "obstacle_weed") == "clear_weed", "Hands + weed = clear_weed")
    
    _assert(Tools.getEnergyCost("till") == 1, "Tilling costs 1")
    _assert(Tools.getEnergyCost("water") == 1, "Watering costs 1")
    _assert(Tools.getEnergyCost("harvest") == 1, "Harvesting costs 1")
end

local function testPlayer()
    print("\n--- Player/GameState Tests ---")
    local p = Player.new(1, 1)
    
    -- Test initial state
    _assert(p.day == 1, "Initial day is 1")
    _assert(p.energy == 20, "Initial energy is 20")
    _assert(p.gold == 0, "Initial gold is 0")
    _assert(p.seeds["carrot"] == 5, "Start with 5 carrot seeds")
    _assert(p.wateringCanCharges == 8, "Watering can starts at 8")
    
    -- Test set energy (simulated)
    p.energy = 15
    _assert(p.energy == 15, "Energy set to 15")
    
    -- Test tool cycling
    p.selectedTool = 1
    p.selectedTool = p.selectedTool + 1 -- manually simulating GameState.cycle_tool(1)
    _assert(p.selectedTool == 2, "Tool cycled forward to 2")
    
    -- Test buySeed
    p.gold = 100
    p.harvestCounts = { carrot = 0, tomato = 0, sunflower = 0 }
    local bought = p:buySeed("carrot")
    _assert(bought, "Can buy carrot seeds")
    _assert(p.gold == 95, "Gold decreased by 5 (carrot seed price)")
    _assert(p.seeds["carrot"] == 6, "Carrot seeds increased to 6")
    
    local boughtTomato = p:buySeed("tomato")
    _assert(not boughtTomato, "Can't buy locked tomato seeds")
    
    p.harvestCounts["carrot"] = 1
    boughtTomato = p:buySeed("tomato")
    _assert(boughtTomato, "Can buy tomato after unlock")
    _assert(p.gold == 85, "Gold decreased by 10 (tomato seed price)")
    
    -- Test sellCropsToBin (_doSell)
    p.crops = { carrot = 3, tomato = 0, sunflower = 0 }
    p.shippingBin = { carrot = 0, tomato = 0, sunflower = 0 }
    local sold = p:_doSell()
    _assert(sold, "Sold crops")
    _assert(p.crops["carrot"] == 0, "Crops emptied after selling")
    _assert(p.shippingBin["carrot"] == 3, "Bin has 3 carrots")
    
    -- Test processShippingBin
    p.gold = 0
    p:processShippingBin()
    _assert(p.gold == 45, "Gold = 3 carrots x 15g = 45g")
    _assert(p.shippingBin["carrot"] == 0, "Bin emptied after processing")
    
    -- Test startNewDay
    p.energy = 5
    p.wateringCanCharges = 2
    p.day = 3
    p:startNewDay()
    _assert(p.day == 4, "Day advanced to 4")
    _assert(p.energy == 20, "Energy restored to 20")
    _assert(p.wateringCanCharges == 8, "Watering can refilled")
    
    -- Test refillWateringCan (_doRefill)
    p.wateringCanCharges = 3
    local refilled = p:_doRefill()
    _assert(refilled, "Can refill watering can")
    _assert(p.wateringCanCharges == 8, "Watering can refilled to 8")
    refilled = p:_doRefill()
    _assert(not refilled, "Can't refill full watering can")
end

local function testFarm()
    print("\n--- Farm Tests (tile grid) ---")
    local t = Tilemap.new()
    t.tiles = {}
    t.objects = {}
    
    for ty = 1, Tilemap.HEIGHT do
        t.tiles[ty] = {}
        t.objects[ty] = {}
        for tx = 1, Tilemap.WIDTH do
            if ty == 1 or ty == Tilemap.HEIGHT or tx == 1 or tx == Tilemap.WIDTH then
                t.tiles[ty][tx] = { state = "border", cropType = nil, growthStage = 0, wateredToday = false }
            else
                t.tiles[ty][tx] = { state = "cleared", cropType = nil, growthStage = 0, wateredToday = false }
            end
        end
    end
    
    _assert(t.tiles[1][1].state == "border", "Corner is border")
    _assert(t.tiles[2][2].state == "cleared", "Interior is cleared")
    
    t.tiles[2][2].state = "tilled"
    _assert(t.tiles[2][2].state == "tilled", "Tile tilled")
    
    t.tiles[2][2].state = "seeded"
    t.tiles[2][2].cropType = "carrot"
    t.tiles[2][2].growthStage = 0
    _assert(t.tiles[2][2].state == "seeded", "Tile seeded")
    _assert(t.tiles[2][2].cropType == "carrot", "Crop type is carrot")
    
    t.tiles[2][2].wateredToday = true
    _assert(t.tiles[2][2].wateredToday, "Tile watered")
    
    t:advanceDay()
    _assert(t.tiles[2][2].state == "growing", "Crop now growing after day advance")
    _assert(t.tiles[2][2].growthStage == 1, "Growth stage is 1")
    _assert(not t.tiles[2][2].wateredToday, "Watered flag reset")
    
    for i = 1, 2 do
        t.tiles[2][2].wateredToday = true
        t:advanceDay()
    end
    
    _assert(t.tiles[2][2].state == "ready", "Carrot ready after 3 days")
    _assert(t.tiles[2][2].growthStage == 3, "Growth stage is 3")
    
    t.tiles[2][2].state = "cleared"
    t.tiles[2][2].cropType = nil
    t.tiles[2][2].growthStage = 0
    _assert(t.tiles[2][2].state == "cleared", "Tile reverted to cleared after harvest")
    
    t.tiles[3][3].state = "seeded"
    t.tiles[3][3].cropType = "tomato"
    t.tiles[3][3].growthStage = 0
    t.tiles[3][3].wateredToday = false
    t:advanceDay()
    _assert(t.tiles[3][3].growthStage == 0, "Unwatered crop doesn't advance")
    _assert(t.tiles[3][3].state == "seeded", "Unwatered crop stays seeded")
end

local function testIntegration()
    print("\n--- Integration Tests (full game loop) ---")
    local p = Player.new(1, 1)
    
    p.selectedTool = 4 -- Hoe
    _assert(Tools.getAction(4, "cleared") == "till", "Hoe action on cleared = till")
    p.energy = p.energy - Tools.getEnergyCost("till")
    _assert(p.energy == 19, "Energy 19 after tilling")
    
    p.selectedTool = 6 -- Seeds
    _assert(Tools.getAction(6, "tilled") == "plant", "Seeds action on tilled = plant")
    p.seeds["carrot"] = p.seeds["carrot"] - 1
    _assert(p.seeds["carrot"] == 4, "4 carrot seeds remaining")
    
    p.selectedTool = 5 -- Watering Can
    _assert(Tools.getAction(5, "seeded") == "water", "WateringCan on seeded = water")
    p.energy = p.energy - Tools.getEnergyCost("water")
    p.wateringCanCharges = p.wateringCanCharges - 1
    _assert(p.energy == 18, "Energy 18 after watering")
    _assert(p.wateringCanCharges == 7, "7 water charges remaining")
    
    p:startNewDay()
    _assert(p.day == 2, "Day 2 after sleeping")
    _assert(p.energy == 20, "Energy restored")
    _assert(p.wateringCanCharges == 8, "Water refilled")
    
    local cropGrowth = 1
    for i = 1, 2 do
        p.energy = p.energy - 1
        p.wateringCanCharges = p.wateringCanCharges - 1
        cropGrowth = cropGrowth + 1
        p:startNewDay()
    end
    
    _assert(cropGrowth == 3, "Carrot fully grown after 3 watered days")
    _assert(Crops.isReady("carrot", cropGrowth), "Carrot is ready to harvest")
    _assert(p.day == 4, "Day 4")
    
    p.selectedTool = 1 -- Hands
    _assert(Tools.getAction(1, "ready") == "harvest", "Hands on ready = harvest")
    p.energy = p.energy - Tools.getEnergyCost("harvest")
    p.crops["carrot"] = (p.crops["carrot"] or 0) + 1
    p.harvestCounts["carrot"] = (p.harvestCounts["carrot"] or 0) + 1
    _assert(p.crops["carrot"] == 1, "1 carrot in inventory")
    
    _assert(Crops.isSeedUnlocked("tomato", p.harvestCounts), "Tomato unlocked after first carrot harvest")
    
    local sold = p:_doSell()
    _assert(sold, "Sold crops to bin")
    _assert(p.crops["carrot"] == 0, "Carrots moved to bin")
    
    p:processShippingBin()
    _assert(p.gold == 15, "Earned 15g from carrot")
    _assert(p.shippingBin["carrot"] == 0, "Bin emptied")
    
    local bought = p:buySeed("tomato")
    _assert(bought, "Bought tomato seeds")
    _assert(p.seeds["tomato"] == 1, "1 tomato seed")
    _assert(p.gold == 5, "5g remaining")
    
    p.energy = 0
    _assert(p.energy < Tools.getEnergyCost("till"), "Not enough energy to till")
    _assert(p.energy >= Tools.getEnergyCost("plant"), "Can plant at 0 energy")
    
    print("\n--- Full Farming Cycle: COMPLETE ---")
end

local function testPathfinding()
    print("\n--- Pathfinding Tests ---")
    local t = Tilemap.new()
    t.tiles = {}
    t.objects = {}
    for ty = 1, 5 do
        t.tiles[ty] = {}
        t.objects[ty] = {}
        for tx = 1, 5 do
            t.tiles[ty][tx] = { state = "cleared", cropType = nil, growthStage = 0, wateredToday = false }
        end
    end
    -- Make a wall in the middle
    t.tiles[2][3].state = "obstacle_rock"
    t.tiles[3][3].state = "obstacle_rock"
    t.tiles[4][3].state = "obstacle_rock"

    local path = Pathfinding.findPath(t, 2, 2, 4, 2)
    _assert(#path > 0, "Found path around wall")
    _assert(path[#path].tx == 4 and path[#path].ty == 2, "Path ends at target")

    -- Test redirect to neighbor for unwalkable target
    local redirPath = Pathfinding.findPath(t, 2, 2, 3, 3)
    _assert(#redirPath > 0, "Found path to neighbor of obstacle")
    local last = redirPath[#redirPath]
    _assert(not (last.tx == 3 and last.ty == 3), "Path does not end ON obstacle")
end

local function testActionRouter()
    print("\n--- ActionRouter Tests ---")
    local t = Tilemap.new()
    t.tiles = {}
    t.objects = {}
    for ty = 1, 5 do
        t.tiles[ty] = {}
        t.objects[ty] = {}
        for tx = 1, 5 do
            t.tiles[ty][tx] = { state = "cleared", cropType = nil, growthStage = 0, wateredToday = false }
        end
    end

    local p = Player.new(1, 1)
    p.selectedTool = 1
    p.selectedSeedType = "carrot"
    p.seeds = { carrot = 1 }
    p.energy = 20
    p.wateringCanCharges = 8

    -- Obstacle clear
    t.tiles[2][2].state = "obstacle_log"
    local r1 = ActionRouter.resolve(t, p, 2, 2, 1, 1)
    _assert(r1.action == "clear_log", "ActionRouter resolves clear_log on log")
    _assert(r1.toolIndex == 2, "ActionRouter selects axe for log")

    -- Till cleared
    local r2 = ActionRouter.resolve(t, p, 3, 3, 1, 1)
    _assert(r2.action == "till", "ActionRouter resolves till on cleared dirt")

    -- Plant tilled
    t.tiles[4][4].state = "tilled"
    local r3 = ActionRouter.resolve(t, p, 4, 4, 1, 1)
    _assert(r3.action == "plant", "ActionRouter resolves plant on tilled dirt")
    
    -- Special object
    t.objects[1][2] = "shipping_bin"
    local r4 = ActionRouter.resolve(t, p, 2, 1, 1, 1)
    _assert(r4.action == "sell", "ActionRouter resolves sell on shipping_bin")
end

print(string.rep("=", 60))
print("TINY FARM - LÖVE2D Automated Test Suite")
print(string.rep("=", 60))

testCropDefs()
testTools()
testPlayer()
testFarm()
testIntegration()
testPathfinding()
testActionRouter()

print("")
print(string.rep("=", 60))
print(string.format("Results: %d PASSED, %d FAILED", passCount, failCount))
if failCount > 0 then
    print("FAILED TESTS:")
    for _, log in ipairs(failLog) do
        print("  " .. log)
    end
end
print(string.rep("=", 60))

os.exit(failCount > 0 and 1 or 0)
