local Grid = {}

Grid.LEVEL_GRID_WIDTH = 13
Grid.LEVEL_GRID_SIZE = 13 * 13

local ROOM_SHAPE_OFFSETS = {
    [1] = { { x = 0, y = 0 } },                                 -- 1x1
    [2] = { { x = 0, y = 0 } },                                 -- IH
    [3] = { { x = 0, y = 0 } },                                 -- IV
    [4] = { { x = 0, y = 0 }, { x = 0, y = 1 } },               -- 1x2
    [5] = { { x = 0, y = 0 }, { x = 0, y = 1 } },               -- IIV
    [6] = { { x = 0, y = 0 }, { x = 1, y = 0 } },               -- 2x1
    [7] = { { x = 0, y = 0 }, { x = 1, y = 0 } },               -- IIH
    [8] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },
    [9] = { { x = 0, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },  -- LTL
    [10] = { { x = 1, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } }, -- LTR
    [11] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } }, -- LBL
    [12] = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 } }, -- LBR
}

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

function Grid.getOccupiedCells(roomDesc)
    local cells = {}

    if roomDesc.GridIndex < 0 or roomDesc.GridIndex >= Grid.LEVEL_GRID_SIZE then
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
                roomDesc.GridIndex + offset.x + offset.y * Grid.LEVEL_GRID_WIDTH
            )
        end

        return cells
    end

    local widthCells = math.floor(roomDesc.Data.Width / 13)
    local heightCells = math.floor(roomDesc.Data.Height / 7)

    for y = 0, heightCells - 1 do
        for x = 0, widthCells - 1 do
            table.insert(cells, roomDesc.GridIndex + x + y * Grid.LEVEL_GRID_WIDTH)
        end
    end

    return cells
end

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

function Grid.joinCells(cells)
    local parts = {}

    for i, cell in ipairs(cells) do
        table.insert(parts, tostring(cell))
    end

    return table.concat(parts, ", ")
end

return Grid
