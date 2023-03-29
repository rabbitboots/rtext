-- Auxiliary color functions.
-- Version: 1.0.1 (2023-MAR-25)


local auxColor = {}


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


--[[
CHANGELOG
1.0.1 (2023-MAR-25)
* (This version is functionally identical to 1.0.0.)

* Added, then removed internal Lua gammaToLinear and linearToGamma functions. In
  a test of creating one million tables of gamma-corrected numbers, the Lua
  functions were not competitive with the implementations in love.math (with JIT
  on or off).

* Added note about toggling JIT (don't do it after love.conf() under normal
  circumstances).


1.0.0 (2023-MAR-24)
* First numbered version (not yet publicly released).
--]]


--[[
Get: Returns the mix of two colors.
Mix: Applies the mix of two colors with love.graphics.setColor().

V: Variables (R, G, B, A)
T: Table ({1, 1, 1, 1})

Corrected: Apply gamma correction (gamma-to-linear -> mix -> linear-to-gamma)
Uncorrected: Do not apply gamma correction

The following are set at the end of the source file depending on LÖVE's
gamma correct state:

auxColor.getVV
auxColor.mixVV
auxColor.getVT
auxColor.mixVT
auxColor.getTT
auxColor.mixTT
--]]


-- If you monkey-patch these functions, either do so before loading this source file,
-- or replace the calls to these locals with the full 'love.*' function paths. Also,
-- avoid toggling JIT compilation anytime after conf.lua, as LÖVE swaps in different
-- implementations depending on `jit.status()`.
local _gammaToLinear = love.math.gammaToLinear
local _linearToGamma = love.math.linearToGamma
local _setColor = love.graphics.setColor


function auxColor.getVVUncorrected(ra, ga, ba, aa, rb, gb, bb, ab)
	return ra*rb, ga*gb, ba*bb, aa*ab
end


function auxColor.mixVVUncorrected(ra, ga, ba, aa, rb, gb, bb, ab)
	_setColor(ra*rb, ga*gb, ba*bb, aa*ab)
end


function auxColor.getVVCorrected(ra, ga, ba, aa, rb, gb, bb, ab)

	ra, ga, ba = _gammaToLinear(ra, ga, ba)
	rb, gb, bb = _gammaToLinear(rb, gb, bb)

	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, aa*ab

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	return ra, ga, ba, aa
end


function auxColor.mixVVCorrected(ra, ga, ba, aa, rb, gb, bb, ab)

	ra, ga, ba = _gammaToLinear(ra, ga, ba)
	rb, gb, bb = _gammaToLinear(rb, gb, bb)

	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, aa*ab

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	_setColor(ra, ga, ba, aa)
end


function auxColor.getVTUncorrected(ra, ga, ba, aa, tb)
	return ra*tb[1], ga*tb[2], ba*tb[3], aa*tb[4]
end


function auxColor.mixVTUncorrected(ra, ga, ba, aa, tb)
	_setColor(ra*tb[1], ga*tb[2], ba*tb[3], aa*tb[4])
end


function auxColor.getVTCorrected(ra, ga, ba, aa, tb)

	ra, ga, ba = _gammaToLinear(ra, ga, ba)
	local rb, gb, bb = _gammaToLinear(tb)

	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, aa*tb[4]

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	return ra, ga, ba, aa
end


function auxColor.mixVTCorrected(ra, ga, ba, aa, tb)

	ra, ga, ba = _gammaToLinear(ra, ga, ba)
	local rb, gb, bb = _gammaToLinear(tb)

	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, aa*tb[4]

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	_setColor(ra, ga, ba, aa)
end


function auxColor.getTTUncorrected(ta, tb)
	return ta[1]*tb[1], ta[2]*tb[2], ta[3]*tb[3], ta[4]*tb[4]
end


function auxColor.mixTTUncorrected(ta, tb)
	_setColor(ta[1]*tb[1], ta[2]*tb[2], ta[3]*tb[3], ta[4]*tb[4])
end


function auxColor.getTTCorrected(ta, tb)

	local ra, ga, ba = _gammaToLinear(ta)
	local rb, gb, bb = _gammaToLinear(tb)

	local aa
	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, ta[4]*tb[4]

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	return ra, ga, ba, aa
end


function auxColor.mixTTCorrected(ta, tb)

	local ra, ga, ba = _gammaToLinear(ta)
	local rb, gb, bb = _gammaToLinear(tb)

	local aa
	ra, ga, ba, aa = ra*rb, ga*gb, ba*bb, ta[4]*tb[4]

	ra, ga, ba = _linearToGamma(ra, ga, ba)

	_setColor(ra, ga, ba, aa)
end


-- Init module.


if love.graphics.isGammaCorrect() then

	auxColor.getVV = auxColor.getVVCorrected
	auxColor.mixVV = auxColor.mixVVCorrected

	auxColor.getVT = auxColor.getVTCorrected
	auxColor.mixVT = auxColor.mixVTCorrected

	auxColor.getTT = auxColor.getTTCorrected
	auxColor.mixTT = auxColor.mixTTCorrected

else
	auxColor.getVV = auxColor.getVVUncorrected
	auxColor.mixVV = auxColor.mixVVUncorrected

	auxColor.getVT = auxColor.getVTUncorrected
	auxColor.mixVT = auxColor.mixVTUncorrected

	auxColor.getTT = auxColor.getTTUncorrected
	auxColor.mixTT = auxColor.mixTTUncorrected
end


return auxColor
