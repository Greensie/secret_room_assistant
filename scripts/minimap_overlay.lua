local MinimapOverlay = {}

local LEGACY_MARKER_ID_PREFIX = "SRA_Candidate_"
local SMALL_ROOM_SIZE = Vector(8, 7)
local LARGE_ROOM_SIZE = Vector(17, 15)
local ZERO_VECTOR = Vector(0, 0)
local SMALL_ICON_SCALE = 0.38
local LARGE_ICON_SCALE = 0.7

local initialized = false
local iconSprite = nil
local candidateMarkers = {}

local function cleanupLegacyRooms()
    local level = MinimapAPI:GetLevel()

    if level == nil then
        return
    end

    local markerIds = {}

    for i, room in ipairs(level) do
        if type(room.ID) == "string" and
            string.sub(room.ID, 1, #LEGACY_MARKER_ID_PREFIX) == LEGACY_MARKER_ID_PREFIX
        then
            table.insert(markerIds, room.ID)
        end
    end

    for i, markerId in ipairs(markerIds) do
        MinimapAPI:RemoveRoomByID(markerId)
    end
end

local function tryInitialize()
    if initialized then
        return true
    end

    if MinimapAPI == nil then
        return false
    end

    iconSprite = Sprite()
    iconSprite:Load("gfx/ui/sra_minimap_icons.anm2", true)
    cleanupLegacyRooms()

    initialized = true
    return true
end

local function getCandidateAnimation(candidate)
    if candidate.isBlocked then
        return "Blocked"
    end

    if candidate.knownNeighborCount >= 3 then
        return "Strong"
    end

    return "Possible"
end

local function findVisibleAnchorRoom(candidate)
    for i, neighbor in ipairs(candidate.knownNeighbors or {}) do
        local neighborPosition = MinimapAPI:GridIndexToVector(neighbor.cell)
        local room = MinimapAPI:GetRoomAtPosition(neighborPosition)

        if room ~= nil and room.RenderOffset ~= nil and room:IsVisible() then
            return room
        end
    end

    return nil
end

function MinimapOverlay.clear()
    candidateMarkers = {}

    if MinimapAPI ~= nil then
        cleanupLegacyRooms()
    end
end

function MinimapOverlay.sync(candidates)
    if not tryInitialize() then
        return false
    end

    candidateMarkers = {}

    for i, candidate in ipairs(candidates) do
        table.insert(candidateMarkers, {
            cell = candidate.cell,
            knownNeighborCount = candidate.knownNeighborCount,
            knownNeighbors = candidate.knownNeighbors,
            isBlocked = candidate.isBlocked,
        })
    end

    return true
end


function MinimapOverlay.render()
    if not tryInitialize() or #candidateMarkers == 0 then
        return
    end

    local isLarge = MinimapAPI:IsLarge()
    local roomSize = isLarge and LARGE_ROOM_SIZE or SMALL_ROOM_SIZE
    local iconScale = isLarge and LARGE_ICON_SCALE or SMALL_ICON_SCALE
    local globalScaleX = MinimapAPI.GlobalScaleX or 1

    for i, candidate in ipairs(candidateMarkers) do
        local anchorRoom = findVisibleAnchorRoom(candidate)

        if anchorRoom ~= nil then
            local candidatePosition = MinimapAPI:GridIndexToVector(candidate.cell)
            local delta = candidatePosition - anchorRoom.Position
            local renderPosition = anchorRoom.RenderOffset + Vector(
                delta.X * roomSize.X * globalScaleX,
                delta.Y * roomSize.Y
            )

            iconSprite:SetFrame(getCandidateAnimation(candidate), 0)
            iconSprite.Scale = Vector(iconScale * globalScaleX, iconScale)
            iconSprite.Color = Color(
                1,
                1,
                1,
                MinimapAPI:GetTransparency(),
                0,
                0,
                0
            )
            iconSprite:Render(renderPosition, ZERO_VECTOR, ZERO_VECTOR)
        end
    end
end


return MinimapOverlay
