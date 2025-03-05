-- Simple Paragraph tests.


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
(1) Create and draw a standalone Simple Paragraph

(2) Test Simple Paragraph transform and color parameters, and also the update callback.

(3) Plug-In Method: Basic Draw method for Simple Paragraphs
--]]

-- `rtext.lua` is not required for making and showing Simple Paragraphs.
local media = require("rtext.media")
local textBlock = require("rtext.text_block")


local main_font = love.graphics.newFont(15)

local test_align = "left"
local test_wrap_limit = 600


love.keyboard.setKeyRepeat(true)


-- Make some Block Styles.
local font = love.graphics.newFont(16)
local b_style = textBlock.newBlockStyle(font)

local font_big = love.graphics.newFont(32)
local b_style_big = textBlock.newBlockStyle(font_big)


-- (1) Create and draw a standalone Simple Paragraph
-- https://www.gutenberg.org/ebooks/43626
local str = [[
For many years I have collected curious epitaphs, and in this volume I offer the result of my gleanings. An attempt is herein made to furnish a book, not compiled from previously published works, but a collection of curious inscriptions copied from gravestones. Some of the chapters have appeared under my name in Chambers’s Journal, Illustrated Sporting and Dramatic News, Newcastle Courant, People’s Journal, (Dundee), Press News, and other publications. I have included a Bibliography of Epitaphs, believing that it will be useful to those who desire to obtain more information on the subject than is presented here. I have not seen any other bibliography of this class of literature, and as a first attempt it must be incomplete. In compiling it I have had the efficient aid of Mr. W. G. B. Page, of the Hull Subscription Library, who has also prepared the Index.]]

local s_para = media.newSimpleParagraph(0, 0, str, b_style, test_align, test_wrap_limit)

-- (2)
local s_para2 = media.newSimpleParagraph(0, 0, str, b_style, "center", 600)

-- Make sure Simple Paragraph draw callbacks are firing
local once_first, once_last = false, false
s_para2.cb_drawFirst = function(self, x, y)
	if not once_first then
		print("s_para2: cb_drawFirst -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_first = true
end
s_para2.cb_drawLast = function(self, x, y)
	if not once_last then
		print("s_para2: cb_drawLast -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_last = true
end


local t = 0


-- Implement rotation of Simple Paragraph 2 through cb_update.
local function s_para_cb_update(self, dt)

	self.d_r = t / 4
end
s_para2.cb_update = s_para_cb_update


function love.update(dt)

	t = t + dt

	s_para2:update(dt)
end


-- (3)
local str3 = "basic_draw -- no transforms, color or drawing callbacks"
local s_para3 = media.newSimpleParagraph(0, 0, str3, b_style)
s_para3.draw = media.basic_simpleParaDraw

s_para3.cb_drawFirst = function(self, x, y)
	love.graphics.print("THIS SHOULDN'T APPEAR", 0, 0)
end
s_para3.cb_drawLast = function(self, x, y)
	love.graphics.print("THIS SHOULDN'T APPEAR", 0, 0)
end

function love.draw()

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.line(test_wrap_limit + 0.5, 0.5, test_wrap_limit + 0.5, love.graphics.getHeight() + 1)

	love.graphics.setColor(0, 0, 1, 1)
	love.graphics.rectangle("line", s_para.x + 0.5, s_para.y + 0.5, s_para.w - 1, s_para.h - 1)

	love.graphics.setColor(1, 1, 1, 1)

	-- (1)
	s_para:draw(0, 0)

	-- (2)
	s_para2.d_x = s_para2.w / 2
	s_para2.d_y = s_para2.h / 2
	s_para2.d_sx = math.cos(t / 2)
	s_para2.d_sy = math.sin(t / 3)
	s_para2.d_ox = s_para2.w / 2
	s_para2.d_oy = s_para2.h / 2

	s_para2.c_r = 0.3
	s_para2.c_g = 0.5
	s_para2.c_b = 0.9
	s_para2.c_a = 0.5

	s_para2:draw(love.graphics.getWidth()/2 - s_para2.w/2, love.graphics.getHeight()/2 - s_para2.h/2)


	-- (3)
	s_para3.d_sx = math.cos(t)
	s_para3.d_sy = math.cos(t)
	s_para3.d_r = t

	s_para3.c_r = 1.0
	s_para3.c_g = 0.0
	s_para3.c_b = 0.0
	s_para3.c_a = 1.0

	s_para3:draw(0, 500)

	-- Interface
	local pad = 2
	love.graphics.setFont(main_font)
	love.graphics.print("-/=: Change wrap limit, 1,2,3,4: Change alignment, ESC: Quit", pad, love.graphics.getHeight() - main_font:getHeight() - pad)
end


function love.keypressed(kc, sc)

	local update = false
	if kc == "1" then
		test_align = "left"
		update = true

	elseif kc == "2" then
		test_align = "center"
		update = true

	elseif kc == "3" then
		test_align = "right"
		update = true

	elseif kc == "4" then
		test_align = "justify"
		update = true

	elseif kc == "-" then
		test_wrap_limit = test_wrap_limit - 10
		update = true

	elseif kc == "=" then
		test_wrap_limit = test_wrap_limit + 10
		update = true

	elseif kc == "escape" then
		love.event.quit()
		return
	end

	if update then
		s_para.wrap_limit = test_wrap_limit
		s_para.align = test_align
		s_para:refreshSize()
	end
end


-- Assertion Tests
--[[
do
	local font = love.graphics.newFont(16)
	local b_style = textBlock.newBlockStyle(font)

	local sp
	--sp = media.newSimpleParagraph("bad", 0, "foobar", b_style) -- #1 bad type
	--sp = media.newSimpleParagraph(0, "bad", "foobar", b_style) -- #2 bad type
	--sp = media.newSimpleParagraph(0, 0, false, b_style) -- #3 bad type
	--sp = media.newSimpleParagraph(0, 0, "foobar", false) -- #4 bad type
	--sp = media.newSimpleParagraph(0, 0, "foobar", b_style, 1) -- #5 bad type
	--sp = media.newSimpleParagraph(0, 0, "foobar", b_style, "bad") -- #5 bad enum
	--sp = media.newSimpleParagraph(0, 0, "foobar", b_style, nil, "bad") -- #6 bad type

	sp = media.newSimpleParagraph(0, 0, "foobar", b_style) -- should be OK
	sp = media.newSimpleParagraph(0, 0, "foobar", b_style, "left", math.huge) -- should be OK

	SimpleParagraph:draw() -- no assertions.
	SimpleParagraph:refreshSize() -- no assertions.
	media.basic_simpleParaDraw() -- no assertions.

	SimpleParagraph:update() -- no assertions.
end
--]]

