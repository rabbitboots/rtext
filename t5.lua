-- Document tests.


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
This file covers low-level aspects of Document structures, plus some Paragraph Style
features. It's mostly a copy-and-paste job of t4.lua. Like that file, it does not
test the RText parser.

(1) Setup and draw a Document.

(2) Test basic draw methods.
--]]


local aligner = require("rtext.aligner")
local media = require("rtext.media")
local textBlock = require("rtext.text_block")


local main_font = love.graphics.newFont(15)


love.keyboard.setKeyRepeat(true)


-- (1)
local document = media.newDocument()

document.wrap_w = 600



-- Make sure Document draw callbacks are firing
local once_first, once_last = false, false
document.cb_drawFirst = function(self, x, y)
	if not once_first then
		print("document: cb_drawFirst -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_first = true
end
document.cb_drawLast = function(self, x, y)
	if not once_last then
		print("document: cb_drawLast -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_last = true
end


-- Setup boilerplate, taken mostly verbatim from t4.lua.

local font_norm = love.graphics.newFont(16)
local b_style = textBlock.newBlockStyle(font_norm)
local f_grp_norm = media.newFontGroup(b_style)

local font_groups = {
	norm = f_grp,
}


local word_style = media.newWordStyle("unused")
local wrap_line_style = media.newWrapLineStyle()
local para_style = media.newParagraphStyle(word_style, wrap_line_style)


local strings1 = {
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
}
local strings2 = {
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
	"Abcdefg hijklmnop qrstuv wxyz. Abcdefg hijklmnop qrstuv wxyz.",
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

-- Make two Full Paragraphs and one Simple paragraph
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


local para2 = makeParagraph(strings2)

para2.draw = media.basic_paraDraw
for i, w_line in ipairs(para2.lines) do
	w_line.draw = media.basic_wrapLineDraw
end


local sp_text = [[
Simple Paragraph text. 0123456789. Simple Paragraph text. 0123456789. Simple Paragraph text. 0123456789. Simple Paragraph text. 0123456789. Simple Paragraph text. 0123456789. Simple Paragraph text. 0123456789.]]

local s_para = media.newSimpleParagraph(0, 0, sp_text, b_style, "left", document.wrap_w)


-- Attach the Paragraphs to the Document.
table.insert(document.paragraphs, para)
table.insert(document.paragraphs, para2)
table.insert(document.paragraphs, s_para)


--[[
There is no arrange function for Documents -- the RText parser handles that as it goes through
the source markup -- so let's position the paragraphs and apply spacing here.
--]]
local prev = document.paragraphs[1]
prev.x = prev.sp_left
prev.y = prev.sp_top

for i = 2, #document.paragraphs do
	local para = document.paragraphs[i]
	para.x = para.sp_left
	para.y = prev.y + prev.h + prev.sp_bottom + para.sp_top

	prev = para
end


local function testUpdateParagraph(para, dt, t)

	para.d_x = math.floor(para.w/2)
	para.d_y = math.floor(para.h/2)
	para.d_ox = math.floor(para.w/2)
	para.d_oy = math.floor(para.h/2)
	para.d_r = math.cos(t)

	para.c_r = 0.75
	para.lines[1].c_g = 0.0

	for i, w_line in ipairs(para.lines) do
		w_line.d_x = math.floor(para.w/2)
		w_line.d_y = math.floor(para.h/2)
		w_line.d_ox = math.floor(para.w/2)
		w_line.d_oy = math.floor(para.h/2)
		w_line.d_sx = math.cos(t+i/15)
		w_line.d_kx = math.sin(t/3)
	end
end


-- Documents do not have XYWH values, but you can get the bounding box of all paragraphs.
local x1, y1, x2, y2 = document:getBoundingBox()
local doc_w = x2 - x1
local doc_h = y2 - y1


local t = 0
local function doc_cb_update(self, dt, t)

	testUpdateParagraph(para, dt, t)
	testUpdateParagraph(para2, dt, t)

	-- Document:update() should call 'cb_update' within its nested Paragraphs, Wrap-Lines and Text Blocks.
	self:update(dt)
end


function love.update(dt)

	t = t + dt
	doc_cb_update(document, dt, t)

	document.d_x = math.floor(doc_w / 2)
	document.d_y = math.floor(doc_h / 2)
	document.d_ox = math.floor(doc_w / 2)
	document.d_oy = math.floor(doc_h / 2)
	document.d_sx = math.sin(t)
	document.d_r = math.cos(t) / 16

	document.c_r = 1 + math.sin(t) / 2
	document.c_b = 1 + math.sin(t) / 2
end


function love.draw()

	-- (1)
	love.graphics.setColor(1, 0, 0, 1)


	love.graphics.rectangle("line", x1 + 0.5, y1 + 0.5, x2 - 1, y2 - 1)
	love.graphics.setColor(1, 1, 1, 1)
	document:draw(0, 0)

	-- (2)
	-- Temporarily swap to the basic draw method. The Document-level Transform
	-- and Color parameters should no longer apply, but Paragraph and Wrap-Line
	-- parameters should still be present.
	local old_draw = document.draw
	document.draw = media.basic_documentDraw

	document:draw(0, 400)

	document.draw = old_draw
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
	-- media.newDocument() -- no assertions.
	-- Document:draw() -- no assertions.
	media.basic_documentDraw() -- no assertions.

	Document:debugDraw() -- no assertions.
	Document:getParagraphAtPoint -- no assertions.
	Document:getBoundingBox() -- no assertions.

	Document:update() -- no assertions.
end
--]]

