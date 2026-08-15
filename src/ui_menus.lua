-- ui_menus.lua: Pause menu, seed shop, and inventory overlays

local Crops = require("src.crops")
local Tools = require("src.tools")

local UIMenus = {}
UIMenus.__index = UIMenus

function UIMenus.new()
    local self = setmetatable({}, UIMenus)
    self.activeMenu = nil   -- nil, "pause", "shop", "inventory"
    self.selectedOption = 1
    self.shopItems = {}
    self.scale = 1.0
    self.transitionTimer = 0
    
    self.cropsImage = love.graphics.newImage("assets/sprites/sprout_lands/crops.png")
    self.cropsImage:setFilter("nearest", "nearest")
    return self
end

--- Open a menu.
-- @param menuName string: "pause", "shop", "inventory"
-- @param player Player: for shop item availability
function UIMenus:open(menuName, player)
    self.activeMenu = menuName
    self.selectedOption = 1
    self.scale = 0.8
    self.transitionTimer = 0
    
    if menuName == "shop" and player then
        self:_buildShopItems(player)
    end
end

--- Close the current menu.
function UIMenus:close()
    self.activeMenu = nil
    self.selectedOption = 1
end

--- Check if any menu is open.
-- @return boolean
function UIMenus:isOpen()
    return self.activeMenu ~= nil
end

function UIMenus:update(dt)
    if not self.activeMenu then return end
    
    if self.transitionTimer < 0.2 then
        self.transitionTimer = math.min(0.2, self.transitionTimer + dt)
        local t = self.transitionTimer / 0.2
        -- Simple ease out back / spring
        local s = 1.70158
        self.scale = 0.8 + (1.0 - 0.8) * ((t - 1) * (t - 1) * ((s + 1) * (t - 1) + s) + 1)
    else
        self.scale = 1.0
    end
    
    -- Update item flash timers
    for _, item in ipairs(self.shopItems) do
        if item.flashTimer and item.flashTimer > 0 then
            item.flashTimer = item.flashTimer - dt
        end
    end
end

--- Handle input for the active menu.
-- @param input Input
-- @param player Player
-- @return string|nil: "resume", "quit", "bought_seed", or nil
function UIMenus:handleInput(input, player)
    if not self.activeMenu then return nil end
    
    -- Close on escape/pause
    if input.pausePressed then
        self:close()
        return "resume"
    end
    
    -- Navigate
    if input.moveY < 0 then
        -- Pressed up (since moveY is set for held keys, we need to handle this carefully)
        -- We use a simple approach: check for pressed keys directly
    end
    
    if input.actionPressed then
        return self:_selectOption(player)
    end
    
    return nil
end

--- Process keyboard navigation events (call from love.keypressed).
-- @param key string
function UIMenus:onKeyPressed(key)
    if not self.activeMenu then return end
    
    local maxOptions = self:_getOptionCount()
    
    if key == "up" or key == "w" then
        self.selectedOption = ((self.selectedOption - 2) % maxOptions) + 1
    elseif key == "down" or key == "s" then
        self.selectedOption = (self.selectedOption % maxOptions) + 1
    end
end

--- Process gamepad navigation events.
-- @param button string
function UIMenus:onGamepadPressed(button)
    if not self.activeMenu then return end
    
    local maxOptions = self:_getOptionCount()
    
    if button == "dpup" then
        self.selectedOption = ((self.selectedOption - 2) % maxOptions) + 1
    elseif button == "dpdown" then
        self.selectedOption = (self.selectedOption % maxOptions) + 1
    end
end

--- Process mouse clicks on menu items.
-- @param x number: screen X
-- @param y number: screen Y
-- @param player Player
-- @return string|nil
function UIMenus:onMouseClick(x, y, player)
    if not self.activeMenu then return nil end
    
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local menuW = 300
    local menuH = self:_getMenuHeight()
    local menuX = sw / 2 - menuW / 2
    local menuY = sh / 2 - menuH / 2
    
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local optionH = fh + 12
    local startY = menuY + 40  -- After title
    
    local maxOptions = self:_getOptionCount()
    local cy = startY
    for i = 1, maxOptions do
        local currentH = optionH
        if self.activeMenu == "shop" then
            currentH = 52
        end
        if x >= menuX and x <= menuX + menuW and y >= cy and y <= cy + currentH then
            self.selectedOption = i
            return self:_selectOption(player)
        end
        cy = cy + currentH
    end
    
    return nil
end

function UIMenus:_getOptionCount()
    if self.activeMenu == "pause" then
        return 2  -- Resume, Quit
    elseif self.activeMenu == "shop" then
        return #self.shopItems + 1  -- Items + Close
    elseif self.activeMenu == "inventory" then
        return 1  -- Close
    end
    return 0
end

function UIMenus:_getMenuHeight()
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    if self.activeMenu == "shop" then
        return 50 + self:_getOptionCount() * 52 + 20
    end
    local optionH = fh + 12
    return 50 + self:_getOptionCount() * optionH + 20
end

function UIMenus:_selectOption(player)
    if self.activeMenu == "pause" then
        if self.selectedOption == 1 then
            self:close()
            return "resume"
        elseif self.selectedOption == 2 then
            return "quit"
        end
    elseif self.activeMenu == "shop" then
        if self.selectedOption <= #self.shopItems then
            local item = self.shopItems[self.selectedOption]
            if player:buySeed(item.seedType) then
                local AudioManager = require("src.audio_manager")
                AudioManager.playSfx("harvest")
                self:_buildShopItems(player)  -- Refresh
                self.shopItems[self.selectedOption].flashTimer = 0.2
                return "bought_seed"
            end
        else
            self:close()
            return "resume"
        end
    elseif self.activeMenu == "inventory" then
        self:close()
        return "resume"
    end
    return nil
end

function UIMenus:_buildShopItems(player)
    self.shopItems = {}
    for _, cropName in ipairs(Crops.ORDER) do
        local def = Crops.TYPES[cropName]
        if def.seedPrice then
            local unlocked = Crops.isSeedUnlocked(cropName, player.harvestCounts)
            local affordable = player.gold >= def.seedPrice
            table.insert(self.shopItems, {
                seedType = cropName,
                name = def.name,
                price = def.seedPrice,
                unlocked = unlocked,
                affordable = affordable and unlocked,
                spriteRow = def.spriteRow,
                stages = def.stages,
                owned = player.seeds[cropName] or 0,
                flashTimer = 0,
            })
        end
    end
end

--- Draw the active menu.
-- @param player Player
function UIMenus:draw(player)
    if not self.activeMenu then return end
    
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    
    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.5 * self.scale)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    -- Menu panel
    local menuW = 300
    local menuH = self:_getMenuHeight()
    local menuX = sw / 2 - menuW / 2
    local menuY = sh / 2 - menuH / 2
    
    love.graphics.push()
    love.graphics.translate(sw / 2, sh / 2)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-sw / 2, -sh / 2)
    
    -- Panel background
    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setLineWidth(1)
    
    -- Title
    local title = ""
    if self.activeMenu == "pause" then title = "PAUSED"
    elseif self.activeMenu == "shop" then title = "SEED SHOP"
    elseif self.activeMenu == "inventory" then title = "INVENTORY"
    end
    
    local tw = font:getWidth(title)
    love.graphics.setColor(1, 0.95, 0.7, 1)
    
    if self.activeMenu == "shop" then
        love.graphics.print(title, menuX + 15, menuY + 12)
    else
        love.graphics.print(title, menuX + menuW / 2 - tw / 2, menuY + 12)
    end
    
    local optionH = fh + 12
    local startY = menuY + 40
    
    if self.activeMenu == "pause" then
        self:_drawOption("Resume", 1, menuX, startY, menuW, optionH, true)
        self:_drawOption("Quit", 2, menuX, startY + optionH, menuW, optionH, true)
        
    elseif self.activeMenu == "shop" then
        local goldText = string.format("%dg", player.gold)
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.print(goldText, menuX + menuW - font:getWidth(goldText) - 15, menuY + 12)
        love.graphics.setColor(1, 1, 1, 1)
        
        local cy = startY
        for i, item in ipairs(self.shopItems) do
            self:_drawShopItem(item, i, menuX, cy, menuW, 52, player)
            cy = cy + 52
        end
        local closeIdx = #self.shopItems + 1
        self:_drawOption("Close", closeIdx, menuX, cy, menuW, 52, true)
        
    elseif self.activeMenu == "inventory" then
        -- Show seeds and crops
        local y = startY
        love.graphics.setColor(0.7, 0.9, 0.6, 1)
        love.graphics.print("Seeds:", menuX + 15, y)
        y = y + fh + 4
        for _, cropName in ipairs(Crops.ORDER) do
            local def = Crops.TYPES[cropName]
            local count = player.seeds[cropName] or 0
            love.graphics.setColor(0.8, 0.8, 0.75, 1)
            love.graphics.print(string.format("  %s: %d", def.name, count), menuX + 15, y)
            y = y + fh + 2
        end
        
        y = y + 8
        love.graphics.setColor(0.9, 0.7, 0.4, 1)
        love.graphics.print("Harvested Crops:", menuX + 15, y)
        y = y + fh + 4
        for _, cropName in ipairs(Crops.ORDER) do
            local def = Crops.TYPES[cropName]
            local count = player.crops[cropName] or 0
            love.graphics.setColor(0.8, 0.8, 0.75, 1)
            love.graphics.print(string.format("  %s: %d", def.name, count), menuX + 15, y)
            y = y + fh + 2
        end
        
        -- Shipping bin removed (instant selling)
        
        -- Adjust menu height for inventory
        -- Close button at bottom
        y = y + 8
        self:_drawOption("Close", 1, menuX, y, menuW, optionH, true)
    end
    
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function UIMenus:_drawOption(text, index, menuX, y, menuW, optionH, enabled)
    local isSelected = (index == self.selectedOption)
    
    -- Draw background
    if isSelected then
        love.graphics.setColor(0.3, 0.3, 0.45, 0.8)
    else
        love.graphics.setColor(0.18, 0.18, 0.25, 0.6)
    end
    love.graphics.rectangle("fill", menuX + 8, y + 2, menuW - 16, optionH - 4, 6, 6)
    
    -- Text
    if not enabled then
        love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
    elseif isSelected then
        love.graphics.setColor(1, 1, 0.8, 1)
    else
        love.graphics.setColor(0.8, 0.8, 0.75, 1)
    end
    
    local prefix = isSelected and "> " or "  "
    local font = love.graphics.getFont()
    local textY = y + (optionH - font:getHeight()) / 2
    love.graphics.print(prefix .. text, menuX + 15, textY)
end

function UIMenus:_drawShopItem(item, index, menuX, y, menuW, optionH, player)
    local isSelected = (index == self.selectedOption)
    
    -- Background
    if isSelected then
        love.graphics.setColor(0.3, 0.3, 0.45, 0.8)
    else
        love.graphics.setColor(0.18, 0.18, 0.25, 0.6)
    end
    
    -- Flash effect on purchase
    if item.flashTimer > 0 then
        love.graphics.setColor(1, 1, 1, item.flashTimer / 0.2)
    end
    
    love.graphics.rectangle("fill", menuX + 8, y + 2, menuW - 16, optionH - 4, 6, 6)
    
    -- Gray out if locked or unaffordable
    if not item.unlocked then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    elseif not item.affordable then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Draw crop sprite (stage 4 = fully grown)
    local drawX = menuX + 16
    local drawY = y + optionH / 2 - 8  -- 16px sprite centered
    if self.cropsImage and item.unlocked then
        local TILE_SIZE = 16
        
        local cropRow = item.spriteRow
        
        local stageIdx = 5 -- The 6th sprite is always the harvested item
        local quad = love.graphics.newQuad(stageIdx * TILE_SIZE, cropRow * TILE_SIZE, TILE_SIZE, TILE_SIZE, self.cropsImage:getDimensions())
        love.graphics.draw(self.cropsImage, quad, drawX, drawY, 0, 1.5, 1.5)
    else
        -- Placeholder if locked
        love.graphics.print("?", drawX + 4, drawY)
    end
    
    -- Text
    if not item.unlocked then
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.print("??? (Locked)", drawX + 32, y + 10)
    else
        if isSelected then love.graphics.setColor(1, 1, 0.8, 1) else love.graphics.setColor(0.9, 0.9, 0.85, 1) end
        love.graphics.print(item.name, drawX + 32, y + 6)
        
        -- Price
        if item.affordable then
            love.graphics.setColor(1, 0.85, 0.2, 1)
        else
            love.graphics.setColor(0.9, 0.3, 0.3, 1)
        end
        love.graphics.print(item.price .. "g", drawX + 32, y + 24)
        
        -- Owned
        love.graphics.setColor(0.6, 0.7, 0.6, 1)
        local font = love.graphics.getFont()
        local ownedText = "Owned: " .. item.owned
        love.graphics.print(ownedText, menuX + menuW - font:getWidth(ownedText) - 16, y + optionH / 2 - font:getHeight() / 2)
    end
end

return UIMenus
