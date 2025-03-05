-- TextBlock module tests.


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
(1) Colorization test

(2) Monochrome test

(3) Extension test

(4) Arbitrary Block Style

(5) Block Shapes (underline, strikethrough, background)
    Text Block color parameters
    Some transform parameters

(6) Text Block basic draw method (no color, transform params)

(7) Draw to TextBatch, Basic Draw to TextBatch
--]]


local _newTextBatch
local love_major, love_minor = love.getVersion()
if love_major <= 11 then
	_newTextBatch = love.graphics.newText

else
	_newTextBatch = love.graphics.newTextBatch
end


-- `rtext.lua` is not needed for these tests.
local media = require("rtext.media")
local textBlock = require("rtext.text_block")
local textUtil = require("rtext.text_util")


local demo_show_debug = false


local main_font = love.graphics.newFont(15)


-- Make a couple of Block Styles.
local bs_norm = textBlock.newBlockStyle(love.graphics.newFont(24))
local bs_small = textBlock.newBlockStyle(love.graphics.newFont(14))

-- Adjust Block Style shapes a bit.
bs_norm.ul_width = 2
bs_norm.st_width = 2


-- And some color tables.
local colors = {}
colors.white = {1, 1, 1, 1}
colors.red = {1, 0, 0, 1}
colors.black = {0, 0, 0, 1}
colors.green = {0, 1, 0, 1}
colors.blue = {0, 0, 1, 1}


-- A simple draw function for blocks, since we are using plain tables as containers.
local function drawBlocks(blocks, x, y)

	x = x or 0
	y = y or 0

	for j, block in ipairs(blocks) do
		if demo_show_debug then
			if block.debugDraw then
				textBlock.debugDraw(block, x, y)
			end
		end
		block:draw(x, y)
	end
end


-- (1) Colorized test
local blk = {}
do
	-- textBlock expects content that is already parsed and arranged into blocks.
	-- We will manually set the markup equivalent of:
	-- "Jackdaws [small][red]love[/small] my[/red] black sphinx of quartz"

	-- We won't pass whitespace metrics onto the Text Blocks since we are just laying
	-- them out in a one-time manner.

	local blocks = blk

	local txt, fw, fh, ftr_w
	local xx = 0
	local ii = 0
	local b_style
	local font

	ii = ii + 1
	txt = "Jackdaws "
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil,
		colors.white
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = "love"
	b_style = bs_small
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		bs_norm.f_baseline - bs_small.f_baseline,
		fw,
		fh,
		nil,
		nil,
		colors.red
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = " my"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil,
		colors.red
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = " black sphinx of quartz"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil,
		colors.white
	)
	xx = xx + fw + ftr_w
end


-- (2) Monochrome text
local blk_mono = {}
do
	-- Monochrome text blocks create slightly fewer tables internally.
	local blocks = blk_mono
	local txt, fw, fh, ftr_w
	local xx = 0
	local ii = 0
	local b_style
	local font

	ii = ii + 1
	txt = "Jackdaws "
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = "love"
	b_style = bs_small
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		bs_norm.f_baseline - bs_small.f_baseline,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = " my"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = " black sphinx of quartz"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w
end


-- (3) Block extension test
local blk_ext = {}
do
	local blocks = blk_ext

	local txt, fw, fh
	local b_style
	local font

	-- The starting block. (We'll set the dimensions later.)
	txt = "Ex"
	b_style = bs_norm
	font = b_style.font
	local block = textBlock.newTextBlock(
		txt,
		b_style,
		0,
		0,
		0,
		0,
		nil,
		nil
	)
	blocks[1] = block

	-- Promote from plain string to coloredtext
	block:extend("ten", colors.red)

	-- A couple more times.
	block:extend("nnnN", colors.green)
	block:extend("NNnnnded text block", colors.blue)

	-- Refresh the block dimensions.
	block.w = textUtil.getTextWidth(block.text, block.font) * block.f_sx
	block.h = font:getHeight() * block.f_sy
end


-- (4) Arbitrary Block
local blk_arb = {}
do

	local blocks = blk_arb
	local txt, fw, fh, ftr_w
	local xx = 0
	local ii = 0
	local b_style
	local font

	-- Set up the Arbitrary Block Style
	local temp_transform = love.math.newTransform()
	local b_style_arb = textBlock.newBlockStyleArbitrary()

	b_style_arb.draw = function(self, x, y)

		love.graphics.push("all")

		temp_transform:setTransformation(
			self.x + self.d_x + x,
			self.y + self.d_y + y,
			self.d_r,
			self.d_sx,
			self.d_sy,
			self.d_ox,
			self.d_oy,
			self.d_kx,
			self.d_ky
		)
		love.graphics.applyTransform(temp_transform)

		love.graphics.setLineStyle("smooth")
		love.graphics.setLineWidth(4)

		-- Ignore transform
		love.graphics.circle("line", 0, 0, self.w/2)

		love.graphics.pop()
	end

	-- Onto block creation...

	ii = ii + 1
	txt = "Fo"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w

	-- Make the arbitrary block
	ii = ii + 1
	local arb = setmetatable({}, b_style_arb)
	arb.x = xx
	arb.y = 0
	arb.w = 24
	arb.h = 24
	arb.d_x = arb.w/2
	arb.d_y = arb.h/2
	arb.d_ox = arb.w/8
	arb.d_oy = arb.h/4

	blocks[ii] = arb
	xx = xx + fw + ftr_w

	ii = ii + 1
	txt = "bar"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy
	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil
	)
	xx = xx + fw + ftr_w
end


local once_first, once_last = false, false
local function cb_drawFirst(self, x, y)
	if not once_first then
		print("allshapes: cb_drawFirst -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_first = true
end
local function cb_drawLast(self, x, y)
	if not once_last then
		print("allshapes: cb_drawLast -- this is just to confirm that the callback is fired. It should print to console only once.")
	end

	once_last = true
end


-- (5) Underline, Strikethrough, Background State; test cb_drawFirst and cb_drawLast callbacks
local blk_shape = {}
do
	local blocks = blk_shape

	local txt, fw, fh, ftr_w
	local xx = 0
	local ii = 0
	local b_style
	local font

	ii = ii + 1
	txt = "AllShapes+ColorParams"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy

	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil,
		colors.white,
		colors.red,
		colors.black,
		colors.blue
	)
	xx = xx + fw + ftr_w

	-- Make sure Text Block draw callbacks are firing in the default draw method
	blocks[ii].cb_drawFirst = cb_drawFirst
	blocks[ii].cb_drawLast = cb_drawLast
end


-- (6) Text Block basic draw (no transform or color params)
local blk_basic = {}
do
	local blocks = blk_basic

	local txt, fw, fh, ftr_w
	local xx = 0
	local ii = 0
	local b_style
	local font

	ii = ii + 1
	txt = "BasicDraw"
	b_style = bs_norm
	font = b_style.font
	ftr_w = font:getWidth(string.match(txt, "%s*$")) * b_style.f_sx
	fw = font:getWidth(txt) * b_style.f_sx - ftr_w
	fh = font:getHeight() * b_style.f_sy

	blocks[ii] = textBlock.newTextBlock(
		txt,
		b_style,
		xx,
		0,
		fw,
		fh,
		nil,
		nil,
		colors.white,
		colors.red,
		colors.black,
		colors.blue
	)

	-- Apply the Basic Draw method
	blocks[ii].draw = textBlock.basic_draw
	blocks[ii].drawToTextBatch = textBlock.basic_drawToTextBatch

	xx = xx + fw + ftr_w
end


-- (7) Draw to TextBatch
local text_batch = _newTextBatch(bs_norm.font)
local function updateTextBatch(text_batch)

	-- Text Batches lose their performance advantage if you are constantly updating them.
	-- This is just for testing purposes (to prove that transform state is being passed along.)
	text_batch:clear()

	local default1 = blk_shape[1]
	local basic1 = blk_basic[1]

	text_batch:add("drawToTextBatch (default, basic):")
	default1:drawToTextBatch(text_batch, 64, 32)
	basic1:drawToTextBatch(text_batch, 64, 64)
end


local function countTables(t, _c, _seen)

	-- Counts values only (doesn't bother with keys)
	_c = _c or 1
	_seen = _seen or {}

	for k, v in pairs(t) do
		if type(v) == "table" then
			if not _seen[v] then
				_seen[v] = true
				_c = _c + 1
				_c = countTables(v, _c, _seen)
			end
		end
	end

	return _c
end


local count_blk = countTables(blk)
local count_blk_mono = countTables(blk_mono)
local count_blk_ext = countTables(blk_ext)

--[[
local inspect = require("demo_lib.inspect.inspect")
print("(1) Colorized Table:", inspect(blk))
print("(2) Monochrome Table:", inspect(blk_mono))
print("(3) Extended Block Table:", inspect(blk_ext))
--]]


local t = 0


blk_shape[1].cb_update = function(self, dt)
	self.c_r = (1.0 + math.cos(t*2.5) / 2)
	self.c_g = (1.0 + math.cos(t*2.6) / 2)
	self.c_b = (1.0 + math.cos(t*2.7) / 2)
	self.c_a = (1.0 + math.cos(t*2.8) / 2)

	self.d_x = math.floor(self.w / 2)
	self.d_y = math.floor(self.h / 2)
	self.d_ox = math.floor(self.w / 2)
	self.d_oy = math.floor(self.h / 2)
	self.d_kx = math.sin(t/4)/2
	self.d_ky = math.sin(t/4.5)/8
end


function love.update(dt)

	t = t + dt
	-- (4) Animate the arbitrary block
	local arb = blk_arb[2]
	arb.d_r = arb.d_r + math.sin(t)/math.pi

	-- Text Blocks do not have an update() method, since they are not expected to have
	-- any sub-structures which need updates. So just call the cb_update method directly.
	local allshapes = blk_shape[1]
	if allshapes.cb_update then
		allshapes:cb_update(dt)
	end
end


function love.draw()

	local y_meter = math.floor(love.graphics.getHeight() / 8 + 0.5)

	-- (1) Colorized test
	love.graphics.push("all")
	drawBlocks(blk, 0, 0)
	love.graphics.pop()

	-- (2) Monochrome test
	love.graphics.push("all")
	drawBlocks(blk_mono, 0, y_meter*1)
	love.graphics.pop()

	-- (3) Extension test
	love.graphics.push("all")
	drawBlocks(blk_ext, 0, y_meter*2)
	love.graphics.pop()

	-- (4) Arbitrary Block
	love.graphics.push("all")
	drawBlocks(blk_arb, 0, y_meter*3)
	love.graphics.pop()

	-- (5) Text Block Shapes
	love.graphics.push("all")
	drawBlocks(blk_shape, 0, y_meter*4)
	love.graphics.pop()

	-- (6) Basic Draw -- none of this should affect the output.
	local basic1 = blk_basic[1]
	basic1.c_r = (1.0 + math.cos(t*2.5) / 2)
	basic1.c_g = (1.0 + math.cos(t*2.6) / 2)
	basic1.c_b = (1.0 + math.cos(t*2.7) / 2)
	basic1.c_a = (1.0 + math.cos(t*2.8) / 2)

	basic1.d_x = math.floor(basic1.w / 2)
	basic1.d_y = math.floor(basic1.h / 2)
	basic1.d_ox = math.floor(basic1.w / 2)
	basic1.d_oy = math.floor(basic1.h / 2)
	basic1.d_kx = math.sin(t/4)/2
	basic1.d_ky = math.sin(t/4.5)/8
	drawBlocks(blk_basic, 0, y_meter*5)


	-- (7) Draw to TextBatch
	updateTextBatch(text_batch)
	love.graphics.draw(text_batch, 0, y_meter*6)


	-- Interface
	love.graphics.setFont(main_font)
	local y_bottom = love.graphics.getHeight()
	local dfy = main_font:getHeight()

	love.graphics.print("Tables in color media: " .. count_blk, 0, y_bottom - dfy*3)
	love.graphics.print("Tables in monochrome media: " .. count_blk_mono, 0, y_bottom - dfy*2)
	love.graphics.print("Tables in extended-block media: " .. count_blk_ext, 0, y_bottom - dfy*1)

	local instructions = "TAB: draw debug info; Esc: Quit"
	local inst_w = main_font:getWidth(instructions)
	love.graphics.print(instructions, love.graphics.getWidth() - inst_w - 4, y_bottom - dfy*1)
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()

	elseif kc == "tab" then
		demo_show_debug = not demo_show_debug
	end
end


-- Assertion Tests
--[[
do
	-- textBlock.newTextBlock: no assertions

	-- textBlock.newBlockStyle
	local foobar = textBlock.newBlockStyle("not-a-font") -- #1 bad type

	-- textBlock.extend: no assertions
	-- textBlock.newBlockStyleArbitrary: no assertions (nothing to assert)
	-- textBlock.renderText: no assertions
	-- textBlock.renderBackground: no assertions
	-- textBlock.renderUnderline: no assertions
	-- textBlock.renderStrikethrough: no assertions
	-- textBlock.default_draw: no assertions
	-- textBlock.basic_draw: no assertions
	-- textBlock.default_drawToTextBatch: no assertions
	-- textBlock.basic_drawToTextBatch: no assertions
	-- textBlock.debugDraw: no assertions
end
--]]
