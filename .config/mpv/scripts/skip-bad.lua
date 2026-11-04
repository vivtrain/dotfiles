-- Check each file with ffprobe before mpv opens it (headers only, tens of ms) and skip files that
-- aren't valid video, e.g. truncated recordings autoload queued, which can take mpv down with them.
-- Skips in the direction you were going (j/k); with nowhere left to go, goes back to the last good
-- video at the same timestamp. stay-open.lua stays as the fallback for failures ffprobe doesn't see.
local utils = require "mp.utils"

local bad = {}            -- path -> true, so each file is only probed once per session
local good = {}           -- path -> true
local last_good_path, last_good_time, restore_time

local function is_bad(path)
    if bad[path] then return true end
    if good[path] or path:find("://") then return false end  -- streams/URLs: don't probe
    local r = mp.command_native({
        name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = { "timeout", "5", "ffprobe", "-v", "error", "-select_streams", "v:0",
                 "-show_entries", "stream=codec_type", "-of", "csv=p=0", path },
    })
    local ok = r.status == 0 and (r.stdout or ""):find("video") ~= nil
    if ok then good[path] = true else bad[path] = true end
    if not ok then
        mp.msg.warn("skipping " .. path .. ": " .. ((r.stderr or ""):gsub("\n.*", "")))
    end
    return not ok
end

local function index_of_path(path)
    for i = 0, mp.get_property_number("playlist-count", 0) - 1 do
        if mp.get_property("playlist/" .. i .. "/filename") == path then return i end
    end
end

mp.observe_property("time-pos", "number", function(_, t)
    if t then last_good_time = t end
end)

mp.add_hook("on_load", 50, function()
    local path = mp.get_property("path")
    if not path or not is_bad(path) then return end

    local pos = mp.get_property_number("playlist-pos", 0)
    local last = last_good_path and index_of_path(last_good_path)
    local dir = (last and pos < last) and -1 or 1
    local count = mp.get_property_number("playlist-count", 0)
    local next = pos + dir
    while next >= 0 and next < count and bad[mp.get_property("playlist/" .. next .. "/filename")] do
        next = next + dir
    end

    if next >= 0 and next < count then
        mp.osd_message("skipped bad file: " .. path:match("[^/]*$"))
        mp.commandv("playlist-play-index", next)
    elseif last then
        mp.osd_message("skipped bad file: " .. path:match("[^/]*$"))
        restore_time = last_good_time
        mp.commandv("playlist-play-index", last)
    end
    -- otherwise (first file is bad, nothing else queued): let mpv try it as usual
end)

mp.register_event("file-loaded", function()
    last_good_path = mp.get_property("path")
    if restore_time then
        mp.commandv("seek", restore_time, "absolute+exact")
        restore_time = nil
    end
end)
