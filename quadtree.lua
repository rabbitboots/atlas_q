-- (BETA)
-- Quadtree implementation for placement of textures within an atlas.


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


local quadtree = {}


--[[
	Sub-node indexes:

	+-+-+
	|1|2|
	+-+-+
	|3|4|
	+-+-+

	The presence of self[1] indicates that all four sub-nodes are present in a node.
	Nodes can either be in use ('self.ref' evals to true) or have sub-nodes, but not both at the same time.
--]]


local _mt_qt = {}
_mt_qt.__index = _mt_qt


local function newNode(x, y, w, h)

	-- [[DBG]] print("newNode: x=" .. x .. ", y=" .. y .. ", w=" .. w .. ", h=" .. h)

	local self = setmetatable({}, _mt_qt)

	self.ref = false

	self.x = x
	self.y = y
	self.w = w
	self.h = h

	return self
end


local function splitNode(self)

	-- [[DBG]] print("SPLIT_NODE: " .. self.x .. ", " .. self.y .. ", " .. self.w .. ", " .. self.h)

	if self.ref then
		error("cannot split a node that is in use.")

	elseif self.w <= 0 or self.h <= 0 then
		error("node is too small to split.")
	end

	self[1] = newNode(self.x, self.y, self.w/2, self.h/2)
	self[2] = newNode(self.x + self.w/2, self.y, self.w/2, self.h/2)
	self[3] = newNode(self.x, self.y + self.h/2, self.w/2, self.h/2)
	self[4] = newNode(self.x + self.w/2, self.y + self.h/2, self.w/2, self.h/2)
end


local function findNode(self, w, h, do_split)

	if not self.ref then
		if self.w > 1 and self.h > 1 and w <= self.w/2 and h <= self.h/2 then
			if not self[1] and do_split then
				splitNode(self)
			end

			if self[1] then
				return findNode(self[1], w, h, do_split)
					or findNode(self[2], w, h, do_split)
					or findNode(self[3], w, h, do_split)
					or findNode(self[4], w, h, do_split)
			end

		elseif not self[1] and w <= self.w and h <= self.h then
			return self
		end
	end

	-- (return nil)
end


local function hasReferences(self)

	if self.ref then
		return self

	elseif self[1] then
		return hasReferences(self[1]) or hasReferences(self[2]) or hasReferences(self[3]) or hasReferences(self[4])
	end
end


local function hasSubReferences(self)

	if self[1] then
		return hasReferences(self[1]) or hasReferences(self[2]) or hasReferences(self[3]) or hasReferences(self[4])
	end

	-- (return nil)
end


local function deleteLeaves(self)

	if self.ref then
		return false

	elseif self[1] then
		if deleteLeaves(self[1]) and deleteLeaves(self[2]) and deleteLeaves(self[3]) and deleteLeaves(self[4]) then
			self[4] = nil
			self[3] = nil
			self[2] = nil
			self[1] = nil

			return true

		else
			return false
		end
	end

	return true
end


function quadtree.newNode(w, h)
	return newNode(0, 0, w, h)
end


function _mt_qt:setRef(ref)

	if self[1] then
		if hasSubReferences(self) then
			--self:dumpTree() -- debug
			error("cannot alter node usage if any of its sub-nodes are in use.")

		else
			deleteLeaves(self)
		end
	end

	self.ref = ref or false
end


function _mt_qt:insertRoot()

	-- [[DBG]] print("INSERT_ROOT")
	-- Empty root: double existing size
	if not self.ref and not self[1] then
		-- [[DBG]] print("empty root. double existing size.")

		self.w = self.w * 2
		self.h = self.h * 2

		return self

	else
		-- [[DBG]] print("place existing root in top-left quadrant of new root.")
		local node = newNode(0, 0, self.w*2, self.h*2)

		node[1] = self
		node[2] = newNode(self.w, 0, self.w, self.h)
		node[3] = newNode(0, self.h, self.w, self.h)
		node[4] = newNode(self.w, self.h, self.w, self.h)

		return node
	end
end


function _mt_qt:deleteEmptyLeaves()
	deleteLeaves(self)
end


function _mt_qt:findNode(w, h, do_split)
	return findNode(self, w, h, do_split)
end


local function getNodes(self, unused, used, _list)

	if used and self.ref then
		table.insert(_list, self)

	elseif unused and not self.ref then
		table.insert(_list, self)
	end

	for i = 1, 4 do
		if self[i] then
			getNodes(self[i], unused, used, _list)
		end
	end
end


function _mt_qt:getNodes(unused, used)

	local _list = {}
	getNodes(self, unused, used, _list)
	return _list
end


local function debugRender(self)

	local r, g, b
	if self.ref then
		r, g, b = 0, 1, 0

	else
		r, g, b = 0, 0, 1
	end

	love.graphics.setColor(r, g, b, 0.1)
	love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle("line", self.x + 0.5, self.y + 0.5, self.w - 1, self.h - 1)

	for i = 1, 4 do
		if self[i] then
			debugRender(self[i])
		end
	end
end


function _mt_qt:debugRender(x, y)

	love.graphics.push("all")

	love.graphics.setLineStyle("rough")
	love.graphics.setLineJoin("miter")
	love.graphics.setLineWidth(1)

	x, y = math.floor(x), math.floor(y)
	love.graphics.translate(x, y)

	debugRender(self)

	love.graphics.pop()
end


local function ind(ent)
	return string.rep(" ", ent)
end
local function dumpTree(self, ent)

	print(ind(ent) .. "Node: " .. tostring(self))
	print(ind(ent) .. "xywh: " .. self.x .. ", " .. self.y .. ", " .. self.w .. ", " .. self.h)
	if self.ref then
		print(ind(ent) .. "ref: " .. tostring(self.ref))
	end

	if self.ref and (self[1] or self[2] or self[3] or self[4]) then
		print("!!! Corruption: This node contains both a reference (in use) and also child nodes.")
	end

	for i = 1, 4 do
		if self[i] then
			print(ind(ent) .. "Q" .. i .. ":")
			dumpTree(self[i], ent + 1)
		end
	end
end
function _mt_qt:dumpTree(ent)

	ent = ent or 0
	print("BEGIN QUADTREE DUMP\n")
	dumpTree(self, ent)
	print("\nEND QUADTREE DUMP")
end


function _mt_qt:getNodeAtPoint(x, y)

	-- [[DBG]] print("xywh", self.x, self.y, self.w, self.h)

	if x >= self.x and x < self.x + self.w and y >= self.y and y < self.y + self.h then
		if not self[1] then
			return self

		else
			for i = 1, 4 do
				if self[i] then
					local ret = self[i]:getNodeAtPoint(x, y)
					if ret then
						return ret
					end
				end
			end
		end
	end

	-- (return nil)
end


return quadtree
