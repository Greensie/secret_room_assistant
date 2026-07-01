----------------------------------------------------------------------------------------------------
--                Stores floor-local exploration, discovery, and rejection state.                 --
--                 Tracks expected Secret Rooms and resets between floor scopes.                  --
----------------------------------------------------------------------------------------------------

local Memory = {}

local visitedCells = {}
local blockedCandidateCells = {}
local foundSecretRoomCells = {}
local expectedSecretRoomCount = 1
local seeForeverUsed = false

--- Clears floor- and dimension-local exploration and rejection state.
function Memory.reset()
    visitedCells = {}
    blockedCandidateCells = {}
    foundSecretRoomCells = {}
    expectedSecretRoomCount = 1
    seeForeverUsed = false
end

--- Stores how many standard Secret Rooms were generated for the current floor.
function Memory.setExpectedSecretRoomCount(count)
    expectedSecretRoomCount = math.max(0, count or 0)
end

--- Records one player-known standard Secret Room without counting it twice.
function Memory.markSecretRoomAsFound(cell)
    if cell ~= nil then
        foundSecretRoomCells[cell] = true
    end
end

--- Reports whether another standard Secret Room may remain on the current floor.
function Memory.hasRemainingSecretRooms()
    local foundCount = 0

    for cell, wasFound in pairs(foundSecretRoomCells) do
        if wasFound then
            foundCount = foundCount + 1
        end
    end

    return foundCount < expectedSecretRoomCount
end

--- Remembers that I Can See Forever revealed entrances for the current floor.
function Memory.markSeeForeverAsUsed()
    seeForeverUsed = true
end

--- Reports whether I Can See Forever already made candidate hints unnecessary.
function Memory.wasSeeForeverUsed()
    return seeForeverUsed
end

--- Records every level-grid cell occupied by a room the player has entered.
function Memory.markCellsAsVisited(cells)
    for i, cell in ipairs(cells) do
        visitedCells[cell] = true
    end
end

--- Reports whether the player has visited a specific level-grid cell.
function Memory.isVisitedCell(cell)
    return visitedCells[cell] == true
end

--- Returns visited cells as a stable, sorted array for candidate calculations.
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

--- Returns the number of unique level-grid cells visited in the current memory scope.
function Memory.getVisitedCount()
    return #Memory.getVisitedCells()
end

--- Permanently rejects a candidate for the current floor after physical or bomb validation fails.
function Memory.markCandidateAsBlocked(cell)
    blockedCandidateCells[cell] = true
end

--- Reports whether a candidate has already been ruled out on the current floor.
function Memory.isCandidateBlocked(cell)
    return blockedCandidateCells[cell] == true
end

return Memory
