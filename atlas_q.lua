-- (BETA)
-- [!] WARNING: all ArrayImage atlas code is untested.


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


local atlasQ = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local quadtree = require(REQ_PATH .. "quadtree")


-- * General *


local gpu_limits = love.graphics.getSystemLimits()
local gpu_tex_types = love.graphics.getTextureTypes()


local function isPow2(n)
	return type(n) == "number" and 0.5 == (math.frexp(n))
end


local function errMustBePow2(arg_n)
	error("argument #" .. arg_n .. ": must be a power-of-two integer.", 2)
end


local function errMustBeIntGE1(arg_n)
	error("argument #" .. arg_n .. ": must be an integer >= 1.", 2)
end


local function errImageTypeUnsup(i_type)
	error("image type is not supported by this system: " .. i_type, 2)
end


local function errTooManySlices(arg_n)
	error("argument #" .. arg_n .. ": slice count exceeds the max supported by this system: " .. gpu_limits.texturelayers, 2)
end


-- * / General *


-- * Image Type: 2D *


local _mt_aq = {}
_mt_aq.__index = _mt_aq


function atlasQ.newAtlas(w, h, pixel_format, tex_settings)

	-- Assertions
	-- [[
	if not isPow2(w) then errMustBePow2(1)
	elseif not isPow2(h) then errMustBePow2(2) end
	--]]

	local self = setmetatable({}, _mt_aq)

	self.quadtree = quadtree.newNode(w, h)

	self.pixel_format = pixel_format
	self.tex_settings = tex_settings

	self.i_data = love.image.newImageData(w, h, self.pixel_format)
	self.tex = love.graphics.newImage(self.i_data, self.tex_settings)

	return self
end


function _mt_aq:enlarge()

	local quadtree = self.quadtree

	-- Confirm the system will accept a larger texture.
	if quadtree.w*2 > gpu_limits.texturesize or quadtree.h*2 > gpu_limits.texturesize then
		return false
	end

	-- Put the quadtree into the top-left quadrant of a new root node.
	quadtree = quadtree:insertRoot()
	self.quadtree = quadtree

	-- Make a new ImageData and paste in the old contents.
	local new_i_data = love.image.newImageData(quadtree.w, quadtree.h, self.pixel_format)
	new_i_data:paste(self.i_data, 0, 0, 0, 0, self.i_data:getWidth(), self.i_data:getHeight())
	self.i_data = new_i_data

	-- Make a new image.
	self.tex = love.graphics.newImage(self.i_data, self.tex_settings)

	-- [[DBG]] print("_mt_aq:enlarge: NEW TEXTURE DIMENSIONS: " .. self.tex:getWidth() .. ", " .. self.tex:getHeight())

	return true
end


function _mt_aq:addImageData(i_data)

	local quadtree = self.quadtree
	local iw, ih = i_data:getDimensions()
	local node

	-- Try to find a node without splitting existing nodes.
	node = quadtree:findNode(iw, ih, false)

	-- Not found: try again with splitting enabled.
	if not node then
		node = quadtree:findNode(iw, ih, true)
	end

	-- Still not found: delete empty leaves and try once more.
	if not node then
		quadtree:deleteEmptyLeaves()
		node = quadtree:findNode(iw, ih, true)
	end

	-- No good.
	if not node then
		return false
	end

	-- [[DBG]] print("_mt_aq:addImageData: node xywh: " .. node.x .. ", " .. node.y .. ", " .. node.w .. ", " .. node.h)

	self.i_data:paste(i_data, node.x, node.y, 0, 0, i_data:getWidth(), i_data:getHeight())
	node:setRef(true)

	-- Call self:refreshTexture() when finished modifying the ImageData.

	-- You can call node:setRef() again and assign a non-false, non-nil value to assist
	-- with bookkeeping.

	return node
end


function _mt_aq:refreshTexture()
	self.tex:replacePixels(self.i_data)
end


-- Use if only a single node was assigned.
function _mt_aq:patchTexture(i_data, node)
	self.tex:replacePixels(i_data, nil, nil, node.x, node.y)
end


-- * / Image Type: 2D *


-- * Image Type: Array *


local _mt_aqa = {}
_mt_aqa.__index = _mt_aqa


function atlasQ.newArrayAtlas(n_slices, w, h, pixel_format, tex_settings)

	-- Assertions
	-- [[
	if not gpu_tex_types["array"] then errImageTypeUnsup("array")
	elseif type(n_slices) ~= "number" or math.floor(n_slices) ~= n_slices or n_slices < 1 then errMustBeIntGE1(1)
	elseif n_slices > gpu_limits.texturelayers then errTooManySlices(1)
	elseif not isPow2(w) then errMustBePow2(2)
	elseif not isPow2(h) then errMustBePow2(3) end
	--]]

	local self = setmetatable({}, _mt_aqa)

	self.pixel_format = pixel_format
	self.tex_settings = tex_settings

	self.quadtrees = {}
	self.i_data_slices = {}
	self.dirty_slices = {}

	for i = 1, n_slices do
		self.quadtrees[i] = quadtree.newNode(w, h)
		self.i_data_slices[i] = love.image.newImageData(w, h, self.pixel_format)
		self.dirty_slices[i] = false
	end

	self.tex = love.graphics.newArrayImage(self.i_data_slices, self.tex_settings)

	return self
end


function _mt_aqa:enlarge()

	local q1 = self.quadtrees[1]
	if q1.w*2 > gpu_limits.texturesize or q1.h*2 > gpu_limits.texturesize then
		return false
	end
	for i, quadtree in ipairs(self.quadtrees) do
		local old_i_data = self.i_data_slices[i]
		quadtree = quadtree:insertRoot()
		self.quadtrees[i] = quadtree

		local new_i_data = love.image.newImageData(quadtree.w, quadtree.h, self.pixel_format)
		new_i_data:paste(old_i_data, 0, 0, 0, 0, old_i_data:getWidth(), old_i_data:getHeight())
		self.i_data_slices[i] = new_i_data
	end

	self.tex = love.graphics.newArrayImage(self.i_data_slices, self.tex_settings)

	-- [[DBG]] print("_mt_aqa:enlarge: NEW TEXTURE DIMENSIONS: " .. self.tex:getWidth() .. ", " .. self.tex:getHeight())

	return true
end


function _mt_aqa:addSlices(count)

	-- Assertions
	-- [[
	if type(count) ~= "number" or count < 1 or math.floor(count) ~= count then errMustBeIntGE1(1) end
	--]]

	if #self.i_data_slices + count > gpu_limits.texturelayers then
		return false
	end

	local q1 = self.quadtrees[1]
	for i = #self.i_data_slices + 1, count - 1 do
		self.quadtrees[i] = quadtree.newNode(q1.w, q1.h)
		self.i_data_slices[i] = love.image.newImageData(q1.w, q1.h, self.pixel_format)
	end

	self.tex = love.graphics.newArrayImage(self.i_data_slices, self.tex_settings)

	for i = 1, #self.i_data_slices do
		self.dirty_slices[i] = false
	end
end


function _mt_aqa:addImageData(slice_n, i_data)

	local quadtree = self.quadtrees[slice_n]
	local target_i_data = self.i_data_slices[slice_n]
	if not quadtree then
		error("invalid slice index: " .. tostring(slice_n))
	end

	local iw, ih = i_data:getDimensions()
	local node

	-- Try to find a node without splitting existing nodes.
	node = quadtree:findNode(iw, ih, false)

	-- Not found: try again with splitting enabled.
	if not node then
		node = quadtree:findNode(iw, ih, true)
	end

	-- Still not found: delete empty leaves and try once more.
	if not node then
		quadtree:deleteEmptyLeaves()
		node = quadtree:findNode(iw, ih, true)
	end

	-- No good.
	if not node then
		return false
	end

	-- [[DBG]] print("_mt_aq:addImageData: node xywh: " .. node.x .. ", " .. node.y .. ", " .. node.w .. ", " .. node.h)

	target_i_data:paste(i_data, node.x, node.y, 0, 0, i_data:getWidth(), i_data:getHeight())
	node:setRef(true)

	self.dirty_slices[slice_n] = true

	-- Call self:refreshTexture() when finished modifying the ImageData.

	-- You can call node:setRef() again and assign a non-false, non-nil value to assist
	-- with bookkeeping.

	return node
end


function _mt_aqa:refreshTexture()

	for i, dirty in ipairs(self.dirty_slices) do
		if dirty then
			self.tex:replacePixels(self.i_data_slices[i], i)
			self.dirty_slices[i] = false
		end
	end
end


-- Use if only a single node was assigned.
function _mt_aqa:patchTexture(i_data, node, slice_n)
	self.tex:replacePixels(i_data, slice_n, nil, node.x, node.y)
end


-- * / Image Type: Array *


--[[
To unassign a chunk, call node:setRef() on the node table returned by addImageData().
The graphical contents will remain in the ImageData and texture (as garbage) until the node is
used for another graphical chunk.
--]]


return atlasQ
