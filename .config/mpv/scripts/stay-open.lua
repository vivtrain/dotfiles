-- Don't quit when the playlist runs out because a file failed to load (e.g. a truncated recording
-- that autoload queued): go back to the last video that played, at the same timestamp. The broken
-- entry stays queued (autoload re-adds anything removed), so j just bounces off it again.
-- Needs idle=yes (mpv.conf) so the player idles instead of exiting.
local good_id, good_time, restore_time

local function index_of(id)
    for i = 0, mp.get_property_number("playlist-count", 0) - 1 do
        if mp.get_property_number("playlist/" .. i .. "/id") == id then return i end
    end
end

mp.observe_property("time-pos", "number", function(_, t)
    if t then good_time = t end
end)

mp.register_event("file-loaded", function()
    local pos = mp.get_property_number("playlist-pos", -1)
    good_id = mp.get_property_number("playlist/" .. pos .. "/id")
    if restore_time then
        mp.commandv("seek", restore_time, "absolute+exact")
        restore_time = nil
    end
end)

mp.observe_property("idle-active", "bool", function(_, idle)
    if not (idle and good_id) then return end
    local i = index_of(good_id)
    if i then
        restore_time = good_time
        mp.commandv("playlist-play-index", i)
    end
end)
