-- RText Media module.

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
Provides Document, Paragraph and Line structures (basically everything higher-
level than Text Blocks).
--]]


local media = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local aligner = require(REQ_PATH .. "aligner")
local auxColor = require(REQ_PATH .. "lib.aux_color")
local textBlock = require(REQ_PATH .. "text_block")
local textUtil = require(REQ_PATH .. "text_util")


-- A temporary transform object for applying scaling, rotation, shearing, etc., to text and associated shapes.
local temp_transform = love.math.newTransform()


local dummy_fn = function() end


-- * Internal *


local function errBadEnum(n, enum_id, val)
	error("argument #" .. n .. ": bad enum for " .. enum_id .. ": " .. tostring(val), 2)
end


local function errArgBadType(n, val, expected, level)

	level = level or 2
	error("argument #" .. n .. ": bad type (expected " .. expected .. ", got " .. type(val) .. ")", level)
end


-- * / Internal *


-- * Documents *


local _mt_doc = {}
_mt_doc.__index = _mt_doc
media._mt_doc = _mt_doc


-- Default draw params for documents.
_mt_doc.d_x = 0
_mt_doc.d_y = 0
_mt_doc.d_r = 0
_mt_doc.d_sx = 1.0
_mt_doc.d_sy = 1.0
_mt_doc.d_ox = 0
_mt_doc.d_oy = 0
_mt_doc.d_kx = 0
_mt_doc.d_ky = 0

-- Default draw color for documents.
_mt_doc.c_r = 1.0
_mt_doc.c_g = 1.0
_mt_doc.c_b = 1.0
_mt_doc.c_a = 1.0


function media.newDocument()

	local self = {}

	-- Horizontal wrap-limit for the document.
	-- Can be helpful to store here in case the document needs to be partially recreated.
	self.wrap_w = math.huge

	self.paragraphs = {}

	setmetatable(self, _mt_doc)

	return self
end


function _mt_doc:draw(x, y, para1, para2)

	x = x or 0
	y = y or 0

	local paragraphs = self.paragraphs

	para1 = para1 or 1
	para2 = para2 or #paragraphs

	para1 = math.max(1, math.min(para1, #paragraphs))
	para2 = math.max(1, math.min(para2, #paragraphs))

	love.graphics.push("all")

	temp_transform:setTransformation(
		self.d_x + x,
		self.d_y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)
	love.graphics.applyTransform(temp_transform)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVV(rr, gg, bb, aa, self.c_r, self.c_g, self.c_b, self.c_a)

	if self.cb_drawFirst then
		self:cb_drawFirst(0, 0)
	end

	for i = para1, para2 do
		local paragraph = paragraphs[i]
		paragraph:draw(0, 0)
	end

	if self.cb_drawLast then
		self:cb_drawLast(0, 0)
	end

	love.graphics.pop()
end


function media.basic_documentDraw(self, x, y, para1, para2)

	x = x or 0
	y = y or 0

	local paragraphs = self.paragraphs

	para1 = para1 or 1
	para2 = para2 or #paragraphs

	para1 = math.max(1, math.min(para1, #paragraphs))
	para2 = math.max(1, math.min(para2, #paragraphs))

	love.graphics.push("all")

	for i = para1, para2 do
		local paragraph = paragraphs[i]
		paragraph:draw(x, y)
	end

	love.graphics.pop()
end


function _mt_doc:debugDraw(x, y, para1, para2)

	-- Does not apply transform parameters.

	local paragraphs = self.paragraphs

	para1 = para1 or 1
	para2 = para2 or #paragraphs

	para1 = math.max(1, math.min(para1, #paragraphs))
	para2 = math.max(1, math.min(para2, #paragraphs))

	for i = para1, para2 do
		local paragraph = paragraphs[i]
		if paragraph.debugDraw then
			paragraph:debugDraw(x, y)
		end
	end
end


function _mt_doc:getParagraphAtPoint(x, y, n)

	-- Does not account for transformations.

	n = n or 1
	local paragraphs = self.paragraphs

	for i = n, #paragraphs do
		local para = paragraphs[i]
		if x >= para.x and x < para.x + para.w and y >= para.y and y < para.y + para.h then
			return para, i
		end
	end

	return nil
end


function _mt_doc:getBoundingBox()

	-- Does not account for transformations.

	local x1, y1, x2, y2 = 0, 0, 0, 0

	for i, para in ipairs(self.paragraphs) do
		x1 = math.min(x1, para.x)
		y1 = math.min(y1, para.y)
		x2 = math.max(x2, para.x + para.w)
		y2 = math.max(y2, para.y + para.h)
	end

	return x1, y1, x2, y2
end


function _mt_doc:update(dt)

	if self.cb_update then
		self:cb_update(dt)
	end
	for i, para in ipairs(self.paragraphs) do
		para:update(dt)
	end
end


-- * / Documents *


-- * Paragraphs *


function media.newParagraph(para_style)

	-- Assertions
	-- [[
	if type(para_style) ~= "table" then errArgBadType(1, para_style, "table") end
	--]]

	local self = {}

	-- Width and height are set during parsing.
	self.x = 0
	self.y = 0
	self.w = 0
	self.h = 0

	-- Draw param defaults are in paragraph style.

	-- * Optional, used when drawing. Can be placed in the paragraph style metatable or directly
	--   in the instance:
	-- self.cb_drawFirst
	-- self.cb_drawLast

	self.lines = {}

	setmetatable(self, para_style)

	return self
end


-- * Font Groups *


local _mt_font_group = {}
_mt_font_group.__index = _mt_font_group


function media.newFontGroup(regular, bold, italic, bold_italic)

	-- Assertions
	-- [[
	if type(regular) ~= "table" then errArgBadType(1, regular, "table")
	elseif bold and type(bold) ~= "table" then errArgBadType(2, bold, "table")
	elseif italic and type(italic) ~= "table" then errArgBadType(3, italic, "table")
	elseif bold_italic and type(bold_italic) ~= "table" then errArgBadType(4, bold_italic, "table") end
	--]]

	local self = {}

	self[1] = regular
	self[2] = bold or false
	self[3] = italic or false
	self[4] = bold_italic or false

	setmetatable(self, _mt_font_group)

	return self
end


function _mt_font_group:getFace(bold, italic)

	-- No assertions.

	local index = 1
	if bold then
		index = index + 1
	end
	if italic then
		index = index + 2
	end

	return self[index] or self[1]
end


-- * / Font Groups *


function media.newWordStyle(f_grp_id)

	-- Assertions
	-- [[
	if type(f_grp_id) ~= "string" then errArgBadType(1, f_grp_id, "string") end
	--]]

	local self = {}

	self.f_grp_id = f_grp_id

	self.bold = false
	self.italic = false
	self.strikethrough = false
	self.underline = false
	self.background = false

	self.color = false
	self.color_ul = false
	self.color_st = false
	self.color_bg = false

	return self
end


function media.newParagraphStyle(word_style, wrap_line_style)

	-- Assertions
	-- [[
	if type(word_style) ~= "table" then errArgBadType(1, word_style, "table")
	elseif wrap_line_style and type(wrap_line_style) ~= "table" then errArgBadType(2, wrap_line_style, "nil/false/table") end
	--]]

	wrap_line_style = wrap_line_style or media.newWrapLineStyle()

	local self = {}
	self.__index = self

	-- Standard paragraph methods.
	self.draw = media.default_paraDraw
	self.debugDraw = media.paraDebugDraw
	self.getWrapLineAtPoint = media.paraGetWrapLineAtPoint
	self.update = media.paraUpdate

	-- Transform params
	self.d_x = 0
	self.d_y = 0
	self.d_r = 0
	self.d_sx = 1.0
	self.d_sy = 1.0
	self.d_ox = 0
	self.d_oy = 0
	self.d_kx = 0
	self.d_ky = 0

	-- Draw color params
	self.c_r = 1.0
	self.c_g = 1.0
	self.c_b = 1.0
	self.c_a = 1.0

	-- Most of the fields below are copied directly to the rtext state table, and may be mutated
	-- by tags during construction of the paragraph.

	-- * Used when constructing or repositioning the paragraph:
	self.sp_left = 0
	self.sp_right = 0
	self.sp_top = 0
	self.sp_bottom = 0

	-- * Used when constructing the paragraph:
	self.word_style = word_style

	self.wrap_line_style = wrap_line_style

	-- Controls the current wrap-line indent.
	self.indent_x = 0

	-- Increases or decreases the wrap-limit for this line.
	self.ext_w = 0

	self.align = "left" -- "left", "center", "right", "justify"
	self.v_align = "baseline" -- "top", "middle", "ascent", "descent", "baseline", "bottom"

	-- For the last wrap-line, "justify" alignment falls back to "left" if this is false.
	self.justify_last_line = false

	-- Pixel granularity setting for justified text. Useful for paragraphs containing
	-- exclusively monospaced glyphs of the same size. For everything else, use 1.
	self.j_x_step = 1

	--[[
	Indent width hint for tags. A good starting value is the width of the tab character
	for the paragraph's default font. (We don't set it here because we don't have
	direct access to the font yet.)

	Something like:
	paragraph style -> word style -> block style[1] -> font:getWidth() * block style.f_sx
	--]]
	self.hint_indent_w = 20

	-- Spacing between paragraph and inner content.
	self.para_margin_left = 0 -- XXX rename to pad / padding
	self.para_margin_right = 0
	self.para_margin_top = 0
	self.para_margin_bottom = 0

	-- Enforces a minimum line height for this paragraph
	self.para_min_line_height = 0

	-- Line-level padding -- bottom side only.
	self.line_pad_bottom = 0

	-- Callbacks

	-- Called before the first text chunk is parsed for a paragraph.
	-- self.cb_initParagraph = false -- (rtext_instance, paragraph)

	-- Called after a wrap-line is finished.
	-- self.cb_finishedWrapLine = false -- (rtext_instance, paragraph, line, last_in_paragraph)

	-- Called after a paragraph is finished.
	-- self.cb_finishedParagraph = false -- (rtext_instance, paragraph)

	return self
end


function media.default_paraDraw(self, x, y)

	love.graphics.push("all")

	temp_transform:setTransformation(
		self.d_x + self.x + x,
		self.d_y + self.y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)
	love.graphics.applyTransform(temp_transform)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVV(rr, gg, bb, aa, self.c_r, self.c_g, self.c_b, self.c_a)

	if self.cb_drawFirst then
		self:cb_drawFirst(0, 0)
	end

	for i, wrap_line in ipairs(self.lines) do
		wrap_line:draw(0, 0)
	end

	if self.cb_drawLast then
		self:cb_drawLast(0, 0)
	end

	love.graphics.pop()
end


function media.basic_paraDraw(self, x, y)

	local xx = self.x + x
	local yy = self.y + y

	for i, wrap_line in ipairs(self.lines) do
		wrap_line:draw(xx, yy)
	end
end


local dbg_font -- used (sometimes) with paraDebugDraw()
function media.paraDebugDraw(self, x, y)

	-- Does not apply transform parameters.

	love.graphics.push("all")

	love.graphics.setColor(0, 0, 1, 0.5)
	love.graphics.rectangle("fill", self.x + x, self.y + y, self.w, self.h)

	for i, line in ipairs(self.lines) do
		love.graphics.setColor(0, 0.8, 0.8, 0.5)
		love.graphics.rectangle("fill", self.x + line.x + x, self.y + line.y + y, line.w, line.h)

		for j, block in ipairs(line.blocks) do
			if block.debugDraw then
				block:debugDraw(self.x + line.x + x, self.y + line.y + y)
			end
		end
		--[[
		-- show wrapline #
		dbg_font = dbg_font or love.graphics.newFont(13)
		love.graphics.setColor(1,1,1,1)
		love.graphics.print(i, dbg_font, line.x + line.w + 32, line.y)
		--]]
	end

	love.graphics.pop()
end


function media.paraGetWrapLineAtPoint(self, x, y, n)

	-- Does not account for transformations.

	n = n or 1
	local lines = self.lines
	for i = n, #lines do
		local line = lines[i]
		if x >= line.x and x < line.x + line.w and y >= line.y and y < line.y + line.h then
			return line, i
		end
	end

	return nil
end


function media.paraUpdate(self, dt)

	if self.cb_update then
		self:cb_update(dt)
	end
	for i, line in ipairs(self.lines) do
		line:update(dt)
	end
end


-- * / Paragraphs *


-- * Wrap-Lines *


function media.newWrapLine(wrap_line_style)

	-- Assertions
	-- [[
	if type(wrap_line_style) ~= "table" then errArgBadType(1, wrap_line_style, "table") end
	--]]

	local self = {}

	self.x = 0
	self.y = 0
	self.w = 0
	self.h = 0

	self.blocks = {}

	setmetatable(self, wrap_line_style)

	return self
end


function media.newWrapLineStyle()

	local self = {}
	self.__index = self

	-- Standard wrap-line methods.
	self.update = media.wrapLineUpdate
	self.draw = media.default_wrapLineDraw
	self.getBlockAtPoint = media.wrapLineGetBlockAtPoint

	-- NOTE: DebugDraw for Wrap-Lines is handled by Paragraphs.

	-- Transform params
	self.d_x = 0
	self.d_y = 0
	self.d_r = 0
	self.d_sx = 1.0
	self.d_sy = 1.0
	self.d_ox = 0
	self.d_oy = 0
	self.d_kx = 0
	self.d_ky = 0

	-- Color params
	self.c_r = 1
	self.c_g = 1
	self.c_b = 1
	self.c_a = 1

	-- Optional callbacks:
	-- self.cb_update
	-- self.cb_drawFirst
	-- self.cb_drawLast

	return self
end


function media.wrapLineGetBlockAtPoint(self, x, n)

	-- Does not account for transformations.

	n = n or 1
	local blocks = self.blocks
	for i = n, #self.blocks do
		local block = self.blocks[i]
		if x >= block.x and x < block.x + block.w + block.ws_w then
			return block, i
		end
	end

	-- (return nil)
end


function media.wrapLineUpdate(self, dt)

	if self.cb_update then
		self:cb_update(dt)
	end
	for i, block in ipairs(self.blocks) do
		if block.cb_update then
			block:cb_update(dt)
		end
	end
end


function media.default_wrapLineDraw(self, x, y)

	love.graphics.push("all")

	temp_transform:setTransformation(
		self.d_x + self.x + x,
		self.d_y + self.y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)
	love.graphics.applyTransform(temp_transform)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVV(rr, gg, bb, aa, self.c_r, self.c_g, self.c_b, self.c_a)

	if self.cb_drawFirst then
		self:cb_drawFirst(0, 0)
	end

	for b, block in ipairs(self.blocks) do
		block:draw(0, 0)
	end

	if self.cb_drawLast then
		self:cb_drawLast(0, 0)
	end

	love.graphics.pop()
end


function media.basic_wrapLineDraw(self, x, y)

	local xx = self.x + x
	local yy = self.y + y

	for b, block in ipairs(self.blocks) do
		block:draw(xx, yy)
	end
end


-- XXX: Get character byte offset within text block at position. This might need to be handled at the line level.


-- * / Wrap-Lines *


-- * Simple Paragraphs *


local simple_para_style = {}
simple_para_style.__index = simple_para_style

simple_para_style.sp_left = 0
simple_para_style.sp_right = 0
simple_para_style.sp_top = 0
simple_para_style.sp_bottom = 0

-- Default draw params for simple paragraphs
simple_para_style.d_x = 0
simple_para_style.d_y = 0
simple_para_style.d_r = 0
simple_para_style.d_sx = 1.0
simple_para_style.d_sy = 1.0
simple_para_style.d_ox = 0
simple_para_style.d_oy = 0
simple_para_style.d_kx = 0
simple_para_style.d_ky = 0

-- Default color params for simple paragraphs
simple_para_style.c_r = 1.0
simple_para_style.c_g = 1.0
simple_para_style.c_b = 1.0
simple_para_style.c_a = 1.0

-- Optional callbacks:
-- s_para.cb_update(self, dt) -- called from Document:update()
-- s_para.cb_drawFirst(self, x, y)
-- s_para.cb_drawLast(self, x, y)


function media.newSimpleParagraph(x, y, text, b_style, align, wrap_limit)

	align = align or "left"
	wrap_limit = wrap_limit or math.huge

	-- Assertions
	-- [[
	if type(x) ~= "number" then errArgBadType(1, x, "number")
	elseif type(y) ~= "number" then errArgBadType(2, y, "number")
	elseif type(text) ~= "string" then errArgBadType(3, text, "string")
	elseif type(b_style) ~= "table" then errArgBadType(4, b_style, "table")
	elseif type(align) ~= "string" then errArgBadType(5, align, "nil/false/string")
	elseif type(wrap_limit) ~= "number" then errArgBadType(6, wrap_limit, "nil/false/number") end

	if align ~= "left" and align ~= "center" and align ~= "right" and align ~= "justify" then
		errBadEnum(5, "LÖVE print alignment", align)
	end
	--]]

	local self = {}
	setmetatable(self, simple_para_style)

	self.x = x
	self.y = y

	self.b_style = b_style

	self.text = text
	self.wrap_limit = wrap_limit
	self.align = align

	-- Default draw params are in the simple para style metatable.

	self:refreshSize()

	return self
end


function simple_para_style:refreshSize()

	-- Calculate paragraph size.
	local b_style = self.b_style
	local font = b_style.font
	local wrap_limit = self.wrap_limit

	local _, wrapped = font:getWrap(self.text, wrap_limit)

	self.w = wrap_limit * b_style.f_sx
	self.h = #wrapped * b_style.f_height * b_style.f_sy
end


function simple_para_style:draw(x, y)

	-- No assertions.

	love.graphics.push("all")

	local b_style = self.b_style
	local font = b_style.font

	temp_transform:setTransformation(
		self.x + b_style.f_ox + self.d_x + x,
		self.y + b_style.f_oy + self.d_y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)
	love.graphics.applyTransform(temp_transform)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVV(rr, gg, bb, aa, self.c_r, self.c_g, self.c_b, self.c_a)

	if self.cb_drawFirst then
		self:cb_drawFirst(0, 0)
	end

	love.graphics.printf(
		self.text,
		font,
		0,
		0,
		self.wrap_limit,
		self.align
	)

	if self.cb_drawLast then
		self:cb_drawLast(0, 0)
	end

	love.graphics.pop()
end


function simple_para_style:update(dt)

	if self.cb_update then
		self:cb_update(dt)
	end
end


function media.basic_simpleParaDraw(self, x, y)

	local b_style = self.b_style

	local xx = self.x + b_style.f_ox + x
	local yy = self.y + b_style.f_oy + y

	love.graphics.printf(
		self.text,
		b_style.font,
		xx,
		yy,
		self.wrap_limit,
		self.align
	)
end


-- * / Simple Paragraphs *


-- * Labels *


--[[
A Label is just a sequence of Text Blocks with some methods for appending and arranging blocks.

For simple use cases, like `Press <gamepad_button> To Continue`, it's less overhead compared to
a full Document or Paragraph.

Labels are not Wrap-Lines, and should not be injected into Documents as part of the text flow.
Whitespace measurement (has_ws, ws_w) is not handled.
--]]


local _mt_label = {}
_mt_label.__index = _mt_label


function media.newLabel()

	local self = {}
	setmetatable(self, _mt_label)

	return self
end


function _mt_label:clear()

	for i = #self, 1, -1 do
		self[i] = nil
	end
end


function _mt_label:appendText(str, block_style, color, color_ul, color_st, color_bg)

	-- Assertions
	-- [[
	if type(str) ~= "string" then errArgBadType(1, str, "string")
	-- block_style is indexed, enforcing type(v) == "table"
	elseif color and type(color) ~= "table" then errArgBadType(3, color, "false/nil/table")
	elseif color_ul and type(color_ul) ~= "table" then errArgBadType(4, color_ul, "false/nil/table")
	elseif color_st and type(color_st) ~= "table" then errArgBadType(5, color_st, "false/nil/table")
	elseif color_bg and type(color_bg) ~= "table" then errArgBadType(6, color_bg, "false/nil/table") end
	--]]

	local font = block_style.font
	local width = font:getWidth(str) * block_style.f_sx
	local height = font:getHeight() * block_style.f_sy

	local block = textBlock.newTextBlock(
		str,
		block_style,
		0,
		0,
		width,
		height,
		nil, -- 'ws_w' not used by labels.
		nil, -- 'has_ws' not used by labels.
		color,
		color_ul,
		color_st,
		color_bg
	)

	self:appendBlock(block)

	return block
end


function _mt_label:extendLastBlock(str, color)

	local block = self[#self]

	if not block then
		error("no Text Block to extend.")
	end

	block:extend(str, color)

	-- Get new width
	local font = block.font
	local width = textUtil.getTextWidth(block.text, font) * block.f_sx

	block.w = width
	block.ws_w = 0
	block.has_ws = false
end


function _mt_label:appendBlock(block)

	-- Assertions
	-- [[
	if type(block) ~= "table" then errArgBadType(1, block, "table") end
	--]]

	local x = 0
	local prev = self[#self]
	self[#self + 1] = block

	if prev then
		x = prev.x + prev.w + prev.ws_w
	end

	block.x = x
end


function _mt_label:arrange(v_align)

	v_align = v_align or "baseline"

	-- Assertions
	-- [[
	if not aligner.enum_v_align[v_align] then errBadEnum(2, "vertical alignment", v_align) end
	--]]

	local prev = self[1]
	prev.x = 0
	for i = 2, #self do
		self.x = prev.x + prev.w + prev.ws_w
	end

	aligner.vertical(self, v_align)
end


function _mt_label:draw(x, y)

	for i, block in ipairs(self) do
		block:draw(x, y)
	end
end


-- * / Labels *


return media
