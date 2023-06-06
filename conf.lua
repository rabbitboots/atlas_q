function love.conf(t)
	local love_major, love_minor = love.getVersion()

	t.window.title = "AtlasQ (Quadtree) Demo (LÖVE " .. love_major .. "." .. love_minor .. ")"
	t.window.resizable = true
end
