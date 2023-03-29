-- (PROTOTYPE)

-- grapheme boundary check implementation, plus some UTF-8 helpers.

--[[
MIT License

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


local gBound = {}

local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""

local utf8 = require("utf8")


local lut = require(REQ_PATH .. "lut")


local grapheme_breaks = lut.grapheme_breaks
local ext_pict = lut.emoji_data["Extended_Pictographic"]


function gBound.checkLUT(lut, code_point)

	-- Bail out early if the code point is greater than the last upper range.
	if code_point > lut[#lut] then
		return false
	end

	for i = 1, #lut, 2 do
		local r1, r2 = lut[i], lut[i + 1]
		if code_point < r1 then
			return false

		elseif code_point <= r2 then
			return true
		end
	end

	return false
end


function gBound.stepCodePoint(str, i)

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
		error("failed to count byte-length of code point in UTF-8 form.")
	end

	return code_point, byte_len
end


--- Find the edge of a grapheme cluster within a string.
-- @param str The string to step through.
-- @param pos Starting byte position in the string. Must be the start of a valid UTF-8 code point.
-- @return The byte position following the cluster boundary. (Subtract 1 when using the return value with string.sub().)
function gBound.stepCluster(str, pos)

	-- XXX: Assertions? (Too slow?)

	while pos <= #str do
		local breaking, next_pos = gBound.checkBreak(str, pos)

		--print(str, pos, breaking, next_pos)

		if breaking then
			--print("return", next_pos)
			return next_pos

		else
			pos = next_pos
		end
	end

	return #str + 1
end


--- Check for a grapheme cluster boundary between two code points in 'str', beginning at 'pos'.
-- @param str The string to check.
-- @param pos Current byte position in the sequence.
-- @return True if there should be a break, false if not, plus the pos value immediately after the sequence.
function gBound.checkBreak(str, pos)

	-- Uses the simplified rules from the Unicode Grapheme Break Chart page:
	-- https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakTest.html#rules

	-- Do not call outside of the string bounds (except for 0), or on positions with UTF-8
	-- continuation bytes.

	--[[
	We mainly care about the code points at pos (a) and the one immediately following (b).
	However, the rules for emoji sequences and regional indicators involve looking back
	through the string.
	--]]

	-- XXX: Assertions? (Too slow?)

	-- 0.2: sot ÷
	if pos == 0 then
		return true, 1 --[[DBG]] , "0.2"
	end

	local a, b, step
	a, step = gBound.stepCodePoint(str, pos)
	if pos + step <= #str then
		b = gBound.stepCodePoint(str, pos + step)

	-- 0.3: ÷ eot
	else
		return true, #str + 1 --[[DBG]] , "0.3"
	end

	local gb = grapheme_breaks
	local has = gBound.checkLUT

	-- Hard-code categories with only one entry.
	-- [UPGRADE-REVIEW]: Check this when upgrading the version of Unicode that is used to
	-- generate the look-up tables.
	local cr = 0xd
	local lf = 0xa
	local zwj = 0x200d

	local control = gb["Control"]
	local extend = gb["Extend"]
	local ri = gb["Regional_Indicator"]
	local prepend = gb["Prepend"]
	local spacing_mark = gb["SpacingMark"]
	local l = gb["L"]
	local v = gb["V"]
	local t = gb["T"]
	local lv = gb["LV"]
	local lvt = gb["LVT"]

	-- XXX: would it be worth caching the results of 'has(v, b)' and 'has(t, b)'?
	-- (The only table look-ups that potentially happen more than once.)
	-- Benchmark it sometime.

	-- 3.0: CR × LF
	if a == cr and b == lf then
		return false, pos + step --[[DBG]] , "3.0"

	-- 4.0: ( Control | CR | LF ) ÷
	elseif has(control, a) or a == cr or a == lf then
		return true, pos + step --[[DBG]] , "4.0"

	-- 5.0: ÷ ( Control | CR | LF )
	elseif has(control, b) or b == cr or b == lf then
		return true, pos + step --[[DBG]] , "5.0"

	-- 6.0: L × ( L | V | LV | LVT )
	elseif has(l, a) and (has(l, b) or has(v, b) or has(lv, b) or has(lvt, b)) then
		return false, pos + step --[[DBG]] , "6.0"

	-- 7.0: ( LV | V ) × ( V | T )
	elseif (has(lv, a) or has(v, a)) and (has(v, b) or has(t, b)) then
		return false, pos + step --[[DBG]] , "7.0"

	-- 8.0: ( LVT | T ) × T
	elseif (has(lvt, a) or has(t, a)) and has(t, b) then
		return false, pos + step --[[DBG]] , "8.0"

	-- 9.0: × (Extend | ZWJ)
	elseif (has(extend, b) or b == zwj) then
		return false, pos + step --[[DBG]] , "9.0"

	-- 9.1: × SpacingMark
	elseif (has(spacing_mark, b)) then
		return false, pos + step --[[DBG]] , "9.1"

	-- 9.2: Prepend ×
	elseif (has(prepend, a)) then
		return false, pos + step --[[DBG]] , "9.2"

	-- Have to walk backwards through the string for the last set of rules.
	else
		local xp = ext_pict

		local p --previous code point(s)
		local j = utf8.offset(str, -1, pos) -- index stepping backwards. (Becomes nil when stepping back from 1.)
		local back_step -- how many bytes to step backwards per code point

		-- 11.0: ExtPict Extend* ZWJ × ExtPict
		-- (Extend* means 0 or more Extend code points)
		if a == zwj and has(xp, b) then
			while j do
				p = utf8.codepoint(str, j)

				if has(xp, p) then
					return false, pos + step --[[DBG]] , "11.0"

				elseif not has(extend, p) then
					break
				end

				j = utf8.offset(str, -1, j)
			end

		elseif has(ri, a) and has(ri, b) then
			local ri_count = 0

			while true do
				-- 12.0: ^ (RI RI)* RI × RI
				if not j then
					if ri_count % 2 == 0 then
						return false, pos + step --[[DBG]] , "12.0"

					-- Kill this inner loop. We reached the start of the document which means
					-- rule 13 (below) is no longer applicable.
					else
						break
					end
				end

				p = utf8.codepoint(str, j)
				local is_ri = has(ri, p)
				if is_ri then
					ri_count = ri_count + 1
				end

				-- 13.0: [^RI] (RI RI)* RI × RI
				if not is_ri and ri_count % 2 == 0 then
					return false, pos + step --[[DBG]] , "13.0"
				end

				j = utf8.offset(str, -1, j)
			end
		end
	end

	-- 999.0: ÷ Any
	return true, pos + step --[[DBG]] , "999.0"
end


return gBound
