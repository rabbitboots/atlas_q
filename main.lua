-- (BETA)
-- Quadtree atlas proto/demo.

--[[
MIT License

Copyright (c) 2023 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

--[[
NOTES:

To demonstrate atlas resizing, the demo starts with a 1x1 pixel atlas. Resizing is expensive,
so in a game, you'd start with dimensions that are close to the expected in-game size.

The demo implements a brief cooldown between the addition of each node. This prevents the
application from going unresponsive when dragging a large number of images into the window.
--]]


require("demo_lib.strict")

local atlasQ = require("atlas_q")
local quickPrint = require("demo_lib.quick_print.quick_print")


love.keyboard.setKeyRepeat(true)


local qp = quickPrint.new()

local demo_font = love.graphics.newFont(13)

local demo_scroll_x = 0
local demo_scroll_y = 0
local demo_scroll_spd = 250
local demo_scale = 1.0

local demo_show_framing = true

local demo_node_count_used = 0
local demo_node_count_unused = 0


-- The Atlas object.
local atl = atlasQ.newAtlas(1, 1)


local cooldown = 0.0
local cooldown_top = 0.1
image_queue = {}


local gpu_limits = love.graphics.getSystemLimits()


function love.load(arguments)

end


local function updateNodeCount()

	demo_node_count_used = 0
	demo_node_count_unused = 0

	local nodes = atl.quadtree:getNodes(true, true)

	for i, node in ipairs(nodes) do
		if node.ref then
			demo_node_count_used = demo_node_count_used + 1

		else
			demo_node_count_unused = demo_node_count_unused + 1
		end
	end
end


local map_r, map_g, map_b, map_a = 0, 0, 0, 0
local function map_setImageDataColor(x, y, r, g, b, a)
	return map_r, map_g, map_b, map_a
end


local function setImageDataColor(i_data, x, y, w, h, r, g, b, a)

	map_r, map_g, map_b, map_a = r, g, b, a
	i_data:mapPixel(map_setImageDataColor, x, y, w, h)
end


local function tryAddImageData(i_data)

	if i_data:getWidth() > gpu_limits.texturesize or i_data:getHeight() > gpu_limits.texturesize then
		print("image exceeds this system's max texture size.")
		return false
	end

	while true do
		local node = atl:addImageData(i_data)
		if node then
			print("image successfully added.")
			print("new atlas size: " .. atl.quadtree.w .. ", " .. atl.quadtree.h)
			print("node xywh: " .. node.x .. ", " .. node.y .. ", " .. node.w .. ", " .. node.h)

			-- Using patchTexture here because we guarantee that only one node changes per frame.
			-- The intended real-game use case is: delete + allocate a bunch of nodes (replace
			-- the cowboys with pirates or whatever), then call 'atl:refreshTexture()' to re-upload
			-- all pixel data.
			atl:patchTexture(i_data, node)
			return true
		end

		print("'atlas > quadtree > findNode' failed. Try enlarging the atlas.")

		if not atl:enlarge() then
			print("enlarge failed (reached max texture size for this system).")
			return false

		else
			print("new atlas dimensions: " .. atl.quadtree.w .. ", " .. atl.quadtree.h)
		end
	end
end


local function tryAddDummyImageData(w, h, r, g, b, a)

	local i_data = love.image.newImageData(w, h)
	setImageDataColor(i_data, 0, 0, w, h, r, g, b, a)
	table.insert(image_queue, i_data)
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()

	elseif kc == "tab" then
		demo_show_framing = not demo_show_framing

	elseif kc == "1" or kc == "kp1" then
		tryAddDummyImageData(1, 1, 0, 0, 1, 1)
		updateNodeCount()

	elseif kc == "2" or kc == "kp2" then
		tryAddDummyImageData(2, 2, 0, 1, 0, 1)
		updateNodeCount()

	elseif kc == "3" or kc == "kp3" then
		tryAddDummyImageData(4, 4, 0, 1, 1, 1)
		updateNodeCount()

	elseif kc == "4" or kc == "kp4" then
		tryAddDummyImageData(8, 8, 1, 0, 0, 1)
		updateNodeCount()

	elseif kc == "5" or kc == "kp5" then
		tryAddDummyImageData(16, 16, 1, 1, 0, 1)
		updateNodeCount()

	elseif kc == "6" or kc == "kp6" then
		tryAddDummyImageData(32, 32, 1, 1, 1, 1)
		updateNodeCount()

	elseif kc == "7" or kc == "kp7" then
		tryAddDummyImageData(64, 64, 0.0, 0.0, 0.5, 1)
		updateNodeCount()

	elseif kc == "8" or kc == "kp8" then
		tryAddDummyImageData(128, 128, 0.0, 0.5, 0.0, 1)
		updateNodeCount()

	elseif kc == "9" or kc == "kp9" then
		tryAddDummyImageData(256, 256, 0.0, 0.5, 0.5, 1)
		updateNodeCount()

	elseif kc == "0" or kc == "kp0" then
		tryAddDummyImageData(512, 512, 0.5, 0.5, 0.5, 1)
		updateNodeCount()

	elseif kc == "backspace" then

		local nodes = atl.quadtree:getNodes(false, true)
		local count = love.math.random(1, #nodes)

		local node = nodes[count]
		if node then
			node:setRef(false)
			atl.quadtree:deleteEmptyLeaves()
		end
		updateNodeCount()

	elseif kc == "delete" then
		-- Maybe less trouble to just start over from scratch with a new structure.
		atl = atlasQ.newAtlas(1, 1)
		for i, i_data in ipairs(image_queue) do
			i_data:release()
		end
		image_queue = {}
		--[[
		local nodes = atl.quadtree:getNodes(false, true)
		for i = #nodes, 1, -1 do
			local node = nodes[i]
			node:setRef(false)
			node:deleteEmptyLeaves()
		end
		atl.quadtree:deleteEmptyLeaves()
		--]]
		updateNodeCount()

	elseif kc == "f1" then
		love.window.setVSync(1 - love.window.getVSync())
	end
end


local demo_mouse1 = false
function love.mousepressed(x, y, button, istouch, presses)

	if button == 1 then
		demo_mouse1 = true
	end

	x = (x + demo_scroll_x) / demo_scale
	y = (y + demo_scroll_y) / demo_scale

	local node = atl.quadtree:getNodeAtPoint(x, y)
	if node then
		print("clicked node at: " .. node.x .. ", " .. node.y .. ", " .. node.w .. ", " .. node.h)
		if node.ref then
			if button == 2 then
				print("^ clearing node")
				node:setRef(false)
				atl.quadtree:deleteEmptyLeaves()
				updateNodeCount()
			end
		end
	end
end


function love.mousereleased(x, y, button, istouch, presses)

	if button == 1 then
		demo_mouse1 = false
	end
end


function love.mousemoved(x, y, dx, dy)

	if demo_mouse1 then
		demo_scroll_x = demo_scroll_x - dx
		demo_scroll_y = demo_scroll_y - dy
	end
end


function love.wheelmoved(x, y)
	demo_scale = math.max(0.05, demo_scale +y/4)
end


function love.filedropped(file)

	-- Deal with loading + converting to ImageData during love.update.
	table.insert(image_queue, file)
end


function love.update(dt)

	-- Add pending ImageData to the atlas
	cooldown = math.max(0, cooldown - dt)
	if #image_queue > 0 and cooldown == 0 then
		cooldown = cooldown_top
		local chunk = table.remove(image_queue, 1)

		local failure = false

		-- Try to load dropped file
		if not chunk:typeOf("ImageData") then
			local ok, ret1 = pcall(love.image.newImageData, chunk)

			-- Image load failure
			if not ok then
				print(ret1)
				failure = true
			else
				chunk = ret1
			end
		end

		if not failure then
			tryAddImageData(chunk)
			chunk:release()
			updateNodeCount()
		end
	end

	-- Additional controls
	local key = love.keyboard.isDown

	if key("left") then
		demo_scroll_x = demo_scroll_x - demo_scroll_spd*dt
	end
	if key("right") then
		demo_scroll_x = demo_scroll_x + demo_scroll_spd*dt
	end
	if key("up") then
		demo_scroll_y = demo_scroll_y - demo_scroll_spd*dt
	end
	if key("down") then
		demo_scroll_y = demo_scroll_y + demo_scroll_spd*dt
	end
	if key("-", "kp-") then
		demo_scale = math.max(0.05, demo_scale - 0.5*dt)
	end
	if key("=", "kp+") then
		demo_scale = math.max(0.05, demo_scale + 0.5*dt)
	end
end


function love.draw()

	-- Background
	love.graphics.setColor(0.125, 0.125, 0.125, 1.0)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	love.graphics.setColor(1.0, 1.0, 1.0, 1.0)

	-- Texture atlas image
	love.graphics.translate(-math.ceil(demo_scroll_x - 0.5), -math.ceil(demo_scroll_y - 0.5))
	love.graphics.scale(demo_scale, demo_scale)
	love.graphics.draw(atl.tex, 0, 0)

	-- Quadtree framing structure
	if demo_show_framing then
		atl.quadtree:debugRender(0, 0)
	end

	-- HUD / status
	love.graphics.origin()

	qp:reset()
	local hud_h = (demo_font:getHeight() + 2) * 3
	local hud_y = love.graphics.getHeight() - hud_h
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, hud_y, love.graphics.getWidth(), hud_h)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setFont(demo_font)
	qp:movePosition(0, hud_y + 2)
	qp:write("Drag-and-drop to add images.\tPress number keys to add arbitrary data.\tLeft-click to drag view\tRight-click to free a node.")
	qp:down()
	qp:write("-=: zoom\tArrows: scroll\tBackspace: free one random node\tDelete: reset atlas\tTab: show quadtree debug (", demo_show_framing, ")")
	qp:down()
	qp:write("Image Queue: ", #image_queue,
		"\tNodes Used/Total: ", demo_node_count_used, "/", demo_node_count_used + demo_node_count_unused,
		"\tAtlas size: ", atl.quadtree.w, "x", atl.quadtree.h,
		"\tScale: ", demo_scale, "\tXY: ", math.floor(demo_scroll_x), ", ", math.floor(demo_scroll_y),
		"\tFPS: ", love.timer.getFPS(),
		"\t(F1) VSync: ", love.window.getVSync()
	)
end

