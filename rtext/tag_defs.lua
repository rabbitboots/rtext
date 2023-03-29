-- Default implementations for RText tags.

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
All examples assume the default tag patterns: "[" and "]".

Tag def arguments:
self: The rtext state table.
str: The arguments string (all text following the ID and its trailing whitespace). The tag def must
	do additional parsing on the string.
paragraph: The Paragraph table currently being processed. Needed for setting up some Paragraph Styles
	(to set specific labels or images within the Paragraph table). Use with caution.
--]]


local tagDefs = {}

local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local aligner = require(REQ_PATH .. "aligner")


-- Set font by Group ID
-- [font <group_id>]
-- On failure: treat as text
tagDefs["font"] = function(self, str)

	local f_grp_id = string.match(str, "%S+")
	if f_grp_id then
		self.f_grp_id = f_grp_id
		return self:refreshFont()
	end

	return false
end


-- Clear font group ID (set the default).
-- [/font]
-- On failure: treat as text
tagDefs["/font"] = function(self)

	self.f_grp_id = self.default_paragraph_style.word_style.f_grp_id
	if self.f_grp_id then
		return self:refreshFont()
	end

	return false
end


-- Set text color.
-- [color <color_id>]
-- On failure: treat as text
tagDefs["color"] = function(self, str)

	local color_id = string.match(str, "%S+")
	if self.colors[color_id] then
		self:setColor(color_id)
		return true

	else
		return false
	end
end


-- Clear text color.
-- [/color]
-- On failure: consume silently
tagDefs["/color"] = function(self)
	self:setColor()
	return true
end


-- Set italics.
-- [i]
-- On failure: consume silently
tagDefs["i"] = function(self)

	self.italic = true
	self:refreshFont()
	return true
end


-- Clear italics.
-- [/i]
-- On failure: consume silently
tagDefs["/i"] = function(self)

	self.italic = false
	self:refreshFont()
	return true
end


-- Set bold.
-- [b]
-- On failure: consume silently
tagDefs["b"] = function(self)

	self.bold = true
	self:refreshFont()
	return true
end


-- Clear bold.
-- [/b]
-- On failure: consume silently
tagDefs["/b"] = function(self)

	self.bold = false
	self:refreshFont()
	return true
end


-- Set underline with an optional color.
-- [ul]
-- [ul <color_id>]
-- On failure: consume silently
tagDefs["ul"] = function(self, str)

	self.lplace.underline = true

	local color_id = string.match(str, "%S+")
	local color_t = self.colors[color_id]

	self.lplace.color_ul = color_t or false

	return true
end


-- Clear underline.
-- [/ul]
-- On failure: consume silently
tagDefs["/ul"] = function(self)

	self.lplace.underline = false
	self.lplace.color_ul = false
	return true
end


-- Set strikethrough with an optional color.
-- [s]
-- [s <color_id>]
-- On failure: consume silently
tagDefs["s"] = function(self, str)

	self.lplace.strikethrough = true

	local color_id = string.match(str, "%S+")
	local color_t = self.colors[color_id]

	self.lplace.color_st = color_t or false

	return true
end


-- Clear strikethrough.
-- [/s]
-- On failure: consume silently
tagDefs["/s"] = function(self)

	self.lplace.strikethrough = false
	self.lplace.color_st = false

	return true
end


-- Set background (highlight) to a referenced color.
-- [bg <color_id>]
-- On failure: treat as text
tagDefs["bg"] = function(self, str)

	local color_id = string.match(str, "%S+")
	local color_t = self.colors[color_id]
	if color_t then
		self.lplace.background = true
		self.lplace.color_bg = color_t
		return true

	else
		return false
	end
end


-- Clear background (highlight) color
-- [/bg]
-- On failure: consume silently
tagDefs["/bg"] = function(self, str)

	self.lplace.background = false
	self.lplace.color_bg = false
	return true
end


-- Set horizontal alignment. See source comments for usage notes.
-- [align <left|center|right|justify|default>]
-- On failure: treat as text
tagDefs["align"] = function(self, str)

	--[[
	USAGE NOTES:

	* If any text is already parsed for the line (including whitespace), the change is deferred
	  to the next wrap-line.

	* When multiple [align] tags appear on the same line, the final tag overrides the others.
	--]]

	local align = string.match(str, "%S+")

	if align == "default" then
		self:setAlign(self.default_align)

	elseif aligner.enum_align[align] then
		self:setAlign(align)

	else
		return false
	end

	return true
end


-- Set vertical alignment. See source comments for usage notes.
-- [valign <top|ascent|middle|baseline|descent|bottom|default>
-- On failure: treat as text
tagDefs["valign"] = function(self, str)

	--[[
	USAGE NOTES:

	* As with [align], changes are deferred if any text has already been parsed for a line, and
	  if multiple [valign] tags appear, the last one gets priority.

	* "baseline" is usually wanted.

	* LÖVE ImageFonts have no baseline, ascent or descent metrics. You can provide your own values
	  by editing the associated Block Style table.
	--]]

	local v_align = string.match(str, "%S+")

	if v_align == "default" then
		self:setVAlign(self.default_v_align)

	elseif aligner.enum_v_align[v_align] then
		self:setVAlign(v_align)

	else
		return false
	end

	return true
end


--- Apply a word style.
-- [style <style_id>]
-- On failure: treat as text
tagDefs["style"] = function(self, str)

	local style_id = string.match(str, "%S+")

	if style_id then
		local style_t = self.word_styles[style_id]
		if style_t then
			self:applyWordStyle(style_t)
			return true
		end
	end

	return false
end


--- Apply a Paragraph Style, deferred to the first chunk of content parsed on a paragraph. This tag
--	should be placed before any text in a paragraph, including whitespace. Note that some paragraph
--	styles don't work correctly when called through this tag: they must be set through custom TagDefs,
--	so that they can apply additional tag arguments to the paragraph table.
-- [para <style_id>]
-- On failure: treat as text
tagDefs["para"] = function(self, str)

	local style_id = string.match(str, "%S+")

	if style_id then
		local style_t = self.para_styles[style_id]
		if style_t then
			return self:setParagraphStyle(style_t)
		end
	end

	return false
end


--- Insert the 'tag open' pattern into the document as text.
-- [t1]
-- On failure: consume silently.
tagDefs["t1"] = function(self)

	self:pushTextQueue(self.t1)

	return true
end


--- Insert the 'tag close' pattern into the document as text.
-- [t2]
-- On failure: consume silently.
tagDefs["t2"] = function(self)

	self:pushTextQueue(self.t2)

	return true
end


--- Insert a non-paragraph-breaking line feed.
-- [br]
-- On failure: consume silently.
tagDefs["br"] = function(self)

	self:pushTextQueue("\n")

	return true
end


--- Set the current wrap-line indent. Intended as an indent override for paragraphs. It may also be placed after a non-breaking line feed ([br]). Placement anywhere else is unreliable (it will be deferred to the next wrap-line, or discarded upon reaching the end of the paragraph). Also overwrites 'ext_w'.
-- [indent]: Indent one level.
-- [indent <n>]: Indent <n> number of levels. <n> falls back to 1 if parsing fails.
-- [indent 0]: Set no indent.
-- On failure: consume silently.
tagDefs["indent"] = function(self, str)

	local level = tonumber(str) or 1
	local offset = self.hint_indent_w * math.max(0, math.floor(level + 0.5))

	self.indent_x = offset
	self.ext_w = -offset

	return true
end


return tagDefs
