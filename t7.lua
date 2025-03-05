-- Test: LinePlacer and Aligner modules.


--[[
Copyright (c) 2023 - 2025 RBTS

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
LinePlacer is basically a sub-component of the RText Instance / Parser. You can kind of,
sort of use it standalone, but a higher-level parsing system is supposed to be driving
it.

Aligner provides functions for Wrap-Line alignment within a Paragraph.

(1) linePlacer.new()

(2) Aligner tests
--]]


local aligner = require("rtext.aligner")
local linePlacer = require("rtext.line_placer")
local media = require("rtext.media")
local textBlock = require("rtext.text_block")

local font = love.graphics.newFont(15)
local b_style = textBlock.newBlockStyle(font)

-- (1)
local lp = linePlacer.new(b_style)


-- (2)
local ta = textBlock.newTextBlock(
	"A",
	b_style,
	0,
	0,
	64,
	32,
	0,
	false,
	nil,
	nil,
	nil,
	nil
)

local tb = textBlock.newTextBlock(
	"B",
	b_style,
	0,
	0,
	64,
	48,
	0,
	false,
	nil,
	nil,
	nil,
	nil
)

local tc = textBlock.newTextBlock(
	"C",
	b_style,
	0,
	0,
	64,
	64,
	0,
	false,
	nil,
	nil,
	nil,
	nil
)


-- Aligner expects a sequence of blocks and a box structure with XYWH fields. Otherwise, it doesn't have any
-- concept of Wrap-Lines, Labels, Paragraphs or Documents.
local box = {}
local function resetBox(box)
	box.x = 0
	box.y = 0
	box.w = 300
	box.h = 200
end
resetBox(box)

local blocks = {ta, tb, tc}


local function drawBoxOutline(box, x, y, blue)

	love.graphics.push("all")
	if blue then
		love.graphics.setColor(0, 0, 1, 1)

	else
		love.graphics.setColor(1, 0, 0, 1)
	end
	love.graphics.rectangle("line", x + box.x + 0.5, y + box.y + 0.5, box.w - 1, box.h - 1)
	love.graphics.pop()
end


local function drawBlocks(box, blocks, x, y)

	for i, block in ipairs(blocks) do
		drawBoxOutline(block, x + box.x, y + box.y, true)
		block:draw(x + box.x, y + box.y)
	end
end

function love.draw()
	love.graphics.setColor(1,1,1,1)
	love.graphics.rectangle("line", 0.5, 0.5, 600-1, 99999)

	resetBox(box)
	local xx, yy
	xx, yy = 0, 0
	aligner.boundingBox(box, blocks, "right", 600, 0, 1)
	drawBoxOutline(box, xx, yy)
	drawBlocks(box, blocks, xx, yy)

	resetBox(box)
	local xx, yy
	xx, yy = 0, 200
	aligner.granular(blocks, "center", 600, 0, 1)
	drawBoxOutline(box, xx, yy)
	drawBlocks(box, blocks, xx, yy)

	-- TODO: aligner.vertical() -> This test is faulty because it's not working with made-up block
	-- sizes instead of different fonts with unique vertical metrics.
	-- You can see a proper test in demo.lua (search the source for 'Vertical Alignment test').
	resetBox(box)
	local xx, yy
	xx, yy = 0, 400
	aligner.vertical(blocks, "bottom")
	drawBoxOutline(box, xx, yy)
	drawBlocks(box, blocks, xx, yy)

	-- TODO: aligner.getHeight() -> This test is also not working correctly. I mean, the
	-- function is, but the results are misleading and have no bearing on what is presented
	-- to the user. aligner.getHeight() is used in t4, t5, t7, and internally in rtext.lua.
	love.graphics.print("aligner.getHeight(blocks): " .. aligner.getHeight(blocks), 0, 550)
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()
		return
	end
end


--[=[
-- Assertion tests
do
	local lp
	--lp = linePlacer.new(false) -- #1 bad type
	--lp = linePlacer.new({}) -- #1 bad sub-type

	-- lp:reset() -- no assertions.
	-- linePlacer.setFragmentSize() -- no assertions.
	-- linePlacer.getBlockFragmentKerning() -- no assertions.
	-- lp:pushBuf() -- no assertions.
	-- lp:getBufWidth() -- no assertions.
	-- lp:clearBuf() -- no assertions.
	-- lp:placeBuf() -- no assertions.
	-- lp:placeArbitraryBlock() -- no assertions.

	local blocks = {}
	-- aligner.boundingBox() -- no assertions.

	--aligner.granular(blocks, "foo", 1234, 0, 1) -- unknown align setting

	-- aligner.getHeight() -- no assertions.

	--aligner.vertical(blocks, "doop") -- unknown vertical align setting
end
--]=]
