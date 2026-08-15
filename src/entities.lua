local Entities = {}

Entities.list = {}

function Entities.init()
    Entities.list = {}
end

function Entities.add(entity)
    table.insert(Entities.list, entity)
end

function Entities.update(dt, tilemap)
    for _, entity in ipairs(Entities.list) do
        if entity.update then
            entity:update(dt, tilemap)
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
