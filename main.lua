local mod = RegisterMod("secret room assistant", 1)
local RoomTypes = require("scripts.room_types")
local Grid = require("scripts.grid")
local Memory = require("scripts.memory")
local Candidates = require("scripts.candidates")
local KnownRooms = require("scripts.known_rooms")
local StageRules = require("scripts.stage_rules")
local WallAccess = require("scripts.wall_access")

local lastStage = nil
local lastStageType = nil
local renderCandidateText = ""
local renderWallText = ""
local renderCheckText = ""
local DEBUG_VERBOSE = false

function mod:OnGameStart(isContinued)
    Memory.reset()
    lastStage = nil
    lastStageType = nil
    renderCandidateText = ""
    renderWallText = ""
    renderCheckText = ""
    Isaac.DebugString("[secret room assistant] mod loaded")
end

function mod:OnNewRoom()
    local game = Game()
    local level = game:GetLevel()
    local roomDesc = level:GetCurrentRoomDesc()
    local currentRoomIndex = level:GetCurrentRoomIndex()
    local stage = level:GetStage()
    local stageType = level:GetStageType()
    local secretAllowed = StageRules.canHaveSecretRoom(level)
    local secretReason = StageRules.getSecretRoomRuleReason(level)

    if stage ~= lastStage or stageType ~= lastStageType then
        Memory.reset()
        lastStage = stage
        lastStageType = stageType
        Isaac.DebugString("[secret room assistant] level memory reset")
    end

    local occupiedCells = Grid.getOccupiedCells(roomDesc)

    if roomDesc.Data ~= nil and KnownRooms.isRelevantForSecretRoomSearch(roomDesc.Data.Type) then
        Memory.markCellsAsVisited(occupiedCells)
    end

    local neighborCells = Grid.getNeighborCellsByDirection(roomDesc)
    local visitedCells = Memory.getVisitedCells()
    local visibleCells = KnownRooms.getVisibleCells(level)
    local roomTypesByCell = KnownRooms.getVisibleRoomTypesByCell(level)

    if roomDesc.Data ~= nil then
        for i, cell in ipairs(occupiedCells) do
            roomTypesByCell[cell] = roomDesc.Data.Type
        end
    end

    local knownCells = Grid.mergeUniqueCells(visitedCells, visibleCells)
    local secretCandidates = Candidates.getTheoreticalSecretCandidates(knownCells, roomTypesByCell)

    if not secretAllowed then
        secretCandidates = {}
    end

    local candidateWalls = WallAccess.getCandidateWallsForRoom(roomDesc, occupiedCells, secretCandidates)
    local candidateWallChecks = WallAccess.getCandidateWallChecks(game:GetRoom(), candidateWalls)
    renderCandidateText = Candidates.formatSecretCandidates(secretCandidates)
    renderWallText = WallAccess.formatCandidateWalls(candidateWalls)
    renderCheckText = WallAccess.formatCandidateWallChecks(candidateWallChecks)

    local roomTypeText = "nil"
    local roomShapeText = "nil"

    if roomDesc.Data ~= nil then
        local roomType = roomDesc.Data.Type
        roomTypeText = RoomTypes.getShortName(roomType)
        roomShapeText = tostring(roomDesc.Data.Shape)
    end

    local verboseLogText = ""

    if DEBUG_VERBOSE then
        verboseLogText =
            " cur=" .. tostring(currentRoomIndex) ..
            " shape=" .. roomShapeText ..
            " stage=" .. tostring(stage) ..
            " stageType=" .. tostring(stageType) ..
            " secretAllowed=" .. tostring(secretAllowed) ..
            " secretReason=" .. secretReason ..
            " occ=[" .. Grid.joinCells(occupiedCells) .. "]" ..
            " n={u:[" .. Grid.joinCells(neighborCells.up) ..
            "] r:[" .. Grid.joinCells(neighborCells.right) ..
            "] d:[" .. Grid.joinCells(neighborCells.down) ..
            "] l:[" .. Grid.joinCells(neighborCells.left) .. "]}" ..
            " visible=[" .. Grid.joinCells(visibleCells) .. "]"
    end

    Isaac.DebugString(
        "[secret room assistant] " ..
        "idx=" .. tostring(roomDesc.GridIndex) ..
        " type=" .. roomTypeText ..
        " cand=[" .. Candidates.formatSecretCandidates(secretCandidates) .. "]" ..
        " walls=[" .. WallAccess.formatCandidateWalls(candidateWalls) .. "]" ..
        " checks=[" .. WallAccess.formatCandidateWallChecks(candidateWallChecks) .. "]" ..
        " visited=" .. tostring(#visitedCells) ..
        " known=" .. tostring(#knownCells) ..
        verboseLogText
    )
end

function mod:OnRender()
    Isaac.RenderText("SRA cand: " .. renderCandidateText, 60, 32, 1, 1, 1, 1)
    Isaac.RenderText("SRA walls: " .. renderWallText, 60, 42, 1, 1, 1, 1)
    Isaac.RenderText("SRA checks: " .. renderCheckText, 60, 52, 1, 1, 1, 1)
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStart)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.OnRender)
