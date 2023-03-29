-- RText main module.

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


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local rtext = {}


-- LÖVE Auxiliary
local utf8 = require("utf8")


-- Troubleshooting
local inspect = require("demo_lib.inspect.inspect")


local aligner = require(REQ_PATH .. "aligner")
local media = require(REQ_PATH .. "media")
local linePlacer = require(REQ_PATH .. "line_placer")
local textBlock = require(REQ_PATH .. "text_block")
local textUtil = require(REQ_PATH .. "text_util")


local _mt_rt = {}
_mt_rt.__index = _mt_rt


--[[
Enums for the granularity level of blocks.
"word": (default) Measure blocks by words (non-whitespace chunks surrounded by whitespace, tags and string boundaries)
"cluster": measure blocks by grapheme clusters.
"code-point": measure blocks by code points. (Breaks emoji, regional indicators, etc. in LÖVE 12)

Best practice is to stick with the default ("word") unless you want to print characters incrementally.
--]]
local enum_block_gran = {
	["word"] = true,
	["cluster"] = true,
	["code-point"] = true
}


local function errArgBadType(n, val, expected, level)

	level = level or 2
	error("argument #" .. n .. ": bad type (expected " .. expected .. ", got " .. type(val) .. ")", level)
end


local function errBadEnum(n, enum_id, val)
	error("argument #" .. n .. ": bad enum for " .. enum_id .. ": " .. tostring(val), 2)
end


function _mt_rt:refreshFont()

	local lplace = self.lplace
	local f_grp = self.font_groups[self.f_grp_id]

	if f_grp then
		local b_style = f_grp:getFace(self.bold, self.italic)

		if b_style then
			self.lplace.b_style = b_style
			return true
		end
	end

	return false
end


function _mt_rt:applyWordStyle(word_style)

	--print("applyWordStyle() f_grp_id", word_style.f_grp_id)

	local lplace = self.lplace

	self.f_grp_id = word_style.f_grp_id

	self.bold = word_style.bold
	self.italic = word_style.italic
	lplace.strikethrough = word_style.strikethrough
	lplace.underline = word_style.underline
	lplace.background = word_style.background

	lplace.color = word_style.color
	lplace.color_ul = word_style.color_ul
	lplace.color_st = word_style.color_st
	lplace.color_bg = word_style.color_bg

	self:refreshFont()
end


function rtext.newWordStyle(f_grp_id)

	local word_style = media.newWordStyle(f_grp_id)
	return word_style
end


function rtext.newWrapLineStyle()

	local wrap_line_style = media.newWrapLineStyle()
	return wrap_line_style
end


function rtext.newParagraphStyle(word_style, wrap_line_style)

	local p_style = media.newParagraphStyle(word_style, wrap_line_style)
	return p_style
end


local function updateDeferredParagraphState(self)

	--print("updateDeferredParagraphState()", debug.traceback())
	if not self.para_busy then
		local para_style = self.pending_paragraph_style
		if para_style then
			self.paragraph_style = para_style
			self.pending_paragraph_style = false

			self._paragraph_style = para_style
			self:applyWordStyle(para_style.word_style)

			self.indent_x = para_style.indent_x
			self.ext_w = para_style.ext_w

			self.align = para_style.align
			self.v_align = para_style.v_align

			self.justify_last_line = para_style.justify_last_line
			self.j_x_step = para_style.j_x_step
			self.hint_indent_w = para_style.hint_indent_w

			self.para_min_line_height = para_style.para_min_line_height
			self.line_pad_bottom = para_style.line_pad_bottom

			self.para_margin_left = para_style.para_margin_left
			self.para_margin_right = para_style.para_margin_right
			self.para_margin_top = para_style.para_margin_top
			self.para_margin_bottom = para_style.para_margin_bottom

			self.cb_initParagraph = para_style.cb_initParagraph
			self.cb_finishedWrapLine = para_style.cb_finishedWrapLine
			self.cb_finishedParagraph = para_style.cb_finishedParagraph
		end
	end
end


local function _setDefaultParagraphStyle(self)

	self.pending_paragraph_style = self.default_paragraph_style
	updateDeferredParagraphState(self)
end


function _mt_rt:setParagraphStyle(para_style)

	-- Assertions
	-- [[
	if type(para_style) ~= "table" then errArgBadType(1, para_style, "table") end
	--]]

	if self.para_style_locked then
		return false
	end
	self.para_style_locked = true

	self.pending_paragraph_style = para_style
	updateDeferredParagraphState(self)

	return not self.para_busy
end


rtext.default_tag_defs = require(REQ_PATH .. "tag_defs")


function rtext.newInstance(font_groups, default_f_grp_id, colors, word_styles, para_styles, def_para_style, data)

	-- Assertions
	-- [[
	if type(font_groups) ~= "table" then errArgBadType(1, font_groups, "table")
	elseif type(default_f_grp_id) ~= "string" then errArgBadType(2, default_f_grp_id, "string") end

	-- Confirm there is a default font group with a regular Block Style and font object.
	local default_f_grp = font_groups[default_f_grp_id]
	if not default_f_grp
	or not default_f_grp[1]
	or type(default_f_grp[1]) ~= "table"
	or type(default_f_grp[1].font) ~= "userdata"
	then
		error("A default Font Group with at least a regular font is required. Group ID: " .. tostring(default_f_grp_id))
	end

	if colors and type(colors) ~= "table" then errArgBadType(3, colors, "nil/false/table")
	elseif word_styles and type(word_styles) ~= "table" then errArgBadType(4, word_styles, "nil/false/table")
	elseif para_styles and type(para_styles) ~= "table" then errArgBadType(5, para_styles, "nil/false/table")
	elseif def_para_style and type(def_para_style) ~= "table" then errArgBadType(6, def_para_style, "nil/false/table")
	elseif data and type(data) ~= "table" then errArgBadType(7, data, "nil/false/table") end
	--]]

	local self = setmetatable({}, _mt_rt)

	local default_b_style = default_f_grp[1]
	self.lplace = linePlacer.new(default_b_style)

	-- Hash of tag handlers, where the tag ID is the key.
	self.tag_defs = rtext.default_tag_defs

	-- Temporary queue of text generated by tags.
	self.text_ingress = {}

	-- Testing: set true to raise a Lua error when tag parsing fails.
	self.bad_tag_error = false

	-- Optional table of assets for tag definitions (textures, etc.).
	-- This is not allocated by default, as none of the core tags make use of it.
	-- When attaching non-core tag defs, check their documentation for requirements.
	self.data = data or false

	-- Tag patterns. These are used in plain mode, and so are literal matches (no string patterns).
	self.t1 = "["
	self.t2 = "]"

	-- Font group tables and colors accessible by string ID
	self.font_groups = font_groups or {}
	self.colors = colors or {}

	-- Style tables accessible by string ID
	self.word_styles = word_styles or {}
	self.para_styles = para_styles or {}

	-- Default resources and settings.
	-- The default paragraph style is applied at the start of processing every paragraph, so make
	-- sure that it doesn't apply any destructive changes that may conflict with further paragraph
	-- style assignments.

	def_para_style = def_para_style or rtext.newParagraphStyle(
		media.newWordStyle(default_f_grp_id),
		media.newWrapLineStyle()
	)
	self.default_paragraph_style = def_para_style
	self.paragraph_style = self.default_paragraph_style

	self.block_granularity = "word"

	-- This callback fires when a wrapped line is complete.
	-- You can use it to change the wrap limit or alignment on a per-wrapline basis, change the position of
	-- the line, etc.
	--self.cb_finishedWrapLine -- (self, paragraph, line, last_in_paragraph)

	-- This callback fires when a paragraph is complete.
	--self.cb_finishedParagraph -- (self, paragraph, para_style)

	-- See this method (and updateParagraphStyle + applyWordStyle) for additional fields.
	self:setDefaultState()

	return self
end


function rtext.newBlockStyle(font)

	local b_style = textBlock.newBlockStyle(font)
	return b_style
end


function rtext.newBlockStyleArbitrary()

	local b_style = textBlock.newBlockStyleArbitrary()
	return b_style
end


function rtext.newFontGroup(regular, bold, italic, bold_italic)

	local f_grp = media.newFontGroup(regular, bold, italic, bold_italic)
	return f_grp
end


function _mt_rt:setDefaultState()

	-- Store a temp copy of the document wrap-width. Used to set the width of paragraphs.
	self.doc_wrap_w = 0

	-- Some state changes are deferred to the start of wrapped line processing.
	-- Ditto for paragraphs.
	self.line_busy = false
	self.para_busy = false

	-- Prevents multiple paragraph style tags from being parsed for a single paragraph.
	-- Some styles mutate the paragraph table, and there is no mechanism for undoing those changes.
	self.para_style_locked = false

	-- Temporary values used to place lines and paragraphs within a document.
	self.ly = 0
	self.py = 0

	_setDefaultParagraphStyle(self)

	-- The following are locked during wrap-line parsing. Do not modify directly.
	-- They will be updated between lines.
	self._align = self.align
	self._v_align = self.v_align

	self._j_x_step = self.j_x_step
	self._indent_x = self.indent_x
	self._ext_w = self.ext_w
end


function _mt_rt:setTagPatterns(open, close)

	-- Assertions
	-- [[
	if type(open) ~= "string" then errArgBadType(1, open, "string")
	elseif #open == 0 then error("argument #1: string must be at least one character (byte) in length.")
	elseif type(close) ~= "string" then errArgBadType(2, close, "string")
	elseif #close == 0 then error("argument #2: string must be at least one character (byte) in length.") end
	--]]

	self.t1 = open 
	self.t2 = close
end


local function updateDeferredWrapLineState(self)

	if not self.line_busy then
		self._align = self.align
		self._v_align = self.v_align

		self._j_x_step = self.j_x_step
		self._indent_x = self.indent_x
		self._ext_w = self.ext_w
	end
end


local function checkParagraphInit(self, paragraph)

	if not self.para_busy then
		-- Set the Paragraph's Style by overwriting its metatable
		setmetatable(paragraph, self._paragraph_style)

		self.ly = self.para_margin_top
		paragraph.x = paragraph.sp_left
		paragraph.w = math.max(0, self.doc_wrap_w - paragraph.sp_left - paragraph.sp_right)

		-- Shorten wrap limit. Indent will be handled later (during horizontal alignment processing).
		self.lplace.wrap_limit = paragraph.w + self._ext_w - self.para_margin_left - self.para_margin_right
		--[[
		print(
			"NEW WRAP LIMIT:", self.lplace.wrap_limit,
			"doc_wrap_w", self.doc_wrap_w,
			"ext_w", self.ext_w,
			"_ext_w", self._ext_w,
			"self.para_margin_left", self.para_margin_left,
			"self.para_margin_right", self.para_margin_right,
			"paragraph.sp_left", paragraph.sp_left,
			"paragraph.sp_right", paragraph.sp_right
		)
		--]]

		if self.cb_initParagraph then
			self:cb_initParagraph(paragraph)
		end

		updateDeferredParagraphState(self)

		--self.lplace.wrap_limit = paragraph.w + self._ext_w

		self.para_busy = true
		self.para_style_locked = true
	end
end


local function checkWrapLineInit(self, paragraph)

	if not self.line_busy then
		updateDeferredWrapLineState(self)
		--self.lplace.wrap_limit = self.doc_wrap_w + self._ext_w
		self.lplace.wrap_limit = paragraph.w + self._ext_w - self.para_margin_left - self.para_margin_right
		--print("NEW WRAP LIMIT:", self.lplace.wrap_limit, "doc_wrap_w", self.doc_wrap_w, "ext_w", self.ext_w, "_ext_w", self._ext_w)

		self.line_busy = true
	end
end


local function assertColorID(self, id)

	local color = self.colors[id]
	if not color then
		error("no color registered with this ID: " .. tostring(id), 2)
	end

	return color
end


function _mt_rt:setColor(id)

	if not id then
		self.lplace.color = false

	else
		local color = assertColorID(self, id)
		self.lplace.color = color
	end
end


function _mt_rt:setAlign(align)

	--print("rt:setAlign()", align, "line_busy", self.line_busy)

	-- Do not modify self.align or self._align directly.

	-- Assertions
	-- [[
	if not aligner.enum_align[align] then errBadEnum(1, "alignment", align) end
	--]]

	self.align = align

	updateDeferredWrapLineState(self)
end


function _mt_rt:setVAlign(v_align)

	-- Do not modify self.v_align or self._v_align directly.

	-- Assertions
	-- [[
	if not aligner.enum_v_align[v_align] then errBadEnum(1, "vertical alignment", v_align) end
	--]]

	self.v_align = v_align

	updateDeferredWrapLineState(self)
end


local function appendWrapLine(self)

	local line = media.newWrapLine(self.wrap_line_style)
	self.lines[#self.lines + 1] = line

	return line
end


local function finishWrappedLine(self, paragraph, line, last_in_paragraph)

	-- Empty paragraph
	if not line then
		--print("finishWrappedLine: Empty paragraph. Make an empty line.")
		line = appendWrapLine(paragraph)
		-- [[
		local lplace = self.lplace
		local blank = textBlock.newTextBlock(
			"",
			lplace.b_style,
			0,
			0,
			0,
			lplace.b_style.f_height * lplace.b_style.f_sy,
			0,
			false,
			self.color,
			self.color_ul,
			self.color_st,
			self.color_bg
		)
		line.blocks[1] = blank
		--]]
	end

	local lplace = self.lplace
	local blocks = line.blocks

	local align = self._align
	if not self.justify_last_line and last_in_paragraph and align == "justify" then
		align = "left"
	end

	--print("finishWrappedLine(): self.justify_last_line:", self.justify_last_line, "last_in_paragraph", last_in_paragraph, "align", align)
	local x_offset = self.indent_x + self.para_margin_left

	-- This sets line.x and line.w.
	aligner.boundingBox(line, blocks, align, lplace.wrap_limit, x_offset, self._j_x_step)
	aligner.vertical(blocks, self._v_align)

	line.y = self.ly
	-- Empty line: Use the current font height.
	if #blocks == 0 then
		line.h = self.lplace.b_style.font:getHeight()

	else
		line.h = math.floor(aligner.getHeight(blocks) + 0.5)
	end
	line.h = math.max(self.para_min_line_height, line.h)

	self.line_busy = false
	updateDeferredWrapLineState(self)

	if self.cb_finishedWrapLine then
		self.cb_finishedWrapLine(self, paragraph, line, last_in_paragraph)
	end

	self.ly = line.y + line.h + self.line_pad_bottom
	--print("NEW SELF.LY", self.ly)
end


local function finishParagraph(self, paragraph)

	local lines = paragraph.lines

	for l, line in ipairs(lines) do
		--paragraph.w = math.max(paragraph.w, line.x + line.w)
		paragraph.h = math.max(paragraph.h, line.y + line.h)
	end
	paragraph.h = paragraph.h + self.para_margin_bottom

	self.py = self.py + paragraph.sp_top
	paragraph.y = self.py

	if self.cb_finishedParagraph then
		self.cb_finishedParagraph(self, paragraph, self._paragraph_style)
	end

	self.py = paragraph.y + paragraph.h + paragraph.sp_bottom
end


local function breakStringLoop(self, paragraph)

	local lplace = self.lplace
	local lines = paragraph.lines

	--print("breakStringLoop: lplace.x", lplace.x)
	if lplace.x > 0 then
		finishWrappedLine(self, paragraph, lines[#lines], false)
		appendWrapLine(paragraph)
		lplace.x = 0
	end

	local cluster_gran = (self.block_granularity ~= "code-point")

	local f = 1
	while f <= lplace.word_buf_len do
		checkWrapLineInit(self, paragraph)
		checkParagraphInit(self, paragraph)

		local blocks = lines[#lines].blocks
		f = lplace:breakBuf(blocks, f, cluster_gran)
		if f <= lplace.word_buf_len then
			finishWrappedLine(self, paragraph, lines[#lines], false)
			appendWrapLine(paragraph)
			blocks = lines[#lines].blocks
			lplace.x = 0
		end
	end
	lplace:clearBuf()
end


local function parseTextChunk(self, chunk, paragraph)

	-- The first bit of text in a line locks some state for the duration of a line or paragraph.
	if not self.line_busy then
		checkWrapLineInit(self, paragraph)
	end
	checkParagraphInit(self, paragraph)

	local lplace = self.lplace

	local lines = paragraph.lines
	local line = lines[#lines] or appendWrapLine(paragraph)

	-- Non-breaking line feeds. These should be injected by tags: line feeds are otherwise
	-- delimiters for paragraphs.
	if chunk == "\n" then
		--print("parseTextChunk: inject non-breaking line feed")
		local blocks = lines[#lines].blocks
		if not lplace:placeBuf(blocks) then
			breakStringLoop(self, paragraph)
		end
		finishWrappedLine(self, paragraph, lines[#lines], false)
		appendWrapLine(paragraph)
		lplace.x = 0

	else
		local i, j = 1, 1
		while i <= #chunk do
			local combined, word, space
			local block_gran = self.block_granularity

			if block_gran == "word" then
				word, space, j = textUtil.walkIsland(chunk, i)

			elseif block_gran == "cluster" then
				word, space, j = textUtil.walkClusterTrailing(chunk, i)

			elseif block_gran == "code-point" then
				word, space, j = textUtil.walkCodePointTrailing(chunk, i)
			end

			combined = word .. space

			--print("parseTextChunk: i,j", i, j, "comb", combined, "word", word, "space |" .. space .. "|")

			lplace:pushBuf(combined, word, space)

			--print("parseTextChunk: #space > 0?", #space > 0)
			if #space > 0 then
				local blocks = lines[#lines].blocks
				if not lplace:placeBuf(blocks) then
					breakStringLoop(self, paragraph)
				end
				lplace:clearBuf()
			end

			i = j
		end
	end
end


function parseParagraph(self, str, doc_wrap_w)

	local lplace = self.lplace

	lplace.x = 0
	self.ly = 0
	self.doc_wrap_w = doc_wrap_w

	_setDefaultParagraphStyle(self)
	local paragraph = media.newParagraph(self.default_paragraph_style)

	--print("parseParagraph", "str", str, "#str:", #str)

	local i, j = 1, 1
	while i <= #str do

		-- Look for upcoming tag
		local t1a, t1b = string.find(str, self.t1, i, true)
		j = t1a and t1a - 1 or #str

		-- Handle text between 'i' and before tag start (or end of paragraph)
		--print("parseParagraph i j", i, j, "t1a t1b", t1a, t1b)
		if i <= j then
			local chunk = string.sub(str, i, j)

			parseTextChunk(self, chunk, paragraph)
			i = j + 1
		end

		-- Handle tags. Treat unparsed / malformed tag content as text content.
		if t1a then
			local t2a, t2b = string.find(str, self.t2, t1b + 1, true)
			--print("parseParagraph: handle tags:", t1a, t1b, t2a, t2b)
			if not t2a then
				if self.bad_tag_error then
					error("parser assertion failed. Incomplete tag: '" .. string.sub(str, t1a, t2b) .. "'.")
				end
				parseTextChunk(self, string.sub(str, t1a, t1b), paragraph)
				i = t1b + 1

			else
				local tag_defs = self.tag_defs
				local tag_str = string.sub(str, t1a + #self.t1, t2b - #self.t2)
				local id, arg_str = string.match(tag_str, "^(%S+)%s*(.*)")

				-- Execute tag handler.
				--[[
				Return values:
					true: tag was successful.
					false: tag failed, and the text should be passed on verbatim
					"arbitrary", <block>: Handler was successful, and has an arbitrary block to add
						to the document. If the line already has contents and the block doesn't fit,
						it will be moved down to the next line.

					No error checking is done on the incoming block.
				--]]
				local verbatim = false
				if not tag_defs[id] then
					verbatim = true

				else
					local res1, res2 = tag_defs[id](self, arg_str, paragraph)
					if not res1 then
						verbatim = true

					elseif res1 == "arbitrary" then
						local lines = paragraph.lines
						if #lines == 0 then
							appendWrapLine(paragraph)
						end

						-- Flush any pending text fragments
						if lplace.word_buf_len > 0 then
							--print("flush remaining fragments before arbitrary block")

							local blocks = lines[#lines].blocks
							if not lplace:placeBuf(blocks) then
								breakStringLoop(self, paragraph)
							end
						end

						-- Try to place on the current line. If the line already has content and there
						-- is not enough space, make a new line and force its placement.
						--print(lines, #lines, lines[#lines])
						if not lplace:placeArbitraryBlock(lines[#lines].blocks, res2, false) then
							if #lines[#lines].blocks > 0 then
								finishWrappedLine(self, paragraph, lines[#lines], false)
								appendWrapLine(paragraph)
								lplace.x = 0
							end

							lplace:placeArbitraryBlock(lines[#lines].blocks, res2, true)
						end
					end
				end

				if verbatim then
					--print("parseParagraph: tag failed: ", string.sub(str, t1a, t2b))
					if self.bad_tag_error then
						error("parser assertion failed. Bad tag: '" .. string.sub(str, t1a, t2b) .. "'.")
					end
					parseTextChunk(self, string.sub(str, t1a, t2b), paragraph)
				end
				i = t2b + 1

				-- Handle any text content pushed by tags
				local text_ingress = self.text_ingress
				if #text_ingress > 0 then
					local z = 1
					while z <= #text_ingress do
						parseTextChunk(self, text_ingress[z], paragraph)
						z = z + 1
					end
					self:clearTextQueue()
				end
			end
		end
	end

	-- Check for last fragments without trailing whitespace
	if lplace.word_buf_len > 0 then
		--print("parseParagraph: check remaining fragments")

		local lines = paragraph.lines
		local blocks = lines[#lines].blocks
		if not lplace:placeBuf(blocks) then
			breakStringLoop(self, paragraph)
		end
		
		--lplace:clearBuf()
	end

	-- Catch paragraphs with tags but no text content
	checkParagraphInit(self, paragraph)

	local lines = paragraph.lines
	finishWrappedLine(self, paragraph, lines[#lines], true) -- clears line_busy
	finishParagraph(self, paragraph)

	return paragraph
end


function _mt_rt:makeDocument(input, width)

	-- Assertions
	-- [[
	if type(input) ~= "string" then errArgBadType(1, input, "string")
	elseif width and type(width) ~= "number" then errArgBadType(2, width, "number") end
	--]]

	width = width or math.huge
	width = math.floor(width)

	self:setDefaultState()

	local document = media.newDocument()
	document.wrap_w = width
	self:parseText(input, document)

	return document
end


function _mt_rt:makeParagraph(input, i, wrap_w)

	self:setDefaultState()

	-- Assertions
	-- [[
	if type(input) ~= "string" then errArgBadType(1, input, "string")
	elseif i and type(i) ~= "number" then errArgBadType(2, i, "number")
	elseif wrap_w and type(wrap_w) ~= "number" then errArgBadType(3, wrap_w, "number") end
	--]]

	i = i or 1
	i = math.floor(i)
	wrap_w = wrap_w or math.huge
	wrap_w = math.floor(wrap_w)

	local lplace = self.lplace
	lplace:clearBuf()

	self.line_busy = false
	self.para_busy = false
	self.para_style_locked = false

	updateDeferredWrapLineState(self)
	updateDeferredParagraphState(self)

	-- Truncate string at the first line feed
	local j = string.find(input, "\n", i, true) or #input + 1
	local str_line = string.sub(input, i, j - 1)
	local paragraph = parseParagraph(self, str_line, wrap_w)

	return paragraph, j + 1
end


function _mt_rt:makeSimpleParagraph(input, i, wrap_w, align, b_style)

	self:setDefaultState()

	-- Assertions
	-- [[
	if type(input) ~= "string" then errArgBadType(1, input, "string")
	elseif type(i) ~= "number" then errArgBadType(2, i, "number")
	elseif type(wrap_w) ~= "number" then errArgBadType(3, wrap_w, "number")
	elseif not aligner.enum_align[align] then errBadEnum(4, "alignment", align)
	elseif type(b_style) ~= "table" then errArgBadType(5, b_style, "table") end
	--]]

	i = i or 1
	i = math.floor(i)
	wrap_w = wrap_w or math.huge
	wrap_w = math.floor(wrap_w)
	align = align or "left"

	-- (lplace is not used in Simple Paragraphs)

	self.line_busy = false
	self.para_busy = false
	self.para_style_locked = false

	updateDeferredWrapLineState(self)
	updateDeferredParagraphState(self)

	-- Truncate string at the first line feed
	local j = string.find(input, "\n", i, true) or #input + 1
	local str_line = string.sub(input, i, j - 1)

	local s_para = media.newSimpleParagraph(0, 0, str_line, b_style, align, wrap_w)

	return s_para, j + 1
end


function _mt_rt:parseText(input, document, i, max_paragraphs)

	-- Call self:setDefaultState() before working on a new document.

	-- Assertions
	-- [[
	if type(input) ~= "string" then errArgBadType(1, input, "string")
	elseif type(document) ~= "table" then errArgBadType(2, document, "table")
	elseif i and type(i) ~= "number" then errArgBadType(3, i, "nil/false/number")
	--elseif i < 1 or i > #input then error("argument #3: string index is out of range.")
	elseif max_paragraphs and type(max_paragraphs) ~= "number" then errArgBadType(4, max_paragraphs, "nil/false/number") end
	--]]

	i = i or 1
	i = math.floor(i)
	max_paragraphs = max_paragraphs or math.huge
	max_paragraphs = math.max(1, math.floor(max_paragraphs))

	local lplace = self.lplace
	lplace:clearBuf()

	while i <= #input do
		--print("\n----------INPUT I", i, "----------\n")
		if max_paragraphs <= 0 then
			break
		end

		self.line_busy = false
		self.para_busy = false
		self.para_style_locked = false

		updateDeferredWrapLineState(self)
		updateDeferredParagraphState(self)

		local j = string.find(input, "\n", i, true) or #input + 1
		local str_line = string.sub(input, i, j - 1)
		local paragraph = parseParagraph(self, str_line, document.wrap_w)
		document.paragraphs[#document.paragraphs + 1] = paragraph

		i = j + 1
		max_paragraphs = max_paragraphs - 1
	end

	return i
end


function _mt_rt:pushTextQueue(str)
	table.insert(self.text_ingress, str)
end


function _mt_rt:clearTextQueue()

	local text_ingress = self.text_ingress
	for i = #text_ingress, 1, -1 do
		text_ingress[i] = nil
	end
end


function _mt_rt:setBlockGranularity(level)

	-- Assertions
	-- [[
	if enum_block_gran[level] == nil then errBadEnum(1, "block granularity", level) end
	--]]

	self.block_granularity = level
end


return rtext


