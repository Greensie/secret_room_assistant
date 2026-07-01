----------------------------------------------------------------------------------------------------
--                  Owns optional diagnostic formatting, logging, and rendering.                  --
--                  Stays disabled in release builds to avoid runtime overhead.                   --
----------------------------------------------------------------------------------------------------

local RoomTypes = require("scripts.room_types")
local Grid = require("scripts.grid")
local Candidates = require("scripts.candidates")
local WallAccess = require("scripts.wall_access")
local BombTests = require("scripts.bomb_tests")

local DebugHelper = {}

local ENABLED = false
local candidateText = ""
local wallText = ""
local checkText = ""
local bombText = ""

--- Clears all optional on-screen diagnostic text.
function DebugHelper.reset()
    candidateText = ""
    wallText = ""
    checkText = ""
    bombText = ""
end

--- Writes one prefixed message only when verbose diagnostics are enabled.
function DebugHelper.log(message)
    if not ENABLED then
        return
    end

    Isaac.DebugString("[secret room assistant] " .. message)
end

--- Clears bomb diagnostics when entering another room.
function DebugHelper.clearBomb()
    if ENABLED then
        bombText = ""
    end
end

--- Formats and stores a complete room snapshot for logs and the debug overlay.
function DebugHelper.captureRoom(context)
    if not ENABLED then
        return
    end

    local roomTypeText = "nil"
    local roomShapeText = "nil"
    local roomDesc = context.roomDesc

    if roomDesc.Data ~= nil then
        roomTypeText = RoomTypes.getShortName(roomDesc.Data.Type)
        roomShapeText = tostring(roomDesc.Data.Shape)
    end

    candidateText = Candidates.formatSecretCandidates(context.candidates)
    wallText = WallAccess.formatCandidateWalls(context.walls)
    checkText = WallAccess.formatCandidateWallChecks(context.checks)

    DebugHelper.log(
        "idx=" .. tostring(roomDesc.GridIndex) ..
        " type=" .. roomTypeText ..
        " cand=[" .. candidateText .. "]" ..
        " walls=[" .. wallText .. "]" ..
        " checks=[" .. checkText .. "]" ..
        " visited=" .. tostring(#context.visitedCells) ..
        " known=" .. tostring(#context.knownCells) ..
        " cur=" .. tostring(context.currentRoomIndex) ..
        " shape=" .. roomShapeText ..
        " stage=" .. tostring(context.stage) ..
        " stageType=" .. tostring(context.stageType) ..
        " dimension=" .. tostring(context.dimension) ..
        " secretAllowed=" .. tostring(context.secretAllowed) ..
        " secretReason=" .. context.secretReason ..
        " occ=[" .. Grid.joinCells(context.occupiedCells) .. "]" ..
        " n={u:[" .. Grid.joinCells(context.neighborCells.up) ..
        "] r:[" .. Grid.joinCells(context.neighborCells.right) ..
        "] d:[" .. Grid.joinCells(context.neighborCells.down) ..
        "] l:[" .. Grid.joinCells(context.neighborCells.left) .. "]}" ..
        " visible=[" .. Grid.joinCells(context.visibleCells) .. "]"
    )
end

--- Records the initial distance evaluation for a bomb explosion.
function DebugHelper.captureBombResult(result)
    if not ENABLED then
        return
    end

    if result == nil then
        DebugHelper.log("bomb ignored: no candidate wall")
        return
    end

    bombText = BombTests.formatResult(result)
    DebugHelper.log("bomb=" .. bombText)
end

--- Records whether a valid bomb test opened the expected doorway.
function DebugHelper.captureBombEvaluation(candidateCell, wasOpened, candidates)
    if not ENABLED then
        return
    end

    candidateText = Candidates.formatSecretCandidates(candidates)
    bombText = BombTests.formatEvaluation(candidateCell, wasOpened)
    DebugHelper.log("bombResult=" .. bombText)
end

--- Draws the optional developer overlay without affecting release gameplay.
function DebugHelper.render()
    if not ENABLED then
        return
    end

    Isaac.RenderText("SRA cand: " .. candidateText, 60, 32, 1, 1, 1, 1)
    Isaac.RenderText("SRA walls: " .. wallText, 60, 42, 1, 1, 1, 1)
    Isaac.RenderText("SRA checks: " .. checkText, 60, 52, 1, 1, 1, 1)
    Isaac.RenderText("SRA bomb: " .. bombText, 60, 62, 1, 1, 1, 1)
end

--- Registers the debug render callback only for an explicitly enabled development build.
function DebugHelper.register(mod)
    if ENABLED then
        mod:AddCallback(ModCallbacks.MC_POST_RENDER, DebugHelper.render)
    end
end

return DebugHelper
