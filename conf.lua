jit.off()

function love.conf(t)
	local major, minor = love.getVersion()
	t.window.title = "RText demos (LÖVE " .. major .. "." .. minor .. ")"
	t.window.resizable = true
	--t.gammacorrect = true
	--t.window.width = 800
	--t.window.height = 600
end
