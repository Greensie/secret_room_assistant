local Grid = require("scripts.grid")

local WallAccess = {}

local SEGMENT_GRID_WIDTH = 13
local SEGMENT_GRID_HEIGHT = 7

local function getRoomGridWidth(roomDesc)
    if roomDesc.Data == nil then
        return SEGMENT_GRID_WIDTH
    end

    return roomDesc.Data.Width
end

function WallAccess.getWallCenterGridIndex(roomDesc, roomCell, direction)
    if roomDesc.GridIndex < 0 or roomDesc.Data == nil then
        return nil
    end

    local roomCellOffset = roomCell - roomDesc.GridIndex
    local segmentX = roomCellOffset % Grid.LEVEL_GRID_WIDTH
    local segmentY = math.floor(roomCellOffset / Grid.LEVEL_GRID_WIDTH)
    local gridX = segmentX * SEGMENT_GRID_WIDTH
    local gridY = segmentY * SEGMENT_GRID_HEIGHT

    if direction == "up" then
        gridX = gridX + 6
    elseif direction == "right" then
        gridX = gridX + 12
        gridY = gridY + 3
    elseif direction == "down" then
        gridX = gridX + 6
        gridY = gridY + 6
    elseif direction == "left" then
        gridY = gridY + 3
    else
        return nil
    end

    return gridX + gridY * getRoomGridWidth(roomDesc)
end

function WallAccess.getApproachGridIndex(roomDesc, roomCell, direction)
    local wallGridIndex = WallAccess.getWallCenterGridIndex(roomDesc, roomCell, direction)

    if wallGridIndex == nil then
        return nil
    end

    local roomGridWidth = getRoomGridWidth(roomDesc)

    if direction == "up" then
        return wallGridIndex + roomGridWidth
    elseif direction == "right" then
        return wallGridIndex - 1
    elseif direction == "down" then
        return wallGridIndex - roomGridWidth
    elseif direction == "left" then
        return wallGridIndex + 1
    end

    return nil
end

function WallAccess.getCandidateWallsForRoom(roomDesc, occupiedCells, candidates)
    local walls = {}

    for i, candidate in ipairs(candidates) do
        for j, neighbor in ipairs(candidate.knownNeighbors or {}) do
            if Grid.containsCell(occupiedCells, neighbor.cell) then
                local wallGridIndex = WallAccess.getWallCenterGridIndex(
                    roomDesc,
                    neighbor.cell,
                    neighbor.direction
                )
                local approachGridIndex = WallAccess.getApproachGridIndex(
                    roomDesc,
                    neighbor.cell,
                    neighbor.direction
                )

                table.insert(walls, {
                    direction = neighbor.direction,
                    candidateCell = candidate.cell,
                    roomCell = neighbor.cell,
                    wallGridIndex = wallGridIndex,
                    approachGridIndex = approachGridIndex,
                })
            end
        end
    end

    table.sort(walls, function(a, b)
        if a.direction == b.direction then
            return a.candidateCell < b.candidateCell
        end

        return a.direction < b.direction
    end)

    return walls
end

function WallAccess.formatCandidateWalls(walls)
    local parts = {}

    for i, wall in ipairs(walls) do
        local gridText = ""

        if wall.wallGridIndex ~= nil then
            gridText = "@g" .. tostring(wall.wallGridIndex)
        end

        table.insert(
            parts,
            wall.direction .. "->" .. tostring(wall.candidateCell) .. gridText
        )
    end

    return table.concat(parts, ", ")
end

function WallAccess.getCandidateWallChecks(room, walls)
    local checks = {}

    for i, wall in ipairs(walls) do
        local wallGridEntity = nil
        local wallGridEntityType = nil
        local wallCollisionClass = nil
        local wallGridCollision = nil
        local approachGridEntity = nil
        local approachGridEntityType = nil
        local approachCollisionClass = nil
        local approachGridCollision = nil

        if wall.wallGridIndex ~= nil then
            wallGridEntity = room:GetGridEntity(wall.wallGridIndex)
            wallGridCollision = WallAccess.getGridCollision(room, wall.wallGridIndex)
        end

        if wall.approachGridIndex ~= nil then
            approachGridEntity = room:GetGridEntity(wall.approachGridIndex)
            approachGridCollision = WallAccess.getGridCollision(room, wall.approachGridIndex)
        end

        if wallGridEntity ~= nil then
            wallGridEntityType = wallGridEntity:GetType()
            wallCollisionClass = wallGridEntity.CollisionClass
        end

        if approachGridEntity ~= nil then
            approachGridEntityType = approachGridEntity:GetType()
            approachCollisionClass = approachGridEntity.CollisionClass
        end

        table.insert(checks, {
            direction = wall.direction,
            candidateCell = wall.candidateCell,
            wallGridIndex = wall.wallGridIndex,
            wallGridEntityType = wallGridEntityType,
            wallCollisionClass = wallCollisionClass,
            wallGridCollision = wallGridCollision,
            approachGridIndex = wall.approachGridIndex,
            approachGridEntityType = approachGridEntityType,
            approachCollisionClass = approachCollisionClass,
            approachGridCollision = approachGridCollision,
        })
    end

    return checks
end

function WallAccess.getGridCollision(room, gridIndex)
    local ok, gridCollision = pcall(function()
        return room:GetGridCollision(gridIndex)
    end)

    if not ok then
        return nil
    end

    return gridCollision
end

local function formatGridCheck(prefix, gridIndex, gridEntityType, collisionClass, gridCollision)
    if gridIndex == nil then
        return prefix .. "?"
    end

    local entityText = "none"

    if gridEntityType ~= nil then
        entityText = "type" .. tostring(gridEntityType) .. ":c" .. tostring(collisionClass or "?")
    end

    return prefix .. tostring(gridIndex) .. ":" .. entityText .. ":gc" .. tostring(gridCollision or "?")
end

function WallAccess.formatCandidateWallChecks(checks)
    local parts = {}

    for i, check in ipairs(checks) do
        table.insert(
            parts,
            check.direction ..
            "->" ..
            tostring(check.candidateCell) ..
            " " ..
            formatGridCheck(
                "w",
                check.wallGridIndex,
                check.wallGridEntityType,
                check.wallCollisionClass,
                check.wallGridCollision
            ) ..
            " " ..
            formatGridCheck(
                "a",
                check.approachGridIndex,
                check.approachGridEntityType,
                check.approachCollisionClass,
                check.approachGridCollision
            )
        )
    end

    return table.concat(parts, ", ")
end

return WallAccess
