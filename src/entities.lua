local Crow = require("src.crow")

local Entities = {}

Entities.list = {}
Entities.crowSpawnTimer = 0

function Entities.init()
    Entities.list = {}
    Entities.crowSpawnTimer = 0
end

function Entities.add(entity)
    table.insert(Entities.list, entity)
end

function Entities.update(dt, tilemap, player)
    -- Remove dead entities
    for i = #Entities.list, 1, -1 do
        if Entities.list[i].dead then
            table.remove(Entities.list, i)
        end
    end

    for _, entity in ipairs(Entities.list) do
        if entity.update then
            -- Pass entities so entities can check each other's spookRadius
            entity:update(dt, tilemap, player, Entities)
        end
    end
    
    -- Crow spawner logic
    Entities.crowSpawnTimer = Entities.crowSpawnTimer + dt
    if Entities.crowSpawnTimer > 10 then -- Check every 10 seconds
        Entities.crowSpawnTimer = 0
        
        -- Find potential crop targets
        local targets = {}
        for ty = 1, tilemap.HEIGHT do
            for tx = 1, tilemap.WIDTH do
                local tile = tilemap:getTile(tx, ty)
                if tile and (tile.state == "growing" or tile.state == "ready" or tile.state == "seeded") then
                    table.insert(targets, {tx = tx, ty = ty})
                end
            end
        end
        
        if #targets > 0 then
            local target = targets[math.random(1, #targets)]
            -- Spawn off-screen
            local startX = -32
            local startY = -32
            Entities.add(Crow.new(startX, startY, target.tx, target.ty))
        end
    end
end

function Entities.queueRender(renderQueue)
    for _, entity in ipairs(Entities.list) do
        if entity.draw then
            table.insert(renderQueue, {
                y = entity.y,
                draw = function() entity:draw() end
            })
        end
    end
end

function Entities.onNewDay(tilemap)
    for _, entity in ipairs(Entities.list) do
        if entity.onNewDay then
            entity:onNewDay(tilemap)
        end
    end
end

return Entities
