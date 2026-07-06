local mod = RegisterMod("secret room assistant", 1)
local Grid = require("scripts.grid")
local Memory = require("scripts.memory")
local Candidates = require("scripts.candidates")
local KnownRooms = require("scripts.known_rooms")
local StageRules = require("scripts.stage_rules")
local WallAccess = require("scripts.wall_access")
local BombTests = require("scripts.bomb_tests")
local MinimapOverlay = require("scripts.minimap_overlay")
local DebugHelper = require("scripts.debug_helper")

local lastStage = nil
local lastStageType = nil
local lastDimension = nil
local lastLayoutSignature = nil
local currentCandidateWalls = {}
local currentSecretCandidates = {}
local pendingBombTests = {}
local ROOM_SECRET = RoomType and RoomType.ROOM_SECRET or 7
local PILLEFFECT_SEE_FOREVER = PillEffect and PillEffect.PILLEFFECT_SEE_FOREVER or 23

--- Clears every candidate once another effect reveals Secret Room entrances.
local function suppressCandidateHints()
    currentCandidateWalls = {}
    currentSecretCandidates = {}
    pendingBombTests = {}
    MinimapOverlay.clear()
end

--- Returns whether the current floor no longer needs Secret Room candidate hints.
local function shouldSuppressCandidateHints(game, level)
    return Memory.wasSeeForeverUsed() or
        StageRules.hasAutomaticSecretRoomReveal(game, level)
end

--- Resets all run-local state when a game starts or a saved run is resumed.
function mod:OnGameStart(isContinued)
    Memory.reset()
    lastStage = nil
    lastStageType = nil
    lastDimension = nil
    lastLayoutSignature = nil
    DebugHelper.reset()
    MinimapOverlay.clear()
    currentCandidateWalls = {}
    currentSecretCandidates = {}
    pendingBombTests = {}
    DebugHelper.log("mod loaded")
end

--- Builds a stable fingerprint for detecting same-stage floor rerolls such as Dice Room D5.
local function getLayoutSignature(level, dimension)
    local parts = {}
    local rooms = level:GetRooms()

    for i = 0, rooms.Size - 1 do
        local roomDesc = rooms:Get(i)

        if roomDesc ~= nil and
            roomDesc.Data ~= nil and
            KnownRooms.getRoomDimension(level, roomDesc) == dimension
        then
            table.insert(
                parts,
                tostring(roomDesc.ListIndex) ..
                ":" ..
                tostring(roomDesc.SafeGridIndex or roomDesc.GridIndex) ..
                ":" ..
                tostring(roomDesc.Data.Type) ..
                ":" ..
                tostring(roomDesc.Data.Shape) ..
                ":" ..
                tostring(roomDesc.DecorationSeed)
            )
        end
    end

    table.sort(parts)

    return table.concat(parts, "|")
end

--- Rebuilds fair-play candidates and physically validates the current room's reachable walls.
function mod:OnNewRoom()
    local game = Game()
    local level = game:GetLevel()
    DebugHelper.clearBomb()
    local roomDesc = level:GetCurrentRoomDesc()
    local currentRoomIndex = level:GetCurrentRoomIndex()
    local stage = level:GetStage()
    local stageType = level:GetStageType()
    local dimension = KnownRooms.getCurrentDimension(level)
    local layoutSignature = getLayoutSignature(level, dimension)
    local secretAllowed = StageRules.canHaveSecretRoom(level)
    local secretReason = StageRules.getSecretRoomRuleReason(level)

    if stage ~= lastStage or
        stageType ~= lastStageType or
        dimension ~= lastDimension or
        layoutSignature ~= lastLayoutSignature
    then
        Memory.reset()
        pendingBombTests = {}
        MinimapOverlay.clear(lastDimension)
        lastStage = stage
        lastStageType = stageType
        lastDimension = dimension
        lastLayoutSignature = layoutSignature
        Memory.setExpectedSecretRoomCount(
            secretAllowed and StageRules.getExpectedSecretRoomCount(game) or 0
        )
        DebugHelper.log("level memory reset")
    end

    local occupiedCells = Grid.getOccupiedCells(roomDesc)

    if KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc) then
        Memory.markCellsAsVisited(occupiedCells)
    end

    local neighborCells = Grid.getNeighborCellsByDirection(roomDesc)
    local visitedCells = Memory.getVisitedCells()
    local visibleCells = KnownRooms.getVisibleCells(level, dimension)
    local roomTypesByCell = KnownRooms.getVisibleRoomTypesByCell(level, dimension)
    local roomShapesByCell = KnownRooms.getVisibleRoomShapesByCell(level, dimension)

    if KnownRooms.isDescriptorRelevantForSecretRoomSearch(level, roomDesc) then
        for i, cell in ipairs(occupiedCells) do
            roomTypesByCell[cell] = roomDesc.Data.Type
            roomShapesByCell[cell] = roomDesc.Data.Shape
        end
    end

    for cell, roomType in pairs(roomTypesByCell) do
        if roomType == ROOM_SECRET then
            Memory.markSecretRoomAsFound(cell)
        end
    end

    local knownCells = Grid.mergeUniqueCells(visitedCells, visibleCells)
    local secretCandidates = Candidates.getTheoreticalSecretCandidates(knownCells, roomTypesByCell, roomShapesByCell)

    if not secretAllowed or
        not Memory.hasRemainingSecretRooms() or
        shouldSuppressCandidateHints(game, level)
    then
        secretCandidates = {}
    end

    local room = game:GetRoom()
    local candidateWalls = WallAccess.getCandidateWallsForRoom(room, roomDesc, occupiedCells, secretCandidates)
    local candidateWallChecks = WallAccess.getCandidateWallChecks(room, candidateWalls)
    currentCandidateWalls = candidateWalls
    currentSecretCandidates = secretCandidates

    for i, check in ipairs(candidateWallChecks) do
        if check.approachStatus == "BLOCKED" then
            Memory.markCandidateAsBlocked(check.candidateCell)
        end
    end

    for i, candidate in ipairs(secretCandidates) do
        candidate.isBlocked = candidate.isBlocked or Memory.isCandidateBlocked(candidate.cell)
    end

    MinimapOverlay.sync(secretCandidates, dimension)
    DebugHelper.captureRoom({
        roomDesc = roomDesc,
        currentRoomIndex = currentRoomIndex,
        stage = stage,
        stageType = stageType,
        dimension = dimension,
        secretAllowed = secretAllowed,
        secretReason = secretReason,
        occupiedCells = occupiedCells,
        neighborCells = neighborCells,
        visibleCells = visibleCells,
        visitedCells = visitedCells,
        knownCells = knownCells,
        candidates = secretCandidates,
        walls = candidateWalls,
        checks = candidateWallChecks,
    })
end

--- Starts a delayed candidate test when an explosion is close enough to a relevant wall.
local function processBombExplosion(position)
    local room = Game():GetRoom()
    local result = BombTests.findClosestCandidateWall(
        room,
        position,
        currentCandidateWalls
    )

    if result == nil then
        DebugHelper.captureBombResult(nil)
        return
    end

    DebugHelper.captureBombResult(result)

    if result.isValidDistance then
        pendingBombTests[result.candidateCell] = BombTests.createPendingTest(
            result,
            Game():GetFrameCount()
        )
    end
end

--- Converts the bomb explosion callback into a position-based candidate test.
function mod:OnBombExplosion(effect)
    processBombExplosion(effect.Position)
end

--- Resolves pending bomb tests after doors have had time to appear in the room.
function mod:OnPostUpdate()
    local game = Game()
    local currentFrame = game:GetFrameCount()

    if shouldSuppressCandidateHints(game, game:GetLevel()) and
        #currentSecretCandidates > 0
    then
        suppressCandidateHints()
        return
    end

    for candidateCell, pendingTest in pairs(pendingBombTests) do
        if currentFrame >= pendingTest.dueFrame then
            local door = nil
            local wasOpened = nil

            if pendingTest.doorSlot ~= nil then
                door = game:GetRoom():GetDoor(pendingTest.doorSlot)
                wasOpened = door ~= nil
            end

            if wasOpened == false then
                Memory.markCandidateAsBlocked(candidateCell)

                for i, candidate in ipairs(currentSecretCandidates) do
                    if candidate.cell == candidateCell then
                        candidate.isBlocked = true
                    end
                end

                MinimapOverlay.sync(currentSecretCandidates, lastDimension)
            end

            DebugHelper.captureBombEvaluation(
                candidateCell,
                wasOpened,
                currentSecretCandidates
            )

            pendingBombTests[candidateCell] = nil
        end
    end
end

--- Hides candidate markers immediately after I Can See Forever is used.
function mod:OnUsePill(pillEffect)
    if pillEffect == PILLEFFECT_SEE_FOREVER then
        Memory.markSeeForeverAsUsed()
        suppressCandidateHints()
    end
end

--- Removes MinimapAPI proxy rooms before the library serializes its save data.
function mod:OnPreGameExit()
    MinimapOverlay.clear()
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStart)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoom)
DebugHelper.register(mod)

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnPostUpdate)
mod:AddCallback(ModCallbacks.MC_USE_PILL, mod.OnUsePill)
mod:AddPriorityCallback(
    ModCallbacks.MC_PRE_GAME_EXIT,
    CallbackPriority.IMPORTANT - 2,
    mod.OnPreGameExit
)
mod:AddCallback(
    ModCallbacks.MC_POST_EFFECT_INIT,
    mod.OnBombExplosion,
    EffectVariant.BOMB_EXPLOSION
)
