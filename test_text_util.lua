-- A test of the text_util.lua module.


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


-- LÖVE supplemental
local utf8 = require("utf8")

local textUtil = require("rtext.text_util")


-- * Test setup *


local function fmtWordIsland(island)
	return "|" .. island.word .. "|" .. island.space .. "|"
end


local function fmtCodePoints(str)

	local codes = {}
	for p, c in utf8.codes(str) do
		table.insert(codes, string.format("0x%x", c))
	end
	local str = table.concat(codes, ", ")

	return str
end


local function makeWordIsland(str, i)

	i = i or 1

	local isl = {}
	isl.word, isl.space = textUtil.walkIsland(str, i)

	return isl
end


local function makeClusterIsland(str, i)

	i = i or 1

	local isl = {}
	isl.word, isl.space = textUtil.walkClusterTrailing(str, i)

	return isl
end


local function makeCodePointIsland(str, i)

	i = i or 1

	local isl = {}
	isl.word, isl.space = textUtil.walkCodePointTrailing(str, i)

	return isl
end


local function testLine(str, i)

	local isl = makeWordIsland(str, i)
	print(fmtWordIsland(isl), fmtCodePoints(isl.space))
end


local function testCluster(str, i)

	local isl = makeClusterIsland(str, i)
	print(fmtWordIsland(isl), fmtCodePoints(isl.space))
end


local function testCodePoint(str, i)

	local isl = makeCodePointIsland(str, i)
	print(fmtWordIsland(isl), fmtCodePoints(isl.space))
end


-- Breaking:
local CHARACTER_TABULATION      = utf8.char(0x0009)
local LINE_FEED                 = utf8.char(0x000a)
local VERTICAL_TAB              = utf8.char(0x000b)
local FORM_FEED                 = utf8.char(0x000c)
local CARRIAGE_RETURN           = utf8.char(0x000d)
local SPACE                     = utf8.char(0x0020)
local OGHAM_SPACE_MARK          = utf8.char(0x1680)
local EN_QUAD                   = utf8.char(0x2000)
local EM_QUAD                   = utf8.char(0x2001)
local EN_SPACE                  = utf8.char(0x2002)
local EM_SPACE                  = utf8.char(0x2003)
local THREE_PER_EM_SPACE        = utf8.char(0x2004)
local FOUR_PER_EM_SPACE         = utf8.char(0x2005)
local SIX_PER_EM_SPACE          = utf8.char(0x2006)
local PUNCTUATION_SPACE         = utf8.char(0x2008)
local THIN_SPACE                = utf8.char(0x2009)
local HAIR_SPACE                = utf8.char(0x200a)
local ZERO_WIDTH_SPACE          = utf8.char(0x200b)
local LINE_SEPARATOR            = utf8.char(0x2028)
local MEDIUM_MATHEMATICAL_SPACE = utf8.char(0x205f)
local IDEOGRAPHIC_SPACE         = utf8.char(0x3000)


-- Non-breaking:
local NON_BREAKING_SPACE        = utf8.char(0x00a0)
local FIGURE_SPACE              = utf8.char(0x2007)
local NARROW_NO_BREAK_SPACE     = utf8.char(0x202f)
local WORD_JOINER               = utf8.char(0x2060)
local BYTE_ORDER_MARK           = utf8.char(0xfeff)


-- * / Test setup *


-- * Testing *

-- [=[
print("*** TEXT UTIL TEST ***")
print("")
print("Word island tests: Given the string template 'foo<space>bar', extract 'foo' and")
print("the trailing space, and then print the space code point values.")
print("")
print("Try every space code point individually.")
testLine("foo" .. CHARACTER_TABULATION .. "bar")
testLine("foo" .. LINE_FEED .. "bar")
testLine("foo" .. VERTICAL_TAB .. "bar")
testLine("foo" .. FORM_FEED .. "bar")
testLine("foo" .. CARRIAGE_RETURN .. "bar")
testLine("foo" .. SPACE .. "bar")
testLine("foo" .. OGHAM_SPACE_MARK .. "bar")
testLine("foo" .. EN_QUAD .. "bar")
testLine("foo" .. EM_QUAD .. "bar")
testLine("foo" .. EN_SPACE .. "bar")
testLine("foo" .. EM_SPACE .. "bar")
testLine("foo" .. THREE_PER_EM_SPACE .. "bar")
testLine("foo" .. FOUR_PER_EM_SPACE .. "bar")
testLine("foo" .. SIX_PER_EM_SPACE .. "bar")
testLine("foo" .. PUNCTUATION_SPACE .. "bar")
testLine("foo" .. THIN_SPACE .. "bar")
testLine("foo" .. HAIR_SPACE .. "bar")
testLine("foo" .. ZERO_WIDTH_SPACE .. "bar")
testLine("foo" .. LINE_SEPARATOR .. "bar")
testLine("foo" .. MEDIUM_MATHEMATICAL_SPACE .. "bar")
testLine("foo" .. IDEOGRAPHIC_SPACE .. "bar")

print("")
print("Try some combinations.")
testLine("foo" .. SPACE .. OGHAM_SPACE_MARK .. EM_QUAD .. "bar")
testLine("foo" .. IDEOGRAPHIC_SPACE .. ZERO_WIDTH_SPACE .. THIN_SPACE .. HAIR_SPACE .. SPACE .. "bar")

print("")
print("Try no space at all.")
testLine("foobar")


print("Try an empty string.")
testLine("")


print("")
print("Try some non-breaking spaces.")
testLine("foo" .. NON_BREAKING_SPACE .. "bar")
testLine("foo" .. FIGURE_SPACE .. "bar")
testLine("foo" .. NARROW_NO_BREAK_SPACE .. "bar")
testLine("foo" .. BYTE_ORDER_MARK .. "bar")
testLine("foo" .. WORD_JOINER .. "bar")

print("")
print("Start a few bytes in (on 'b').")
testLine("foo  bar   zaz", 6)

print("")
print("Test beginning with a space. (Expected: | ||).")
testLine(SPACE .. "bar")

print("")
--]=]

-- [=[
print("")
print("Code Point tests.")
print("'A  ' (|A|  |)")
testCodePoint("A  ")

print("'ABC  ' (|A||)")
testCodePoint("ABC  ")

print("'   D' (||   |)")
testCodePoint("   D")

print("Gets only the first code point from a grapheme cluster.")
print("'👨‍🦲👨‍🦲' (|👨||)")
testCodePoint("👨‍🦲👨‍🦲")
--]=]


-- [=[
print("")
print("Grapheme Cluster tests.")
print("'F   ' (|F|   |)")
testCluster("F   ")

print("'  F ' (||  |)")
testCluster("  F ")

print("'FF' (|F||)")
testCluster("FF")

print("'g̈houle' (|g̈||)") -- g̈ == U+0067 + U+0308
testCluster("g̈houle")

print("'g̈ h' (|g̈| |)")
testCluster("g̈ h")

print("'👨‍🦲👨‍🦲' (|👨‍🦲||)")
testCluster("👨‍🦲👨‍🦲")
--]=]


-- * / Testing *


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()
	end
end


local mouse_x = -128
function love.update(dt)

	mouse_x = love.mouse.getX()
end


local font = love.graphics.newFont(24)


function love.draw()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font)
	love.graphics.print("Check the console output for most of the test results.\nTests for walkCodePointToWidth() and walkClusterToWidth() follow:")

	local str, cpi, cpw

	str = "The five boxing wizards jump quickly."
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.print(str, 0, 128)
	love.graphics.setColor(1, 1, 1, 1)
	cpi, cpw = textUtil.walkCodePointsToWidth(str, font, mouse_x)
	love.graphics.print(string.sub(str, 1, cpi), 0, 128)

	str = "The👨‍🦲five👨‍🦲boxing👨‍🦲wizards👨‍🦲jump👨‍🦲quickly."
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.print(str, 0, 224)
	love.graphics.setColor(1, 1, 1, 1)
	cpi, cpw = textUtil.walkClustersToWidth(str, font, mouse_x)
	love.graphics.print(string.sub(str, 1, cpi), 0, 224)

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.line(mouse_x + 0.5, 0.5, mouse_x + 0.5, love.graphics.getHeight() + 1)
	love.graphics.setColor(1, 1, 1, 1)
end


--[=[
-- Test assertions
do
	--textUtil.stepCodePoint(false, 1) -- #1 utf8.codepoint -> bad type
	--textUtil.stepCodePoint("foobar", function() end) -- #2 utf8.codepoint -> bad type
	--textUtil.stepCodePoint("öööö", 2) -- utf8.codepoint -> invalid UTF-8 code.
	--textUtil.stepCodePoint("") -- utf8.codepoint -> out of range

	--textUtil.getRunLUT(str, i, lut) -- no assertions
	--textUtil.getRunLUTNot(str, i, lut) -- no assertions
	--textUtil.getRun(str, i, func) -- no assertions

	local sa, sb, i
	sa, sb, i = textUtil.walkFull("", 1) -- OK: empty strings with index 1 are handled as a special case.
	--sa, sb, i = textUtil.walkFull("foo", 0) -- #2 index out of range
	--sa, sb, i = textUtil.walkFull("foo", 999) -- #2 index out of range

	sa, sb, i = textUtil.walkIsland("", 1) -- OK
	--sa, sb, i = textUtil.walkIsland("foo", 0) -- #2 index out of range
	--sa, sb, i = textUtil.walkIsland("foo", 999) -- #2 index out of range
	
	sa, sb, i = textUtil.walkCodePointTrailing("", 1) -- OK
	--sa, sb, i = textUtil.walkCodePointTrailing("foo", 0) -- #2 index out of range
	--sa, sb, i = textUtil.walkCodePointTrailing("foo", 99) -- #2 index out of range

	sa, sb, i = textUtil.walkClusterTrailing("", 1) -- OK
	--sa, sb, i = textUtil.walkClusterTrailing("foo", 0) -- #2 index out of range
	--sa, sb, i = textUtil.walkClusterTrailing("foo", 999) -- #2 index out of range

	--textUtil.walkCodePointsToWidth("", font, 300) -- no assertions
	--textUtil.walkClustersToWidth(str, font, min) -- no assertions
	--textUtil.getTextWidth(text, font) -- no assertions
end
--]=]
