local StageRules = {}

local STAGE_VOID = LevelStage and LevelStage.STAGE7 or 12
local STAGE_HOME = LevelStage and LevelStage.STAGE8 or 13

function StageRules.getSecretRoomRuleReason(level)
    local stage = level:GetStage()

    if stage == STAGE_VOID then
        return "void_no_standard_secret"
    end

    if stage == STAGE_HOME then
        return "home_no_standard_secret"
    end

    return "normal"
end

function StageRules.canHaveSecretRoom(level)
    return StageRules.getSecretRoomRuleReason(level) == "normal"
end

return StageRules
