-- pathfinding.lua: Grid-based A* pathfinding for the farm tilemap
-- Uses a binary min-heap priority queue for O(log n) operations.
-- Returns a list of {tx, ty} waypoints from start to goal (exclusive of start).
-- If the goal tile is unwalkable (an obstacle), finds the nearest walkable
-- neighbour of the goal so the player can walk adjacent and interact.

local Pathfinding = {}

-- ── Binary Min-Heap ──────────────────────────────────────────────────────────

local Heap = {}
Heap.__index = Heap

function Heap.new()
    return setmetatable({ data = {}, size = 0 }, Heap)
end

function Heap:push(item)
    self.size = self.size + 1
    self.data[self.size] = item
    self:_siftUp(self.size)
end

function Heap:pop()
    if self.size == 0 then return nil end
    local top = self.data[1]
    self.data[1] = self.data[self.size]
    self.data[self.size] = nil
    self.size = self.size - 1
    if self.size > 0 then self:_siftDown(1) end
    return top
end

function Heap:_siftUp(i)
    while i > 1 do
        local parent = math.floor(i / 2)
        if self.data[parent].f > self.data[i].f then
            self.data[parent], self.data[i] = self.data[i], self.data[parent]
            i = parent
        else break end
    end
end

function Heap:_siftDown(i)
    while true do
        local smallest = i
        local l, r = 2 * i, 2 * i + 1
        if l <= self.size and self.data[l].f < self.data[smallest].f then smallest = l end
        if r <= self.size and self.data[r].f < self.data[smallest].f then smallest = r end
        if smallest == i then break end
        self.data[i], self.data[smallest] = self.data[smallest], self.data[i]
        i = smallest
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function heuristic(ax, ay, bx, by)
    -- Manhattan distance — correct for 4-directional grid movement
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function key(tx, ty) return ty * 10000 + tx end

local NEIGHBOURS = { {0,-1}, {0,1}, {-1,0}, {1,0} }

-- ── Public API ────────────────────────────────────────────────────────────────

--- Find a walkable path from (startTX, startTY) to (goalTX, goalTY).
-- If the goal is unwalkable, the path will lead to the closest walkable
-- neighbour of the goal (so the player can stand adjacent and interact).
--
-- @param tilemap  Tilemap  — must expose :isWalkable(tx,ty) and .WIDTH/.HEIGHT
-- @param startTX  number   — 1-indexed column
-- @param startTY  number   — 1-indexed row
-- @param goalTX   number
-- @param goalTY   number
-- @return table|nil  — ordered list of {tx,ty} steps (excludes start), or nil if unreachable
function Pathfinding.findPath(tilemap, startTX, startTY, goalTX, goalTY)
    -- If already at goal, no path needed
    if startTX == goalTX and startTY == goalTY then return {} end

    -- If the goal tile is not walkable, redirect to its nearest walkable neighbour
    local actualGoalTX, actualGoalTY = goalTX, goalTY
    if not tilemap:isWalkable(goalTX, goalTY) then
        local bestDist = math.huge
        for _, d in ipairs(NEIGHBOURS) do
            local nx, ny = goalTX + d[1], goalTY + d[2]
            if tilemap:isWalkable(nx, ny) then
                local dist = heuristic(startTX, startTY, nx, ny)
                if dist < bestDist then
                    bestDist = dist
                    actualGoalTX, actualGoalTY = nx, ny
                end
            end
        end
        -- No walkable neighbour exists (e.g. completely surrounded) → unreachable
        if bestDist == math.huge then return nil end
    end

    local openSet = Heap.new()
    local gScore  = {}   -- key → best known cost from start
    local cameFrom = {}  -- key → {tx, ty, parentKey}

    local startKey = key(startTX, startTY)
    local goalKey  = key(actualGoalTX, actualGoalTY)

    gScore[startKey] = 0
    openSet:push({ tx = startTX, ty = startTY, f = heuristic(startTX, startTY, actualGoalTX, actualGoalTY) })

    local iterations = 0
    local MAX_ITER = tilemap.WIDTH * tilemap.HEIGHT * 2  -- safety cap

    while openSet.size > 0 and iterations < MAX_ITER do
        iterations = iterations + 1
        local current = openSet:pop()
        local ck = key(current.tx, current.ty)

        if ck == goalKey then
            return Pathfinding._reconstruct(cameFrom, startKey, goalKey, current.tx, current.ty)
        end

        local currentG = gScore[ck] or math.huge

        for _, d in ipairs(NEIGHBOURS) do
            local nx, ny = current.tx + d[1], current.ty + d[2]
            if tilemap:isWalkable(nx, ny) or (nx == actualGoalTX and ny == actualGoalTY) then
                local nk = key(nx, ny)
                local tentativeG = currentG + 1
                if tentativeG < (gScore[nk] or math.huge) then
                    gScore[nk] = tentativeG
                    cameFrom[nk] = ck
                    openSet:push({
                        tx = nx, ty = ny,
                        f  = tentativeG + heuristic(nx, ny, actualGoalTX, actualGoalTY)
                    })
                end
            end
        end
    end

    return nil  -- No path found
end

--- Reconstruct the path from the cameFrom map.
-- cameFrom[nodeKey] = parentKey (number)
function Pathfinding._reconstruct(cameFrom, startKey, goalKey, goalTX, goalTY)
    local path = {}
    local currentKey = goalKey
    -- Trace back to start
    while currentKey ~= startKey do
        local tx = currentKey % 10000
        local ty = math.floor(currentKey / 10000)
        table.insert(path, 1, { tx = tx, ty = ty })
        currentKey = cameFrom[currentKey]
        if not currentKey then return nil end  -- Broken chain (shouldn't happen)
    end
    return path
end

--- Find all walkable tiles reachable from a starting position
function Pathfinding.getReachableTiles(tilemap, startX, startY)
    local reachable = {}
    local queue = { {x = startX, y = startY} }
    local visited = {}
    
    local function posToKey(x, y) return x .. "," .. y end
    visited[posToKey(startX, startY)] = true
    
    local index = 1
    while index <= #queue do
        local curr = queue[index]
        index = index + 1
        
        if tilemap:isWalkable(curr.x, curr.y) or (curr.x == startX and curr.y == startY) then
            if tilemap:isWalkable(curr.x, curr.y) then
                table.insert(reachable, {x = curr.x, y = curr.y})
            end
            
            local neighbors = {
                {x = curr.x - 1, y = curr.y},
                {x = curr.x + 1, y = curr.y},
                {x = curr.x, y = curr.y - 1},
                {x = curr.x, y = curr.y + 1}
            }
            
            for _, n in ipairs(neighbors) do
                local nKey = posToKey(n.x, n.y)
                if not visited[nKey] then
                    visited[nKey] = true
                    if tilemap:isWalkable(n.x, n.y) then
                        table.insert(queue, {x = n.x, y = n.y})
                    end
                end
            end
        end
    end
    
    return reachable
end

return Pathfinding
