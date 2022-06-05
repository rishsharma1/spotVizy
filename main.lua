-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Your code here
local spotify = require("spotify")
local util = require("util")
local currPlayingTrack = spotify.getCurrentPlayingTrack()

local getCurrentPlayingTrackHandler = function(event)
    print("Event: ".. event.name)
    if event.currentPlayingTrack.success then
        print("ID: ".. event.currentPlayingTrack.id)
        print("NAME: ".. event.currentPlayingTrack.trackName)
        for i = 1, #event.currentPlayingTrack.artists do
            print(string.format("ARTIST #%d: %s",i,event.currentPlayingTrack.artists[i]))
        end
        print("LINK: ".. event.currentPlayingTrack.link)
        print("PROGRESS_MS: ".. event.currentPlayingTrack.progressMs)
        spotify.getAudioAnalysis(event.currentPlayingTrack)
    end
end

local getAudioAnalysisHandler = function (event)
    print("Event: ".. event.name)
    --print(util.dump(event.audioAnalysis))
end
Runtime:addEventListener(spotify.EVENTS.CURRENT_PLAYING_TRACK, getCurrentPlayingTrackHandler )
Runtime:addEventListener(spotify.EVENTS.TRACK_AUDIO_ANALYSIS, getAudioAnalysisHandler)