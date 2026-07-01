----------------------------------------------------------------------------------------------------
--                  Defines floors where standard Secret Rooms may be generated.                  --
--                  Counts room bonuses and detects effects that reveal secrets.                  --
----------------------------------------------------------------------------------------------------

local StageRules = {}

local STAGE_HOME = LevelStage and LevelStage.STAGE8 or 13
local DIMENSION_NORMAL = Dimension and Dimension.NORMAL or 0
local ROOM_SECRET = RoomType and RoomType.ROOM_SECRET or 7
local COLLECTIBLE_LUNA = CollectibleType and CollectibleType.COLLECTIBLE_LUNA or 589
local TRINKET_FRAGMENTED_CARD = TrinketType and TrinketType.TRINKET_FRAGMENTED_CARD or 102
local COLLECTIBLE_XRAY_VISION = CollectibleType and CollectibleType.COLLECTIBLE_XRAY_VISION or 76
local COLLECTIBLE_BLUE_MAP = CollectibleType and CollectibleType.COLLECTIBLE_BLUE_MAP or 246
local COLLECTIBLE_MIND = CollectibleType and CollectibleType.COLLECTIBLE_MIND or 333
local STATE_BLUE_MAP_EFFECT = LevelStateFlag and LevelStateFlag.STATE_BLUE_MAP_EFFECT or 9
local STATE_FULL_MAP_EFFECT = LevelStateFlag and LevelStateFlag.STATE_FULL_MAP_EFFECT or 10
local CHALLENGE_NULL = Challenge and Challenge.CHALLENGE_NULL or 0

--- Reads the active challenge ID across Isaac API variants.
local function getCurrentChallenge()
    if Isaac.GetChallenge ~= nil then
        return Isaac.GetChallenge()
    end

    return Game().Challenge or CHALLENGE_NULL
end

--- Reads Repentogon challenge room filters when available.
local function getChallengeRoomFilter(game)
    if game.GetChallengeParams == nil then
        return nil
    end

    local ok, challengeParams = pcall(function()
        return game:GetChallengeParams()
    end)

    if not ok or challengeParams == nil or challengeParams.GetRoomFilter == nil then
        return nil
    end

    local filterOk, roomFilter = pcall(function()
        return challengeParams:GetRoomFilter()
    end)

    if filterOk then
        return roomFilter
    end

    return nil
end

--- Checks whether a challenge room filter explicitly includes one room type.
local function roomFilterContains(roomFilter, roomType)
    if type(roomFilter) ~= "table" then
        return false
    end

    for i, filteredRoomType in ipairs(roomFilter) do
        if filteredRoomType == roomType then
            return true
        end
    end

    return false
end

--- Returns whether the active challenge explicitly filters standard Secret Rooms out.
function StageRules.isChallengeWithoutSecretRooms(game)
    if getCurrentChallenge() == CHALLENGE_NULL then
        return false
    end

    local roomFilter = getChallengeRoomFilter(game)

    if type(roomFilter) ~= "table" or #roomFilter == 0 then
        return false
    end

    return roomFilterContains(roomFilter, ROOM_SECRET)
end

--- Explains whether the current floor can generate a standard Secret Room.
function StageRules.getSecretRoomRuleReason(level)
    local game = Game()

    if game:IsGreedMode() then
        return "greed_fixed_layout"
    end

    if StageRules.isChallengeWithoutSecretRooms(game) then
        return "challenge_no_standard_secret"
    end

    local stage = level:GetStage()

    if level.GetDimension ~= nil and level:GetDimension() ~= DIMENSION_NORMAL then
        return "non_normal_dimension"
    end

    if stage == STAGE_HOME then
        return "home_no_standard_secret"
    end

    return "normal"
end

--- Returns true only on floors where standard Secret Room candidates are meaningful.
function StageRules.canHaveSecretRoom(level)
    return StageRules.getSecretRoomRuleReason(level) == "normal"
end

--- Counts standard Secret Rooms generated from the players' floor-start bonuses.
function StageRules.getExpectedSecretRoomCount(game)
    local count = 1

    for playerIndex = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(playerIndex)
        count = count + player:GetCollectibleNum(COLLECTIBLE_LUNA, true)
        count = count + player:GetTrinketMultiplier(TRINKET_FRAGMENTED_CARD)
    end

    return count
end

--- Returns whether mapping or X-Ray effects already reveal standard Secret Room locations.
function StageRules.hasAutomaticSecretRoomReveal(game, level)
    if level:GetStateFlag(STATE_BLUE_MAP_EFFECT) or
        level:GetStateFlag(STATE_FULL_MAP_EFFECT)
    then
        return true
    end

    for playerIndex = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(playerIndex)
        local effects = player:GetEffects()

        if player:HasCollectible(COLLECTIBLE_BLUE_MAP) or
            player:HasCollectible(COLLECTIBLE_MIND) or
            player:HasCollectible(COLLECTIBLE_XRAY_VISION) or
            effects:HasCollectibleEffect(COLLECTIBLE_XRAY_VISION)
        then
            return true
        end
    end

    return false
end

return StageRules
