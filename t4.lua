-- Full Paragraph + Wrap-Line tests.


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
This file covers low-level aspects of Paragraphs (Transform and Color params; cb_drawFirst,
cb_drawLast; aspects of Wrap-Lines), and isn't a test of the RText parser. It also touches
on some features which can't be handled well in an isolated environment (cb_update).

(1) Create and draw a standalone Full Paragraph, with Transform and Color parameter changes
    applied to the Paragraph and Wrap-Lines. Test cb_callback for Wrap-Lines and Text
    Blocks.

(2) Test basic draw variations (no transform or color parameters; no draw callbacks).
--]]


local aligner = require("rtext.aligner")
local media = require("rtext.media")
local textBlock = require("rtext.text_block")


local main_font = love.graphics.newFont(15)


love.keyboard.setKeyRepeat(true)


-- Setup boilerplate
local font_norm = love.graphics.newFont(16)
local b_style = textBlock.newBlockStyle(font_norm)
local f_grp_norm = media.newFontGroup(b_style)

local font_groups = {
	norm = f_grp,
}


--[[
NOTE: Most fields in Word Styles and Paragraph Styles are intended for configuring the RText
instance, which we don't care about here.

However, Paragraph Styles also serve as metatables for Paragraphs, so we do have to create
some in order to continue with testing.
--]]


local word_style = media.newWordStyle("unused")
local wrap_line_style = media.newWrapLineStyle()
local para_style = media.newParagraphStyle(word_style, wrap_line_style)


-- https://www.gutenberg.org/ebooks/215
local strings1 = {
	"Day after day, for days unending, Buck toiled in the traces.",
	"Always, they broke camp in the dark, and the first gray of dawn",
	"found them hitting the trail with fresh miles reeled off behind",
	"them. And always they pitched camp after dark, eating their bit",
	"of fish, and crawling to sleep into the snow. Buck was ravenous.",
}
local strings2 = {
	"The pound and a half of sun-dried salmon, which was his ration",
	"for each day, seemed to go nowhere. He never had enough, and",
	"suffered from perpetual hunger pangs. Yet the other dogs, because",
	"they weighed less and were born to the life, received a pound only",
	"of the fish and managed to keep in good condition.",
}


-- A function to make a test paragraph (making more than one this way is a huge pain).
local function makeParagraph(strings)
	local para = media.newParagraph(para_style)

	local line_y = font_norm:getHeight()
	local line_n = 0
	for i, str in ipairs(strings) do
		local w_line = media.newWrapLine(wrap_line_style)
		w_line.y = line_y * line_n

		local text_w = font_norm:getWidth(str)

		local blocks = w_line.blocks
		blocks[#blocks + 1] = textBlock.newTextBlock(
			str,
			b_style,
			0, 0,
			text_w,
			font_norm:getHeight(),
			0,
			false,
			nil,
			nil,
			nil,
			nil
		)
		line_n = line_n + 1
		w_line.w = math.max(w_line.w, text_w)
		w_line.h = aligner.getHeight(blocks)

		para.lines[#para.lines + 1] = w_line
	end


	-- Set paragraph dimensions. This is normally handled by the parser.
	for i, w_line in ipairs(para.lines) do

		para.w = math.max(para.w, w_line.w)
	end
	local last_line = para.lines[#para.lines]
	if last_line then
		para.h = last_line.y + last_line.h
	end

	return para
end


-- (1) Create and draw a standalone Full Paragraph
local para = makeParagraph(strings1)

local function block_cb_update(self, dt)
	self.temp = self.temp or 0
	self.temp = self.temp + dt
	self.c_a = 1.0 + math.cos(self.temp) / 2.0
end
local function w_line_cb_update(self, dt)
	self.temp = self.temp or 0
	self.temp = self.temp + dt
	self.c_a = 1.0 + math.cos(self.temp * 4) / 2.0
end


para.lines[3].blocks[1].cb_update = block_cb_update
para.lines[2].cb_update = w_line_cb_update


-- Make sure Full Paragraph draw callbacks are firing
local once_first, once_last = false, false
para.cb_drawFirst = function(self, x, y)
	if not once_first then
		print("para: cb_drawFirst -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_first = true
end
para.cb_drawLast = function(self, x, y)
	if not once_last then
		print("para: cb_drawLast -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_last = true
end


-- Same with Wrap-Line draw callbacks.
local w_line1 = para.lines[1]
local once_first, once_last = false, false
w_line1.cb_drawFirst = function(self, x, y)
	if not once_first then
		print("w_line1: cb_drawFirst -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_first = true
end
w_line1.cb_drawLast = function(self, x, y)
	if not once_last then
		print("w_line1: cb_drawLast -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_last = true
end


-- (2) Test basic draw methods.
local para2 = makeParagraph(strings2)

para2.draw = media.basic_paraDraw
for i, w_line in ipairs(para2.lines) do
	w_line.draw = media.basic_wrapLineDraw
end



local function testUpdateParagraph(para, dt, t)

	para.d_x = math.floor(para.w/2)
	para.d_y = math.floor(para.h/2)
	para.d_ox = math.floor(para.w/2)
	para.d_oy = math.floor(para.h/2)
	para.d_r = math.cos(t)

	para.c_r = 0.75
	para.lines[1].c_g = 0.0

	-- Test cb_update for Wrap-Lines and Text Blocks
	para:update(dt) -- also calls/tests media.wrapLineUpdate

	for i, w_line in ipairs(para.lines) do
		w_line.d_x = math.floor(para.w/2)
		w_line.d_y = math.floor(para.h/2)
		w_line.d_ox = math.floor(para.w/2)
		w_line.d_oy = math.floor(para.h/2)
		w_line.d_sx = math.cos(t+i/15)
		w_line.d_kx = math.sin(t/3)
	end
end


local t = 0
function love.update(dt)

	t = t + dt
	testUpdateParagraph(para, dt, t)
	testUpdateParagraph(para2, dt, t)
end


function love.draw()

	-- (1)
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", para.x + 0.5, para.y + 0.5, para.w - 1, para.h - 1)

	love.graphics.setColor(1, 1, 1, 1)
	para:draw(0, 0) -- calls WrapLine:draw()

	-- (2): Should not be colorized or transformed, even though the parameters are being set just like para1.
	para2:draw(0, 300)
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()
		return
	end
end


-- Assertion Tests
--[[
do

	--local word_style = media.newWordStyle(false) -- #1 bad type

	--local para = media.newParagraph("foo") -- #1 bad type

	local font_norm = love.graphics.newFont(16)
	local b_style = textBlock.newBlockStyle(font_norm)

	local f_grp
	--f_grp = media.newFontGroup("bad_type") -- #1 bad type

	-- NOTE: the assertions will allow incorrect or corrupt tables through. This is wrong,
	-- but it will pass the check.
	f_grp = media.newFontGroup({})

	f_grp = media.newFontGroup(b_style, nil, nil, nil) -- Correct
	--f_grp = media.newFontGroup(b_style, "foo", nil, nil) -- #2 bad type
	--f_grp = media.newFontGroup(b_style, nil, "foo", nil) -- #3 bad type
	--f_grp = media.newFontGroup(b_style, nil, nil, "foo") -- #4 bad type

	-- _mt_font_group:getFace(bold, italic) -- no assertions

	--local w_line = media.newWrapLine(nil) -- #1 bad type

	local wrap_line_style = media.newWrapLineStyle() -- no assertions
	--local word_style = media.newWordStyle(nil) -- #1 bad type
	local word_style = media.newWordStyle("unused")

	--media.newParagraphStyle(nil, wrap_line_style) -- #1 bad type
	local ps = media.newParagraphStyle(word_style, nil) -- Is okay. Arg #2 has a default, since
	-- Wrap-Line Styles are fairly limited.

	-- media.wrapLineGetBlockAtPoint(self, x, n) -- no assertions
	-- ^ used in demo.lua.

	-- para:update() -- no assertions
	-- WrapLine:update() -- no assertions
	-- para:draw() -- no assertions
	-- WrapLine:draw() -- no assertions

	-- media.default_wrapLineDraw() -- no assertions
	-- media.basic_wrapLineDraw() -- no assertions
	-- media.default_paraDraw() -- no assertions
	-- media.basic_paraDraw() -- no assertions

	-- media.paraGetWrapLineAtPoint() -- no assertions

	-- media.paraDebugDraw(self, x, y) -- no assertions

end
--]]

