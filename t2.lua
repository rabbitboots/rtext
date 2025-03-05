-- Label tests.


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
(1) Make, draw a standalone label with mixed Block Styles

(2) Make a long label with many Text Blocks, and draw only a small range of the
    total Blocks.

(3) Make a label with an Arbitrary Block ("Press <Gamepad Button> To Continue")
--]]

local utf8 = require("utf8")

-- `rtext.lua` is not required for making and showing labels.
local media = require("rtext.media")
local textBlock = require("rtext.text_block")


-- Make some Block Styles.
local font = love.graphics.newFont(24)
local b_style = textBlock.newBlockStyle(font)

local font_big = love.graphics.newFont(32)
local b_style_big = textBlock.newBlockStyle(font_big)


-- (1) Make, draw a standalone Label.
local label = media.newLabel()
label:appendText("!?", b_style, {1, 0, 0, 1}, {1, 1, 1, 1}, false, false)


-- Test `label:clear()`: "!?" should not be present in the test output.
label:clear()


label:appendText("One", b_style, {1, 0, 0, 1}, {1, 1, 1, 1}, false, false)
label:appendText(" Two ", b_style_big, {1, 1, 0, 1}, false, {1, 1, 1, 1}, false)
label:appendText("Thr", b_style, {0, 0, 0, 1}, false, false, {0.5, 0.5, 0.5, 1})

-- Test 'label:extendLastBlock()`: Final block should be "Three", with a different color for the final two chars.
label:extendLastBlock("ee", {0, 0.25, 0.025, 1})

-- ^ tests extendLastBlock() updating the width of the block: there should not be an overlap between Three and Four
label:appendText("Four", b_style, {0, 0, 0, 1}, false, false, {0.2, 0.2, 0.2, 1})


label:arrange()

-- (2) Make a long label with many Text Blocks. We will draw a subsection as it scrolls horizontally.
local label2 = media.newLabel()


-- https://www.gutenberg.org/ebooks/30411
local message = [[
Familiar Phrases.  Go to send for.  Have you say that?  Have you understand that he says?  At what purpose have say so?  Put your confidence at my.  At what o'clock dine him?  Apply you at the study during that you are young.  Dress your hairs.  Sing an area.  These apricots and these peaches make me and to come water in mouth.  How do you can it to deny?  Wax my shoes.  That is that I have think.  That are the dishes whose you must be and to abstain.  This meat ist not too over do.  This ink is white.  This room is filled of bugs.  This girl have a beauty edge.  It is a noise which to cleave the head.  This wood is fill of thief's.  Tell me, it can one to know?  Give me some good milk newly get out.  To morrow hi shall be entirely (her master) or unoccupied.  She do not that to talk and to cackle.  Dry this wine.  He laughs at my nose, he jest by me.  He has spit in my coat.  He has me take out my hairs.  He does me some kicks.  He has scratch the face with hers nails.  He burns one's self the brains.  He is valuable his weight's gold.  He has the word for to laugh.  He do the devil at four.  He make to weep the room.  He was fighted in duel.  They fight one's selfs together.  He do want to fall.  It must never to laugh of the unhappies.  He was wanting to be killed.  I am confused all yours civilities.  I am catched cold.  I not make what to coughand spit.  Never I have feeld a such heat  Till say-us?  Till hither.  I have put my stockings outward.  I have croped the candle.  I have mind to vomit.  I will not to sleep on street.  I am catched cold in the brain.  I am pinking me with a pin.  I dead myself in envy to see her.  I take a broth all morning.  I shall not tell you than two woods.  Have you understanded?  Let him have know?  Have you understand they?  Do you know they?  Do you know they to?  The storm is go over.  The sun begins to dissipe it.  Witch prefer you?  The paving stone is sliphery.  The thunderbolt is falling down.  The rose-trees begins to button.  The ears are too length.  The hands itch at him.  Have you forgeted me?  Lay him hir apron.  Help-to a little most the better yours terms.  Dont you are awaken yet?  That should must me to cost my life.  We are in the canicule.  No budge you there.  Do not might one's understand to speak.  Where are their stockings, their shoes, her shirt and her petlicot?  One's can to believe you?  One's find-modest the young men rarely.  If can't to please at every one's.  Take that boy and whip him to much.  Take attention to cut you self.  Take care to dirt you self.  Dress my horse.  Since you not go out, I shall go out nor I neither.  That may dead if I lie you.  What is it who want you?  Why you no helps me to?  Upon my live.  All trees have very deal bear.  A throat's ill.  You shall catch cold one's.  You make grins.  Will some mutton?  Will you fat or slight?  Will you this?  Will you a bon?  You not make who to babble.  You not make that to prate all day's work.  You interompt me.  You mistake you self heavily.  You come too rare.]]


-- Split the message by code point.
for p, c in utf8.codes(message) do
	label2:appendText(utf8.char(c), b_style)
end


-- (3) Make a label with an Arbitrary Block.

-- Start with an Arbitrary Block Style.
local b_style_custom = textBlock.newBlockStyleArbitrary()

-- You can set vertical font metrics in an Arbitrary Block Style to help with placement within a flow of text.
-- Or you can tweak the transform parameters (d_x, d_y, d_ox, d_oy) on a per-Block basis.
-- I will just guess at the baseline here so that the button symbol is roughly in the correct spot.
b_style_custom.f_baseline = 20


b_style_custom.draw = function(self, x, y)

	love.graphics.push("all")

	love.graphics.draw(
		self.texture,
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

	love.graphics.pop()
end


-- Make a custom block and attach the style.
local block_custom = setmetatable({}, b_style_custom)
block_custom.texture = love.graphics.newImage("demo_res/image_font/mock_gamepad_a.png")
block_custom.x = 0
block_custom.y = 0
block_custom.w = block_custom.texture:getWidth()
block_custom.h = block_custom.texture:getHeight()



-- Now make the label.
local label3 = media.newLabel()
label3:appendText("Press ", b_style)
label3:appendBlock(block_custom)
label3:appendText(" to continue.", b_style)

label3:arrange("baseline")


local t = 0
function love.update(dt)

	t = t + dt

	-- (2) Rewind and fast-forward the long message.
	if love.keyboard.isScancodeDown("left", "a") then
		t = t - dt * 4

	elseif love.keyboard.isScancodeDown("right", "d") then
		t = t + dt * 4
	end
end


function love.draw()

	love.graphics.setColor(1, 1, 1, 1)

	-- (1)
	label:draw(0, 0)

	-- Calculate and show the label bounding box
	local x1, y1, x2, y2 = 0, 0, 0, 0
	for i, block in ipairs(label) do
		x1 = math.min(x1, block.x)
		y1 = math.min(y1, block.y)
		x2 = math.max(x2, block.x + block.w)
		y2 = math.max(y2, block.y + block.h)
	end

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", x1 + 0.5, y1 + 0.5, x2 - x1 - 1, y2 - y1 - 1)


	-- (2) Long Label time.
	love.graphics.setColor(1, 1, 1, 1)

	local x = -love.graphics.getWidth()/2 + t * 48

	-- Find the visible range. Let's be lazy and allow considerable overdraw -- say,
	-- 1/4th of the window width on either side.
	local quarter = love.graphics.getWidth() / 4
	local l1, l2 = 1, #label2
	for i, block in ipairs(label2) do
		if block.x >= x - quarter then
			l1 = i
			break
		end
	end
	for i = l1, #label2 do
		local block = label2[i]
		if block.x > x + love.graphics.getWidth() + quarter then
			l2 = i
			break
		end
	end

	-- Right-click to confirm the label range is being limited as described above.
	if love.mouse.isDown(2) then
		love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
		love.graphics.scale(0.5, 0.5)
		love.graphics.translate(-love.graphics.getWidth()/2, -love.graphics.getHeight()/2)
	end

	for i = l1, l2 do
		local block = label2[i]
		-- Play with the positioning of blocks while we're at it... use Label:arrange() to reset.
		block.y = math.floor(math.sin(t + block.x / 64) * 28)
		block:draw(-x, 256)
	end

	-- (3)
	-- Center the label and pulse its alpha value
	local l3_last = label3[#label3]
	if l3_last then
		local l3_width = l3_last.x + l3_last.w
		local half_width = math.floor(0.5 + love.graphics.getWidth() / 2 - l3_width / 2)
		local l3_lowest = -math.huge
		for i, block in ipairs(label3) do
			l3_lowest = math.max(l3_lowest, block.y + block.h)
		end
		local offset_y = math.floor(love.graphics.getHeight() - l3_lowest * 1.5)

		local rr, gg, bb, aa = love.graphics.getColor()

		-- pulse between 50% and 100% alpha
		local new_a = ((1.0 + math.sin(t*2)) / 2) / 2 + 0.5

		love.graphics.setColor(rr, gg, bb, new_a)
		label3:draw(half_width, offset_y)
		love.graphics.setColor(rr, gg, bb, aa)
	end
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()
		return
	end
end


-- Assertion Tests
--[[
do
	local font = love.graphics.newFont(16)
	local b_style = textBlock.newBlockStyle(font)

	local label = media.newLabel() -- no assertions
	label:clear() -- no assertions
	--label:appendText("foo", nil) -- textBlock.newTextBlock: #2 index nil
	--label:appendText("foo", b_style, "bad_type", nil, nil, nil) -- #3 bad type
	--label:appendText("foo", b_style, nil, "bad_type", nil, nil) -- #4 bad type
	--label:appendText("foo", b_style, nil, nil, "bad_type", nil) -- #5 bad type
	--label:appendText("foo", b_style, nil, nil, nil, "bad_type") -- #6 bad type

	label:appendText("", b_style) -- Empty strings are permitted

	--label:appendBlock(nil) -- #1 bad type
	--label:arrange("foobar") -- aligner: bad vertical align enum

	--label:draw() -- no assertions
end
--]]

