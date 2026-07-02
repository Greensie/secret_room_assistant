----------------------------------------------------------------------------------------------------
--                 Builds fair-play Secret Room candidates from known map cells.                  --
--                 Ranks locations and rejects topology forbidden by room types.                  --
----------------------------------------------------------------------------------------------------

local Grid = require("scripts.grid")

local Candidates = {}

local ROOM_BOSS = RoomType and RoomType.ROOM_BOSS or 5
local ROOM_SUPERSECRET = RoomType and RoomType.ROOM_SUPERSECRET or 8

--- Returns known orthogonal neighbors and the wall direction facing the candidate cell.
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

--- Counts how many player-known cells touch a potential Secret Room location.
function Candidates.countKnownNeighbors(cell, knownCells)
    return #Candidates.getKnownNeighbors(cell, knownCells)
end

--- Rejects locations touching a Boss Room because Secret Rooms cannot connect to one.
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

--- Rejects locations touching a known Super Secret Room.
local function hasSuperSecretNeighbor(knownNeighbors, roomTypesByCell)
    if roomTypesByCell == nil then
        return false
    end

    for i, neighbor in ipairs(knownNeighbors) do
        if roomTypesByCell[neighbor.cell] == ROOM_SUPERSECRET then
            return true
        end
    end

    return false
end

--- Marks locations touching a known narrow room shape as impossible.
local function hasNarrowRoomNeighbor(knownNeighbors, roomShapesByCell)
    if roomShapesByCell == nil then
        return false
    end

    for i, neighbor in ipairs(knownNeighbors) do
        if Grid.isNarrowRoomShape(roomShapesByCell[neighbor.cell]) then
            return true
        end
    end

    return false
end

--- Adds an empty cell once it satisfies the basic topology and room-type rules.
local function addCandidateIfValid(candidatesByCell, candidateCell, knownCells, roomTypesByCell, roomShapesByCell)
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

    if hasSuperSecretNeighbor(knownNeighbors, roomTypesByCell) then
        return
    end

    if knownNeighborCount >= 2 then
        candidatesByCell[candidateCell] = {
            isBlocked = hasNarrowRoomNeighbor(knownNeighbors, roomShapesByCell),
            knownNeighborCount = knownNeighborCount,
            knownNeighbors = knownNeighbors,
        }
    end
end

--- Builds and ranks all plausible Secret Room cells using only information available to the player.
function Candidates.getTheoreticalSecretCandidates(knownCells, roomTypesByCell, roomShapesByCell)
    local candidatesByCell = {}

    for i, knownCell in ipairs(knownCells) do
        local column = knownCell % Grid.LEVEL_GRID_WIDTH

        addCandidateIfValid(candidatesByCell, knownCell - Grid.LEVEL_GRID_WIDTH, knownCells, roomTypesByCell, roomShapesByCell)

        if column < Grid.LEVEL_GRID_WIDTH - 1 then
            addCandidateIfValid(candidatesByCell, knownCell + 1, knownCells, roomTypesByCell, roomShapesByCell)
        end

        addCandidateIfValid(candidatesByCell, knownCell + Grid.LEVEL_GRID_WIDTH, knownCells, roomTypesByCell, roomShapesByCell)

        if column > 0 then
            addCandidateIfValid(candidatesByCell, knownCell - 1, knownCells, roomTypesByCell, roomShapesByCell)
        end
    end

    local candidates = {}

    for cell, candidateData in pairs(candidatesByCell) do
        table.insert(candidates, {
            cell = cell,
            isBlocked = candidateData.isBlocked,
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

--- Maps candidate confidence and blocked state to the symbol shown by the UI.
function Candidates.getCandidateSymbol(knownNeighborCount, isBlocked)
    if isBlocked then
        return "x"
    end

    if knownNeighborCount >= 3 then
        return "!"
    end

    return "?"
end

--- Produces a compact candidate list for verbose diagnostics.
function Candidates.formatSecretCandidates(candidates)
    local parts = {}

    for i, candidate in ipairs(candidates) do
        local symbol = Candidates.getCandidateSymbol(
            candidate.knownNeighborCount,
            candidate.isBlocked
        )

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
