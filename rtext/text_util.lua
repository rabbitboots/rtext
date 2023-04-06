-- Text utilities.

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


local textUtil = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


-- LÖVE supplemental
local utf8 = require("utf8")

local gBound = require(REQ_PATH .. "lib.g_bound.g_bound")

local singular_charpattern = "^(" .. utf8.charpattern .. ")"
local singular_ws_charpattern = "^(" .. utf8.charpattern .. ")(%s*)"


local function errIndexOutOfRange(arg_n)
	error("argument #" .. arg_n .. ": string byte index is out of range.", 2)
end


-- A look-up table of whitespace code points to treat as word delimiters.
-- Commented-out entries are not whitespace or are non-breaking.
-- (x) == not recommended for use here.


textUtil.ws_break = {
	[0x0009] = true, -- ASCII tab
	[0x000a] = true, -- ASCII line feed
	[0x000b] = true, -- ASCII vertical tab (x)
	[0x000c] = true, -- ASCII form feed (x)
	[0x000d] = true, -- ASCII carriage return (x)
	[0x0020] = true, -- ASCII space
--	[0x00a0] = true, -- Non-breaking space (noBreak)
	[0x1680] = true, -- Ogham space mark
	[0x2000] = true, -- En quad
	[0x2001] = true, -- Em quad
	[0x2002] = true, -- En space
	[0x2003] = true, -- Em space
	[0x2004] = true, -- Three-per-em space
	[0x2005] = true, -- Four-per-em space
	[0x2006] = true, -- Six-per-em space
--	[0x2007] = true, -- Figure space (noBreak)
	[0x2008] = true, -- Punctuation space
	[0x2009] = true, -- Thin space
	[0x200a] = true, -- Hair space
	[0x200b] = true, -- Zero width space
	[0x2028] = true, -- Line separator (x)
--	[0x202f] = true, -- Narrow no-break space (noBreak)
	[0x205f] = true, -- Medium mathematical space
--	[0x2060] = true, -- Word joiner
	[0x3000] = true, -- Ideographic space
--	[0xfeff] = true, -- Byte order mark (x)
}


--[[
-- String versions of ws_break. It's easier to compare them with grapheme clusters in string form.
textUtil.ws_break_str = {}
for k in pairs(textUtil.ws_break) do
	textUtil.ws_break_str[k] = utf8.char(k)
end
--]]



-- * Code point stepping functions *


--- Get one code point from a UTF-8 string and return it, plus its UTF-8 size in bytes.
-- @param str The string to check. Must contain at least one code point.
-- @param i Byte position. Must be on a UTF-8 start byte.
-- @return The code point integer, and the size of the code point in bytes when encoded as UTF-8.
function textUtil.stepCodePoint(str, i)

	-- Assumes str[i] is a UTF-8 starting (non-continuation) byte.

	local code_point = utf8.codepoint(str, i)
	local byte_len

	if code_point <= 0x007f then
		byte_len = 1

	elseif code_point <= 0x07ff then
		byte_len = 2

	elseif code_point <= 0xffff then
		byte_len = 3

	elseif code_point <= 0x10ffff then
		byte_len = 4

	else
		-- This shouldn't be reached unless utf8.codepoint() is swapped out.
		error("failed to count byte-length of code point in UTF-8 form.")
	end

	return code_point, byte_len
end


--- Count a run of code points which appear in a look-up table.
-- @param str The string to check.
-- @param i Starting byte position in the string.
-- @param lut The look-up table to use.
-- @return Next unread byte position, and the final byte position of the run of code points (or 0 if none were found).
function textUtil.getRunLUT(str, i, lut)

	local j = 0
	while i <= #str do
		local code_point, step = textUtil.stepCodePoint(str, i)
		if lut[code_point] then
			i = i + step
			j = i - 1

		else
			break
		end
	end

	return i, j
end


--- Count a run of code points which do not appear in a look-up table.
-- @param str The string to check.
-- @param i Starting byte position in the string.
-- @param lut The look-up table to use.
-- @return Next unread byte position, and the final byte position of the run of code points (or 0 if none were found).
function textUtil.getRunLUTNot(str, i, lut)

	local j = 0
	while i <= #str do
		local code_point, step = textUtil.stepCodePoint(str, i)
		if not lut[code_point] then
			i = i + step
			j = i - 1

		else
			break
		end
	end

	return i, j
end


--- Count a run of code points which satisfy some classification as determined by a higher order function.
-- @param str The string to check.
-- @param i Starting byte position in the string.
-- @param func The function which tests the code point. It takes the code_point as its sole argument, and returns
--	true for a positive result and negative if it doesn't belong to the run of text.
-- @return Next unread byte position, and the final byte position of the run of code points (or 0 if none were found).
function textUtil.getRun(str, i, func)

	local j = 0
	while i <= #str do
		local code_point, step = textUtil.stepCodePoint(str, i)
		if func(code_point) then
			i = i + step
			j = i - 1

		else
			break
		end
	end

	return i, j
end


-- * / Code point stepping functions *


-- * String walk functions *


--- Split a string, starting at position 'i', at the last instance of trailing whitespace.
-- @param str The string to walk.
-- @param i Starting byte position in the string.
-- @return Substring for the non-whitespace word, substring for the trailing whitespace, and the next unread byte position
--	in the string.
function textUtil.walkFull(str, i)

	-- Handle empty strings as a special case
	if #str == 0 then
		return "", "", 1
	end

	-- Assertions
	-- [[
	if i < 1 or i > #str then errIndexOutOfRange(2) end
	--]]

	local ws_break = textUtil.ws_break
	local j = #str + 1

	-- Walk backwards until we hit a non-whitespace code point.
	while j >= i do
		local new_j = utf8.offset(str, -1, j)
		if not new_j then
			break
		end

		local code_point = utf8.codepoint(str, new_j)
		if not ws_break[code_point] then
			return string.sub(str, i, j - 1), string.sub(str, j), #str + 1
		end

		j = new_j
	end

	-- It's all whitespace
	return "", string.sub(str, i), #str + 1
end


--- In a string, starting at position 'i', get a run of non-whitespace text followed by a run of whitespace.
-- @param str The string to walk.
-- @param i Starting byte position in the string.
-- @return Substring for the non-whitespace word, substring for the trailing whitespace, and the next unread byte position
--	in the string.
function textUtil.walkIsland(str, i)

	-- Handle empty strings as a special case
	if #str == 0 then
		return "", "", 1
	end

	-- Assertions
	-- [[
	if i < 1 or i > #str then errIndexOutOfRange(2) end
	--]]

	-- Get non-whitespace range.
	local word_i = i
	local word_j
	i, word_j = textUtil.getRunLUTNot(str, i, textUtil.ws_break)

	-- Get trailing whitespace range.
	local space_i = i
	local space_j
	i, space_j = textUtil.getRunLUT(str, space_i, textUtil.ws_break)

	return string.sub(str, word_i, word_j), string.sub(str, space_i, space_j), i
end


--- In a string, starting at position 'i', check for one non-whitespace code point followed by a run of whitespace.
-- @param str The string to walk.
-- @param i The starting byte position in the string.
-- @return Substring for the non-whitespace code point, substring for the trailing whitespace, and the next unread byte
--	position on the string.
function textUtil.walkCodePointTrailing(str, i)

	-- Handle empty strings + byte #1 as a special case
	if #str == 0 and i == 1 then
		return "", "", 1
	end

	-- Assertions
	-- [[
	if i < 1 or i > #str then errIndexOutOfRange(2) end
	--]]

	local code_str = ""
	local code_point, step = textUtil.stepCodePoint(str, i)
	if not textUtil.ws_break[code_point] then
		code_str = utf8.char(code_point)
		i = i + step
	end

	-- Get trailing whitespace range.
	local space_i = i
	local space_j
	i, space_j = textUtil.getRunLUT(str, space_i, textUtil.ws_break)

	return code_str, string.sub(str, space_i, space_j), i
end


--- In a string, starting at position 'i', check for one non-whitespace grapheme cluster followed by a run of whitespace.
-- @param str The string to walk.
-- @param i The starting byte position in the string.
-- @return Substring for the non-whitespace grapheme cluster, substring for the trailing whitespace, and the next unread byte
--	position on the string.
function textUtil.walkClusterTrailing(str, i)

	-- Handle empty strings + byte #1 as a special case
	if #str == 0 and i == 1 then
		return "", "", 1
	end

	-- Assertions
	-- [[
	if i < 1 or i > #str then errIndexOutOfRange(2) end
	--]]

	-- Check if the first code point is whitespace.
	local code_point = utf8.codepoint(str, i)
	if textUtil.ws_break[code_point] then
		local space_i = i
		local space_j
		i, space_j = textUtil.getRunLUT(str, space_i, textUtil.ws_break)
		return "", string.sub(str, space_i, space_j), i
	end

	local cluster_i = i
	i = gBound.stepCluster(str, i)
	local cluster_j = i - 1

	-- Get trailing whitespace range.
	local space_i = i
	local space_j
	i, space_j = textUtil.getRunLUT(str, space_i, textUtil.ws_break)

	return string.sub(str, cluster_i, cluster_j), string.sub(str, space_i, space_j), i
end


--- Measure a string by code points, stopping when meeting / passing a minimum width, or when reaching the
--	end of the string. Trailing whitespace is included in the measurement.
-- @param str The string to walk.
-- @param font The font to use for measurement.
-- @param min The minimum desired text size.
-- @return End byte position and determined width, which may not meet the minimum desired text size if the
--	string was too short. If the string is empty, returns index 0 and width 0.
function textUtil.walkCodePointsToWidth(str, font, min)

	if #str == 0 then
		return 0, 0
	end

	local i = 1
	local w = 0
	local last_j = false

	repeat
		local code_point, step = textUtil.stepCodePoint(str, i)
		local j = i + step - 1
		w = font:getWidth(string.sub(str, 1, j))

		if w >= min then
			--return last_j or j, w
			if last_j then
				return last_j, w

			else
				return j, w
			end

		else
			i = i + step
			last_j = j
		end
	until i > #str

	return #str, font:getWidth(str)
end


--- Measure a string by grapheme clusters, stopping when meeting / passing a minimum width, or when reaching the
--	end of the string. Trailing whitespace is included in the measurement.
-- @param str The string to walk.
-- @param font The font to use for measurement.
-- @param min The minimum desired text size.
-- @return End byte position and determined width, which may not meet the minimum desired text size if the
--	string was too short. If the string is empty, returns index 0 and width 0.
function textUtil.walkClustersToWidth(str, font, min)

	if #str == 0 then
		return 0, 0
	end

	local i = 1
	local w = 0
	local last_j = false

	repeat
		local next_pos = gBound.stepCluster(str, i)
		local j = next_pos - 1
		w = font:getWidth(string.sub(str, 1, j))

		if w >= min then
			--return last_j or j, w
			if last_j then
				return last_j, w

			else
				return j, w
			end

		else
			i = next_pos
			last_j = j
		end
	until i > #str

	return #str, font:getWidth(str)
end


-- * / String walk functions *


-- * Text width *


local temp_str = {}
function textUtil.getStringFromText(text)

	if type(text) == "string" then
		return text

	else
		for i, chunk in ipairs(text) do
			if type(chunk) == "string" then
				temp_str[#temp_str + 1] = chunk
			end
		end

		local concat = table.concat(temp_str)

		for i = #temp_str, 1, -1 do
			temp_str[i] = nil
		end

		return concat
	end
end



--- Get the width of a string or coloredtext sequence.
function textUtil.getTextWidth(text, font)

	local str = textUtil.getStringFromText(text)
	local width = font:getWidth(str)

	return width
end


-- * / Text width *


return textUtil
