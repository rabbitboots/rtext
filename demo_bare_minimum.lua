-- Barebones RText setup example.

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


-- Load the module.
local rtext = require("rtext.rtext")


-- This will be our rtext instance. Before creating it, we first need to set up some
-- font-related structures.
local rt

do
	-- Set up at least one LÖVE Font.
	local font = love.graphics.newFont(24)

	-- Fonts go into Block Style tables, which provide additional metadata and drawing methods.
	local b_style = rtext.newBlockStyle(font)

	--[[
	The Block Style tables are attached to a FontGroup table, which allows rtext to select
	between regular, bold, italic and bold-italic font faces. In this example, we will
	implement only the regular font.
	--]]
	local f_grp = rtext.newFontGroup(b_style)

	-- Now, when creating the rtext instance, we must assign a table of font groups with
	-- string IDs. We must also pass in the ID representing the default font group.
	local font_groups = {
		norm = f_grp,
	}

	rt = rtext.newInstance(font_groups, "norm")

	-- To recap:
	-- Font -> Block Style -> FontGroup -> table of font groups with string IDs.
end


-- Let's generate a drawable document.
local sample = "[align left]Hello,\n[align center]World\n[align right]!"

local document = rt:makeDocument(sample, love.graphics.getWidth() / 4) -- (input, wrap_width)


function love.draw()

	-- Illustrate the wrap-limit:
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.line(document.wrap_w + 0.5, 0.5, document.wrap_w + 0.5, love.graphics.getHeight())
	love.graphics.setColor(1, 1, 1, 1)

	-- Draw the document:
	document:draw(0, 0)
end


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()
		return
	end
end

