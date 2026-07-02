----------------------------------------------------------------------------------------------------
--                   Converts room shapes into stable level-grid cell geometry.                   --
--                   Provides shared cell, neighbor, and room-anchor utilities.                   --
----------------------------------------------------------------------------------------------------

local Grid = {}

Grid.LEVEL_GRID_WIDTH = 13
Grid.LEVEL_GRID_SIZE = 13 * 13

local ROOM_SHAPE_IH = RoomShape and RoomShape.ROOMSHAPE_IH or 2
local ROOM_SHAPE_IV = RoomShape and RoomShape.ROOMSHAPE_IV or 3
local ROOM_SHAPE_IIV = RoomShape and RoomShape.ROOMSHAPE_IIV or 5
local ROOM_SHAPE_IIH = RoomShape and RoomShape.ROOMSHAPE_IIH or 7

local ROOM_SHAPE_OFFSETS = {
    [1] = { { x = 0, y = 0 } },                                 -- 1x1
    [2] = { { x = 0, y = 0 } },                                 -- IH
    [3] = { { x = 0, y = 0 } },                                 -- IV
    [4] = { { x = 0, y = 0 }, { x = 0, y = 1 } },               -- 1x2
    [5] = { { x = 0, y = 0 }, { x = 0, y = 1 } },               -- IIV
    [6] = { { x = 0, y = 0 }, { x = 1, y = 0 } },               -- 2x1
    [7] = { { x = 0, y = 0 }, { x = 1, y = 0 } },               -- IIH
    [8] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },
    [9] = { { x = 0, y = 0 }, { x = -1, y = 1 }, { x = 0, y = 1 } }, -- LTL
    [10] = { { x = 0, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },  -- LTR
    [11] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 } },  -- LBL
    [12] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } },  -- LBR
}

--- Returns whether a room shape is one of Isaac's narrow "I" room layouts.
function Grid.isNarrowRoomShape(shape)
    return shape == ROOM_SHAPE_IH or
        shape == ROOM_SHAPE_IV or
        shape == ROOM_SHAPE_IIV or
        shape == ROOM_SHAPE_IIH
end

--- Returns SafeGridIndex as the stable room anchor, with GridIndex as a compatibility fallback.
function Grid.getRoomAnchorCell(roomDesc)
    if roomDesc == nil then
        return -1
    end

    local safeGridIndex = roomDesc.SafeGridIndex

    if safeGridIndex ~= nil and
        safeGridIndex >= 0 and
        safeGridIndex < Grid.LEVEL_GRID_SIZE
    then
        return safeGridIndex
    end

    return roomDesc.GridIndex or -1
end

--- Checks whether a level-grid cell exists in an array of cell indexes.
function Grid.containsCell(cells, targetCell)
    if cells == nil then
        return false
    end

    for i, cell in ipairs(cells) do
        if cell == targetCell then
            return true
        end
    end

    return false
end

--- Merges multiple cell arrays into one sorted list without duplicates.
function Grid.mergeUniqueCells(...)
    local mergedCells = {}
    local cellsByIndex = {}
    local cellLists = { ... }

    for i, cells in ipairs(cellLists) do
        if cells ~= nil then
            for j, cell in ipairs(cells) do
                if not cellsByIndex[cell] then
                    cellsByIndex[cell] = true
                    table.insert(mergedCells, cell)
                end
            end
        end
    end

    table.sort(mergedCells)

    return mergedCells
end

--- Expands a room shape from its stable anchor into every occupied level-grid cell.
function Grid.getOccupiedCells(roomDesc)
    local cells = {}
    local anchorCell = Grid.getRoomAnchorCell(roomDesc)

    if anchorCell < 0 or anchorCell >= Grid.LEVEL_GRID_SIZE then
        return cells
    end

    if roomDesc.Data == nil then
        return cells
    end

    local shape = roomDesc.Data.Shape
    local offsets = ROOM_SHAPE_OFFSETS[shape]

    if offsets ~= nil then
        for i, offset in ipairs(offsets) do
            table.insert(
                cells,
                anchorCell + offset.x + offset.y * Grid.LEVEL_GRID_WIDTH
            )
        end

        return cells
    end

    local widthCells = math.floor(roomDesc.Data.Width / 13)
    local heightCells = math.floor(roomDesc.Data.Height / 7)

    for y = 0, heightCells - 1 do
        for x = 0, widthCells - 1 do
            table.insert(cells, anchorCell + x + y * Grid.LEVEL_GRID_WIDTH)
        end
    end

    return cells
end

--- Returns unoccupied orthogonal cells around a room, grouped by direction.
function Grid.getNeighborCellsByDirection(roomDesc)
    local occupiedCells = Grid.getOccupiedCells(roomDesc)

    local neighbors = {
        up = {},
        right = {},
        down = {},
        left = {},
    }

    for i, cell in ipairs(occupiedCells) do
        local column = cell % Grid.LEVEL_GRID_WIDTH

        local upCell = cell - Grid.LEVEL_GRID_WIDTH
        local rightCell = cell + 1
        local downCell = cell + Grid.LEVEL_GRID_WIDTH
        local leftCell = cell - 1

        if upCell >= 0 and not Grid.containsCell(occupiedCells, upCell) then
            table.insert(neighbors.up, upCell)
        end

        if column < Grid.LEVEL_GRID_WIDTH - 1 and not Grid.containsCell(occupiedCells, rightCell) then
            table.insert(neighbors.right, rightCell)
        end

        if downCell < Grid.LEVEL_GRID_SIZE and not Grid.containsCell(occupiedCells, downCell) then
            table.insert(neighbors.down, downCell)
        end

        if column > 0 and not Grid.containsCell(occupiedCells, leftCell) then
            table.insert(neighbors.left, leftCell)
        end
    end

    return neighbors
end

--- Serializes cell indexes for optional diagnostic messages.
function Grid.joinCells(cells)
    local parts = {}

    for i, cell in ipairs(cells) do
        table.insert(parts, tostring(cell))
    end

    return table.concat(parts, ", ")
end

return Grid
