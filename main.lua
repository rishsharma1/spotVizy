-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Your code here
local spotify = require("spotify")
local util = require("util")
local state = {
    tick =  system.getTimer(),
    active = false,
    initialised = false,
    activeIntervals = {
     tatums = {},
     segments = {},
     beats = {},
     bars = {},
     sections = {},
    },
}

local myRectangle = display.newRect( 0, 0, 320, 480)
myRectangle.strokeWidth = 3
myRectangle:setFillColor( 0.5 )
myRectangle:setStrokeColor( 1, 0, 0 )
myRectangle.x = display.contentCenterX
myRectangle.y = display.contentCenterY

local myCircle = display.newCircle( 100, 100, 100 )
myCircle:setFillColor( 0.5 )


myCircle.fill.effect = "generator.perlinNoise"
 
myCircle.fill.effect.color1 = { 0.9, 0.1, 0.3, 1 }
myCircle.fill.effect.color2 = { 0.8, 0.8, 0.8, 1 }
myCircle.fill.effect.scale = 50

graphics.defineEffect{
    category = "generator", group = "time", name = "pingpong",
 
    isTimeDependent = true,
 
    fragment = [[
        P_DEFAULT vec2 hash( P_DEFAULT vec2 p )
        {
            p = vec2( dot(p,vec2(127.1,311.7)),
                     dot(p,vec2(269.5,183.3)) );
            return -1.0 + 2.0*fract(sin(p)*43758.5453123);
        }
        
        P_DEFAULT float noise( in P_DEFAULT vec2 p )
        {
            const P_DEFAULT float K1 = 0.366025404; // (sqrt(3)-1)/2;
            const P_DEFAULT float K2 = 0.211324865; // (3-sqrt(3))/6;
            P_DEFAULT vec2 i = floor( p + (p.x+p.y)*K1 );
            P_DEFAULT vec2 a = p - i + (i.x+i.y)*K2;
            P_DEFAULT vec2 o = (a.x>a.y) ? vec2(1.0,0.0) : vec2(0.0,1.0);
            P_DEFAULT vec2 b = a - o + K2;
            P_DEFAULT vec2 c = a - 1.0 + 2.0*K2;
            P_DEFAULT vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
            P_DEFAULT vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
            return dot( n, vec3(70.0) );
        }
        
        P_DEFAULT float fbm(P_DEFAULT vec2 uv)
        {
            P_DEFAULT float f;
            P_DEFAULT mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
            f  = 0.5000*noise( uv ); uv = m*uv;
            f += 0.2500*noise( uv ); uv = m*uv;
            f += 0.1250*noise( uv ); uv = m*uv;
            f += 0.0625*noise( uv ); uv = m*uv;
            f = 0.5 + 0.5*f;
            return f;
        }
        
        // no defines, standard redish flames
        //#define BLUE_FLAME
        //#define GREEN_FLAME
        
        P_COLOR vec4 FragmentKernel( P_UV vec2 texCoord )
        {
            P_UV vec2 uv = texCoord.xy;
               P_UV vec2 q = uv;
            q.x *= CoronaVertexUserData.x;
            q.y *= CoronaVertexUserData.y;
            P_DEFAULT float strength = floor(q.x+1.);
            P_DEFAULT float T3 = max(3.,1.25*strength)*CoronaTotalTime;
            q.x = mod(q.x,CoronaVertexUserData.x)-CoronaVertexUserData.x/2.;
            q.y -= 0.25;
            P_DEFAULT float n = fbm(strength*q - vec2(0,T3));
            P_DEFAULT float c = 1. - 16. * pow( max( 0., length(q*vec2(1.8+q.y*1.5,.75) ) - n * max( 0., q.y+.25 ) ),1.2 );
            P_DEFAULT	float c1 = n * c * (1.5-pow(CoronaVertexUserData.z*uv.y,4.));
            c1=clamp(c1,0.,1.);
            P_COLOR vec3 col = vec3(1.5*c1, 1.5*c1*c1*c1, c1*c1*c1*c1*c1*c1);
            #ifdef BLUE_FLAME
                col = col.zyx;
            #endif
            #ifdef GREEN_FLAME
                col = 0.85*col.yxz;
            #endif
            P_DEFAULT float a = c * (1.-pow(uv.y,3.));
            return CoronaColorScale(vec4( mix(vec3(0.),col,a), a));
        }
    ]],
    vertexData =
    {
        {
            name = "hello",
            default = 0.9, 
            index = 0,  -- This corresponds to "CoronaVertexUserData.x"
        },
        {
            name = "jason",
            default = 3.0, 
            index = 1,  -- This corresponds to "CoronaVertexUserData.x"
        },
        {
            name = "rishabh",
            default = 3.0, 
            index = 2,  -- This corresponds to "CoronaVertexUserData.x"
        }
    },

}
myRectangle.fill.effect = "generator.time.pingpong"
myCircle.fill.effect = "generator.time.pingpong"
myRectangle.fill.effect.jason = 0.0

local function printArtists(artists)
    for i = 1, #artists do
        print(string.format("ARTIST #%d: %s",i,artists[i]))
    end
end

local function inSync(a, b)
    local result = false
    if not a or not b then
        return result
    elseif a.id == b.id then
        result = true
    end
    return result
end

local function findIntervalIndex(analysisType, allAnalysis, trackProgress)
    local analysis = allAnalysis[analysisType]
    local progress = trackProgress

    for i = 1, #analysis do
        if i == #analysis then
            return i
        end
        if analysis[i].start < progress and progress < analysis[i+1].start then
            return i
        end
    end
end

local getCurrentPlayingTrackHandler = function(event)
    print("Event: ".. event.name)
    if event.currentPlayingTrack.success then
        local songIsInSync = inSync(state.currentPlayingTrack,event.currentPlayingTrack)
        if not songIsInSync or not state.active or not state.initialised then
            print("Song not in Sync!")
            state.currentPlayingTrack = event.currentPlayingTrack
            spotify.getAudioAnalysis(event.currentPlayingTrack)
        else
            print("Song in Sync!")
        end
    elseif not event.currentPlayingTrack.success and not event.currentPlayingTrack.isPlaying then
        if state.active then
            state.active = false
        end
    end
end

local getAudioAnalysisHandler = function (event)
    print("Event: ".. event.name)
    state.tock = system.getTimer() - state.tick
    
    state.audioAnalysis = event.audioAnalysis
    state.initalTrackProgress = state.currentPlayingTrack.progressMs + state.tock
    state.trackProgress = state.currentPlayingTrack.progressMs + state.tock
    state.initialStart = system.getTimer()

    if not state.initialised then
        state.initialised = true
    end
    if not state.active then
        state.active = true
    end
end

-- Called when a mouse event has been received.
local function onMouseEvent( event )
    if event.type == "down" then
        if event.isPrimaryButtonDown then
            state.tick = system.getTimer()
            local currPlayingTrack = spotify.getCurrentPlayingTrack()
        end
    end
end

Runtime:addEventListener(spotify.EVENTS.CURRENT_PLAYING_TRACK, getCurrentPlayingTrackHandler)
Runtime:addEventListener(spotify.EVENTS.TRACK_AUDIO_ANALYSIS, getAudioAnalysisHandler)
Runtime:addEventListener( "mouse", onMouseEvent )


local function myListener( event )
    if state.active then
        local now = system.getTimer()
        state.trackProgress = (now - state.initialStart) + state.initalTrackProgress
        for i = 1, #spotify.intervalTypes do
            local intervalType = spotify.intervalTypes[i]
            local index = findIntervalIndex(intervalType, state.audioAnalysis, state.trackProgress)
            if intervalType == 'beats' and state.beatIndex ~= index then
                myCircle.x = math.random(20, 300)
                myCircle.y = math.random(20, 460)
                state.beatIndex = index
                myCircle:setFillColor( math.random(), math.random(), math.random() )
                myCircle.fill.effect.color1 = { math.random(), math.random(), math.random(), 1 }
                myCircle.fill.effect.color2 = { math.random(), math.random(), math.random(), 1 }
                myRectangle.fill.effect.jason = math.random(1, 5)
            end
            if not state.activeIntervals[intervalType].start or index ~= state.activeIntervals[intervalType].index then
                state.activeIntervals[intervalType] = state.audioAnalysis[intervalType][index]
                state.activeIntervals[intervalType].index = index
            end
            local start = state.activeIntervals[intervalType].start
            local duration = state.activeIntervals[intervalType].duration
            local elapsed  = state.trackProgress - start
            state.activeIntervals[intervalType].elapsed = elapsed
            state.activeIntervals[intervalType].progress = util.ease(elapsed/duration)
        end
    end
end
Runtime:addEventListener( "enterFrame", myListener )


