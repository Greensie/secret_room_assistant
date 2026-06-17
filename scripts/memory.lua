local Memory = {}

local visitedCells = {}

function Memory.reset()
    visitedCells = {}
end

function Memory.markCellsAsVisited(cells)
    for i, cell in ipairs(cells) do
        visitedCells[cell] = true
    end
end

function Memory.isVisitedCell(cell)
    return visitedCells[cell] == true
end

function Memory.getVisitedCells()
    local cells = {}

    for cell, isVisited in pairs(visitedCells) do
        if isVisited then
            table.insert(cells, cell)
        end
    end

    table.sort(cells)

    return cells
end

function Memory.getVisitedCount()
    return #Memory.getVisitedCells()
end

return Memory
