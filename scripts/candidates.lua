local Grid = require("scripts.grid")

local Candidates = {}

local ROOM_BOSS = RoomType and RoomType.ROOM_BOSS or 5

function Candidates.getKnownNeighbors(cell, knownCells)
    local neighbors = {}
    local column = cell % Grid.LEVEL_GRID_WIDTH

    local upCell = cell - Grid.LEVEL_GRID_WIDTH
    local rightCell = cell + 1
    local downCell = cell + Grid.LEVEL_GRID_WIDTH
    local leftCell = cell - 1

    if upCell >= 0 and Grid.containsCell(knownCells, upCell) then
        table.insert(neighbors, { cell = upCell, direction = "down" })
    end

    if column < Grid.LEVEL_GRID_WIDTH - 1 and Grid.containsCell(knownCells, rightCell) then
        table.insert(neighbors, { cell = rightCell, direction = "left" })
    end

    if downCell < Grid.LEVEL_GRID_SIZE and Grid.containsCell(knownCells, downCell) then
        table.insert(neighbors, { cell = downCell, direction = "up" })
    end

    if column > 0 and Grid.containsCell(knownCells, leftCell) then
        table.insert(neighbors, { cell = leftCell, direction = "right" })
    end

    return neighbors
end

function Candidates.countKnownNeighbors(cell, knownCells)
    return #Candidates.getKnownNeighbors(cell, knownCells)
end

local function hasBossNeighbor(knownNeighbors, roomTypesByCell)
    if roomTypesByCell == nil then
        return false
    end

    for i, neighbor in ipairs(knownNeighbors) do
        if roomTypesByCell[neighbor.cell] == ROOM_BOSS then
            return true
        end
    end

    return false
end

local function addCandidateIfValid(candidatesByCell, candidateCell, knownCells, roomTypesByCell)
    if candidateCell == nil then
        return
    end

    if candidateCell < 0 or candidateCell >= Grid.LEVEL_GRID_SIZE then
        return
    end

    if Grid.containsCell(knownCells, candidateCell) then
        return
    end

    local knownNeighbors = Candidates.getKnownNeighbors(candidateCell, knownCells)
    local knownNeighborCount = #knownNeighbors

    if hasBossNeighbor(knownNeighbors, roomTypesByCell) then
        return
    end

    if knownNeighborCount >= 2 then
        candidatesByCell[candidateCell] = {
            knownNeighborCount = knownNeighborCount,
            knownNeighbors = knownNeighbors,
        }
    end
end

function Candidates.getTheoreticalSecretCandidates(knownCells, roomTypesByCell)
    local candidatesByCell = {}

    for i, knownCell in ipairs(knownCells) do
        local column = knownCell % Grid.LEVEL_GRID_WIDTH

        addCandidateIfValid(candidatesByCell, knownCell - Grid.LEVEL_GRID_WIDTH, knownCells, roomTypesByCell)

        if column < Grid.LEVEL_GRID_WIDTH - 1 then
            addCandidateIfValid(candidatesByCell, knownCell + 1, knownCells, roomTypesByCell)
        end

        addCandidateIfValid(candidatesByCell, knownCell + Grid.LEVEL_GRID_WIDTH, knownCells, roomTypesByCell)

        if column > 0 then
            addCandidateIfValid(candidatesByCell, knownCell - 1, knownCells, roomTypesByCell)
        end
    end

    local candidates = {}

    for cell, candidateData in pairs(candidatesByCell) do
        table.insert(candidates, {
            cell = cell,
            knownNeighborCount = candidateData.knownNeighborCount,
            knownNeighbors = candidateData.knownNeighbors,
        })
    end

    table.sort(candidates, function(a, b)
        if a.knownNeighborCount == b.knownNeighborCount then
            return a.cell < b.cell
        end

        return a.knownNeighborCount > b.knownNeighborCount
    end)

    return candidates
end

function Candidates.getCandidateSymbol(knownNeighborCount)
    if knownNeighborCount >= 3 then
        return "!"
    end

    return "?"
end

function Candidates.formatSecretCandidates(candidates)
    local parts = {}

    for i, candidate in ipairs(candidates) do
        local symbol = Candidates.getCandidateSymbol(candidate.knownNeighborCount)

        table.insert(
            parts,
            tostring(candidate.cell) ..
            ":" ..
            symbol ..
            "(" ..
            tostring(candidate.knownNeighborCount) ..
            ")"
        )
    end

    return table.concat(parts, ", ")
end

return Candidates
