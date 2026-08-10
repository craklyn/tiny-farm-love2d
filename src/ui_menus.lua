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
    return self
end

--- Open a menu.
-- @param menuName string: "pause", "shop", "inventory"
-- @param player Player: for shop item availability
function UIMenus:open(menuName, player)
    self.activeMenu = menuName
    self.selectedOption = 1
    
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
    for i = 1, maxOptions do
        local oy = startY + (i - 1) * optionH
        if x >= menuX and x <= menuX + menuW and y >= oy and y <= oy + optionH then
            self.selectedOption = i
            return self:_selectOption(player)
        end
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
                self:_buildShopItems(player)  -- Refresh
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
        local unlocked = Crops.isSeedUnlocked(cropName, player.harvestCounts)
        local affordable = player.gold >= def.seedPrice
        table.insert(self.shopItems, {
            seedType = cropName,
            name = def.name .. " Seeds",
            price = def.seedPrice,
            unlocked = unlocked,
            affordable = affordable and unlocked,
        })
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
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    -- Menu panel
    local menuW = 300
    local menuH = self:_getMenuHeight()
    local menuX = sw / 2 - menuW / 2
    local menuY = sh / 2 - menuH / 2
    
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
    love.graphics.print(title, sw / 2 - tw / 2, menuY + 12)
    
    local optionH = fh + 12
    local startY = menuY + 40
    
    if self.activeMenu == "pause" then
        self:_drawOption("Resume", 1, menuX, startY, menuW, optionH, true)
        self:_drawOption("Quit", 2, menuX, startY + optionH, menuW, optionH, true)
        
    elseif self.activeMenu == "shop" then
        -- Gold display
        love.graphics.setColor(1, 0.85, 0.2, 1)
        local goldText = string.format("Gold: %dg", player.gold)
        love.graphics.print(goldText, menuX + menuW - font:getWidth(goldText) - 15, menuY + 12)
        
        for i, item in ipairs(self.shopItems) do
            local label
            if not item.unlocked then
                label = "??? (locked)"
            else
                label = string.format("%s - %dg", item.name, item.price)
            end
            self:_drawOption(label, i, menuX, startY + (i - 1) * optionH, menuW, optionH, item.affordable)
        end
        local closeIdx = #self.shopItems + 1
        self:_drawOption("Close", closeIdx, menuX, startY + (#self.shopItems) * optionH, menuW, optionH, true)
        
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
        
        y = y + 8
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.print("Shipping Bin:", menuX + 15, y)
        y = y + fh + 4
        for _, cropName in ipairs(Crops.ORDER) do
            local def = Crops.TYPES[cropName]
            local count = player.shippingBin[cropName] or 0
            love.graphics.setColor(0.8, 0.8, 0.75, 1)
            love.graphics.print(string.format("  %s: %d", def.name, count), menuX + 15, y)
            y = y + fh + 2
        end
        
        -- Adjust menu height for inventory
        -- Close button at bottom
        y = y + 8
        self:_drawOption("Close", 1, menuX, y, menuW, optionH, true)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function UIMenus:_drawOption(text, index, menuX, y, menuW, optionH, enabled)
    local isSelected = (index == self.selectedOption)
    
    -- Highlight background
    if isSelected then
        love.graphics.setColor(0.3, 0.3, 0.45, 0.6)
        love.graphics.rectangle("fill", menuX + 8, y, menuW - 16, optionH, 4, 4)
    end
    
    -- Text
    if not enabled then
        love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
    elseif isSelected then
        love.graphics.setColor(1, 1, 0.8, 1)
    else
        love.graphics.setColor(0.8, 0.8, 0.75, 1)
    end
    
    local prefix = isSelected and "> " or "  "
    love.graphics.print(prefix .. text, menuX + 15, y + 4)
end

return UIMenus
