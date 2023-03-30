-- Test: RText module, Line Placer, Tag Defs, Aligner.


--[[
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
This file tests the RText module, but it isn't a full test of the parser and tags
(those are easier to test within demo.lua).

(1) rtext.newInstance(); rt:makeDocument()

(2) Custom tag patterns

(3) Change Block Granularity

(4) pushTextQueue, clearTextQueue (via [br])

(5) rt:makeSimpleParagraph()

(6) rt:makeParagraph()

(7) rt:parseText()

--]]


local aligner = require("rtext.aligner")
local media = require("rtext.media")
local rtext = require("rtext.rtext")


local rt, sample

local font = love.graphics.newFont(24)
local b_style = rtext.newBlockStyle(font)
local f_grp = rtext.newFontGroup(b_style)

local font_groups = {
	norm = f_grp,
}

-- (1)
rt = rtext.newInstance(font_groups, "norm")

sample = "[align left]Hello,\n[align center]World\n[align right]!"

local doc1 = rt:makeDocument(sample, love.graphics.getWidth() / 4)


-- (2)
rt = rtext.newInstance(font_groups, "norm")
rt:setTagPatterns("<", ">")
sample = "<align left>[Hello],\n<align center>[World]\n<align right>[!]"
local doc2 = rt:makeDocument(sample, love.graphics.getWidth() / 4)


-- (3)
rt = rtext.newInstance(font_groups, "norm")
rt:setBlockGranularity("code-point")
sample = "[align left]Hello,\n[align center]World\n[align right]!"
local doc3 = rt:makeDocument(sample, love.graphics.getWidth() / 4)


-- (4) pushTextQueue, clearTextQueue via [br]
rt = rtext.newInstance(font_groups, "norm")
sample = "[align left]Hello,[br][align center]World[br][align right]!"
local doc4 = rt:makeDocument(sample, love.graphics.getWidth() / 4)


-- (5) rt:makeSimpleParagraph()
rt = rtext.newInstance(font_groups, "norm")
local s_paras = {}
local sp_input = "Simple Paragraph One.\nSimple Paragraph Two\nSimple Paragraph Three."
local sp_i = 1
while sp_i <= #sp_input do
	local s_para
	s_para, sp_i = rt:makeSimpleParagraph(sp_input, sp_i, 120, "left", b_style)
	table.insert(s_paras, s_para)
end


-- (6) rt:makeParagraph()
rt = rtext.newInstance(font_groups, "norm")
local paras = {}
local p_input = "Full Paragraph One.\nFull Paragraph Two.\nFull Paragraph Three."
local p_i = 1
while p_i <= #p_input do
	local para
	para, p_i = rt:makeParagraph(p_input, p_i, 120)
	table.insert(paras, para)
end


-- (7) rt:parseText()
rt = rtext.newInstance(font_groups, "norm")
local doc7 = media.newDocument()
local d7_input = "One.\nTwo.\nThree.\nFour."
local d_i = 1
while d_i <= #d7_input do
	d_i = rt:parseText(d7_input, doc7, d_i, 1)
end


function love.draw()

	-- Illustrate the wrap-limit:
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.line(doc1.wrap_w + 0.5, 0.5, doc1.wrap_w + 0.5, love.graphics.getHeight())
	love.graphics.setColor(1, 1, 1, 1)

	-- (1)
	doc1:draw(0, 0)

	-- (2)
	doc2:draw(0, 100)

	-- (3)
	doc3:debugDraw(0, 200)
	doc3:draw(0, 200)

	-- (4)
	doc4:draw(0, 300)

	-- (5)
	local yy = 0
	for i, s_para in ipairs(s_paras) do
		s_para:draw(250, yy)
		yy = yy + s_para.h
	end

	-- (6)
	local yy = 300
	for i, para in ipairs(paras) do
		para:draw(250, yy)
		yy = yy + para.h
	end

	-- (7)
	doc7:draw(500, 0)
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
	local rt
	--rtext.newInstance(font_groups, default_f_grp_id, colors, word_styles, para_styles, def_para_style, data)
	--rt = rtext.newInstance(nil) -- #1 bad type
	--rt = rtext.newInstance({}, false) -- #2 bad type
	--rt = rtext.newInstance({}, "non-existent group ID") -- missing default font

	local font, b_style, f_grp, font_groups

	font = love.graphics.newFont(24)
	b_style = rtext.newBlockStyle(font)
	f_grp = rtext.newFontGroup(b_style)
	font_groups = {
		norm = f_grp,
	}
	rt = rtext.newInstance(font_groups, "norm") -- OK

	--[[
	font = love.graphics.newFont(24)
	local bad_group = { norm = {"this should be a Font object"}, }
	font_groups = {
		norm = bad_group,
	}
	rt = rtext.newInstance(font_groups, "norm") -- missing default font
	--]]

	--rt = rtext.newInstance(font_groups, "norm", "bad_type") -- #3 bad type
	--rt = rtext.newInstance(font_groups, "norm", nil, "bad_type") -- #4 bad type
	--rt = rtext.newInstance(font_groups, "norm", nil, nil, "bad_type") -- #5 bad type
	--rt = rtext.newInstance(font_groups, "norm", nil, nil, nil, "bad_type") -- #6 bad type
	--rt = rtext.newInstance(font_groups, "norm", nil, nil, nil, "bad_type") -- #6 bad type
	--rt = rtext.newInstance(font_groups, "norm", nil, nil, nil, nil, "bad_type") -- #7 bad type

	-- rt:refreshFont() -- no assertions
	-- rt:applyWordStyle() -- no assertions

	--rt:setParagraphStyle("bad_type") -- #1 bad type

	-- rt:setDefaultState -- no assertions

	--rt:setTagPatterns(99, "bar") -- #1 bad type
	--rt:setTagPatterns("", "bar") -- #1 empty string not allowed
	--rt:setTagPatterns("foo", 99) -- #2 bad type
	--rt:setTagPatterns("foo", "") -- #2 empty string not allowed

	--rt:updateDeferredWrapLineState() -- no assertions.

	--rt:setColor("bad") -- no color registered with this ID

	--rt:setAlign("foo") -- bad enum align
	--rt:setVAlign("foo") -- bad enum align

	--rt:setBlockGranularity("foo") -- #1 bad enum

	-- rt:pushTextQueue() -- no assertions
	-- rt:clearTextQueue() -- no assertions
	local s_para, sp_i
	--s_para, sp_i = rt:makeSimpleParagraph(false, 1, math.huge, "left", b_style) -- #1 bad type
	--s_para, sp_i = rt:makeSimpleParagraph("foo", "noodle", math.huge, "left", b_style) -- #2 bad type
	--s_para, sp_i = rt:makeSimpleParagraph("foo", 1, "noodle", "left", b_style) -- #3 bad type
	--s_para, sp_i = rt:makeSimpleParagraph("foo", 1, math.huge, "noodle", b_style) -- #4 bad enum
	--s_para, sp_i = rt:makeSimpleParagraph("foo", 1, math.huge, "left", "noodle") -- #5 bad enum

	local para, p_i
	--para, p_i = rt:makeParagraph(false, 1, math.huge) -- #1 bad type
	--para, p_i = rt:makeParagraph("foo", "noodle", math.huge) -- #2 bad type
	--para, p_i = rt:makeParagraph("foo", 1, "noodle") -- #3 bad type

	--rt:makeDocument(false, math.huge) -- #1 bad type
	--rt:makeDocument("foo", "noodle") -- #2 bad type
	local document = media.newDocument()
	--rt:parseText(99, document, i, math.huge) -- #1 bad type
	--rt:parseText("foo\nbar", false, i, math.huge) -- #2 bad type
	--rt:parseText("foo\nbar", document, {}, math.huge) -- #3 bad type
	--rt:parseText("foo\nbar", document, 1, function() end) -- #4 bad type
end
--]=]
