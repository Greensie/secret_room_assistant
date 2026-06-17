local Grid = require("scripts.grid")

local KnownRooms = {}

local ROOM_ULTRASECRET = RoomType and RoomType.ROOM_ULTRASECRET or 35

function KnownRooms.isRelevantForSecretRoomSearch(roomType)
    return roomType ~= ROOM_ULTRASECRET
end

local function addUniqueCell(cells, cellsByIndex, cell)
    if cellsByIndex[cell] then
        return
    end

    cellsByIndex[cell] = true
    table.insert(cells, cell)
end

function KnownRooms.getVisibleCells(level)
    local cells = {}
    local cellsByIndex = {}

    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
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

function KnownRooms.getVisibleRoomTypesByCell(level)
    local roomTypesByCell = {}
    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
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

return KnownRooms
