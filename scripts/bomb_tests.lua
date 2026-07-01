----------------------------------------------------------------------------------------------------
--                 Matches explosions to candidate walls and validates distance.                  --
--                 Creates delayed checks that confirm whether a doorway opened.                  --
----------------------------------------------------------------------------------------------------

local BombTests = {}

BombTests.MAX_TEST_DISTANCE = 70
BombTests.EVALUATION_DELAY_FRAMES = 5

--- Finds the candidate wall nearest to an explosion and checks whether the blast was close enough.
function BombTests.findClosestCandidateWall(room, explosionPosition, candidateWalls)
    local closestResult = nil

    for i, wall in ipairs(candidateWalls or {}) do
        if wall.wallGridIndex ~= nil then
            local wallPosition = room:GetGridPosition(wall.wallGridIndex)
            local distance = explosionPosition:Distance(wallPosition)

            if closestResult == nil or distance < closestResult.distance then
                closestResult = {
                    candidateCell = wall.candidateCell,
                    direction = wall.direction,
                    distance = distance,
                    isValidDistance = distance <= BombTests.MAX_TEST_DISTANCE,
                    doorSlot = wall.doorSlot,
                }
            end
        end
    end

    return closestResult
end

--- Formats an initial bomb-distance evaluation for optional diagnostic output.
function BombTests.formatResult(result)
    if result == nil then
        return "no_candidate_wall"
    end

    local status = "TOO_FAR"

    if result.isValidDistance then
        status = "VALID"
    end

    return "candidate=" .. tostring(result.candidateCell) ..
        " direction=" .. result.direction ..
        " slot=" .. tostring(result.doorSlot or "?") ..
        " distance=" .. tostring(math.floor(result.distance + 0.5)) ..
        " " .. status
end

--- Creates a delayed test so door creation can be checked a few frames after the explosion.
function BombTests.createPendingTest(result, currentFrame)
    return {
        candidateCell = result.candidateCell,
        doorSlot = result.doorSlot,
        dueFrame = currentFrame + BombTests.EVALUATION_DELAY_FRAMES,
    }
end

--- Formats the final result of checking whether an explosion opened a door.
function BombTests.formatEvaluation(candidateCell, wasOpened)
    local status = "UNKNOWN"

    if wasOpened == true then
        status = "OPENED"
    elseif wasOpened == false then
        status = "FAILED"
    end

    return "candidate=" .. tostring(candidateCell) .. " " .. status
end

return BombTests
