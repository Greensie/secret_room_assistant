local RoomTypes = {}

RoomTypes.NAMES = {
    [RoomType.ROOM_DEFAULT] = "ROOM_DEFAULT",
    [RoomType.ROOM_SHOP] = "ROOM_SHOP",
    [RoomType.ROOM_TREASURE] = "ROOM_TREASURE",
    [RoomType.ROOM_BOSS] = "ROOM_BOSS",
    [RoomType.ROOM_MINIBOSS] = "ROOM_MINIBOSS",
    [RoomType.ROOM_SECRET] = "ROOM_SECRET",
    [RoomType.ROOM_SUPERSECRET] = "ROOM_SUPERSECRET",
    [RoomType.ROOM_ARCADE] = "ROOM_ARCADE",
    [RoomType.ROOM_CURSE] = "ROOM_CURSE",
    [RoomType.ROOM_CHALLENGE] = "ROOM_CHALLENGE",
    [RoomType.ROOM_LIBRARY] = "ROOM_LIBRARY",
    [RoomType.ROOM_SACRIFICE] = "ROOM_SACRIFICE",
    [RoomType.ROOM_DEVIL] = "ROOM_DEVIL",
    [RoomType.ROOM_ANGEL] = "ROOM_ANGEL",
    [RoomType.ROOM_PLANETARIUM] = "ROOM_PLANETARIUM",
    [RoomType.ROOM_ULTRASECRET] = "ROOM_ULTRASECRET",
}

function RoomTypes.getName(roomType)
    return RoomTypes.NAMES[roomType] or "UNKNOWN"
end

function RoomTypes.getShortName(roomType)
    local roomTypeName = RoomTypes.getName(roomType)

    return string.gsub(roomTypeName, "ROOM_", "")
end

return RoomTypes