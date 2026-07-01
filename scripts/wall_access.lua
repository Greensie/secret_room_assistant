----------------------------------------------------------------------------------------------------
--                 Maps candidate walls to room grids and validates bomb access.                  --
--                 Detects physical blockers while ignoring harmless decoration.                  --
----------------------------------------------------------------------------------------------------

local Grid = require("scripts.grid")

local WallAccess = {}

local SEGMENT_GRID_WIDTH = 13
local SEGMENT_GRID_HEIGHT = 7
local ROOM_SHAPE_LTL = RoomShape and RoomShape.ROOMSHAPE_LTL or 9
local DOOR_LEFT_0 = DoorSlot and DoorSlot.LEFT0 or 0
local DOOR_UP_0 = DoorSlot and DoorSlot.UP0 or 1
local DOOR_RIGHT_0 = DoorSlot and DoorSlot.RIGHT0 or 2
local DOOR_DOWN_0 = DoorSlot and DoorSlot.DOWN0 or 3
local DOOR_LEFT_1 = DoorSlot and DoorSlot.LEFT1 or 4
local DOOR_UP_1 = DoorSlot and DoorSlot.UP1 or 5
local DOOR_RIGHT_1 = DoorSlot and DoorSlot.RIGHT1 or 6
local DOOR_DOWN_1 = DoorSlot and DoorSlot.DOWN1 or 7
local GRID_DECORATION = GridEntityType and GridEntityType.GRID_DECORATION or 0
local GRID_FIREPLACE = GridEntityType and GridEntityType.GRID_FIREPLACE or 13
local GRID_SPIDERWEB = GridEntityType and GridEntityType.GRID_SPIDERWEB or 10
local PERSISTENT_BLOCKING_GRID_TYPES = {}
local STATIC_BLOCKING_ENTITY_TYPES = {
    [EntityType and EntityType.ENTITY_STONEHEAD or 42] = true,
    [EntityType and EntityType.ENTITY_CONSTANT_STONE_SHOOTER or 202] = true,
    [EntityType and EntityType.ENTITY_BRIMSTONE_HEAD or 203] = true,
    [EntityType and EntityType.ENTITY_QUAKE_GRIMACE or 804] = true,
    [EntityType and EntityType.ENTITY_BOMB_GRIMACE or 809] = true,
}

--- Registers a physical obstacle whose original placement remains invalid after destruction.
local function addPersistentBlockingGridType(name, fallback)
    local gridType = GridEntityType and GridEntityType[name] or fallback

    if gridType ~= nil then
        PERSISTENT_BLOCKING_GRID_TYPES[gridType] = true
    end
end

addPersistentBlockingGridType("GRID_ROCK", 2)
addPersistentBlockingGridType("GRID_ROCKB", 3)
addPersistentBlockingGridType("GRID_ROCKT", 4)
addPersistentBlockingGridType("GRID_ROCK_BOMB", 5)
addPersistentBlockingGridType("GRID_ROCK_ALT", 6)
addPersistentBlockingGridType("GRID_SPIKES", 8)
addPersistentBlockingGridType("GRID_SPIKES_ONOFF", 9)
addPersistentBlockingGridType("GRID_TNT", 12)
addPersistentBlockingGridType("GRID_FIREPLACE", GRID_FIREPLACE)
addPersistentBlockingGridType("GRID_POOP", 14)
addPersistentBlockingGridType("GRID_STATUE", 21)
addPersistentBlockingGridType("GRID_ROCK_SS", 22)
addPersistentBlockingGridType("GRID_PILLAR", 24)
addPersistentBlockingGridType("GRID_ROCK_SPIKED", 25)
addPersistentBlockingGridType("GRID_ROCK_ALT2", 26)
addPersistentBlockingGridType("GRID_ROCK_GOLD", 27)

--- Converts a level cell into stable room-local coordinates, including the LTL shape pivot.
local function getRoomSegmentPosition(roomDesc, roomCell)
    local anchorCell = Grid.getRoomAnchorCell(roomDesc)
    local baseX = anchorCell % Grid.LEVEL_GRID_WIDTH
    local baseY = math.floor(anchorCell / Grid.LEVEL_GRID_WIDTH)
    local cellX = roomCell % Grid.LEVEL_GRID_WIDTH
    local cellY = math.floor(roomCell / Grid.LEVEL_GRID_WIDTH)
    local pivotX = 0

    if roomDesc.Data ~= nil and roomDesc.Data.Shape == ROOM_SHAPE_LTL then
        pivotX = 1
    end

    return cellX - baseX + pivotX, cellY - baseY
end

--- Returns a stationary Stone Head or Grimace occupying the sampled approach cell.
local function getBlockingEntityTypeAtGridIndex(room, gridIndex)
    if gridIndex == nil then
        return nil
    end

    for i, entity in ipairs(Isaac.GetRoomEntities()) do
        if STATIC_BLOCKING_ENTITY_TYPES[entity.Type] and
            room:GetGridIndex(entity.Position) == gridIndex
        then
            return entity.Type
        end
    end

    return nil
end

--- Classifies live collision and persistent obstacle types while ignoring harmless decorations.
local function isBlockingGridSample(gridEntityType, gridCollision)
    if gridCollision ~= 0 then
        return true
    end

    if gridEntityType == GRID_DECORATION or gridEntityType == GRID_SPIDERWEB then
        return false
    end

    return PERSISTENT_BLOCKING_GRID_TYPES[gridEntityType] == true
end

--- Returns the runtime room-grid width, with descriptor dimensions as a compatibility fallback.
local function getRoomGridWidth(room, roomDesc)
    local ok, roomGridWidth = pcall(function()
        return room:GetGridWidth()
    end)

    if ok and roomGridWidth ~= nil then
        return roomGridWidth
    end

    if roomDesc.Data ~= nil then
        return roomDesc.Data.Width + 2
    end

    return SEGMENT_GRID_WIDTH + 2
end

--- Returns the runtime room-grid height, with descriptor dimensions as a compatibility fallback.
local function getRoomGridHeight(room, roomDesc)
    local ok, roomGridHeight = pcall(function()
        return room:GetGridHeight()
    end)

    if ok and roomGridHeight ~= nil then
        return roomGridHeight
    end

    if roomDesc.Data ~= nil then
        return roomDesc.Data.Height + 2
    end

    return SEGMENT_GRID_HEIGHT + 2
end

--- Maps a stable room segment and direction to the center grid index of its wall.
function WallAccess.getWallCenterGridIndex(room, roomDesc, roomCell, direction)
    if Grid.getRoomAnchorCell(roomDesc) < 0 or roomDesc.Data == nil then
        return nil
    end

    local segmentX, segmentY = getRoomSegmentPosition(roomDesc, roomCell)
    local gridX = segmentX * SEGMENT_GRID_WIDTH
    local gridY = segmentY * SEGMENT_GRID_HEIGHT
    local roomGridWidth = getRoomGridWidth(room, roomDesc)
    local roomGridHeight = getRoomGridHeight(room, roomDesc)

    if direction == "up" then
        gridX = gridX + 7

        if segmentY > 0 then
            gridY = gridY + 1
        end
    elseif direction == "right" then
        gridY = gridY + 4

        if gridX + 14 < roomGridWidth - 1 then
            gridX = gridX + 13
        else
            gridX = gridX + 14
        end
    elseif direction == "down" then
        gridX = gridX + 7

        if gridY + 8 < roomGridHeight - 1 then
            gridY = gridY + 7
        else
            gridY = gridY + 8
        end
    elseif direction == "left" then
        gridY = gridY + 4

        if segmentX > 0 then
            gridX = gridX + 1
        end
    else
        return nil
    end

    return gridX + gridY * roomGridWidth
end

--- Returns the room-grid cell where the player must be able to place a bomb by the wall.
function WallAccess.getApproachGridIndex(room, roomDesc, roomCell, direction)
    local wallGridIndex = WallAccess.getWallCenterGridIndex(room, roomDesc, roomCell, direction)

    if wallGridIndex == nil then
        return nil
    end

    local roomGridWidth = getRoomGridWidth(room, roomDesc)

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

--- Returns the second inward grid cell retained only for verbose diagnostics.
function WallAccess.getInnerApproachGridIndex(room, roomDesc, roomCell, direction)
    local approachGridIndex = WallAccess.getApproachGridIndex(
        room,
        roomDesc,
        roomCell,
        direction
    )

    if approachGridIndex == nil then
        return nil
    end

    local roomGridWidth = getRoomGridWidth(room, roomDesc)

    if direction == "up" then
        return approachGridIndex + roomGridWidth
    elseif direction == "right" then
        return approachGridIndex - 1
    elseif direction == "down" then
        return approachGridIndex - roomGridWidth
    elseif direction == "left" then
        return approachGridIndex + 1
    end

    return nil
end

--- Maps a stable room-local segment and direction to the matching Isaac DoorSlot.
function WallAccess.getDoorSlot(roomDesc, roomCell, direction)
    if Grid.getRoomAnchorCell(roomDesc) < 0 then
        return nil
    end

    local segmentX, segmentY = getRoomSegmentPosition(roomDesc, roomCell)

    if direction == "left" then
        if segmentY > 0 then
            return DOOR_LEFT_1
        end

        return DOOR_LEFT_0
    elseif direction == "up" then
        if segmentX > 0 then
            return DOOR_UP_1
        end

        return DOOR_UP_0
    elseif direction == "right" then
        if segmentY > 0 then
            return DOOR_RIGHT_1
        end

        return DOOR_RIGHT_0
    elseif direction == "down" then
        if segmentX > 0 then
            return DOOR_DOWN_1
        end

        return DOOR_DOWN_0
    end

    return nil
end

--- Builds physical wall-test records for candidates touching the current room shape.
function WallAccess.getCandidateWallsForRoom(room, roomDesc, occupiedCells, candidates)
    local walls = {}

    for i, candidate in ipairs(candidates) do
        for j, neighbor in ipairs(candidate.knownNeighbors or {}) do
            if Grid.containsCell(occupiedCells, neighbor.cell) then
                local wallGridIndex = WallAccess.getWallCenterGridIndex(
                    room,
                    roomDesc,
                    neighbor.cell,
                    neighbor.direction
                )
                local approachGridIndex = WallAccess.getApproachGridIndex(
                    room,
                    roomDesc,
                    neighbor.cell,
                    neighbor.direction
                )
                local innerApproachGridIndex = WallAccess.getInnerApproachGridIndex(
                    room,
                    roomDesc,
                    neighbor.cell,
                    neighbor.direction
                )
                local doorSlot = WallAccess.getDoorSlot(
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
                    innerApproachGridIndex = innerApproachGridIndex,
                    doorSlot = doorSlot,
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

--- Formats candidate wall locations for optional diagnostic output.
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

--- Rejects walls blocked by approach collision, persistent grids, fireplaces, or static NPCs.
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
        local approachBlockingEntityType = nil
        local innerApproachGridEntity = nil
        local innerApproachGridEntityType = nil
        local innerApproachCollisionClass = nil
        local innerApproachGridCollision = nil

        if wall.wallGridIndex ~= nil then
            wallGridEntity = room:GetGridEntity(wall.wallGridIndex)
            wallGridCollision = WallAccess.getGridCollision(room, wall.wallGridIndex)
        end

        if wall.approachGridIndex ~= nil then
            approachGridEntity = room:GetGridEntity(wall.approachGridIndex)
            approachGridCollision = WallAccess.getGridCollision(room, wall.approachGridIndex)
            approachBlockingEntityType = getBlockingEntityTypeAtGridIndex(
                room,
                wall.approachGridIndex
            )
        end

        if wall.innerApproachGridIndex ~= nil then
            innerApproachGridEntity = room:GetGridEntity(wall.innerApproachGridIndex)
            innerApproachGridCollision = WallAccess.getGridCollision(
                room,
                wall.innerApproachGridIndex
            )
        end

        if wallGridEntity ~= nil then
            wallGridEntityType = wallGridEntity:GetType()
            wallCollisionClass = wallGridEntity.CollisionClass
        end

        if approachGridEntity ~= nil then
            approachGridEntityType = approachGridEntity:GetType()
            approachCollisionClass = approachGridEntity.CollisionClass
        end

        if innerApproachGridEntity ~= nil then
            innerApproachGridEntityType = innerApproachGridEntity:GetType()
            innerApproachCollisionClass = innerApproachGridEntity.CollisionClass
        end

        local approachStatus = "UNKNOWN"

        if wallGridEntityType == GRID_FIREPLACE then
            approachStatus = "BLOCKED"
        elseif approachBlockingEntityType ~= nil then
            approachStatus = "BLOCKED"
        elseif approachGridCollision ~= nil then
            if isBlockingGridSample(approachGridEntityType, approachGridCollision) then
                approachStatus = "BLOCKED"
            else
                approachStatus = "OPEN"
            end
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
            approachBlockingEntityType = approachBlockingEntityType,
            innerApproachGridIndex = wall.innerApproachGridIndex,
            innerApproachGridEntityType = innerApproachGridEntityType,
            innerApproachCollisionClass = innerApproachCollisionClass,
            innerApproachGridCollision = innerApproachGridCollision,
            approachStatus = approachStatus,
        })
    end

    return checks
end

--- Reads a grid collision class safely across supported Isaac API variants.
function WallAccess.getGridCollision(room, gridIndex)
    local ok, gridCollision = pcall(function()
        return room:GetGridCollision(gridIndex)
    end)

    if not ok then
        return nil
    end

    return gridCollision
end

--- Formats one grid-entity sample used by verbose wall diagnostics.
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

--- Formats complete wall-access evaluations for optional diagnostic output.
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
            ) ..
            ":e" .. tostring(check.approachBlockingEntityType or "none") ..
            " " ..
            formatGridCheck(
                "i",
                check.innerApproachGridIndex,
                check.innerApproachGridEntityType,
                check.innerApproachCollisionClass,
                check.innerApproachGridCollision
            ) ..
            ":" ..
            check.approachStatus
        )
    end

    return table.concat(parts, ", ")
end

return WallAccess
