-- RText LinePlacer module.

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


local linePlacer = {}


--[[
LinePlacer arranges marked-up text into wrapped lines of text blocks and
handles line-wrap and breaking words.

A temporary word buffer (self.word_buf) is used to determine if a single word
fits into a line, or if it has to be moved or broken into smaller fragments.
The contents of the word buffer should represent one clump of non-whitespace
text, with up to one instance of whitespace (trailing at the end). When the
word buffer contains this whitespace, it is time to place the word-fragments
and clear the buffer. You also need to check for words with no trailing
whitespace at the end of your loop.

USAGE NOTES:

* When getting the length of the word buffer, use `self.word_buf_len` instead
  of `#self.word_buf`. The word buffer may contain junk tables from previous
  calls.

* Do not pass line feeds, empty strings or strings containing mixed content
  (word, space, word, space...) to the word buffer.
--]]


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


-- LÖVE Auxiliary
local utf8 = require("utf8")


local textBlock = require(REQ_PATH .. "text_block")
local textUtil = require(REQ_PATH .. "text_util")


local _mt_lp = {}
_mt_lp.__index = _mt_lp


-- * Internal *


local function errArgBadType(n, val, expected)
	error("argument #" .. n .. ": bad type (expected " .. expected .. ", got " .. type(val) .. ")", 2)
end


local function errArgBadSub(n, id, val, expected)
	error("argument #" .. n .. ": field " .. id .. ": bad type (expected " .. expected .. ", got " .. type(val) .. ")", 2)
end


-- Helper to get the kerning offset between the last code point of 's1' and the first code point of 's2'.
local function kerningPairs(font, s1, s2)

	--print(s1, type(s1), s2, type(s2))

	local kerning = 0

	local k1 = utf8.offset(s1, -1)
	local k2 = utf8.offset(s2, 2) -- (one past the desired boundary)

	if k1 and k2 then
		kerning = font:getKerning(string.sub(s1, k1), string.sub(s2, 1, k2 - 1))
	end

	--print(font, "|"..s1.."|", "|"..s2.."|", "kerning", kerning)

	return kerning
end


local function writeLineBlock(self, x, blocks, b_style, font_h, combined, word_w, space_w, has_ws, color, color_ul, color_st, color_bg)

	local last_block = blocks[#blocks]
	if last_block
	and self.block_merge_mode
	and getmetatable(last_block) == b_style
	and last_block.color_ul == color_ul
	and last_block.color_st == color_st
	and last_block.color_bg == color_bg
	then
		textBlock.extend(last_block, combined, color)

		-- Need to recalculate block measurements.
		local str = textUtil.getStringFromText(last_block.text)
		local font = b_style.font
		local new_word, new_space = textUtil.walkFull(str, 1)

		last_block.w = font:getWidth(new_word) * b_style.f_sx
		last_block.has_ws = (#new_space > 0)
		last_block.ws_w = #new_space > 0 and (font:getWidth(new_space) * b_style.f_sx) or 0

	else
		local block = textBlock.newTextBlock(
			combined,
			b_style,
			x,
			0,
			word_w,
			font_h,
			space_w,
			has_ws,
			color,
			color_ul,
			color_st,
			color_bg
		)
		blocks[#blocks + 1] = block
	end
end


-- Clears GC-able references from reused word buffer fragments so that we don't prevent them from being collected.
local function _wipeBufReferences(self)

	for i = 1, self.word_buf_len do
		local fragment = word_buf[i]
		fragment.combined = false
		fragment.word = false
		fragment.space = false

		fragment.b_style = false

		fragment.color = false
		fragment.color_ul = false
		fragment.color_st = false
		fragment.color_bg = false
	end
end


-- * / Internal *


--- Makes a new linePlacer instance.
-- @param def_b_style The starting Block Style to use when setting text. Required. (See `text_block.lua` for more info.)
-- @return The linePlacer instance.
function linePlacer.new(def_b_style)

	-- Assertions
	-- [[
	if type(def_b_style) ~= "table" then
		errArgBadType(1, def_b_style, "table")

	elseif type(def_b_style.font) ~= "userdata" then
		errArgBadSub(2, "def_b_style.font", def_b_style.font, "userdata (LÖVE Font)")
	end
	--]]

	local self = {}

	-- Default resources and settings.
	self.b_style = def_b_style
	self.color = false
	self.wrap_limit = math.huge

	-- Shape state flags.
	self.underline = false
	self.strikethrough = false
	self.background = false

	-- A color table to use for shapes when no explicit color is set.
	self.default_shape_color = {1, 1, 1, 1}

	-- Individual colors for underline, strikethrough and background/highlight. When not
	-- populated, falls back to 'self.color' or 'linePlacer.color_default'.
	self.color_ul = false
	self.color_st = false
	self.color_bg = false

	-- Cursor position.
	self.x = 0

	-- Temporary word buffer.
	self.word_buf = {}

	-- Current length of the buffer (anything past this index is old data).
	self.word_buf_len = 0

	-- The max number of buffer entries to reuse. Anything greater than this index is discarded
	-- when invoking clearBuf.
	-- For minimally tagged input, word buffer usage should rarely exceed one entry. It will
	-- increase from tags appearing within words.
	-- Text in reused entries is set to false so that the strings remain eligible for garbage
	-- collection.
	self.word_buf_cutoff = 0

	-- When true, fragments are merged into the last Text Block when they have compatible styles.
	-- This can result in less memory usage for the final Document, but it performs additional
	-- string concatenations during construction, and it will break justify alignment. It should
	-- not be used with cluster or code-point granularity (it will incur a lot of overhead for
	-- no real benefit).
	self.block_merge_mode = false

	setmetatable(self, _mt_lp)

	return self
end


--- Resets the cursor X position and empties the word buffer and string buffer. Call between uses.
function _mt_lp:reset()

	self.x = 0
	self:clearBuf()
end


--- Kerning offsets are rolled into block width dimensions.
function linePlacer.setFragmentSize(prev, frag)

	local font = frag.b_style.font

	frag.word_w = font:getWidth(frag.word)
	frag.space_w = font:getWidth(frag.space)

	-- Intra-fragment kerning 
	if #frag.word > 0 and #frag.space > 0 then
		frag.word_w = frag.word_w + kerningPairs(font, frag.word, frag.space)
	end

	-- Kerning between previous and current fragment. Affects the previous fragment.
	-- Leave 'prev' false/nil if the current fragment is the start of a new line.
	--[[
	    Prev       Frag
	+------+--+ +------+--+
	|word  |sp|-|word  |sp|
	+------+--+ +------+--+

	+------+    +------+--+
	|word  |----|word  |sp|
	+------+    +------+--+

	+------+--+        +--+
	|word  |sp|--------|sp|
	+------+--+        +--+

	+------+           +--+
	|word  |-----------|sp|
	+------+           +--+
	--]]

	-- Differences in the following style fields should prevent inter-fragment kerning from being applied.
	if prev
	and prev.b_style.font == font -- implicitly covers differences in italic and bold state
	and prev.color_bg == frag.color_bg
	and prev.color_ul == frag.color_ul
	and prev.color_st == frag.color_st
	then
		local p_id, p_w, f_id

		if #prev.space > 0 then
			p_id, p_w = "space", "space_w"

		elseif #prev.word > 0 then
			p_id, p_w = "word", "word_w"
		end

		if #frag.word > 0 then
			f_id = "word"

		elseif #frag.space > 0 then
			f_id = "space"
		end

		if p_id and f_id then
			prev[p_w] = prev[p_w] + kerningPairs(font, prev[p_id], frag[f_id])
		end
	end

	--print("setFragmentSize", prev.combined, prev.word_w
end


local function getLastColoredTextString(coloredtext)

	for i = #coloredtext, 1, -1 do
		local chunk = coloredtext[i]
		if type(chunk) == "string" then
			return i, chunk
		end
	end

	-- (return nil, nil)
end


--- Get the scaled kerning offset between the last block in a line and the first fragment to be placed next.
function linePlacer.getBlockFragmentKerning(block, frag)

	local b_style = block.__index

	-- Check for style compatibility.
	if b_style == frag.b_style
	and block.color_bg == frag.color_bg
	and block.color_ul == frag.color_ul
	and block.color_st == frag.color_st
	then
		local last_text
		if type(block.text) == "table" then
			local _
			_, last_text = getLastColoredTextString(block.text)
			if not last_text then
				error("no strings in this coloredtext. (Can't get kerning against an empty string.)")
			end

		else
			last_text = block.text
		end

		local offset = kerningPairs(b_style.font, last_text, frag.combined) * b_style.f_sx
		--print("linePlacer.getBlockFragmentKerning(): offset:", offset)

		return kerningPairs(b_style.font, last_text, frag.combined) * b_style.f_sx
	end

	return 0
end


--- Push a fragment of text onto the word buffer.
-- @param combined Word content plus whitespace. There must be at least one codepoint in the combined text.
-- @param word Just the word content.
-- @param space Just the trailing whitespace content, if applicable.
-- @return The fragment table (which is also appended to self.word_buf).
function _mt_lp:pushBuf(combined, word, space)

	local word_buf = self.word_buf
	local b_style = self.b_style

	local fragment = word_buf[self.word_buf_len + 1] or {}
	word_buf[self.word_buf_len + 1] = fragment

	fragment.combined = combined
	fragment.word = word
	fragment.space = space

	fragment.b_style = b_style
	fragment.font_h = b_style.f_height

	fragment.color = self.color

	local color_fallback = self.color or self.default_shape_color

	fragment.color_ul = self.underline and (self.color_ul or color_fallback) or false
	fragment.color_st = self.strikethrough and (self.color_st or color_fallback) or false
	fragment.color_bg = self.background and self.color_bg or false

	-- Calculate width of word and whitespace parts, including kerning against the last code point
	-- in the buffer.
	local prev = word_buf[self.word_buf_len]
	linePlacer.setFragmentSize(prev, fragment) -- sets fragment.word_w, fragment.space_w

	self.word_buf_len = self.word_buf_len + 1

	-- 'fragment.combined_w' is (word_w + space_w)

	return fragment
end


--- Get the text width of word-buffer contents, plus trailing whitespace if applicable.
-- @return Width of the buffer contents without trailing whitespace; width of trailing whitespace.
function _mt_lp:getBufWidth()

	local word_buf = self.word_buf
	local count = 0

	for i = 1, self.word_buf_len - 1 do
		local frag = word_buf[i]
		local b_style = frag.b_style
		count = count + (frag.word_w + frag.space_w) * b_style.f_sx
	end

	local space_w = 0
	local last = word_buf[self.word_buf_len]
	if last then
		local b_style = last.b_style
		count = count + last.word_w * b_style.f_sx
		space_w = last.space_w * b_style.f_sx
	end

	return count, space_w
end


--- Clear the word buffer.
-- @param full When true, clears all fragment tables regardless of the cutoff setting.
function _mt_lp:clearBuf(full)

	if full then
		local word_buf = self.word_buf
		for i = #word_buf, 1, -1 do
			word_buf[i] = nil
		end

	else
		-- Discard fragment tables past the cutoff index.
		local word_buf = self.word_buf
		for i = #word_buf, self.word_buf_len + 1, -1 do
			word_buf[i] = nil
		end

		-- Uncomment to blank out all garbage-collectable references in reused fragments on every buffer clear.
		-- May be helpful in some extreme cases.
		--_wipeBufReferences(self)
	end

	self.word_buf_len = 0
end


--- Try to place the word buffer contents into the current block array. The word buffer is cleared when successful, and left as-is when the word doesn't fit.
-- @param blocks The block array to append to.
-- @param break_first When true, always break the first fragment of the word. Needed for this module's implementation of justify alignment.
-- @return true if all contents of the word buffer were placed on the line, false if not.
function _mt_lp:placeBuf(blocks)

	local word_buf = self.word_buf

	-- These values are scaled.
	local w_width, w_space = self:getBufWidth()

	-- Check for kerning between the last block and first fragment, but only if the style is compatible.
	local last_block = blocks[#blocks]
	local first_frag = word_buf[1]
	local bf_kern = 0
	if last_block and first_frag then
		bf_kern = linePlacer.getBlockFragmentKerning(last_block, first_frag)
		w_width = w_width + bf_kern
	end

	--print("placeBuf", "self.x", self.x, "w_width", w_width, "w_space", w_space, "wrap_limit", self.wrap_limit)
	--print("Word fits?", (self.x + w_width <= self.wrap_limit))

	-- Word fits on the current line
	if self.x + w_width <= self.wrap_limit then
		-- Apply kerning offset to last block
		if last_block then
			if last_block.has_ws then
				last_block.ws_w = last_block.ws_w + bf_kern

			else
				last_block.w = last_block.w + bf_kern
			end
		end

		for i = 1, self.word_buf_len do
			local frag = word_buf[i]
			local b_style = frag.b_style

			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.b_style,
				frag.font_h * b_style.f_sy,
				frag.combined,
				frag.word_w * b_style.f_sx,
				frag.space_w * b_style.f_sx,
				(#frag.space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (frag.word_w + frag.space_w) * b_style.f_sx
		end
		self:clearBuf()

		return true

	-- Word doesn't fit
	else
		return false
	end
end


--- Fit as much of the word buffer contents as possible into a block array. Intended to be called in a loop. The caller needs to clear the word buffer after the work is finished.
-- @param blocks The block array.
-- @param f Index of the current fragment in the word buffer. Should be 1 on the first call, and subsequent calls should use the fragment index returned by this function.
-- @param cluster_gran When true, break words by grapheme cluster boundaries. When false/nil, break by code points.
-- @return The index of the next fragment (f). Work is complete if 'f > self.word_buf_len'.
function _mt_lp:breakBuf(blocks, f, cluster_gran)

	local word_buf = self.word_buf

	--[[
	print("breakBuf: current contents (f=="..f..")")
	for i = 1, self.word_buf_len do
		print("", i, "|"..self.word_buf[i].combined.."|")
	end
	--]]

	-- Need to recalculate fragment sizes as we go.
	linePlacer.setFragmentSize(false, word_buf[f])

	while f <= self.word_buf_len do

		--print("f/word_buf_len", f, self.word_buf_len)

		local frag = word_buf[f]
		local frag2 = false
		if f + 1 <= self.word_buf_len then
			frag2 = word_buf[f + 1]
		end

		if not frag2 then
			linePlacer.setFragmentSize(false, frag)

		else
			linePlacer.setFragmentSize(frag, frag2)
		end

		--print("self.x", self.x, "frag.word_w", frag.word_w, "wrap_limit", self.wrap_limit)

		if self.x + frag.word_w * frag.b_style.f_sx <= self.wrap_limit then
			--print("f: Fits in current line. Append:", frag.combined, "self.x:", self.x)
			local b_style = frag.b_style
			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.b_style,
				frag.font_h * b_style.f_sy,
				frag.combined,
				frag.word_w * b_style.f_sx,
				frag.space_w * b_style.f_sx,
				(#frag.space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (frag.word_w + frag.space_w) * b_style.f_sx
			f = f + 1

		else
			--print("f: Doesn't fit in current line. Break fragment.")

			local b_style = frag.b_style
			local font = b_style.font

			local break_j

			-- break by grapheme cluster boundaries
			if cluster_gran then
				break_j = textUtil.walkClustersToWidth(
					frag.combined,
					font,
					self.wrap_limit / math.max(b_style.f_sx, 1) - self.x
				)

			-- break by code points
			else
				break_j = textUtil.walkCodePointsToWidth(
					frag.combined,
					font,
					self.wrap_limit / math.max(b_style.f_sx, 1) - self.x
				)			
			end

			local b_combined = string.sub(frag.combined, 1, break_j)
			--print("b_combined", b_combined, #b_combined, break_j)

			if #b_combined == 0 then
				-- prevents an infinite loop
				return f + 1
			end

			local b_word, b_space = textUtil.walkIsland(b_combined, 1)

			local b_word_w = font:getWidth(b_word)
			local b_space_w = font:getWidth(b_space)

			--print("frag:", frag.combined, frag.word, frag.space, frag.word_w, frag.space_w)
			--print("b_combined", b_combined, "b_word", b_word, "b_space", b_space, "b_word_w", b_word_w, "b_space_w", b_space_w)

			-- End this line if there is already something here and this reduced fragment
			-- passes beyond the wrap limit.
			if self.x > 0 and self.x + b_word_w * b_style.f_sx > self.wrap_limit then
				--print("breakBuf: end early (f=="..f.."). x", self.x, "b_word_w", b_word_w, "b_style.f_sx", b_style.f_sx, "wrap_limit", self.wrap_limit)

				return f
			end

			--print("PLACING "..b_combined.." AT X "..self.x)
			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.b_style,
				frag.font_h * b_style.f_sy,
				b_combined,
				b_word_w * b_style.f_sx,
				b_space_w * b_style.f_sx,
				(#b_space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (b_word_w + b_space_w) * b_style.f_sx

			-- Remove what we added.
			frag.combined = string.sub(frag.combined, #b_combined + 1)
			frag.word = string.sub(frag.word, #b_word + 1)
			frag.space = string.sub(frag.space, #b_space + 1)

			-- Recalculate frag.word_w and frag.space_w
			linePlacer.setFragmentSize(false, frag)

			--print("new frag combined", frag.combined, "word", frag.word, "space", frag.space)
			--print("#frag.word", #frag.word, "#frag.space", #frag.space, "f", f)

			-- Increment if the non-whitespace part of the fragment has been reduced to an empty string.
			if #frag.word == 0 then
				f = f + 1
			end
		end
	end

	--self:flushStringCache(blocks)

	-- Caller must clear the word buffer when finished.
	--print("breakBuf: end (f=="..f..")")
	return f
end


--- Try to place an arbitrary block on the line. The caller is responsible for setting up the block structure -- see
--	the comments in text_block.lua for more info.
-- @param blocks The blocks array.
-- @param block The arbitrary block to add.
-- @param force_placement When true, always place the block, regardless of the remaining space.
-- @return true if the block was placed successfully, false if not (try again on a new line).
function _mt_lp:placeArbitraryBlock(blocks, block, force_placement)

	if force_placement or self.x + block.w <= self.wrap_limit then
		block.x = self.x
		blocks[#blocks + 1] = block
		self.x = self.x + block.w
		return true

	-- Block doesn't fit
	else
		return false
	end
end


return linePlacer
