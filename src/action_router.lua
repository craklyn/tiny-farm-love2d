-- action_router.lua: Context-sensitive action resolver for touch/click input.
-- Given a tilemap, player state, and a tapped tile, returns the best action
-- to perform — choosing the right "tool" automatically so the player doesn't
-- have to manually cycle through the toolbar for basic actions.
--
-- Priority order:
--   1. Object interaction (cot, well, seed_box, shipping_bin)
--   2. Obstacle clearing (rock/log/weed → auto-selects correct tool)
--   3. Ready crop → harvest (hands implicit)
--   4. Tilled soil → plant active seed
--   5. Cleared soil → till
--   6. Seeded/growing (unwatered) → water
--   7. Nothing applicable → nil

local Tools = require("src.tools")

local ActionRouter = {}

-- Object names that trigger special interactions
local SPECIAL_OBJECTS = {
    cot          = "sleep",
    well         = "refill",
    seed_box     = "open_shop",
    shipping_bin = "sell",
}

-- Tool index lookup by name for auto-selection
local function toolIndexByName(name)
    for i, t in ipairs(Tools.LIST) do
        if t.name == name then return i end
    end
    return 1
end

--- Resolve the best action for a given tapped tile.
--
-- @param tilemap   Tilemap
-- @param player    Player   — for energy, seed inventory, watering can charges
-- @param tapTX     number   — tapped tile column (1-indexed)
-- @param tapTY     number   — tapped tile row (1-indexed)
-- @param playerTX  number   — player's current tile column
-- @param playerTY  number   — player's current tile row
--
-- @return table|nil with fields:
--   .action      string   — action name (matches Tools.ENERGY_COSTS keys, or special)
--   .toolIndex   number   — tool to use (auto-selected)
--   .targetTX    number   — tile to act ON (may differ from tapTX if object adjacent)
--   .targetTY    number
--   .walkTo      bool     — true if player must walk to an adjacent tile first
--   .seedType    string|nil — seed type if action == "plant"
function ActionRouter.resolve(tilemap, player, tapTX, tapTY, playerTX, playerTY)
    -- ── 1. Check for a special object on the tapped tile ──────────────────
    local obj = tilemap:getObject(tapTX, tapTY)
    if obj and SPECIAL_OBJECTS[obj] then
        return {
            action    = SPECIAL_OBJECTS[obj],
            toolIndex = 1,
            targetTX  = tapTX,
            targetTY  = tapTY,
            walkTo    = true,
            seedType  = nil,
        }
    end

    -- ── 2. Get tile state ──────────────────────────────────────────────────
    local tile = tilemap:getTile(tapTX, tapTY)
    if not tile then return nil end

    local state = tile.state

    -- ── 3. Obstacles → clear with correct tool ────────────────────────────
    if state == "obstacle_rock" then
        return {
            action    = "clear_rock",
            toolIndex = toolIndexByName("Pickaxe"),
            targetTX  = tapTX,
            targetTY  = tapTY,
            walkTo    = true,
            seedType  = nil,
        }
    end

    if state == "obstacle_log" then
        return {
            action    = "clear_log",
            toolIndex = toolIndexByName("Axe"),
            targetTX  = tapTX,
            targetTY  = tapTY,
            walkTo    = true,
            seedType  = nil,
        }
    end

    if state == "obstacle_weed" then
        return {
            action    = "clear_weed",
            toolIndex = toolIndexByName("Hands"),
            targetTX  = tapTX,
            targetTY  = tapTY,
            walkTo    = true,
            seedType  = nil,
        }
    end

    -- ── 4. Ready crop → harvest ───────────────────────────────────────────
    if state == "ready" then
        return {
            action    = "harvest",
            toolIndex = toolIndexByName("Hands"),
            targetTX  = tapTX,
            targetTY  = tapTY,
            walkTo    = true,
            seedType  = nil,
        }
    end

    -- ── 5. Tilled soil → plant active seed (if player has seeds) ──────────
    if state == "tilled" then
        local seedType = player.selectedSeedType
        if player.seeds[seedType] and player.seeds[seedType] > 0 then
            return {
                action    = "plant",
                toolIndex = toolIndexByName("Seeds"),
                targetTX  = tapTX,
                targetTY  = tapTY,
                walkTo    = true,
                seedType  = seedType,
            }
        end
        -- No seeds of active type — still walkable, just nothing to do
        return nil
    end

    -- ── 6. Cleared soil → till ────────────────────────────────────────────
    if state == "cleared" then
        if player.energy >= Tools.getEnergyCost("till") then
            return {
                action    = "till",
                toolIndex = toolIndexByName("Hoe"),
                targetTX  = tapTX,
                targetTY  = tapTY,
                walkTo    = true,
                seedType  = nil,
            }
        end
        return nil
    end

    -- ── 7. Seeded / Growing and not yet watered today → water ─────────────
    if (state == "seeded" or state == "growing") and not tile.wateredToday then
        if player.wateringCanCharges > 0 and player.energy >= Tools.getEnergyCost("water") then
            return {
                action    = "water",
                toolIndex = toolIndexByName("Watering Can"),
                targetTX  = tapTX,
                targetTY  = tapTY,
                walkTo    = true,
                seedType  = nil,
            }
        end
        return nil
    end

    return nil
end

--- Get the cursor highlight color for a hovered tile (for HUD tile cursor).
-- Returns r, g, b floats.
-- @param tilemap  Tilemap
-- @param player   Player
-- @param tx       number
-- @param ty       number
-- @return number, number, number
function ActionRouter.getCursorColor(tilemap, player, tx, ty)
    local result = ActionRouter.resolve(tilemap, player, tx, ty, 0, 0)
    if result then
        -- Green = valid action
        return 0.2, 0.9, 0.3
    end
    local tile = tilemap:getTile(tx, ty)
    if tile then
        local s = tile.state
        if s == "border" or s:find("obstacle") then
            return 0.9, 0.3, 0.2  -- Red = blocked
        end
        -- Already watered or nothing to do
        return 0.9, 0.85, 0.3  -- Yellow = neutral/already done
    end
    return 1, 1, 1
end

return ActionRouter
