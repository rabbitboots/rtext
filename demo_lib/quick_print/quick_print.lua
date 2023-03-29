-- QuickPrint: A text drawing library for LÖVE.
-- Version: 1.0.9a
-- LÖVE supported versions: 11.4
-- See LICENSE, README.md and the demos for more info.

--[[
	BUGS
	#1: In LÖVE 11.4, adding empty or whitespace-only strings to a Text Object crashes the application.
	This is fixed in LÖVE 12.
	'_love11TextGuard()' is implemented as a workaround. [UPGRADE] Remove in LÖVE 12.

	#2: In LÖVE 11.4, small wraplimit values given to Text:addf() crash the application.
	This is fixed in LÖVE 12. Text:setf() and love.graphics.printf() are not affected.
	Workaround: If using Text:addf(), find a minimum working value for your font(s) and never
	make the reference width smaller than that.
--]]

local quickPrint = {}


-- LÖVE Supplemental
local utf8 = require("utf8")


-- Main object metatable
local _mt_qp = {}
_mt_qp.__index = _mt_qp


-- Override these (either here or in individual qp instances) to change printing behavior.
-- For example, you could write a wrapper that first prints a black drop-shadow version of the text.
_mt_qp._love_print = love.graphics.print
_mt_qp._love_printf = love.graphics.printf
_mt_qp._text_add = nil
_mt_qp._text_addf = nil


--[[
Auxiliary database of font details. Helps with placement of LÖVE ImageFonts, which
do not have a baseline metric. The table uses weak references so that it does not prevent
LÖVE Font objects from being garbage collected.

Note that the Aux DB is module-wide, not per-instance, and fonts may only have one table
entry.
--]]
quickPrint.aux_db = {}
quickPrint._mt_aux_db = {__mode = "k"}
setmetatable(quickPrint.aux_db, quickPrint._mt_aux_db)


local enum_align = {["left"] = true, ["center"] = true, ["right"] = true, ["justify"] = true}
local enum_v_align = {["top"] = true, ["middle"] = true, ["true-middle"] = true, ["baseline"] = true, ["bottom"] = true}


-- * Internal Error + Utility Functions *


local function errType(arg_n, val, expected)
	error("argument #" .. arg_n .. " bad type (expected " .. expected .. ", got: " .. type(val) .. ")", 3)
end


local function errEnumAlign(arg_n, val)
	error("argument #" .. arg_n .. ": invalid horizontal align enum: " .. tostring(val), 3)
end


local function errEnumVAlign(arg_n, val)
	error("argument #" .. arg_n .. ": invalid vertical align enum: " .. tostring(val), 3)
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
				for i = 1, #text do
					local chunk = text[i]
					if type(chunk) == "string" and string.find(text[i], "%S") then
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


local function getVAlignOffset(font, aux, v_align)
	-- Value for "top" and invalid enums.
	local ret = 0

	if v_align == "true-middle" then
		ret = -math.floor(aux.sy * (aux.height / 2) + 0.5)

	elseif v_align == "middle" then
		ret = -math.floor(aux.sy * (aux.baseline - (aux.baseline - aux.ascent)) / 2 + 0.5)

	elseif v_align == "baseline" then
		ret = -math.floor(aux.sy * (aux.baseline) + 0.5)

	elseif v_align == "bottom" then
		ret = -aux.sy * aux.height
	end

	-- Multiply the result with self.sy.
	return ret
end


-- * / Internal Error + Utility Functions *


-- * Internal Write Functions *


local function plainWrite(self, str, font, aux)
	local text_width = font:getWidth(str)
	local align = self.align
	local scale_x = self.sx * aux.sx
	local scale_y = self.sy * aux.sy

	if font ~= self.line_font then
		self:clearKerningMemory()
	end

	-- Handle tab placement.
	if self.tabs then
		local tab_x = self.tabs[self.tab_i]

		if type(tab_x) == "table" then
			align = tab_x.align or align
			tab_x = tab_x.x
		end

		if tab_x then
			if align == "left" or align == "justify" then
				self.x = math.max(self.x, tab_x)

			elseif align == "center" then
				self.x = math.max(self.x, tab_x - math.floor(text_width*scale_x/2))

			elseif align == "right" then
				self.x = math.max(self.x, tab_x - text_width*scale_x)
			end

			self:clearKerningMemory()
		end
	end

	if #str > 0 then
		-- Apply plain alignment relative to cursor X

		-- Check kerning, if applicable.
		-- NOTE: The kerning offset may be incorrect if you switched between incompatible fonts from the last print operation.
		-- You can eliminate the kerning check by calling self:clearKerningMemory() between writes.
		if self.last_glyph then
			self.x = self.x + font:getKerning(self.last_glyph, utf8.codepoint(str, 1))
		end

		local px = self.origin_x + self.x + aux.ox
		local py = self.origin_y + self.y + aux.oy

		py = py + getVAlignOffset(font, aux, self.v_align) * self.sy

		-- NOTE: plainWrite() on its own does not move the cursor down to the next line, even if the string contains '\n'.
		if self.text_object then
			if _love11TextGuard(str) then
				if self._text_add then
					self._text_add(self.text_object, str, px, py, 0, scale_x, scale_y, 0, 0, 0, 0)
				else
					self.text_object:add(str, px, py, 0, scale_x, scale_y, 0, 0, 0, 0)
				end
			end

		else
			self._love_print(str, px, py, 0, scale_x, scale_y, 0, 0, 0, 0)
		end
	end

	-- Update kerning info for next write on this line
	-- May be cleared by advanceTab().
	if #str > 0 then
		self.last_glyph = utf8.codepoint(str, utf8.offset(str, -1))
	end

	self.x = math.ceil(self.x + text_width * scale_x)
	self:advanceTab()
end


local function formattedPrintLogic(self, text, align, font, aux, px, py)
	local scale_x = self.sx * aux.sx
	local scale_y = self.sy * aux.sy
	local scaled_w = math.ceil(self.ref_w / math.max(scale_x, 0.0000001)) -- avoid div/0
	py = py + getVAlignOffset(font, aux, self.v_align) * self.sy

	px = px + aux.ox
	py = py + aux.oy

	if self.text_object then
		if _love11TextGuard(text) then
			if self._text_addf then
				self.text_addf(self.text_object, text, scaled_w, align, px, py, 0, scale_x, scale_y, 0, 0, 0, 0)
			else
				self.text_object:addf(text, scaled_w, align, px, py, 0, scale_x, scale_y, 0, 0, 0, 0)
			end
		end

	else
		self._love_printf(text, px, py, scaled_w, align, 0, scale_x, scale_y, 0, 0, 0, 0)
	end
end


-- * / Internal Write Functions *


-- * Public Functions *


function quickPrint.new(ref_w, ref_h)
	-- Assertions
	-- [[
	if type(ref_w) ~= "number" and ref_w ~= nil then errType(1, ref_w, "number or nil")
	elseif type(ref_h) ~= "number" and ref_h ~= nil then errType(2, ref_h, "number or nil") end
	--]]

	local self = {}

	self.origin_x = 0
	self.origin_y = 0
	self.ref_w = ref_w or math.huge
	self.ref_h = ref_h or math.huge
	-- ref_h does nothing, but is provided in case it helps with assigning scissor boxes
	-- or placement against a bottom boundary.

	self.x = 0
	self.y = 0

	-- The last character in Unicode Code Point integer form, or false if there is no last character.
	self.last_glyph = false

	-- The last font object used on a single line, if known. Differences between last and current font
	-- may cause last_glyph to be cleared.
	self.line_font = false

	-- These are passed to love.graphics.print(). Cursor movement will attempt to take scale into account.
	self.sx = 1
	self.sy = 1

	-- Vertical padding between cursor lines (in pixels.)
	-- Depending on your needs, you may want to use Font:setLineHeight() instead to achieve a similar effect.
	self.pad_v = 0

	-- Alignment setting for plain print() and write() calls. For plain text, this is relative to the
	-- current cursor X position. For formatted text, it is relative to the reference width and the
	-- current tab stop if tabs are enabled.
	-- Some functions can override it. "justify" applies to formatted-print calls only, and will be
	-- treated as "left" for plain writes.
	self.default_align = "left" -- "left", "center", "right", "justify"
	self.align = self.default_align

	-- Vertical alignment of text, relative to the cursor. "top" is recommended when using a single font.
	-- The others might be helpful if you are mixing fonts. If using "middle" or "baseline" with an
	-- ImageFont, you must set the baseline metric in the font's aux table,
	self.default_v_align = "top" -- "top", "middle", "true-middle", "baseline", "bottom"
	self.v_align = self.default_v_align

	-- Sequence of "tab stops" with a per-pixel granularity, or false to disable tabs.
	-- Tab stop positions are absolute, not cumulative. They should be ordered smallest to largest.
	-- Each entry in self.tabs can be either a number or a table containing {x = <number>, align = <string|nil>},
	-- where 'x' is the horizontal tab position, and 'align' is "left", "center", "right" or nil, overriding
	-- the current plain-align mode if present.
	-- Applies to qp:print*(), qp:write*(), and qp:writefSingle().
	self.tab_i = 1
	self.tabs = false

	-- Assign a LÖVE Text object to append strings to it instead of writing to the framebuffer or active canvas.
	self.text_object = false

	setmetatable(self, _mt_qp)

	return self
end


function quickPrint.registerFont(font)
	-- Assertions
	-- [[
	if type(font) ~= "userdata" then errType(1, font, "userdata (LÖVE Font)") end
	--]]

	local entry = {}

	entry.height = font:getHeight()
	entry.ascent = font:getAscent()
	entry.descent = font:getDescent()
	entry.baseline = font:getBaseline()

	-- Font scale. Is multiplied with qp.sx and qp.sy.
	entry.sx = 1.0
	entry.sy = 1.0

	-- Font offset in pixels (not scaled by aux.sx and aux.sy).
	entry.ox = 0
	entry.oy = 0

	-- Overwrites any existing entry.
	quickPrint.aux_db[font] = entry

	return entry
end


function quickPrint.getAux(font)
	-- No assertions.
	-- * 'font' is type-checked by quickPrint.registerFont().

	local aux = quickPrint.aux_db[font]

	if not aux then
		aux = quickPrint.registerFont(font)
	end

	return aux
end


-- * / Public Functions *


-- * State Get/Set, Cursor Movement, Tab Advance *


function _mt_qp:getFont()
	return self.text_object and self.text_object:getFont() or love.graphics.getFont()
end


function _mt_qp:setTextObject(text_object)
	-- Assertions
	-- [[
	if text_object and type(text_object) ~= "userdata" then errType(1, text_object, "false/nil or userdata (LÖVE Text Object)") end
	--]]

	self.text_object = text_object or false
end


function _mt_qp:getTextObject()
	return self.text_object or nil
end


function _mt_qp:setTabs(tabs)
	-- Assertions
	-- [[
	if tabs and type(tabs) ~= "table" then errType(1, tabs, "table or false/nil") end
	--]]

	self.tabs = tabs or false
end


function _mt_qp:getTabs()
	return self.tabs or nil
end


function _mt_qp:setAlign(align)
	-- Assertions
	-- [[
	if not enum_align[align] then errEnumAlign(1, align) end
	--]]

	self.align = align
end


function _mt_qp:getAlign()
	return self.align
end


function _mt_qp:setDefaultAlign(align)
	-- Assertions
	-- [[
	if not enum_align[align] then errEnumAlign(1, align) end
	--]]

	self.default_align = align
end


function _mt_qp:getDefaultAlign()
	return self.default_align
end


function _mt_qp:setVAlign(v_align)
	-- Assertions
	-- [[
	if not enum_v_align[v_align] then errEnumVAlign(1, v_align) end
	--]]

	self.v_align = v_align
end


function _mt_qp:getVAlign()
	return self.v_align
end


function _mt_qp:setDefaultVAlign(v_align)
	-- Assertions
	-- [[
	if not enum_v_align[v_align] then errEnumVAlign(1, v_align) end
	--]]

	self.default_v_align = v_align
end


function _mt_qp:getDefaultVAlign()
	return self.default_v_align
end


function _mt_qp:advanceX(width)
	-- Assertions
	-- [[
	if type(width) ~= "number" then errType(1, width, "number") end
	--]]

	-- Cursor X advance is generally only useful with left alignment. The other align modes are intended to
	-- be used with virtual tab stops.

	self.x = math.ceil(self.x + width)

	self:clearKerningMemory()
end


function _mt_qp:advanceXStr(str)
	-- Assertions
	-- [[
	if type(str) ~= "string" then errType(1, str, "string") end
	--]]

	local font = self:getFont()
	local width = font:getWidth(str)

	self.x = math.ceil(self.x + width)

	self:clearKerningMemory()
end


function _mt_qp:setXMin(x_min)
	-- Assertions
	-- [[
	if type(x_min) ~= "number" then errType(1, x_min, "number") end
	--]]

	self.x = math.max(self.x, x_min)

	self:clearKerningMemory()
end


function _mt_qp:advanceXCoarse(coarse_x, margin)
	margin = margin or 0

	-- Assertions
	-- [[
	if type(coarse_x) ~= "number" then errType(1, coarse_x, "number")
	elseif type(margin) ~= "number" then errType(2, margin, "nil/number") end
	--]]

	self.x = math.max(self.x, math.floor(((self.x + margin + coarse_x) / coarse_x)) * coarse_x)

	self:clearKerningMemory()
end


function _mt_qp:advanceTab()
	if self.tabs then
		local tab_x = self.tabs[self.tab_i]
		if type(tab_x) == "table" then
			tab_x = tab_x.x
		end
		if tab_x and self.x < tab_x then
			self.x = tab_x
			self:clearKerningMemory()
		end

		self.tab_i = self.tab_i + 1
	end
end


function _mt_qp:setTabIndex(i)
	-- Assertions
	-- [[
	if type(i) ~= "number" then errType(1, i, "number") end
	--]]

	-- Does not check if a tabs table is currently populated, or that the index has an entry.
	self.tab_i = i
end


function _mt_qp:getTabIndex()
	local i = self.tab_i
	return (i == math.huge and false or i)
end


function _mt_qp:setPosition(x, y)
	-- Assertions
	-- [[
	if type(x) ~= "number" then errType(1, x, "number")
	elseif type(y) ~= "number" then errType(2, y, "number") end
	--]]

	self.x = x
	self.y = y

	self.tab_i = math.huge -- invalidate tab stop state
	self:clearKerningMemory()
end


function _mt_qp:setXPosition(x)
	-- Assertions
	-- [[
	if type(x) ~= "number" then errType(1, x, "number") end
	--]]

	self.x = x

	self.tab_i = math.huge
	self:clearKerningMemory()
end


function _mt_qp:setYPosition(y)
	-- Assertions
	-- [[
	if type(y) ~= "number" then errType(1, y, "number") end
	--]]

	self.y = y

	-- Does not invalidate tab stop state.
	-- Does not clear kerning memory.
end


function _mt_qp:getPosition()
	return self.x, self.y
end


function _mt_qp:getXPosition()
	return self.x
end


function _mt_qp:getYPosition()
	return self.y
end


function _mt_qp:movePosition(dx, dy)
	-- Assertions
	-- [[
	if type(dx) ~= "number" then errType(1, dx, "number")
	elseif type(dy) ~= "number" then errType(2, dy, "number") end
	--]]

	self.x = self.x + dx
	self.y = self.y + dy

	self.tab_i = math.huge
	self:clearKerningMemory()
end


function _mt_qp:moveXPosition(dx)
	-- Assertions
	-- [[
	if type(dx) ~= "number" then errType(1, dx, "number") end
	--]]

	self.x = self.x + dx

	self.tab_i = math.huge
	self:clearKerningMemory()
end


function _mt_qp:moveYPosition(dy)
	-- Assertions
	-- [[
	if type(dy) ~= "number" then errType(1, dy, "number") end
	--]]

	self.y = self.y + dy

	-- Does not invalidate tab stop state.
	-- Does not clear kerning memory.
end


function _mt_qp:setOrigin(origin_x, origin_y)
	-- Assertions
	-- [[
	if type(origin_x) ~= "number" then errType(1, origin_x, "number")
	elseif type(origin_y) ~= "number" then errType(2, origin_y, "number") end
	--]]

	self.origin_x = origin_x
	self.origin_y = origin_y

	self.x = 0
	self.y = 0

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:setXOrigin(origin_x)
	-- Assertions
	-- [[
	if type(origin_x) ~= "number" then errType(1, origin_x, "number") end
	--]]

	self.origin_x = origin_x

	self.x = 0
	self.y = 0

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:setYOrigin(origin_y)
	-- Assertions
	-- [[
	if type(origin_y) ~= "number" then errType(1, origin_y, "number") end
	--]]

	self.origin_y = origin_y

	self.x = 0
	self.y = 0

	self.tab_i = 1
	self:clearKerningMemory()
end



function _mt_qp:getOrigin()
	return self.origin_x, self.origin_y
end


function _mt_qp:getXOrigin()
	return self.origin_x
end


function _mt_qp:getYOrigin()
	return self.origin_y
end


function _mt_qp:moveOrigin(dx, dy)
	-- Assertions
	-- [[
	if type(dx) ~= "number" then errType(1, dx, "number")
	elseif type(dy) ~= "number" then errType(2, dy, "number") end
	--]]

	self.origin_x = self.origin_x + dx
	self.origin_y = self.origin_y + dy

	self.x = 0
	self.y = 0

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:setReferenceDimensions(ref_w, ref_h)
	-- Assertions
	-- [[
	if type(ref_w) ~= "number" then errType(1, ref_w, "number or nil") end
	if type(ref_h) ~= "number" then errType(2, ref_h, "number or nil") end
	--]]

	self.ref_w = ref_w
	self.ref_h = ref_h

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:getReferenceDimensions()
	return self.ref_w, self.ref_h
end


function _mt_qp:setReferenceWidth(ref_w)
	-- Assertions
	-- [[
	if type(ref_w) ~= "number" then errType(1, ref_w, "number") end
	--]]

	self.ref_w = ref_w

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:getReferenceWidth()
	return self.ref_w
end


function _mt_qp:setReferenceHeight(ref_h)
	-- Assertions
	-- [[
	if type(ref_h) ~= "number" then errType(1, ref_h, "number") end
	--]]

	self.ref_h = ref_h

	self.tab_i = 1
	self:clearKerningMemory()
end


function _mt_qp:getReferenceHeight()
	return self.ref_h
end


function _mt_qp:setScale(sx, sy)
	-- Assertions
	-- [[
	if type(sx) ~= "number" then errType(1, sx, "number")
	elseif type(sy) ~= "number" and sy ~= nil then errType(2, sy, "number or nil") end
	--]]

	self.sx = sx
	self.sy = sy or sx
end


function _mt_qp:getScale()
	return self.sx, self.sy
end


function _mt_qp:setVerticalPadding(pad_v)
	-- Assertions
	-- [[
	if type(pad_v) ~= "number" then errType(1, pad_v, "number") end
	--]]

	self.pad_v = pad_v
end


function _mt_qp:getVerticalPadding()
	return self.pad_v
end


function _mt_qp:reset()
	self.x = 0
	self.y = 0

	self.tab_i = 1
	self:clearKerningMemory()
	self.align = self.default_align
	self.v_align = self.default_v_align
end


function _mt_qp:down(qty)
	-- Assertions
	-- [[
	if type(qty) ~= "number" and qty ~= nil then errType(1, pad_v, "number or nil") end
	--]]

	qty = qty or 1

	if qty > 0 then
		local font = self:getFont()
		local aux = quickPrint.getAux(font)
		local scale_y = self.sy * aux.sy
		self.x = 0
		self.y = math.ceil(self.y + self.pad_v + (qty * (font:getHeight() * font:getLineHeight() * scale_y)))

		self.tab_i = 1
		self:clearKerningMemory()
	end
end


function _mt_qp:clearKerningMemory()
	self.last_glyph = false
	self.line_font = false
end


-- * / State Get/Set, Cursor Movement, Tab Advance *


-- * Write Methods *


function _mt_qp:write(...)
	-- No assertions.

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	for i = 1, select("#", ...) do
		plainWrite(self, tostring(select(i, ...)), font, aux)
	end
end


function _mt_qp:writeSeq(tbl)
	-- Assertions
	-- [[
	if type(tbl) ~= "table" then errType(1, tbl, "table") end
	--]]

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	for i = 1, #tbl do
		plainWrite(self, tostring(tbl[i]), font, aux)
	end
end


function _mt_qp:write1(s1)
	-- No assertions.

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
end


function _mt_qp:write2(s1, s2)
	-- No assertions.

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)
end


function _mt_qp:write3(s1, s2, s3)
	-- No assertions.

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)
	plainWrite(self, tostring(s3), font, aux)
end


function _mt_qp:write4(s1, s2, s3, s4)
	-- No assertions.

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)
	plainWrite(self, tostring(s3), font, aux)
	plainWrite(self, tostring(s4), font, aux)
end


function _mt_qp:print(...)
	-- No assertions.

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	for i = 1, select("#", ...) do
		plainWrite(self, tostring(select(i, ...)), font, aux)
	end

	self:down()
end


function _mt_qp:printSeq(tbl)
	-- Assertions
	-- [[
	if type(tbl) ~= "table" then errType(1, tbl, "table") end
	--]]

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	for i = 1, #tbl do
		plainWrite(self, tostring(tbl[i]), font, aux)
	end

	self:down()
end


function _mt_qp:print1(s1)
	-- No assertions.

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)
	
	plainWrite(self, tostring(s1), font, aux)

	self:down()
end


function _mt_qp:print2(s1, s2)
	-- No assertions.

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)

	self:down()
end


function _mt_qp:print3(s1, s2, s3)
	-- No assertions.

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)
	plainWrite(self, tostring(s3), font, aux)

	self:down()
end


function _mt_qp:print4(s1, s2, s3, s4)
	-- No assertions.

	self:clearKerningMemory()
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	plainWrite(self, tostring(s1), font, aux)
	plainWrite(self, tostring(s2), font, aux)
	plainWrite(self, tostring(s3), font, aux)
	plainWrite(self, tostring(s4), font, aux)

	self:down()
end


function _mt_qp:writefSingle(text, align)
	-- Assertions
	-- [[
	if type(text) ~= "string" and type(text) ~= "table" then errType(1, text, "string or table")
	elseif align and not enum_align[align] then errEnumAlign(2, align) end
	--]]

	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	self:clearKerningMemory()
	self.x = 0

	-- Collect tab stop info
	local tab_i
	local tab_t
	local tab_x
	if self.tabs then
		tab_i = self.tab_i
		tab_t = self.tabs[tab_i]
		tab_x = type(tab_t) == "number" and tab_t or nil
	end

	--[[
	Align priority: 1) function argument, 2) tab align, 3) self.align
	--]]

	if type(tab_t) == "table" then
		align = align or tab_t.align
		tab_x = tab_t.x
	end

	align = align or self.align

	if tab_x then
		if align == "left" then
			self.x = math.floor(tab_x)

		elseif align == "center" then
			self.x = math.floor(tab_x - self.ref_w/2)

		elseif align == "right" then
			self.x = math.floor(tab_x - self.ref_w)
		end
	end

	formattedPrintLogic(self, text, align, font, aux, self.origin_x + self.x, self.origin_y + self.y)
	self:advanceTab()
end


function _mt_qp:printfSingle(text, align)
	-- Assertions
	-- [[
	if type(text) ~= "string" and type(text) ~= "table" then errType(1, text, "string or table")
	elseif align and not enum_align[align] then errEnumAlign(2, align) end
	--]]

	-- Tab stops are not taken into account.
	align = align or self.align

	self:writefSingle(text, align)
	self:down()
end


function _mt_qp:printf(text, align)
	-- Assertions
	-- [[
	if type(text) ~= "string" and type(text) ~= "table" then errType(1, text, "string or table")
	elseif align and not enum_align[align] then errEnumAlign(2, align) end
	--]]

	-- Tab stops are not taken into account.
	align = align or self.align
	local font = self:getFont()
	local aux = quickPrint.getAux(font)

	-- [WARN] [PERF] Multi-line handling needs to generate a throwaway table to determine how far down to move
	-- the Y cursor. To reduce overhead (for big paragraphs), you can printf() to a LÖVE Text object only when
	-- the text changes, and draw that instead. Then move the cursor by Text:getHeight() (assuming you don't add
	-- more bits of text to the Text object.)

	-- If this is the last thing you care about printing and you don't need to keep track of the Y cursor after
	-- this point, you can use qp:printfSingle() instead.

	self:clearKerningMemory()
	self.x = 0
	formattedPrintLogic(self, text, align, font, aux, self.origin_x + self.x, self.origin_y + self.y)

	local scale_x = self.sx * aux.sx
	local scaled_w = math.ceil(self.ref_w / math.max(scale_x, 0.0000001)) -- avoid div/0
	local wid, wrap_t = font:getWrap(text, scaled_w)

	-- getWrap() accounts for '\n' embedded in strings, and it also handles coloredtext sequences.
	self:down(#wrap_t)
end


-- * / Write Methods *


return quickPrint

