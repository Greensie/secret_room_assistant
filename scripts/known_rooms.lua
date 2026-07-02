----------------------------------------------------------------------------------------------------
--                   Collects rooms and cells legitimately known to the player.                   --
--                 Resolves dimensions and room types without revealing secrets.                  --
----------------------------------------------------------------------------------------------------

local Grid = require("scripts.grid")

local KnownRooms = {}

local ROOM_ULTRASECRET = RoomType and RoomType.ROOM_ULTRASECRET or 35
local MAX_DIMENSION = 2

--- Excludes room types that must not influence standard Secret Room candidates.
function KnownRooms.isRelevantForSecretRoomSearch(roomType)
    return roomType ~= ROOM_ULTRASECRET
end

--- Compares engine room descriptors by pointer identity rather than Lua wrapper identity.
local function descriptorsMatch(first, second)
    if first == nil or second == nil then
        return false
    end

    return GetPtrHash(first) == GetPtrHash(second)
end

--- Resolves the Repentance dimension that owns a room descriptor.
function KnownRooms.getRoomDimension(level, roomDesc)
    if roomDesc == nil then
        return 0
    end

    local gridIndex = roomDesc.SafeGridIndex or roomDesc.GridIndex

    for dimension = 0, MAX_DIMENSION do
        local dimensionRoom = level:GetRoomByIdx(gridIndex, dimension)

        if descriptorsMatch(roomDesc, dimensionRoom) then
            return dimension
        end
    end

    return 0
end


--- Returns the dimension containing the room currently occupied by the player.
function KnownRooms.getCurrentDimension(level)
    return KnownRooms.getRoomDimension(level, level:GetCurrentRoomDesc())
end

--- Adds a cell to an ordered result buffer only once.
local function addUniqueCell(cells, cellsByIndex, cell)
    if cellsByIndex[cell] then
        return
    end

    cellsByIndex[cell] = true
    table.insert(cells, cell)
end

--- Collects cells revealed on the minimap in the active dimension without leaking hidden rooms.
function KnownRooms.getVisibleCells(level, dimension)
    local cells = {}
    local cellsByIndex = {}

    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
            KnownRooms.getRoomDimension(level, roomDesc) == dimension and
            roomDesc.DisplayFlags ~= 0 and
            roomDesc.Data ~= nil and
            KnownRooms.isRelevantForSecretRoomSearch(roomDesc.Data.Type)
        then
            local occupiedCells = Grid.getOccupiedCells(roomDesc)

            for j, cell in ipairs(occupiedCells) do
                addUniqueCell(cells, cellsByIndex, cell)
            end
        end
    end

    table.sort(cells)

    return cells
end

--- Maps visible cells in one dimension to their known room types for candidate filtering.
function KnownRooms.getVisibleRoomTypesByCell(level, dimension)
    local roomTypesByCell = {}
    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
            KnownRooms.getRoomDimension(level, roomDesc) == dimension and
            roomDesc.DisplayFlags ~= 0 and
            roomDesc.Data ~= nil and
            KnownRooms.isRelevantForSecretRoomSearch(roomDesc.Data.Type)
        then
            local occupiedCells = Grid.getOccupiedCells(roomDesc)

            for j, cell in ipairs(occupiedCells) do
                roomTypesByCell[cell] = roomDesc.Data.Type
            end
        end
    end

    return roomTypesByCell
end

--- Maps visible cells in one dimension to their known room shapes for candidate filtering.
function KnownRooms.getVisibleRoomShapesByCell(level, dimension)
    local roomShapesByCell = {}
    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
            KnownRooms.getRoomDimension(level, roomDesc) == dimension and
            roomDesc.DisplayFlags ~= 0 and
            roomDesc.Data ~= nil and
            KnownRooms.isRelevantForSecretRoomSearch(roomDesc.Data.Type)
        then
            local occupiedCells = Grid.getOccupiedCells(roomDesc)

            for j, cell in ipairs(occupiedCells) do
                roomShapesByCell[cell] = roomDesc.Data.Shape
            end
        end
    end

    return roomShapesByCell
end

return KnownRooms
