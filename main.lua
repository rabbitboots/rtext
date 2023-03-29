-- RText demo and test launcher.

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
Usage:

To launch the main demo, just run:
	`love .`

To run other demos and tests:

In LÖVE 11.x:
	`love . demo_bare_minimum`

(Note the dot, and the lack of a '.lua' extension on the end.)

In LÖVE 12, you can just call the .lua file directly:
	`love demo_bare_minimum.lua`
--]]


-- Debug helper stuff
--[[
local _print = print
print = function(...)
	_print(...)
	_print(debug.traceback())
end
--]]

function love.load(arguments)

	local demo_id = arguments[1] or "demo"

	require(demo_id)
end
