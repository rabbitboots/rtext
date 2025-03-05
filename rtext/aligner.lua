-- Alignment implementation.

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


local aligner = {}


aligner.enum_align = {left = true, center = true, right = true, justify = true}
aligner.enum_v_align = {top = true, ascent = true, middle = true, baseline = true, descent = true, bottom = true}


-- Normalizes to left alignment and returns total width.
local function setInitialHorizontalAlignment(blocks)

	local prev_block = blocks[1]
	if prev_block then
		prev_block.x = 0
	end
	for i = 2, #blocks do
		local block = blocks[i]
		block.x = prev_block.x + prev_block.w + prev_block.ws_w
		prev_block = block
	end

	local last_block = blocks[#blocks]
	if last_block then
		return last_block.x + last_block.w -- don't include trailing whitespace of last block

	else
		return 0
	end
end


--- @param j_x_step Allows for coarse positioning of blocks. Useful for monospaced fonts. For variable width fonts
--	(or if you want the normal justify layout for mono text), use the default (1).
local function justifyImplementation(blocks, remain, x_offset, j_x_step)

	-- prevent negative weirdness and div/0
	j_x_step = j_x_step and math.max(j_x_step, 1) or 1

	-- NOTE: This function is destructive, as it changes block sizes to fill gaps.

	-- Count the number of whitespace gaps between blocks, and how much we need to space out blocks.
	-- (Ignore the final block's trailing whitespace.)
	local n_gaps = 0
	for i = 1, #blocks - 1 do
		local block = blocks[i]
		if block.has_ws then
			n_gaps = n_gaps + 1
		end
	end

	local gap_w = 0
	if n_gaps > 0 then -- avoid div/0
		gap_w = remain / n_gaps
	end

	--print("\tjustify: n_gaps", n_gaps, "gap_w", gap_w, "#blocks", #blocks)

	-- Space out blocks that appear after trailing whitespace in the previous block.
	-- This excludes the first block in the line.
	-- Set fractional positions, then floor them in a second pass. Also widen blocks
	-- to close the gaps.
	local placed_n = 1
	local prev_block = blocks[1]
	for i = 2, #blocks do
		local sub_block = blocks[i]
		local h_spacing = 0

		if prev_block.has_ws then
			h_spacing = gap_w
			placed_n = placed_n + 1
		end

		sub_block.x = prev_block.x + prev_block.w + prev_block.ws_w + h_spacing

		prev_block = sub_block
	end

	prev_block = blocks[1]
	for i = 2, #blocks do
		local sub_block = blocks[i]
		--sub_block.x = math.floor(sub_block.x + 0.5)
		sub_block.x = math.floor((sub_block.x) / j_x_step) * j_x_step

		-- Widen block width or whitespace to cover the gaps. This stretches shapes to remove
		-- gaps, and can be helpful when implementing mouse cursor selection.
		if prev_block.has_ws then
			prev_block.ws_w = sub_block.x - (prev_block.x + prev_block.w)

		-- This shouldn't happen, but handle it just in case
		else
			prev_block.w = sub_block.x - prev_block.x
		end

		prev_block = sub_block
	end

	-- One more loop, for indent on a per-block basis.
	if x_offset ~= 0 then
		for i, block in ipairs(blocks) do
			block.x = block.x + x_offset
		end
	end
end


--- Apply horizontal alignment by offsetting a container bounding box, or offsetting block positions in the case of 'justify' alignment.
-- @param box A table containing 'x', 'y', 'w' and 'h' fields.
-- @param blocks The array of text blocks which belong to the bounding box.
-- @param align The horizontal alignment mode: "left", "center", "right" or "justify"
-- @param line_width The intended line width.
-- @param x_offset X pixel offset for indents, margins, padding, etc.
-- @param j_x_step Justify alignment pixel granularity. Should be 1 in most cases.
-- @return Nothing.
function aligner.boundingBox(box, blocks, align, line_width, x_offset, j_x_step)

	local blocks_w = setInitialHorizontalAlignment(blocks)
	local remain = math.max(0, line_width - blocks_w)

	if align == "left" then
		box.x = x_offset
		box.w = blocks_w

	elseif align == "center" then
		box.x = x_offset + math.floor(remain / 2 + 0.5)
		box.w = blocks_w

	elseif align == "right" then
		box.x = x_offset + math.floor(remain)
		box.w = blocks_w

	elseif align == "justify" then
		justifyImplementation(blocks, remain, 0, j_x_step)
		box.x = x_offset
		box.w = line_width

	else
		error("unknown align setting: " .. tostring(align))
	end
end


--- Apply horizontal alignment by offsetting block positions.
-- @param blocks The block array to arrange.
-- @param align The horizontal alignment mode: "left", "center", "right" or "justify"
-- @param line_width The intended line width.
-- @param x_offset X pixel offset for indents.
-- @param j_x_step Justify alignment pixel granularity. Should be 1 in most cases.
-- @return Nothing.
function aligner.granular(blocks, align, line_width, x_offset, j_x_step)

	local blocks_w = setInitialHorizontalAlignment(blocks)
	local remain = math.max(0, line_width - blocks_w)

	if align == "left" then
		for i, block in ipairs(blocks) do
			block.x = block.x + x_offset
		end

	elseif align == "center" then
		local offset = math.floor(remain / 2 + 0.5)
		for i, block in ipairs(blocks) do
			block.x = block.x + offset + x_offset
		end

	elseif align == "right" then
		local offset = math.floor(remain)
		for i, block in ipairs(blocks) do
			block.x = block.x + offset + x_offset
		end

	elseif align == "justify" then
		justifyImplementation(blocks, remain, x_offset, j_x_step)

	else
		error("unknown align setting: " .. tostring(align))
	end
end


function aligner.getHeight(blocks)

	-- Will return 0 for empty block-arrays. In that situation, the height of a default / currently
	-- selected font may be better.
	local tallest = 0
	for i, block in ipairs(blocks) do
		tallest = math.max(tallest, block.f_height * block.f_sy)
	end

	return tallest
end


--- Set vertical (in-line) alignment.
-- @param blocks The block array to arrange.
-- @param v_align The vertical alignment setting: "top", "middle" (between baseline and ascent), "ascent", "descent", "baseline" and "bottom"
-- @return Nothing.
function aligner.vertical(blocks, v_align)

	if v_align == "top" then
		for i, block in ipairs(blocks) do
			block.y = 0
		end

	elseif v_align == "middle" then -- half of the tallest height
		local middle = -math.huge
		for i, block in ipairs(blocks) do
			--local height = (block.f_type == "text" and block.f_height) or block.h
			local height = block.f_height * block.f_sy
			middle = math.max(middle, height / 2)
		end
		for i, block in ipairs(blocks) do
			block.y = math.floor(middle - (block.f_height * block.f_sy / 2) + 0.5)
		end

	elseif v_align == "ascent" then
		local ascent = -math.huge
		for i, block in ipairs(blocks) do
			ascent = math.max(ascent, (block.f_baseline - block.f_ascent) * block.f_sy)
		end
		for i, block in ipairs(blocks) do
			block.y = ascent - (block.f_baseline - block.f_ascent) * block.f_sy
		end

	elseif v_align == "descent" then
		local descent = -math.huge
		for i, block in ipairs(blocks) do
			descent = math.max(descent, (block.f_baseline - block.f_descent) * block.f_sy)
		end
		for i, block in ipairs(blocks) do
			block.y = descent - (block.f_baseline - block.f_descent) * block.f_sy
		end

	elseif v_align == "baseline" then
		local baseline = -math.huge
		for i, block in ipairs(blocks) do
			baseline = math.max(baseline, block.f_baseline * block.f_sy)
		end
		for i, block in ipairs(blocks) do
			block.y = baseline - block.f_baseline * block.f_sy
		end

	elseif v_align == "bottom" then
		local bottom = -math.huge
		for i, block in ipairs(blocks) do
			bottom = math.max(bottom, block.f_height * block.f_sy)
		end
		for i, block in ipairs(blocks) do
			block.y = bottom - block.f_height * block.f_sy
		end

	else
		error("unknown vertical align setting: " .. tostring(v_align))
	end
end


return aligner
