local AudioManager = {}

local bgm
local sfx = {}
local sfx_instances = {}

function AudioManager.init()
    -- Load BGM
    bgm = love.audio.newSource("assets/audio/music/bgm_wholesome.ogg", "stream")
    bgm:setVolume(0.3)
    bgm:setLooping(true)
    bgm:play()

    -- Load SFX
    sfx["click"] = love.audio.newSource("assets/audio/sfx/ui_click.wav", "static")
    sfx["till"] = love.audio.newSource("assets/audio/sfx/till.wav", "static")
    sfx["water"] = love.audio.newSource("assets/audio/sfx/water.wav", "static")
    sfx["harvest"] = love.audio.newSource("assets/audio/sfx/harvest.wav", "static")

    -- Set volumes
    for k, v in pairs(sfx) do
        v:setVolume(0.5)
        sfx_instances[k] = {}
    end
end

function AudioManager.playSfx(name)
    local source = sfx[name]
    if not source then return end
    
    -- Clone to allow overlapping sounds
    local inst = source:clone()
    inst:play()
    table.insert(sfx_instances[name], inst)
    
    -- Cleanup finished sources periodically to prevent memory leaks
    local active = {}
    for _, s in ipairs(sfx_instances[name]) do
        if s:isPlaying() then
            table.insert(active, s)
        end
    end
    sfx_instances[name] = active
end

return AudioManager
