function love.conf(t)
    t.identity = "tiny-farm"
    t.version = "11.5"
    t.window.title = "Tiny Farm"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = false
    t.modules.physics = false  -- Not using Box2D physics
end
