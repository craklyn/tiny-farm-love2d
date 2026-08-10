-- tools.lua: Tool definitions and action validation/execution

local Tools = {}

-- Tool definitions
Tools.LIST = {
    { name = "Hands",        icon = 0, canActOn = { "obstacle_weed", "ready" } },
    { name = "Axe",          icon = 1, canActOn = { "obstacle_log" } },
    { name = "Pickaxe",      icon = 2, canActOn = { "obstacle_rock" } },
    { name = "Hoe",          icon = 3, canActOn = { "cleared" } },
    { name = "Watering Can", icon = 4, canActOn = { "seeded", "growing" } },
    { name = "Seeds",        icon = 5, canActOn = { "tilled" } },
}

-- Energy costs per action
Tools.ENERGY_COSTS = {
    clear_weed  = 1,
    clear_log   = 2,
    clear_rock  = 2,
    till        = 1,
    water       = 1,
    harvest     = 1,
    plant       = 0,
    sell        = 0,
    refill      = 0,
    sleep       = 0,
}

--- Check if a tool can act on a given tile state.
-- @param toolIndex number: 1-based index into Tools.LIST
-- @param tileState string: current tile state
-- @return boolean
function Tools.canActOnTile(toolIndex, tileState)
    local tool = Tools.LIST[toolIndex]
    if not tool then return false end
    for _, validState in ipairs(tool.canActOn) do
        if validState == tileState then
            return true
        end
    end
    return false
end

--- Get the action name for a tool acting on a tile state.
-- @param toolIndex number
-- @param tileState string
-- @return string|nil: action name, or nil if invalid
function Tools.getAction(toolIndex, tileState)
    if not Tools.canActOnTile(toolIndex, tileState) then
        return nil
    end
    local toolName = Tools.LIST[toolIndex].name
    if toolName == "Hands" then
        if tileState == "obstacle_weed" then return "clear_weed" end
        if tileState == "ready" then return "harvest" end
    elseif toolName == "Axe" then
        return "clear_log"
    elseif toolName == "Pickaxe" then
        return "clear_rock"
    elseif toolName == "Hoe" then
        return "till"
    elseif toolName == "Watering Can" then
        return "water"
    elseif toolName == "Seeds" then
        return "plant"
    end
    return nil
end

--- Get the energy cost for an action.
-- @param action string
-- @return number
function Tools.getEnergyCost(action)
    return Tools.ENERGY_COSTS[action] or 0
end

return Tools
