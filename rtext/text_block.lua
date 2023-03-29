-- TextBlock module: arrays of drawable media blocks.

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


local textBlock = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local auxColor = require(REQ_PATH .. "lib.aux_color")


-- LÖVE Graphics locals


-- * Internal *


-- A temporary transform object for applying scaling, rotation, shearing, etc., to text and associated shapes.
local temp_transform = love.math.newTransform()


local function errArgBadType(n, expected, val)
	error("argument #" .. n .. ": bad type (expected " .. expected .. ", got " .. type(val) .. ")", 2)
end


-- [UPGRADE] Remove in LÖVE 12.
local _love11TextGuard
do
	local major, minor = love.getVersion()
	if major <= 11 then
		_love11TextGuard = function(text)
			if type(text) == "string" and string.find(text, "%S") then
				return true

			else
				for i, chunk in ipairs(text) do
					if type(chunk) == "string" and string.find(chunk, "%S") then
						return true
					end
				end
			end

			return false
		end

	else
		_love11TextGuard = function()
			return true
		end
	end
end


-- * / Internal *


-- * Public API *


function textBlock.newBlockStyle(font)

	-- Assertions
	-- [[
	if type(font) ~= "userdata" then errArgBadType(1, "userdata (LÖVE Font)", font) end
	--]]

	local self = {}
	self.__index = self

	-- -> Required:
	-- IDs the Text Block as drawable text (as opposed to an arbitrary block).
	self.f_type = "text"

	-- The LÖVE Font object.
	self.font = font

	-- Base font offsets when drawing.
	self.f_ox = 0
	self.f_oy = 0

	-- X and Y scale when constructing and drawing blocks.
	-- Non-integral values may lead to off-the-pixel-grid positioning of blocks -> blurry text
	self.f_sx = 1.0
	self.f_sy = 1.0

	--[[
	The following vertical font metrics are cached as well. This allows tweaking the metrics of
	LÖVE ImageFonts, which only have their height set by the Font subsystem, so that they may
	be vertically aligned with TrueType and BMFont blocks.
	--]]
	self.f_height = font:getHeight()
	self.f_baseline = font:getBaseline()
	self.f_ascent = font:getAscent()
	self.f_descent = font:getDescent()

	-- Extender method.
	self.extend = textBlock.extend

	-- Methods used to render text and shapes.
	self.renderText = textBlock.renderText
	self.renderBackground = textBlock.renderBackground
	self.renderUnderline = textBlock.renderUnderline
	self.renderStrikethrough = textBlock.renderStrikethrough

	self.draw = textBlock.default_draw
	self.drawToTextBatch = textBlock.default_drawToTextBatch
	self.debugDraw = textBlock.debugDraw

	-- -> Dependent on shape implementation; required for the default methods.
	-- X and Y offsets when drawing underlines. Added to 'f_ox' and 'f_oy'.
	self.ul_ox = 0
	self.ul_oy = self.f_baseline

	-- The underline width and style.
	self.ul_width = 1
	self.ul_style = "smooth"

	-- X and Y offsets when drawing strikethrough lines. Added to 'f_ox' and 'f_oy'.
	self.st_ox = 0
	self.st_oy = math.floor(self.f_height / 2)

	-- The strikethrough width and style.
	self.st_width = 1.0
	self.st_style = "smooth"

	-- X and Y offsets when drawing background rectangles. Added to 'f_ox' and 'f_oy'.
	self.bg_ox = 0
	self.bg_oy = 0

	-- Extend or shorten the dimensions of background rectangles when drawing.
	self.bg_ext_w = 0
	self.bg_ext_h = 0

	-- Default transform parameters.
	self.d_x = 0
	self.d_y = 0
	self.d_r = 0
	self.d_sx = 1.0
	self.d_sy = 1.0
	self.d_ox = 0
	self.d_oy = 0
	self.d_kx = 0
	self.d_ky = 0

	-- Default color parameters. These are mixed with coloredtext colors and shape colors
	-- (underline, strikethrough, background.)
	self.c_r = 1.0
	self.c_b = 1.0
	self.c_g = 1.0
	self.c_a = 1.0

	-- Stand-ins for whitespace measurements.
	-- These are used during RText Paragraph creation (they help with justify alignment), but are not used in Labels.
	self.ws_w = 0
	self.has_ws = false

	--[[
	Optional callbacks:
	cb_drawFirst
	cb_drawLast
	cb_update
	--]]

	--[[
	Font object-level state is not handled here:
	* Fallback fonts
	* Font filters
	--]]

	return self
end


function textBlock.newTextBlock(text, b_style, x, y, w, h, ws_w, has_ws, color, color_ul, color_st, color_bg)

	-- No assertions.

	local block = {}

	if color then
		block.text = {color, text}

	else
		block.text = text
	end

	block.x = x
	block.y = y
	block.w = w
	block.h = h

	-- (*1): Leave nil to fall back to a stand-in value in the Block Style.
	block.ws_w = ws_w -- (*1) 0
	block.has_ws = has_ws  -- (*1) nil

	block.color_ul = color_ul -- (*1) nil
	block.color_bg = color_bg -- (*1) nil
	block.color_st = color_st -- (*1) nil

	-- See Block Style for more fields.
	setmetatable(block, b_style)

	return block
end


function textBlock.extend(self, new_text, color)

	-- No assertions.

	local text = self.text

	-- string + <string|coloredtext> = coloredText
	if type(text) == "string" then
		self.text = {text}
		if color then
			self.text[#self.text + 1] = color
		end
		self.text[#self.text + 1] = new_text

	-- Extend coloredtext
	else
		if color then
			self.text[#self.text + 1] = color
		end
		self.text[#self.text + 1] = new_text
	end
end


function textBlock.newBlockStyleArbitrary()

	local self = {}
	self.__index = self

	self.f_type = "arbitrary" -- overwrite as needed, but it should be anything but "text"

	self.f_sx = 1.0
	self.f_sy = 1.0

	-- Arbitrary blocks need to provide some fake vertical metrics for correct placement among
	-- Text Blocks.
	self.f_height = 0
	self.f_baseline = 0
	self.f_ascent = 0
	self.f_descent = 0

	-- Default transform parameters.
	self.d_x = 0
	self.d_y = 0
	self.d_r = 0
	self.d_sx = 1.0
	self.d_sy = 1.0
	self.d_ox = 0
	self.d_oy = 0
	self.d_kx = 0
	self.d_ky = 0

	-- Default color parameters.
	self.c_r = 1.0
	self.c_b = 1.0
	self.c_g = 1.0
	self.c_a = 1.0

	-- Not used, but include them so that Arbitrary Blocks can be processed along with
	-- Text Blocks.
	self.ws_w = 0
	self.has_ws = false

	--[[
	Caller needs to set:
		self.draw
		self.x, self.y, self.w, self.h

	Caller can set 'self.debugDraw' to help with troubleshooting.
	--]]

	-- * Set this as the arbitrary block's metatable.

	return self
end


-- * / Public API *


-- * Default plug-ins *


function textBlock.renderText(self, x, y)

	love.graphics.print(self.text, self.font, x, y, 0, self.f_sx, self.f_sy)
end


function textBlock.renderBackground(self, x, y, w, h, color)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVT(rr, gg, bb, aa, color)

	love.graphics.rectangle(
		"fill",
		x + self.bg_ox,
		y + self.bg_oy,
		w + self.bg_ext_w,
		h + self.bg_ext_h
	)

	love.graphics.setColor(rr, gg, bb, aa)
end


function textBlock.renderUnderline(self, x1, y1, x2, y2, color)

	love.graphics.push("all")

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVT(rr, gg, bb, aa, color)

	love.graphics.setLineWidth(self.ul_width)
	love.graphics.setLineStyle(self.ul_style)

	love.graphics.line(
		x1 + self.ul_ox + 0.5,
		y1 + self.ul_oy + 0.5,
		x2 + self.ul_ox + 0.5,
		y2 + self.ul_oy + 0.5
	)

	love.graphics.pop()
end


function textBlock.renderStrikethrough(self, x1, y1, x2, y2, color)

	love.graphics.push("all")

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mixVT(rr, gg, bb, aa, color)

	love.graphics.setLineWidth(self.st_width)
	love.graphics.setLineStyle(self.st_style)

	love.graphics.line(
		x1 + self.st_ox + 0.5,
		y1 + self.st_oy + 0.5,
		x2 + self.st_ox + 0.5,
		y2 + self.st_oy + 0.5
	)

	love.graphics.pop()
end


function textBlock.default_draw(self, x, y)

	love.graphics.push("all")

	temp_transform:setTransformation(
		self.x + self.f_ox + self.d_x + x,
		self.y + self.f_oy + self.d_y + y,
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
		self:cb_drawFirst(x, y)
	end

	-- Render functions should restore any graphics state changes they make.

	if self.color_bg then
		self:renderBackground(0, 0, self.w + self.ws_w, self.h, self.color_bg)
	end
	if self.color_ul then
		self:renderUnderline(0, 0, self.w + self.ws_w - 1, 0, self.color_ul)
	end

	self:renderText(0, 0)

	if self.color_st then
		self:renderStrikethrough(0, 0, self.w + self.ws_w - 1, 0, self.color_st)
	end

	if self.cb_drawLast then
		self:cb_drawLast(x, y)
	end

	love.graphics.pop()
end


function textBlock.basic_draw(self, x, y)

	local xx = self.x + self.f_ox + x
	local yy = self.y + self.f_oy + y

	if self.color_bg then
		self:renderBackground(xx, yy, self.w + self.ws_w, self.h, self.color_bg)
	end
	if self.color_ul then
		self:renderUnderline(xx, yy, xx + self.w + self.ws_w - 1, yy, self.color_ul)
	end

	self:renderText(xx, yy)

	if self.color_st then
		self:renderStrikethrough(xx, yy, xx + self.w + self.ws_w - 1, yy, self.color_st)
	end
end


function textBlock.default_drawToTextBatch(self, text_batch, x, y)

	-- No assertions.

	local font = self.font

	-- Does not apply color parameters (self.c_r, self.c_g, self.c_b, self.c_a).
	-- But coloredtext info will be passed along to the TextBatch.

	if _love11TextGuard(self.text) then
		text_batch:add(
			self.text,
			self.x + self.f_ox + self.d_x + x,
			self.y + self.f_oy + self.d_y + y,
			self.d_r,
			self.d_sx,
			self.d_sy,
			self.d_ox,
			self.d_oy,
			self.d_kx,
			self.d_ky
		)
	end
end


function textBlock.basic_drawToTextBatch(self, text_batch, x, y)

	-- No assertions.

	-- There isn't really anything to pare down here, but it should
	-- ignore transform parameters like the other 'basic' variations.

	local font = self.font

	if _love11TextGuard(self.text) then
		text_batch:add(
			self.text,
			self.x + self.f_ox + x,
			self.y + self.f_oy + y,
			0,
			1.0,
			1.0,
			0.0,
			0.0,
			0.0,
			0.0
		)
	end
end


function textBlock.debugDraw(self, x, y)

	-- Does not apply transform parameters.

	local font = self.font

	love.graphics.push("all")

	love.graphics.translate(self.x + x, self.y + y)

	-- Word portion of block
	love.graphics.setColor(1, 0, 0, 0.5)
	love.graphics.rectangle("fill", 0, 0, self.w, self.h)

	-- Trailing whitespace portion of block
	if self.has_ws and self.ws_w > 0 then
		love.graphics.setColor(0, 1, 0, 0.5)
		love.graphics.rectangle("fill", self.w, 0, self.ws_w, self.h)
	end

	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle("rough")

	-- [[
	-- Illustrate the font's ascent, baseline and descent.
	local y_baseline = font:getBaseline()
	local y_ascent = y_baseline - font:getAscent()
	local y_descent = y_baseline - font:getDescent()

	love.graphics.setColor(1,1,1,1)
	love.graphics.line(
		0.5,
		y_ascent + 0.5,
		self.w - 1 + 0.5,
		y_ascent + 0.5
	)

	love.graphics.setColor(0,1,1,1)
	love.graphics.line(
		0.5,
		y_baseline + 0.5,
		self.w - 1 + 0.5,
		y_baseline + 0.5
	)

	love.graphics.setColor(1,0,1,1)
	love.graphics.line(
		0.5,
		y_descent + 0.5,
		self.w - 1 + 0.5,
		y_descent + 0.5
	)

	love.graphics.setColor(1,1,1,1)
	--]]

	-- Draw indicators for backgrounds, underlines and strikethroughs.
	-- Block Style shape offsetting and expansions / contractions is not accounted for.
	local tick = love.timer.getTime() * 4
	if self.color_bg then
		love.graphics.setColor(1,0,1,1)
		love.graphics.rectangle(
			"line",
			0,
			0,
			self.w + (self.has_ws and self.ws_w or 0) - 1,
			self.h - 1
		)
	end

	if self.color_ul then
		love.graphics.setColor(0,1,1,1)
		love.graphics.line(
			0.5,
			self.f_baseline + 0.5,
			self.w - 1 + 0.5,
			self.f_baseline + 0.5
		)
	end

	if self.color_st then
		love.graphics.setColor(1,1,0,1)
		love.graphics.line(
			0.5,
			math.floor(self.f_height / 2) + 0.5,
			0.5,
			math.floor(self.f_height / 2) + 0.5
		)
	end

	love.graphics.pop()
end


-- * / Default plug-ins *


return textBlock
