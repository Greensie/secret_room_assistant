----------------------------------------------------------------------------------------------------
--                  Synchronizes candidate markers with native MinimapAPI icons.                  --
--                 Uses icon-only proxy rooms without revealing hidden geometry.                  --
----------------------------------------------------------------------------------------------------

local MinimapOverlay = {}

local LEGACY_MARKER_ID_PREFIX = "SRA_Candidate_"
local PROXY_SHAPE_ID = "SRA_CandidateProxy"
local ICON_ID_STRONG = "SRA_CandidateStrong"
local ICON_ID_POSSIBLE = "SRA_CandidatePossible"
local ICON_ID_BLOCKED = "SRA_CandidateBlocked"
local PROXY_ROOM_TYPE = RoomType and RoomType.ROOM_ULTRASECRET or 29
local ZERO_VECTOR = Vector(0, 0)

local initialized = false
local iconSprite = nil

--- Identifies proxy rooms owned by this mod using their stable ID prefix.
local function isCandidateRoom(room)
    return type(room.ID) == "string" and
        string.sub(room.ID, 1, #LEGACY_MARKER_ID_PREFIX) == LEGACY_MARKER_ID_PREFIX
end

--- Detaches a proxy room from cached MinimapAPI adjacency before removing it.
local function removeAdjacentRoomRefs(room)
    if room.AdjacentRooms == nil then
        return
    end

    for i, adjacentRoom in ipairs(room.AdjacentRooms) do
        if adjacentRoom.RemoveAdjacentRoom ~= nil then
            adjacentRoom:RemoveAdjacentRoom(room)
        end
    end
end

--- Removes current and legacy candidate proxy rooms from every MinimapAPI dimension.
local function cleanupCandidateRooms(dimensionToClean)
    for dimension, level in pairs(MinimapAPI.Levels or {}) do
        if dimensionToClean == nil or dimension == dimensionToClean then
            for i = #level, 1, -1 do
                local room = level[i]

                if isCandidateRoom(room) then
                    removeAdjacentRoomRefs(room)
                    table.remove(level, i)
                end
            end
        end
    end
end

--- Registers marker sprites and an icon-only proxy shape once MinimapAPI is available.
local function tryInitialize()
    if initialized then
        return true
    end

    if MinimapAPI == nil then
        return false
    end

    iconSprite = Sprite()
    iconSprite:Load("gfx/ui/sra_minimap_icons.anm2", true)
    MinimapAPI:AddIcon(ICON_ID_STRONG, iconSprite, "Strong", 0)
    MinimapAPI:AddIcon(ICON_ID_POSSIBLE, iconSprite, "Possible", 0)
    MinimapAPI:AddIcon(ICON_ID_BLOCKED, iconSprite, "Blocked", 0)
    MinimapAPI:AddRoomShape(
        PROXY_SHAPE_ID,
        {},
        {},
        ZERO_VECTOR,
        Vector(1, 1),
        {},
        {},
        ZERO_VECTOR,
        {},
        Vector(0.25, 0.25),
        {},
        nil
    )
    cleanupCandidateRooms()

    initialized = true
    return true
end

--- Selects the MinimapAPI icon matching candidate confidence or rejection state.
local function getCandidateIcon(candidate)
    if candidate.isBlocked then
        return ICON_ID_BLOCKED
    end

    if candidate.knownNeighborCount >= 3 then
        return ICON_ID_STRONG
    end

    return ICON_ID_POSSIBLE
end

--- Removes all current or legacy candidate proxy rooms from MinimapAPI.
function MinimapOverlay.clear(dimension)
    if MinimapAPI ~= nil then
        cleanupCandidateRooms(dimension)
    end
end

--- Replaces icon-only candidate proxies and delegates positioning and rendering to MinimapAPI.
function MinimapOverlay.sync(candidates, dimension)
    if not tryInitialize() then
        return false
    end

    cleanupCandidateRooms(dimension)

    for i, candidate in ipairs(candidates) do
        MinimapAPI:AddRoom({
            Position = MinimapAPI:GridIndexToVector(candidate.cell),
            ID = LEGACY_MARKER_ID_PREFIX .. tostring(candidate.cell),
            Type = PROXY_ROOM_TYPE,
            Shape = PROXY_SHAPE_ID,
            PermanentIcons = {getCandidateIcon(candidate)},
            DisplayFlags = 4,
            NoUpdate = true,
            IgnoreDescriptorFlags = true,
            Dimension = dimension or MinimapAPI.CurrentDimension,
        })
    end

    return true
end

return MinimapOverlay
