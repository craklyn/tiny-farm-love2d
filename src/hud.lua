-- hud.lua: Heads-up display overlay rendering

local Tools        = require("src.tools")
local Crops        = require("src.crops")
local ActionRouter = require("src.action_router")

local HUD = {}
HUD.__index = HUD

function HUD.new()
    local self = setmetatable({}, HUD)
    self.toolIconsImage = nil
    self.toolIconQuads = {}
    
    -- Milestone toast
    self.toastMessage = nil
    self.toastTimer = 0
    self.TOAST_DURATION = 3.0
    
    -- Milestone tracking
    self.milestonesEarned = {}
    
    return self
end

function HUD:init()
    self.toolIconsImage = love.graphics.newImage("assets/sprites/tool_icons.png")
    self.toolIconsImage:setFilter("nearest", "nearest")
    
    for i = 0, 5 do
        self.toolIconQuads[i] = love.graphics.newQuad(
            i * 16, 0, 16, 16,
            self.toolIconsImage:getDimensions()
        )
    end
end

--- Check and trigger milestones.
-- @param player Player
function HUD:checkMilestones(player)
    local totalHarvests = 0
    for _, count in pairs(player.harvestCounts) do
        totalHarvests = totalHarvests + count
    end
    
    local milestones = {
        { id = "first_harvest", condition = totalHarvests >= 1, msg = "🌾 First Harvest!" },
        { id = "green_thumb",   condition = totalHarvests >= 10, msg = "🌿 Green Thumb!" },
        { id = "golden_field",  condition = player.gold >= 500, msg = "💰 Golden Field!" },
        { id = "master_farmer", condition = (
            player.harvestCounts.carrot >= 1 and
            player.harvestCounts.tomato >= 1 and
            player.harvestCounts.sunflower >= 1
        ), msg = "👨‍🌾 Master Farmer!" },
    }
    
    for _, m in ipairs(milestones) do
        if m.condition and not self.milestonesEarned[m.id] then
            self.milestonesEarned[m.id] = true
            self:showToast(m.msg)
        end
    end
end

--- Show a toast notification.
-- @param message string
function HUD:showToast(message)
    self.toastMessage = message
    self.toastTimer = self.TOAST_DURATION
end

--- Update HUD state (toast timers, etc.).
-- @param dt number
function HUD:update(dt)
    if self.toastTimer > 0 then
        self.toastTimer = self.toastTimer - dt
        if self.toastTimer <= 0 then
            self.toastMessage = nil
        end
    end
end

--- Draw the HUD overlay (call AFTER camera:release, in screen space).
-- @param player Player
-- @param tilemap Tilemap (for cursor info)
-- @param camera Camera
-- @param input Input
function HUD:draw(player, tilemap, camera, input)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    
    -- === Top Bar Background ===
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, sw, fh + 12)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Day counter (top-left)
    love.graphics.setColor(0.9, 0.9, 0.8, 1)
    love.graphics.print("Day " .. player.day, 10, 6)
    
    -- Energy (top-center)
    local energyText = string.format("Energy: %d/%d", player.energy, player.maxEnergy)
    local etw = font:getWidth(energyText)
    -- Energy bar background
    local barX = sw / 2 - 60
    local barY = 6
    local barW = 120
    local barH = fh
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    -- Energy bar fill
    local fill = player.energy / player.maxEnergy
    local r = 0.3 + 0.7 * (1 - fill)  -- Red when low
    local g = 0.3 + 0.7 * fill         -- Green when high
    love.graphics.setColor(r, g, 0.2, 0.9)
    love.graphics.rectangle("fill", barX + 1, barY + 1, (barW - 2) * fill, barH - 2)
    -- Energy text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(energyText, sw / 2 - etw / 2, 6)
    
    -- Gold (top-right)
    local goldText = string.format("%dg", player.gold)
    local gtw = font:getWidth(goldText)
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.print(goldText, sw - gtw - 10, 6)
    
    -- === Bottom Bar Background ===
    local bottomY = sh - fh - 16
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, bottomY, sw, fh + 16)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Current tool (bottom-left)
    local tool = Tools.LIST[player.selectedTool]
    if tool and self.toolIconQuads[tool.icon] then
        love.graphics.draw(self.toolIconsImage, self.toolIconQuads[tool.icon],
            10, bottomY + 2, 0, 2, 2)  -- 2x scale
    end
    love.graphics.setColor(0.9, 0.9, 0.8, 1)
    love.graphics.print(tool and tool.name or "?", 46, bottomY + 8)
    
    -- Seed type indicator (when Seeds tool is selected)
    if tool and tool.name == "Seeds" then
        local seedInfo = string.format(" [%s x%d]", 
            player.selectedSeedType, 
            player.seeds[player.selectedSeedType] or 0)
        local toolNameWidth = font:getWidth(tool.name)
        love.graphics.setColor(0.6, 0.9, 0.4, 1)
        love.graphics.print(seedInfo, 46 + toolNameWidth, bottomY + 8)
    end
    
    -- Seed counts (bottom-center)
    local seedX = sw / 2 - 80
    for i, cropName in ipairs(Crops.ORDER) do
        local count = player.seeds[cropName] or 0
        local emoji = ({ carrot = "Ca", tomato = "To", sunflower = "Su" })[cropName]
        local text = string.format("%s:%d", emoji, count)
        
        if Crops.isSeedUnlocked(cropName, player.harvestCounts) then
            love.graphics.setColor(0.8, 0.9, 0.7, 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
        end
        love.graphics.print(text, seedX + (i - 1) * 55, bottomY + 8)
    end
    
    -- Watering can charges (bottom-right)
    local waterText = string.format("Water: %d/%d", player.wateringCanCharges, player.maxWateringCanCharges)
    local wtw = font:getWidth(waterText)
    love.graphics.setColor(0.4, 0.7, 0.95, 1)
    love.graphics.print(waterText, sw - wtw - 10, bottomY + 8)

    -- === Active Seed Pill (touch-first: always visible, tap to cycle) ===
    local seedName = player.selectedSeedType
    local seedCount = player.seeds[seedName] or 0
    local seedEmoji = ({ carrot = "🥕", tomato = "🍅", sunflower = "🌻" })[seedName] or "?"
    local pillText = string.format("%s %s x%d", seedEmoji, seedName, seedCount)
    local pillW = font:getWidth(pillText) + 24
    local pillH = fh + 10
    local pillX = sw / 2 - pillW / 2
    local pillY = bottomY - pillH - 6

    -- Pill background (greener when seeds are available, grey if empty)
    if seedCount > 0 then
        love.graphics.setColor(0.18, 0.52, 0.22, 0.88)
    else
        love.graphics.setColor(0.25, 0.25, 0.25, 0.75)
    end
    love.graphics.rectangle("fill", pillX, pillY, pillW, pillH, pillH/2, pillH/2)
    -- Border
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", pillX, pillY, pillW, pillH, pillH/2, pillH/2)
    -- Text
    love.graphics.setColor(1, 1, 0.9, 1)
    love.graphics.print(pillText, pillX + 12, pillY + 5)

    -- Store pill bounds for touch detection in main.lua
    self.seedPillBounds = { x = pillX, y = pillY, w = pillW, h = pillH }
    
    -- === Tile Cursor (mouse mode) ===
    if input.mode == "mouse" then
        self:_drawTileCursor(player, tilemap, camera, input)
    end
    
    -- === Toast Notification ===
    if self.toastMessage and self.toastTimer > 0 then
        local alpha = math.min(1, self.toastTimer)  -- Fade out in last second
        local tw = font:getWidth(self.toastMessage)
        local tx = sw / 2 - tw / 2 - 10
        local ty = sh / 2 - 40
        
        love.graphics.setColor(0.1, 0.1, 0.15, 0.85 * alpha)
        love.graphics.rectangle("fill", tx, ty, tw + 20, fh + 16, 6, 6)
        love.graphics.setColor(1, 0.95, 0.5, alpha)
        love.graphics.print(self.toastMessage, tx + 10, ty + 8)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

--- Draw the tile cursor highlight when using mouse input.
function HUD:_drawTileCursor(player, tilemap, camera, input)
    local mtx, mty = input:getMouseTile(camera)
    if not mtx or not mty then return end

    local tile = tilemap:getTile(mtx, mty)
    if not tile then return end

    -- Use ActionRouter for smart cursor coloring
    local r, g, b = ActionRouter.getCursorColor(tilemap, player, mtx, mty)

    -- Draw cursor in world space
    local tileScreenSize = camera:getTileScreenSize()
    local sx, sy = camera:tileToScreen(mtx, mty)
    sx = sx - tileScreenSize / 2
    sy = sy - tileScreenSize / 2

    love.graphics.setColor(r, g, b, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, tileScreenSize, tileScreenSize)
    love.graphics.setLineWidth(1)
end

return HUD
