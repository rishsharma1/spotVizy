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
        success = false
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
        currPlayingTrack.success = true
    else
        print(response.error.message)
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
    return 
end

local function handleAudioAnalysis( event)
    print(util.dump(event))
    if not event.isError then
        local response = json.decode( event.response )
        for i = 1, #M.intervalTypes do
            local intervalType = M.intervalTypes[i]
            if response[intervalType] then
                local t = response[intervalType]
                t[1].duration = t[1].start + t[1].duration
                t[1].start = 0
                t[#t].duration = 69
            end
        end
        local event = { name=M.EVENTS.TRACK_AUDIO_ANALYSIS, audioAnalysis=response, target=Runtime}
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
    network.request(SPOTIFY_CURRENT_TRACK, "GET", handleGetCurrentPlayingTrack, params);
    return {}
end

M.getAudioAnalysis = function(currentPlayingTrack)
    local params = setupParams()
    local audioAnalysisURL = string.format(SPOTIFY_AUDIO_ANALYSIS, currentPlayingTrack.id)
    network.request(audioAnalysisURL, "GET", handleAudioAnalysis, params)
end

return M
