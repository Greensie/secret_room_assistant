----------------------------------------------------------------------------------------------------
--                   Collects rooms and cells legitimately known to the player.                   --
--                 Resolves dimensions and room types without revealing secrets.                  --
----------------------------------------------------------------------------------------------------

local Grid = require("scripts.grid")

local KnownRooms = {}

local ROOM_DEFAULT = RoomType and RoomType.ROOM_DEFAULT or 1
local ROOM_ULTRASECRET = RoomType and RoomType.ROOM_ULTRASECRET or 35
local LEVEL_STAGE_2_1 = LevelStage and LevelStage.STAGE2_1 or 4
local LEVEL_STAGE_2_2 = LevelStage and LevelStage.STAGE2_2 or 5
local STAGE_TYPE_REPENTANCE = StageType and StageType.STAGETYPE_REPENTANCE or 4
local STAGE_TYPE_REPENTANCE_B = StageType and StageType.STAGETYPE_REPENTANCE_B or 5
local CURSE_OF_LABYRINTH = LevelCurse and LevelCurse.CURSE_OF_LABYRINTH or 1
local MAX_DIMENSION = 2

--- Excludes room types that must not influence standard Secret Room candidates.
function KnownRooms.isRelevantForSecretRoomSearch(roomType)
    return roomType ~= ROOM_ULTRASECRET
end

--- Returns whether the current stage uses Repentance's alternate path room set.
local function isAltPath(level)
    local stageType = level:GetStageType()

    if stageType == STAGE_TYPE_REPENTANCE or stageType == STAGE_TYPE_REPENTANCE_B then
        return true
    end

    if StageAPI ~= nil and
        StageAPI.Loaded and
        StageAPI.GetCurrentStage ~= nil
    then
        local currentStage = StageAPI.GetCurrentStage()

        if currentStage ~= nil and currentStage.LevelgenStage ~= nil then
            local levelgenStageType = currentStage.LevelgenStage.StageType
            return levelgenStageType == STAGE_TYPE_REPENTANCE or
                levelgenStageType == STAGE_TYPE_REPENTANCE_B
        end
    end

    return false
end

--- Returns whether a descriptor is the Mines/Ashpit II minecart room.
local function isMinecartRoom(level, roomDesc)
    if roomDesc == nil or roomDesc.Data == nil then
        return false
    end

    if roomDesc.Data.Type ~= ROOM_DEFAULT or roomDesc.Data.Subtype ~= 10 then
        return false
    end

    if not isAltPath(level) then
        return false
    end

    local absoluteStage = level:GetStage()

    if level.GetAbsoluteStage ~= nil then
        absoluteStage = level:GetAbsoluteStage()
    end

    local isCurseLabyrinth = false

    if level.GetCurses ~= nil then
        isCurseLabyrinth = level:GetCurses() & CURSE_OF_LABYRINTH == CURSE_OF_LABYRINTH
    end

    return (absoluteStage == LEVEL_STAGE_2_2 and not isCurseLabyrinth) or
        (absoluteStage == LEVEL_STAGE_2_1 and isCurseLabyrinth)
end

--- Excludes descriptor-specific layouts that cannot have standard Secret Room entrances.
function KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc)
    if roomDesc == nil or roomDesc.Data == nil then
        return false
    end

    return KnownRooms.isRelevantForSecretRoomSearch(roomDesc.Data.Type) and
        not isMinecartRoom(level, roomDesc)
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
            KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc)
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
            KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc)
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
            KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc)
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
