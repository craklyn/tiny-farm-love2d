-- hud.lua: Heads-up display overlay rendering

local Tools        = require("src.tools")
local Crops        = require("src.crops")
local ActionRouter = require("src.action_router")

local HUD = {}
HUD.__index = HUD

-- Centralized theme configuration
local UI_THEME = {
    colors = {
        text_light = {0.96, 0.92, 0.90, 1}, -- Warm Off-White (#F5EBE6)
        text_gold = {0.95, 0.77, 0.18, 1},  -- Warm Gold (#F4C430)
        energy_fill = {0.35, 0.70, 0.33, 1}, -- Muted Emerald (#5BB356)
        energy_low = {0.8, 0.2, 0.2, 0.9},
        energy_bg = {0.07, 0.10, 0.06, 0.9}, -- Near-Black Green (#121A11)
        water = {0.3, 0.6, 0.9, 1}
    },
    padding = {
        x = 12,
        y = 8
    },
    safe_zone_top = 16,
    safe_zone_bottom = 16,
    safe_zone_side = 16
}

function HUD.new()
    local self = setmetatable({}, HUD)
    self.toolIconsImage = nil
    self.toolIconQuads = {}
    
    self.toastMessage = nil
    self.toastTimer = 0
    self.TOAST_DURATION = 3.0
    self.milestonesEarned = {}
    
    self.uiPanelImage = nil
    self.uiPanelQuads = {}
    
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
    
    self.uiPanelImage = love.graphics.newImage("assets/sprites/ui_wood_panel.png")
    self.uiPanelImage:setFilter("nearest", "nearest")
    local iw, ih = self.uiPanelImage:getDimensions()
    -- 9-slice quads (16px corners)
    self.uiPanelQuads = {
        love.graphics.newQuad(0, 0, 16, 16, iw, ih),
        love.graphics.newQuad(16, 0, 16, 16, iw, ih),
        love.graphics.newQuad(32, 0, 16, 16, iw, ih),
        love.graphics.newQuad(0, 16, 16, 16, iw, ih),
        love.graphics.newQuad(16, 16, 16, 16, iw, ih),
        love.graphics.newQuad(32, 16, 16, 16, iw, ih),
        love.graphics.newQuad(0, 32, 16, 16, iw, ih),
        love.graphics.newQuad(16, 32, 16, 16, iw, ih),
        love.graphics.newQuad(32, 32, 16, 16, iw, ih)
    }
end

function HUD:checkMilestones(player)
    local totalHarvests = 0
    for _, count in pairs(player.harvestCounts) do
        totalHarvests = totalHarvests + count
    end
    
    local milestones = {
        { id = "first_harvest", condition = totalHarvests >= 1, msg = "First Harvest!" },
        { id = "green_thumb",   condition = totalHarvests >= 10, msg = "Green Thumb!" },
        { id = "golden_field",  condition = player.gold >= 500, msg = "Golden Field!" },
        { id = "master_farmer", condition = (
            player.harvestCounts.wheat >= 1 and
            player.harvestCounts.tomato >= 1 and
            player.harvestCounts.wheat >= 1
        ), msg = "Master Farmer!" },
    }
    
    for _, m in ipairs(milestones) do
        if m.condition and not self.milestonesEarned[m.id] then
            self.milestonesEarned[m.id] = true
            self:showToast(m.msg)
        end
    end
end

function HUD:showToast(message)
    self.toastMessage = message
    self.toastTimer = self.TOAST_DURATION
end

function HUD:update(dt)
    if self.toastTimer > 0 then
        self.toastTimer = self.toastTimer - dt
        if self.toastTimer <= 0 then
            self.toastMessage = nil
        end
    end
end

function HUD:draw(player, tilemap, camera, input)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    
    self:drawHeader(player, sw, sh, font, fh)
    self:drawControls(player, sw, sh, font, fh)
    
    if input.mode == "mouse" then
        self:_drawTileCursor(player, tilemap, camera, input)
    end
    
    self:drawToast(sw, sh, font, fh)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function HUD:drawPanel(x, y, w, h)
    local img = self.uiPanelImage
    local q = self.uiPanelQuads
    local c = 16 -- corner size
    local cw, ch = 16, 16 -- center size of image
    local mw, mh = w - c*2, h - c*2 -- center size of target
    
    if mw < 0 then mw = 0 end
    if mh < 0 then mh = 0 end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw corners
    love.graphics.draw(img, q[1], x, y)
    love.graphics.draw(img, q[3], x + w - c, y)
    love.graphics.draw(img, q[7], x, y + h - c)
    love.graphics.draw(img, q[9], x + w - c, y + h - c)
    
    -- Draw top and bottom edges (tiled horizontally)
    if mw > 0 then
        love.graphics.setScissor(x + c, y, mw, h)
        for i = 0, math.ceil(mw / cw) - 1 do
            local sx = (i % 2 == 1) and -1 or 1
            local ox = (i % 2 == 1) and cw or 0
            love.graphics.draw(img, q[2], x + c + i * cw, y, 0, sx, 1, ox, 0)
            love.graphics.draw(img, q[8], x + c + i * cw, y + h - c, 0, sx, 1, ox, 0)
        end
        love.graphics.setScissor()
    end
    
    -- Draw left and right edges (tiled vertically)
    if mh > 0 then
        love.graphics.setScissor(x, y + c, w, mh)
        for j = 0, math.ceil(mh / ch) - 1 do
            local sy = (j % 2 == 1) and -1 or 1
            local oy = (j % 2 == 1) and ch or 0
            love.graphics.draw(img, q[4], x, y + c + j * ch, 0, 1, sy, 0, oy)
            love.graphics.draw(img, q[6], x + w - c, y + c + j * ch, 0, 1, sy, 0, oy)
        end
        love.graphics.setScissor()
    end
    
    -- Draw center (tiled horizontally and vertically)
    if mw > 0 and mh > 0 then
        love.graphics.setScissor(x + c, y + c, mw, mh)
        for i = 0, math.ceil(mw / cw) - 1 do
            local sx = (i % 2 == 1) and -1 or 1
            local ox = (i % 2 == 1) and cw or 0
            for j = 0, math.ceil(mh / ch) - 1 do
                local sy = (j % 2 == 1) and -1 or 1
                local oy = (j % 2 == 1) and ch or 0
                love.graphics.draw(img, q[5], x + c + i * cw, y + c + j * ch, 0, sx, sy, ox, oy)
            end
        end
        love.graphics.setScissor()
    end
end

function HUD:printShadow(text, x, y, color)
    love.graphics.setColor(27/255, 16/255, 12/255, 1) -- #1B100C Solid Dark Chocolate Outline
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.print(text, x + 2, y + 2)
    love.graphics.setColor(color or UI_THEME.colors.text_light)
    love.graphics.print(text, x, y)
end

function HUD:drawHeader(player, sw, sh, font, fh)
    -- Unified top bar layout
    local txtDay = string.format("DAY: %d", player.day)
    local txtStamina = "STAMINA:"
    
    local wDay = font:getWidth(txtDay)
    local wStamina = font:getWidth(txtStamina)
    
    local barW = 120
    
    local w = sw - UI_THEME.safe_zone_side * 2
    local h = fh + UI_THEME.padding.y * 2
    local x = UI_THEME.safe_zone_side
    local y = UI_THEME.safe_zone_top
    
    self:drawPanel(x, y, w, h)
    
    -- Left: Day
    self:printShadow(txtDay, x + UI_THEME.padding.x, y + UI_THEME.padding.y, UI_THEME.colors.text_light)
    
    -- Center: Stamina
    local centerX = x + w / 2 - (wStamina + 10 + barW) / 2
    self:printShadow(txtStamina, centerX, y + UI_THEME.padding.y, UI_THEME.colors.text_light)
    
    local fill = player.energy / player.maxEnergy
    local barX = centerX + wStamina + 10
    local barY = y + UI_THEME.padding.y + 4
    local barH = fh - 8
    
    love.graphics.setColor(UI_THEME.colors.energy_bg)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    
    if fill > 0.2 then
        love.graphics.setColor(UI_THEME.colors.energy_fill)
    else
        love.graphics.setColor(UI_THEME.colors.energy_low)
    end
    love.graphics.rectangle("fill", barX, barY, barW * fill, barH)
end

function HUD:drawControls(player, sw, sh, font, fh)
    local tool = Tools.LIST[player.selectedTool]
    local toolName = tool and tool.name or "?"
    
    -- Active Seed Pill (Bottom Center)
    local seedName = player.selectedSeedType
    local seedCount = player.seeds[seedName] or 0
    local seedNameDisplay = seedName:sub(1,1):upper() .. seedName:sub(2)
    local seedText = string.format("%s x%d", seedNameDisplay, seedCount)
    local seedW = font:getWidth(seedText) + UI_THEME.padding.x * 2
    local seedH = fh + UI_THEME.padding.y * 2
    local seedX = sw / 2 - seedW / 2
    local seedY = sh - seedH - UI_THEME.safe_zone_bottom
    
    self:drawPanel(seedX, seedY, seedW, seedH)
    local color = seedCount > 0 and UI_THEME.colors.text_light or {0.5, 0.5, 0.5, 1}
    self:printShadow(seedText, seedX + UI_THEME.padding.x, seedY + UI_THEME.padding.y, color)
    self.seedPillBounds = { x = seedX, y = seedY, w = seedW, h = seedH }
    
    -- Water status (Bottom Right)
    if toolName == "Watering Can" then
        local waterText = string.format("WATER: %d/%d", player.wateringCanCharges, player.maxWateringCanCharges)
        local waterW = font:getWidth(waterText) + UI_THEME.padding.x * 2
        local waterH = fh + UI_THEME.padding.y * 2
        local waterX = sw - waterW - UI_THEME.safe_zone_side
        local waterY = sh - waterH - UI_THEME.safe_zone_bottom
        
        self:drawPanel(waterX, waterY, waterW, waterH)
        self:printShadow(waterText, waterX + UI_THEME.padding.x, waterY + UI_THEME.padding.y, UI_THEME.colors.water)
    end
end

function HUD:_drawTileCursor(player, tilemap, camera, input)
    local mtx, mty = input:getMouseTile(camera)
    if not mtx or not mty then return end

    local tile = tilemap:getTile(mtx, mty)
    if not tile then return end

    local r, g, b = ActionRouter.getCursorColor(tilemap, player, mtx, mty)

    local tileScreenSize = camera:getTileScreenSize()
    local sx, sy = camera:tileToScreen(mtx, mty)
    sx = sx - tileScreenSize / 2
    sy = sy - tileScreenSize / 2

    love.graphics.setColor(r, g, b, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, tileScreenSize, tileScreenSize)
    love.graphics.setLineWidth(1)
end

function HUD:drawToast(sw, sh, font, fh)
    if self.toastMessage and self.toastTimer > 0 then
        local alpha = math.min(1, self.toastTimer)
        local tw = font:getWidth(self.toastMessage)
        local tx = sw / 2 - tw / 2 - 10
        local ty = sh / 2 - 40
        
        love.graphics.setColor(0.1, 0.1, 0.15, 0.85 * alpha)
        love.graphics.rectangle("fill", tx, ty, tw + 20, fh + 16, 6, 6)
        love.graphics.setColor(1, 0.95, 0.5, alpha)
        love.graphics.print(self.toastMessage, tx + 10, ty + 8)
    end
end

return HUD
