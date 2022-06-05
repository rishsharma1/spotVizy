local M = {}
local json = require( "json" )
local util = require("util")
local SPOTIFY_CURRENT_TRACK = 'https://api.spotify.com/v1/me/player/currently-playing'
local SPOTIFY_AUDIO_ANALYSIS = 'https://api.spotify.com/v1/audio-analysis/%s'
local BEARER_TOKEN = ''

M.EVENTS = {
    CURRENT_PLAYING_TRACK = "CPT",
    TRACK_AUDIO_ANALYSIS = "TAA",
}
M.intervalTypes = {'tatums', 'segments', 'beats', 'bars', 'sections'}

local function handleCorrectCPT_Response(response)
    local currPlayingTrack = {
        id = nil,
        trackName = nil,
        artists = nil,
        link = nil,
        progressMs = nil,
        durationMs = nil,
        isPlaying = false,
        success = false,
    }

    if response.item then
        artists = {} 
        currPlayingTrack.id = response.item.id  
        currPlayingTrack.trackName = response.item.name
        for i = 1, #response.item.artists do
            table.insert(artists,response.item.artists[i].name);
        end 
        currPlayingTrack.artists = artists
        currPlayingTrack.link = response.item.external_urls.spotify
        currPlayingTrack.progressMs = response.progress_ms
        currPlayingTrack.durationMs = response.item.duration_ms
        currPlayingTrack.isPlaying = response.is_playing
        currPlayingTrack.success = true
    else
        if response.error then
            print(response.error.message)
        else
            print("Error!")
        end
    end
    return currPlayingTrack
end

local function handleGetCurrentPlayingTrack( event )
    
    currPlayingTrack = {}
    if not event.isError then
        local response = json.decode( event.response )
        if response then
            print('Received Response!')
            currPlayingTrack = handleCorrectCPT_Response(response)
        else
            print('Error! Did not receive response.')
        end
        local event = { name=M.EVENTS.CURRENT_PLAYING_TRACK, currentPlayingTrack=currPlayingTrack, target=Runtime}
        Runtime:dispatchEvent(event)
    else
        print( "Error!" )
    end
    return currPlayingTrack
end

local function handleCorrectTAA_Response(response, currentPlayingTrack)
    for i = 1, #M.intervalTypes do
        local intervalType = M.intervalTypes[i]
        if response[intervalType] then
            local t = response[intervalType]
            t[1].duration = t[1].start + t[1].duration
            t[1].start = 0
            t[#t].duration = (currentPlayingTrack.durationMs / 1000) - t[#t].start

            for i = 1, #t do
                local interval = t[i]
                if interval.loudness_max_time then
                    interval.loudness_max_time = interval.loudness_max_time * 1000
                end
                interval.start = interval.start * 1000
                interval.duration = interval.duration * 1000
            end
        end
    end
    response.success = true
    return response
end


local function handleAudioAnalysis(event, currentPlayingTrack)

    aAnalysis = {}
    if not event.isError then
        local response = json.decode( event.response )
        if response then
            print('Received Response!')
            aAnalysis = handleCorrectTAA_Response(response, currentPlayingTrack)
        else
            print('Error! Did not receive response.')
            aAnalysis.success = false
        end

        local event = { name=M.EVENTS.TRACK_AUDIO_ANALYSIS, audioAnalysis=aAnalysis, target=Runtime}
        Runtime:dispatchEvent(event)
    else
        print( "Error!" )
    end
    return 
end

local function setupParams()
    local params = {}
    local headers = {}
    headers["Authorization"] = string.format("Bearer %s", BEARER_TOKEN)
    params.headers = headers
    return params
end 

M.getCurrentPlayingTrack =  function()
    local params = setupParams()
    network.request(SPOTIFY_CURRENT_TRACK, "GET", handleGetCurrentPlayingTrack, params)
end

M.getAudioAnalysis = function(currentPlayingTrack)
    local params = setupParams()
    local audioAnalysisURL = string.format(SPOTIFY_AUDIO_ANALYSIS, currentPlayingTrack.id)
    network.request(audioAnalysisURL, "GET", function(event) handleAudioAnalysis(event, currentPlayingTrack); end, params)
end

return M
