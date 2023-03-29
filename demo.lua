-- Main RText demo.

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


-- A very basic scaling system. Adjust this and the starting window dimensions in conf.lua until the
-- text is reasonably sized for your display. (Some things aren't scaling correctly, but it should
-- cover 99% of the demo.)
local DEMO_SCALE = 1.0
local function SCALE(v)
	return math.floor(v*DEMO_SCALE + 0.5)
end
local function FSCALE(v)
	return v*DEMO_SCALE
end


local demo_background_tint = {0.20, 0.20, 0.20, 1.00}
local demo_text_tint       = {1.00, 1.00, 1.00, 1.00}


love.keyboard.setKeyRepeat(true)


-- LÖVE Auxiliary
local utf8 = require("utf8")


-- Demo Lib
local inspect = require("demo_lib.inspect.inspect")
local quickPrint = require("demo_lib.quick_print.quick_print")
local strict = require("demo_lib.strict")

-- RText
local auxiliary = require("rtext.auxiliary")
local textBlock = require("rtext.text_block")
local media = require("rtext.media")
local rtext = require("rtext.rtext")



-- Helps to draw the demo's information panel.
local qp = quickPrint.new()


local demo_font = love.graphics.newFont("demo_res/truetype/NotoSansMono-Regular.ttf", SCALE(15))


local demo_doc_wrap_w = math.floor(love.graphics.getWidth() * 0.8 + 0.5)
local demo_doc_x = math.floor(0.5 + love.graphics.getWidth() / 2 - demo_doc_wrap_w / 2)

-- Holds results of getBoundingBox()
local demo_doc_x1 = 0
local demo_doc_y1 = 0
local demo_doc_x2 = 0
local demo_doc_y2 = 0


local demo_scroll_y = 0
local demo_align = "left"
local demo_align_justify_last = false -- controls justify alignment of the last line of a paragraph
local demo_v_align = "top"
local demo_debug_render = false

local mouse_focus = false

-- Only valid when mouse_focus is true
local mouse_x = 0
local mouse_y = 0
local hover_para = false
local hover_line = false
local hover_block = false


local samples = {}
local sample_i = 1
local document -- This demo has one active document instance at a time.


-- Basic tests of line-breaking and word-breaking.
--[=[
table.insert(samples, {
	text = "A B C D E F G",
})
table.insert(samples, {
	text = "ABC DEF GHI",
})

table.insert(samples, {
	text = 
		"1 2 3 4 5 6 7 8 9 10 11 12 13 14 15\n" ..
		"16 17 18 19 20 21 22 23 24 25 26 27 28 29 30\n" ..
		"31 32 33 34 35 36 37 38 39 40 41 42 43 44 45\n" ..
		"46 47 48 49 50 51 52 53 54 55 56 57 58 59 60\n" ..
		"61 62 63 64 65 66 67 68 69 70 71 72 73 74 75\n" ..
		"76 77 78 79 80 81 82 83 84 85 86 87 88 89 90\n",
})

table.insert(samples, {
	text = "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 ",
})
--]=]


-- Testing inconsistent kerning applied when breaking long words
--[=[
table.insert(samples, {
	text = "[font vera]AV A[ul]V[/ul]L[color blue]T[/color]L[color blue]T"),
})
--]=]


--[=[
table.insert(samples, {
	text =
		"[b]Breaking whitespace[/b]\n\n" ..

		"U+0009 ASCII tab |" .. utf8.char(0x0009) .. "|\n" ..
		"U+000A [s]ASCII line feed[/s] (\\n is parsed out)\n" ..
		"U+000B ASCII vertical tab |" .. utf8.char(0x000b) .. "|\n" ..
		"U+000C ASCII form feed |" .. utf8.char(0x000c) .. "|\n" ..
		"U+000D ASCII carriage return |" .. utf8.char(0x000d) .. "|\n" ..
		"U+0020 ASCII space |" .. utf8.char(0x0020) .. "|\n" ..
		"U+1680 Ogham space mark |" .. utf8.char(0x1680) .. "|\n" ..
		"U+2000 En quad |" .. utf8.char(0x2000) .. "|\n" ..
		"U+2001 Em quad |" .. utf8.char(0x2001) .. "|\n" ..
		"U+2002 En space |" .. utf8.char(0x2002) .. "|\n" ..
		"U+2003 Em space |" .. utf8.char(0x2003) .. "|\n" ..
		"U+2004 Three-per-em space |" .. utf8.char(0x2004) .. "|\n" ..
		"U+2005 Four-per-em space |" .. utf8.char(0x2005) .. "|\n" ..
		"U+2006 Six-per-em space |" .. utf8.char(0x2006) .. "|\n" ..
		"U+2008 Punctuation space |" .. utf8.char(0x2008) .. "|\n" ..
		"U+2009 Thin space |" .. utf8.char(0x2009) .. "|\n" ..
		"U+200A Hair space |" .. utf8.char(0x200a) .. "|\n" ..
		"U+200B Zero width space |" .. utf8.char(0x200b) .. "|\n" ..
		"U+2028 Line separator |" .. utf8.char(0x2028) .. "|\n" ..
		"U+205F Medium mathematical space |" .. utf8.char(0x205f) .. "|\n" ..
		"U+3000 Ideographic space |" .. utf8.char(0x3000) .. "|\n" ..

		"\n\n[b]Non-breaking whitespace[/b]" ..

		"U+00A0 Non-breaking space |" .. utf8.char(0x00a0) .. "|\n" ..
		"U+2007 Figure space |" .. utf8.char(0x2007) .. "|\n" ..
		"U+202F Narrow no-break space |" .. utf8.char(0x202f) .. "|\n" ..
		"U+2060 Word joiner |" .. utf8.char(0x2060) .. "|\n" ..
		"U+FEFF Byte order mark |" .. utf8.char(0xfeff) .. "|\n" ..

		"",
})
--]=]


--[=[
table.insert(samples, {
	text =
		"All breaking whitespace (except \\n) in the same run:\n\n" ..
		"Foo" ..
		utf8.char(
			0x0009, 0x000b, 0x000c, 0x000d,
			0x0020, 0x1680, 0x2000, 0x2001,
			0x2002, 0x2003, 0x2004, 0x2005,
			0x2006, 0x2008, 0x2009, 0x200a,
			0x200b, 0x2028, 0x205f, 0x3000
		)
		.. "Bar"
})
--]=]


--[=[
table.insert(samples, {
	text = [[
Horizontal Alignment test (left, center, right, justify)

[align left]The five boxing wizards jump quickly.

[align center]The five boxing wizards jump quickly.

[align right]The five boxing wizards jump quickly.

[align justify]The five boxing wizards jump quickly.]],
})
--]=]


table.insert(samples, {
	text = [[
[align center][b]Demo[/b]

[*][i]Left mouse button[/i]: Move document left position

[*][i]Right mouse button[/i]: Resize document wrap-limit

[*][i]Key left/right[/i]: Step through sample documents

[*][i]Key up/down and pageup/pagedown[/i]: Scroll

[*][i]Key tab[/i]: toggle debug rendering

[*][i]Key 0[/i]: toggle VSync

[*][i]Space[/i]: zoom out

[*][i]Key escape[/i]: Quit]],
})


table.insert(samples, {
	text = [[
Arbitrary text colors: [color red]One [color green]Two [color blue]Three

Faces: Regular, [b]Bold[/b], [i]Italic[/i], [b][i]Bold-Italic[/b][/i].

Superscript: y = x[font sup]2[/font] + 1

Subscript: Foo[font sub]bar.[/font]

Shapes: [ul]Underline[/ul], [s]Strikethrough[/s], [bg gray][color black]Background[/color][/bg]

Horizontal separator:

[para aux_hori_sep]

[para h1]HEADING

List Items:
[*]Bang
[**]Bam

Alignment: (left, right, center, justify)
[align left]The five boxing wizards jump quickly.

[align center]The five boxing wizards jump quickly.

[align right]The five boxing wizards jump quickly.

[align justify]We need an extra long bunch of text for justify to actually show up okay there we go]]
,
})


table.insert(samples, {
	text = "Test BMFont.\n[font bmf02]BMF Number Two",
})


table.insert(samples, {
	text = "SDF BMFont test (font size 32, scaled x" .. SCALE(3) .. ")\n"
	.. "\n"
	.. "[font bmf01]Signed,\n"
	.. "[font bmf01]Distance\n"
	.. "[font bmf01]Field.\n",
})



table.insert(samples, {
	text = "Test textures embedded into the text flow (via arbitrary blocks).\n\n"
	.. "[align center][valign middle][color red]"
	.. "[img pumpkin]Furious"
	.. "[img pumpkin]Pumpkin"
	.. "[img pumpkin]Screams"
	.. "[img pumpkin]Forever"
	.. "[img pumpkin]"
	,
})


table.insert(samples, {
	text = [[
Test ImageFont symbols.

Press [font gamebuttons]A[/font] to continue.

Press [font gamebuttons]Z[/font] to go back.

Press [font gamebuttons]A[/font] and [font gamebuttons]Z[/font] simultaneously to continue and go back.]],
})



table.insert(samples, {
	text = [[
Test image paragraph style: left, right, center + unaccompanied


[p-img catboat]Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz.

[p-img catboat right]Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz. Abcdefg. Hijklmnop. Qrstuv. Wxyz.

[p-img catboat left 0.5 0.5]
]],
})


table.insert(samples, {
	text = [[
Test ImageFont and scaling.

[font db437]COUNT DORKULA EMERGES FROM FORTRESS DORKASTLE AND SURVEYS HIS REALM OF DORKERY.
[font db437]
[font db437]...
[font db437]
[para db_coarse][align justify]Test the j_x_step setting with justified text. The glyphs in this paragraph should have a "coarse" granularity when spaced out by the justify algorithm.
[font db437]
[font db437][align justify]This paragraph, however, should resize smoothly as the wrap-limit is adjusted.
]],
})


table.insert(samples, {
	block_granularity = "cluster",
	update_document = true,
	-- https://www.gutenberg.org/ebooks/1063
	text = [[Test "cluster" block granularity and Transform + Color parameter animations.

[font anim]The wine sparkled in his eyes and the bells jingled. My own fancy grew warm with the Medoc. We had passed through walls of piled bones, with casks and puncheons intermingling, into the inmost recesses of catacombs. I paused again, and this time I made bold to seize Fortunato by an arm above the elbow.]],
})


table.insert(samples, {
	text = [[
Test paragraph and document render callbacks.

[para warning_box][color black]The following procedure is dangerous. Exercise the utmost caution when performing the following procedure. Do not question the following procedure. Follow the following procedure.
]],
})


table.insert(samples, {
	text = [[
Test escaping tag open and close patterns.

[t1]brackets[t2]

[t1]t1[t2] [t1]t2[t2]


Test invalid and malformed tags: (they should both be injected as text)

[not_a_real_tag]

[tag_missing_close_pattern

Only one paragraph-style setting per paragraph.

[para h1][para db_coarse]Foobar

Paragraph-style tag must appear before any text content in a paragraph, including whitespace.

 [para h1]Foobar

Test Paragraph Style tag followed by Word Style tag. The latter should override some aspects of the former.

[para h1][i][ul green]I should be italicized and have a green underline.
]],
})


table.insert(samples, {
	text = [[
Test arbitrary per-paragraph indents.

(Note the mess when narrow wrap-limits are applied.)

None.
[indent]One. One. One. One. One.
[indent 2]Two. Two. Two. Two. Two.
[indent 3]Three. Three. Three. Three.
[indent 4]Four. Four. Four. Four. Four.
[indent 5]Five. Five. Five. Five. Five.
[indent 4]Four. Four. Four. Four. Four.
[indent 3]Three. Three. Three. Three.
[indent 2]Two. Two. Two. Two. Two.
[indent 1]One. One. One. One. One.
None.]],
})


table.insert(samples, {
	text = "Test arbitrary indents with non-breaking line feeds.\n\n"
		.. "None.[br]"
		.. "[indent]One. One. One. One. One. One.[br]"
		.. "[indent 2]Two. Two. Two. Two. Two.[br]"
		.. "[indent 3]Three. Three. Three. Three.[br]"
		.. "[indent 4]Four. Four. Four. Four.[br]"
		.. "[indent 5]Five. Five. Five. Five.[br]"
		.. "[indent 4]Four. Four. Four. Four.[br]"
		.. "[indent 3]Three. Three. Three. Three.[br]"
		.. "[indent 2]Two. Two. Two. Two. Two.[br]"
		.. "[indent 1]One. One. One. One. One.[br]"
		.. "[indent 0]None. None. None. None.",
})


--Non-paragraph-breaking line feed
table.insert(samples, {
	text = [[
Test non-breaking line feed

123[br]456[br 2]boop.
]],
})


table.insert(samples, {
	text = [[
Test built-in bullet point paragraph style.

[para aux_bullet1]Bang.
[*]Bam.
[**]Bag.

[n 1.]Number.
[nn i.]Roman.
[nnn X]Bar.]],
})
--[para aux_num_list1 1]Can't use the 'para' tag for numbered lists.


table.insert(samples, {
	text = "Test word style.\n\nDefault style. [style test_bold]Test bold style.\nThe style resets on the next paragraph.",
})


table.insert(samples, {
	text = [[
Vertical Alignment test (top, ascent, middle, baseline, descent, bottom)
[i]('baseline' is usually the desired vertical alignment.)[/i]

[valign top][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](top)

[valign ascent][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](ascent)

[valign middle][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](middle)

[valign baseline][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](baseline)

[valign descent][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](descent)

[valign bottom][font small]abcdefg[font norm]hijklmnop[font big]qrstuv[font norm]wxyz.,/!@#$%^&*_+| [font small](bottom)]],
})


table.insert(samples, {
	text = [[
Formatting test (regular, bold, bold-italic, mixed)

"Allow me to interject."

[i]"Allow me to interject."[/i]

[b]"Allow me to interject."[/b]

[b][i]"Allow me to interject."[/i][/b]

"[i]Allow[/i] [b]me[/b] to [b][i]interject.[/i][/b]"]],
})


table.insert(samples, {
	text = [=[
Text color and hard-coded shapes

[color red]Red [color green]Green [color blue]Blue[/color]

[bg gray][color black]Black text on gray background[/color][/bg]

Underlines: [ul red]With custom color[/ul]; [ul]With text color[/ul]

Strikethrough: [s cyan]With custom color[/s]; [s]With text color[/s]

[bg gray][s white][ul red][color black]REDACTED[/color][/ul][/s][/bg]]=],
})


table.insert(samples, {
	text = "Test wrap-breaking large words:\n\nJACKDAWSLOVEMYBIGSPHINXOFQUARTZTHEQUICKBROWNFOXJUMPSOVERTHELAZYDOGTHEFIVEBOXINGWIZARDSJUMPQUICKLY",
})

local str_aaa = "A[i]A[b]A[/i]A[/b]"
table.insert(samples, {
	text = "Break large words composed of multiple blocks:\n\n" .. string.rep(str_aaa, 12),
})

table.insert(samples, {
	limit_draw_range = true,
	text = [[
Large Document with a partial rendering range. (Hold Space to zoom out and see the range limit.)

[align center][i]https://www.lipsum.com/[/i]

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam iaculis mollis mi, pharetra hendrerit tellus tempor sed. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin sapien libero, scelerisque vitae felis vitae, porttitor congue turpis. Proin eget purus nec velit vestibulum dictum eget eu nulla. Sed ullamcorper dolor non felis auctor dignissim. Praesent aliquam, ante ut dictum blandit, dolor risus eleifend nunc, vitae porttitor tortor arcu et diam. Fusce viverra mi nec tortor faucibus dignissim. Mauris facilisis turpis vel lorem finibus faucibus. Maecenas consectetur tincidunt rhoncus. Nulla eu ante ligula. Cras cursus lobortis mollis. Sed vitae dui blandit, cursus dui et, commodo lacus. Vivamus tempor mauris ac enim viverra, nec fringilla odio rutrum. Suspendisse potenti. Cras vel ex tincidunt, accumsan nibh eget, pharetra tellus. Mauris laoreet arcu risus, et aliquet velit volutpat a.

Donec tincidunt rhoncus risus, a vulputate tellus laoreet eget. Donec sodales justo sed gravida porttitor. Etiam tempor laoreet magna, nec venenatis libero bibendum non. Fusce a libero nisl. Suspendisse volutpat tellus sed iaculis rhoncus. Integer pulvinar posuere mauris. Quisque egestas, ipsum ultricies euismod elementum, enim tortor malesuada magna, sed tempor arcu neque sed mi. Curabitur lacinia metus nibh, vel volutpat velit euismod at. Nulla gravida nulla ac nunc euismod, varius eleifend erat lobortis. Aenean vel lacinia ante. In condimentum lectus nec nunc sagittis congue. Integer rutrum justo metus, at placerat enim consequat eu. Integer auctor nunc ut gravida aliquam. Mauris orci mi, gravida a finibus vel, eleifend ut neque. Fusce a varius nulla. Aenean sit amet accumsan nunc.

Sed vel est quis neque facilisis bibendum eu pharetra lacus. Donec eget elementum leo, sit amet mattis ipsum. Curabitur consequat sapien id lorem porttitor, eget imperdiet mi imperdiet. Aenean faucibus finibus elit non mattis. Cras molestie vehicula ipsum id sollicitudin. Quisque a tincidunt lorem. Aenean eget feugiat purus. Sed ullamcorper mauris quis ante finibus, a vulputate massa tristique. Suspendisse viverra sollicitudin commodo. Fusce eu ligula ultrices dolor dignissim gravida vel id augue. Integer vitae erat a leo convallis placerat eu egestas dolor. Quisque aliquam, nunc a egestas blandit, ante leo efficitur ante, quis ornare velit nisl vitae metus. In at justo vitae nibh condimentum lacinia nec nec sem. Nulla purus libero, malesuada et enim quis, laoreet egestas dolor.

Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Donec in efficitur mauris. Proin ipsum massa, tempor id consequat ut, luctus sit amet urna. Interdum et malesuada fames ac ante ipsum primis in faucibus. Ut at elit ut magna blandit varius et at nulla. Pellentesque volutpat lacus et ipsum ullamcorper malesuada. Proin nec feugiat orci. Suspendisse potenti. Nulla pharetra lacinia dolor ac sodales. Praesent laoreet tempus urna interdum pellentesque.

Fusce posuere metus at mi commodo, eget gravida ex convallis. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean eu est eu risus malesuada sodales sit amet dapibus ligula. Ut egestas mi ac ex iaculis luctus et sit amet tellus. Etiam vulputate tellus vitae bibendum hendrerit. Mauris ullamcorper, neque in tempor volutpat, eros dui interdum dui, et lobortis velit risus eu dui. Etiam at mauris augue.

Donec vulputate luctus felis, vel tristique lorem. Aenean eget leo vehicula, gravida nulla ullamcorper, ornare ligula. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam volutpat magna pellentesque lectus fermentum consequat in sit amet nunc. Vivamus pulvinar efficitur eros non sollicitudin. Cras tempus quam ut dui rhoncus euismod. Sed id posuere velit. Aenean viverra accumsan tincidunt. Nulla dignissim, massa id tempor scelerisque, purus tortor lacinia purus, eget elementum tellus nulla vel leo. Nam scelerisque rutrum lectus, vehicula feugiat massa ultrices quis. Lorem ipsum dolor sit amet, consectetur adipiscing elit.

Integer facilisis vestibulum facilisis. Curabitur varius arcu et commodo porttitor. Proin a odio sit amet lorem congue lobortis ac et arcu. Phasellus hendrerit hendrerit vulputate. Nullam risus libero, dapibus eget odio ut, varius commodo mi. Praesent pretium nec libero in consequat. Praesent in porta metus, nec volutpat neque. Proin in condimentum mi. Maecenas luctus orci nec tortor viverra pharetra. Aenean ut risus sapien.

Morbi posuere est justo, id tempus erat consequat vitae. Maecenas luctus tristique nisl, et vulputate purus tempor id. Pellentesque pretium lobortis sem, non fringilla mi pretium rutrum. Aliquam convallis volutpat orci, vitae pulvinar lorem porttitor a. In fermentum enim vitae urna sollicitudin maximus. Donec facilisis sodales condimentum. Nam a tortor lorem.

Proin vulputate dictum enim ac bibendum. Suspendisse ultricies magna purus, ac placerat lacus lacinia porttitor. Nulla facilisi. Aliquam tempus urna non diam auctor pulvinar. Cras quis porta arcu. Integer vitae magna fringilla, ullamcorper neque ut, luctus tellus. Nulla elementum lacus sed tempus blandit. Proin faucibus at dui vel pretium. Nullam viverra elit eget enim auctor, a gravida velit pulvinar. Sed vulputate eu eros sit amet iaculis.

Cras sagittis semper ipsum eget cursus. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean nec quam vulputate lacus porttitor fringilla. Cras in faucibus leo, vitae pharetra nisl. Etiam pulvinar finibus bibendum. Nam sodales finibus dolor, sit amet suscipit nibh placerat in. Nam rutrum varius iaculis. Suspendisse vitae magna at nibh hendrerit porta. Praesent vel ante in neque blandit luctus a et urna. Ut magna nisi, convallis ut ipsum eget, ullamcorper gravida felis. Suspendisse blandit lorem tristique sem efficitur cursus.

Pellentesque nec arcu ligula. Cras leo diam, vehicula non bibendum ac, semper posuere nibh. Interdum et malesuada fames ac ante ipsum primis in faucibus. Aenean lacinia volutpat tincidunt. Fusce vitae turpis luctus, varius mi ac, congue risus. Suspendisse non condimentum neque. Nullam nec risus venenatis, tempus enim a, tincidunt sem. Duis aliquam nunc vitae tempor gravida.

Maecenas in molestie massa. Donec vulputate arcu sed tellus semper, at dignissim ipsum efficitur. Nam laoreet dui ornare odio pulvinar condimentum. Etiam quis sodales tortor. Mauris auctor pharetra velit, eget pretium lorem fermentum in. Ut consectetur, augue et ultricies congue, arcu libero suscipit ex, eu euismod elit magna at diam. Nulla pulvinar dolor eget massa malesuada egestas. Quisque semper, quam commodo luctus ultricies, magna elit bibendum leo, vel luctus risus arcu volutpat sem. Nam at ultrices tellus. Praesent vitae aliquam augue. Maecenas condimentum non ex et pharetra. Suspendisse potenti. Praesent vel nisi nulla. Nulla blandit venenatis tristique. In feugiat justo sed leo mollis, quis malesuada augue placerat. Fusce gravida massa eu elit semper, ac lacinia turpis iaculis.

Fusce pulvinar, ligula vitae finibus tincidunt, lacus magna pretium libero, ut malesuada magna ex sit amet ligula. Quisque venenatis mi quis urna rhoncus molestie. Sed a finibus ligula, non pharetra velit. Curabitur ligula felis, condimentum eget lobortis non, ultricies ut urna. Vivamus et felis eu leo luctus congue. Cras sed augue bibendum libero rutrum luctus id ac lorem. Nunc quam velit, pulvinar sit amet pretium vitae, semper a tortor. Fusce vulputate consectetur hendrerit. Aliquam imperdiet tortor eget mollis egestas. Quisque sem erat, pulvinar at venenatis dignissim, tempus sed purus. Praesent et accumsan tortor, ut consectetur enim. Aliquam facilisis sapien at mi tempor convallis. Vestibulum pretium a elit pulvinar accumsan. Nulla viverra fermentum auctor.

Mauris fermentum velit vel urna euismod malesuada. Nullam dignissim, quam a pellentesque egestas, nulla ligula accumsan elit, ac consectetur diam lorem at mauris. Nunc suscipit velit ligula, posuere pretium felis tincidunt non. Ut vehicula lobortis finibus. Nam arcu ante, hendrerit sit amet ante eget, dictum egestas sapien. Sed aliquam leo et enim pretium, sit amet aliquam sapien fringilla. Praesent quis vulputate nibh. Nullam eget libero in nunc interdum ornare sed sit amet metus. Curabitur ipsum nisi, facilisis nec mi vitae, venenatis ullamcorper ligula. Quisque mattis, turpis quis dictum cursus, odio dui fringilla purus, ac feugiat nunc leo id nulla. Cras congue lectus ut enim aliquam, et malesuada mauris posuere. Donec sed purus nisl.

Sed mattis magna justo, at lobortis nunc facilisis sed. Donec a hendrerit nisi. In hac habitasse platea dictumst. Donec id est gravida, ullamcorper mi quis, ornare magna. Curabitur quis velit id nisi tristique fermentum. Sed dignissim elementum molestie. Integer a eros condimentum quam pulvinar condimentum. Quisque congue hendrerit metus non condimentum. Etiam fermentum mi tortor, vel ultrices purus elementum at. Donec scelerisque est tempus sapien posuere, id placerat leo feugiat. Aliquam a nisi velit. Proin tincidunt accumsan porttitor. Curabitur laoreet lorem ipsum. Nam pharetra est vitae tempus feugiat. Aenean id tempor mauris, sit amet vulputate est.

Suspendisse potenti. Curabitur suscipit molestie ex, vitae semper lectus tincidunt et. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Donec sollicitudin, massa eu vehicula tincidunt, nulla tortor porta ante, vel ornare turpis elit et orci. Duis volutpat convallis diam, sed hendrerit lacus maximus in. Donec pretium eros neque, nec finibus nunc tincidunt ut. Vivamus velit diam, lacinia ut accumsan non, lacinia quis libero. Aenean quis diam at dui cursus mollis vel eu ligula. Maecenas id sapien magna. Etiam dapibus enim sit amet neque egestas cursus. Sed at augue tincidunt, pulvinar mi sit amet, mattis nulla.

Nunc justo mauris, ornare eu magna nec, scelerisque varius nunc. In a quam vel leo maximus aliquam vel eget tellus. Duis tincidunt pellentesque dignissim. Sed nec ex ut elit euismod laoreet. Nam lobortis neque justo, convallis pellentesque libero ullamcorper vitae. Phasellus eget odio nunc. Morbi ac convallis lacus. Sed maximus neque eget sapien mollis feugiat. In egestas ac felis eu tempor. Phasellus at tincidunt mauris, ut cursus erat. Nunc vitae aliquam ligula, lacinia gravida lacus. Interdum et malesuada fames ac ante ipsum primis in faucibus. Integer hendrerit dapibus diam id tristique. Nunc auctor augue ac elementum luctus. Donec odio tellus, consectetur eget turpis in, condimentum elementum turpis. Pellentesque ultrices felis id justo rhoncus, ut volutpat magna tempus.

Curabitur iaculis in odio in molestie. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Pellentesque fringilla, justo eget laoreet commodo, eros mauris dignissim ligula, vitae aliquam quam nisl quis urna. Sed ac lobortis nisi. Pellentesque quis tortor vel diam tincidunt viverra eget at tortor. Mauris aliquam dignissim enim id gravida. Cras tempus finibus mi, id rutrum diam laoreet sed. Donec enim turpis, vulputate eu diam vitae, pretium efficitur nibh. Suspendisse ullamcorper gravida pulvinar. Maecenas condimentum leo eget tortor consectetur mollis. Nunc ultrices, enim a pharetra scelerisque, mi dui facilisis ligula, sit amet ultrices sapien est nec neque. Interdum et malesuada fames ac ante ipsum primis in faucibus. Praesent eu egestas ligula.

Cras mattis in augue eget auctor. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Maecenas a diam augue. Donec ut dolor quam. Suspendisse et dolor dapibus nisi dictum volutpat quis ac purus. Quisque efficitur gravida tincidunt. Cras tristique sodales tincidunt. Donec vitae facilisis nibh. Donec ac consectetur libero. Interdum et malesuada fames ac ante ipsum primis in faucibus. In sed vestibulum elit. Vivamus eget aliquet nisl. Suspendisse et nisl interdum, pulvinar nisi quis, molestie enim. Praesent nisi ipsum, fringilla pretium sodales ultricies, volutpat eu libero. Nullam dictum malesuada diam eget maximus. Aenean gravida mi pulvinar enim sagittis, sit amet ornare orci interdum.

Nam bibendum enim ut nisl tristique, nec scelerisque nibh cursus. Fusce ut felis nisl. Donec ex odio, tincidunt elementum enim non, tempus luctus nisi. Duis iaculis egestas fringilla. Mauris elementum elit nibh, eu gravida dolor consectetur quis. Nullam porta enim vitae tellus pellentesque, finibus facilisis arcu mollis. Aliquam nec nisi ornare, sodales libero eget, varius sem. Curabitur vulputate luctus euismod. Praesent finibus a ipsum at aliquam. Duis diam dolor, maximus eget tortor quis, ultrices scelerisque eros. Duis ac massa dignissim, feugiat purus id, mattis nibh.
Generated 20 paragraphs, 1886 words, 12804 bytes of Lorem Ipsum]],
})


-- RText instance setup.
local rt
do
	-- Font-group tables and colors accessible by string ID

	local colors = {
		red = {1, 0, 0, 1},
		green = {0, 1, 0, 1},
		blue = {0, 0, 1, 1},
		magenta = {1, 0, 1, 1},
		cyan = {0, 1, 1, 1},
		yellow = {1, 1, 0, 1},
		black = {0, 0, 0, 1},
		gray = {127/255, 127/255, 127/255, 1},
		white = {1, 1, 1, 1},
	}

	-- Font face tables (determines which Block Style IDs represent bold, italic, etc.)
	local font_groups = {

		small = rtext.newFontGroup(
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Regular.ttf", SCALE(12))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Bold.ttf", SCALE(12))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Italic.ttf", SCALE(12))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-BoldItalic.ttf", SCALE(12)))
		),
		norm = rtext.newFontGroup(
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Regular.ttf", SCALE(16))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Bold.ttf", SCALE(16))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Italic.ttf", SCALE(16))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-BoldItalic.ttf", SCALE(16)))
		),
		big = rtext.newFontGroup(
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Regular.ttf", SCALE(24))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Bold.ttf", SCALE(24))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Italic.ttf", SCALE(24))),
			textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-BoldItalic.ttf", SCALE(24)))
		),
	}

	font_groups.sup = rtext.newFontGroup(
		textBlock.newBlockStyle(font_groups.small[1].font),
		textBlock.newBlockStyle(font_groups.small[2].font),
		textBlock.newBlockStyle(font_groups.small[3].font),
		textBlock.newBlockStyle(font_groups.small[4].font)
	)
	font_groups.sub = rtext.newFontGroup(
		textBlock.newBlockStyle(font_groups.small[1].font),
		textBlock.newBlockStyle(font_groups.small[2].font),
		textBlock.newBlockStyle(font_groups.small[3].font),
		textBlock.newBlockStyle(font_groups.small[4].font)
	)
	-- [[
	for i, sup_inf in ipairs(font_groups.sup) do

		local font = sup_inf.font
		--sup_inf.f_oy = -math.floor(font:getBaseline() / 4 + 0.5)

		sup_inf.f_height = font_groups.norm[i].f_height
		sup_inf.f_baseline = font_groups.norm[i].f_baseline
		sup_inf.f_ascent = font_groups.norm[i].f_ascent
		sup_inf.f_descent = font_groups.norm[i].f_descent
	end
	-- [[
	for i, sub_inf in ipairs(font_groups.sub) do

		local font = sub_inf.font
		sub_inf.f_oy = font_groups.norm[i].f_height - math.floor(font:getHeight() * 0.75 + 0.5)

		sub_inf.f_height = font_groups.norm[i].f_height
		sub_inf.f_baseline = font_groups.norm[i].f_baseline
		sub_inf.f_ascent = font_groups.norm[i].f_ascent
		sub_inf.f_descent = font_groups.norm[i].f_descent
	end
	--]]

	local db_glyphs =
	 "☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼" ..
	" !\"#$%&'()*+,-./0123456789:;<=>?" ..
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_" ..
	"`abcdefghijklmnopqrstuvwxyz{|}~⌂" ..
	"ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒ" ..
	"áíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐" ..
	"└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀" ..
	"αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■"

	font_groups.db437 = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newImageFont("demo_res/image_font/dosbox_437.png", db_glyphs, 0))
	)
	local db_inf = font_groups.db437[1]
	db_inf.f_baseline = 10
	db_inf.f_ascent = 10
	db_inf.f_descent = 2
	db_inf.f_sx = FSCALE(2.0)
	db_inf.f_sy = FSCALE(2.0)

	db_inf.font:setFilter("nearest", "nearest")


	font_groups.gamebuttons = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newImageFont("demo_res/image_font/mock_gamepad_input.png", "AZ ", 0))
	)
	local gp_inf = font_groups.gamebuttons[1]
	gp_inf.f_sx = FSCALE(1.0)
	gp_inf.f_sy = FSCALE(1.0)
	gp_inf.f_baseline = 20
	gp_inf.f_ascent = 20
	gp_inf.f_descent = 2


	font_groups.vera = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/Vera.ttf", SCALE(64)))
	)

	font_groups.scaled = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Regular.ttf", SCALE(12))),
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Bold.ttf", SCALE(12))),
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Italic.ttf", SCALE(12))),
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-BoldItalic.ttf", SCALE(12)))
	)
	font_groups.scaled[1].f_sx = 2
	font_groups.scaled[1].f_sy = 2
	font_groups.scaled[2].f_sx = 2
	font_groups.scaled[2].f_sy = 2
	font_groups.scaled[3].f_sx = 2
	font_groups.scaled[3].f_sy = 2
	font_groups.scaled[4].f_sx = 2
	font_groups.scaled[4].f_sy = 2

	font_groups.anim = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/truetype/NotoSerif-Regular.ttf", SCALE(24)))
	)

	do
		-- This is not a very good animation example. You'd probably want something higher
		-- in the structure driving the updates. The point is just to show what you can do
		-- with individual Text Blocks.
		local anim = font_groups.anim[1]
		anim.d_sx = 0
		anim.cb_update = function(self, dt)
			self.d_x = math.floor(self.w / 2)
			self.d_y = math.floor(self.h / 2)
			self.d_ox = math.floor(self.w / 2)
			self.d_oy = math.floor(self.h / 2)

			self.temp = self.temp or 0
			self.temp = self.temp + dt
			self.d_sx = math.min(1, math.max(0, self.temp*20 - self.x/8))

			--self.d_r = math.cos(self.temp*2+self.x/64) * math.pi/8 -- nausea warning
			self.c_a = math.min(1, self.d_sx*2)

			self.c_g = 1.0 + math.cos(self.temp+self.x) / 2
			self.c_b = 1.0 + math.sin(self.temp+self.x) / 2

			self.d_y = math.floor(self.d_y + math.sin((self.temp+self.x/64)) * 12)
		end
	end

	-- I think the kerning might be off on this because of the BMfont generator I used.
	font_groups.bmf02 = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/bm_font/bmf02.fnt"))
	)
	-- This will lose quality when scaled up. Not much we can do about that.
	-- See the SDF BMFont below for an alternative...
	local bm2 = font_groups.bmf02[1]
	bm2.f_sx = SCALE(1)
	bm2.f_sy = SCALE(1)

	-- SDF test.
	-- This is a pretty basic implementation which performs shader switches and a uniform upload for
	-- every associated text block. It demonstrates that SDF integration into rtext is possible, but
	-- you might want want to write new drawing code that is more efficient.
	font_groups.bmf01 = rtext.newFontGroup(
		textBlock.newBlockStyle(love.graphics.newFont("demo_res/bm_font/bmf01.fnt"))
	)

	local shader_sdf = love.graphics.newShader("demo_res/shader/sdf.glsl")
	local bm_sdf = font_groups.bmf01[1]
	bm_sdf.f_sx = SCALE(3)
	bm_sdf.f_sy = SCALE(3)
	bm_sdf.renderText = function(self, x, y)

		local old_shader = love.graphics.getShader()
		love.graphics.setShader(shader_sdf)

		local spread = 2.0
		local scale = (self.f_sx + self.f_sy) * 0.5
		shader_sdf:send("smoothing", 0.25 / (spread * scale))
		-- I believe the scale here should also take LÖVE transform state scaling into account.
		-- It has been ommitted here to keep the demo simple.

		love.graphics.print(self.text, self.font, x, y, 0, self.f_sx, self.f_sy)

		love.graphics.setShader(old_shader)
	end

	local lst_default = rtext.newWrapLineStyle()
	local wst_norm = rtext.newWordStyle("norm")

	local wst_bold = rtext.newWordStyle("norm")
	wst_bold.bold = true
	wst_bold.color = {0.24, 0.24, 0.78, 1.0}

	local wst_header = rtext.newWordStyle("big")
	wst_header.bold = true
	wst_header.underline = true
	wst_header.color = colors.yellow
	wst_header.color_ul = colors.red

	local wst_437 = rtext.newWordStyle("db437")

	local word_styles = {
		test_bold = wst_bold,
		h1 = wst_header,
		dos = wst_437,
	}

	local pst_default = rtext.newParagraphStyle(wst_norm, lst_default)

	local pst_header = rtext.newParagraphStyle(wst_header, lst_default)
	pst_header.align = "center"

	local pst_bullet1 = auxiliary.makeBulletedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"•",
		SCALE(32),
		SCALE(14)
	)
	local pst_bullet2 = auxiliary.makeBulletedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"•",
		SCALE(64),
		SCALE(46)
	)
	local pst_bullet3 = auxiliary.makeBulletedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"•",
		SCALE(96),
		SCALE(78)
	)

	local pst_numList1 = auxiliary.makeNumberedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"?.",
		SCALE(32),
		SCALE(14)
	)
	local pst_numList2 = auxiliary.makeNumberedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"?.",
		SCALE(64),
		SCALE(46)
	)
	local pst_numList3 = auxiliary.makeNumberedListStyle(
		wst_norm,
		lst_default,
		love.graphics.newFont(SCALE(15)),
		"?.",
		SCALE(96),
		SCALE(78)
	)

	local pst_horiSep = auxiliary.makeHorizontalSeparatorStyle(
		wst_norm,
		lst_default,
		SCALE(1),
		"smooth",
		SCALE(32),
		SCALE(32)
	)
	local pst_img = auxiliary.makeImageStyle(wst_norm, lst_default)

	local warn_pad = SCALE(30)
	local half_pad = math.floor(warn_pad / 2 + 0.5)
	local pst_warn = rtext.newParagraphStyle(wst_norm, lst_default)
	--pst_warn.indent_x = warn_pad
	--pst_warn.ext_w = -warn_pad*2
	pst_warn.sp_top = warn_pad
	pst_warn.sp_bottom = warn_pad
	pst_warn.sp_left = warn_pad
	pst_warn.sp_right = warn_pad
	pst_warn.para_margin_left = warn_pad
	pst_warn.para_margin_right = warn_pad
	pst_warn.para_margin_top = warn_pad
	pst_warn.para_margin_bottom = warn_pad

	pst_warn.cb_drawFirst = function(self, x, y)

		love.graphics.push("all")

		local half_pad = math.floor(warn_pad / 2 + 0.5)

		love.graphics.setColor(0.7, 0.7, 0.3, 1.0)
		love.graphics.rectangle(
			"fill",
			x,
			y,
			self.w,
			self.h
		)

		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineWidth(2)
		love.graphics.rectangle(
			"line",
			x,
			y,
			self.w - 1,
			self.h - 1
		)

		--print(self.box_x, self.box_y, self.box_w, self.box_y)
		--[[
		love.graphics.rectangle("fill", x + half_pad, y, self.w - half_pad, self.h)
		love.graphics.rectangle("line", x + half_pad, y, self.w - half_pad - 1, self.h - 1)
		--]]

		love.graphics.pop()
	end

	local pst_db_coarse = rtext.newParagraphStyle(wst_437, lst_default)
	pst_db_coarse.j_x_step = font_groups.db437[1].font:getWidth("M") * font_groups.db437[1].f_sx

	local para_styles = {
		h1 = pst_header,

		aux_bullet1 = pst_bullet1,
		aux_bullet2 = pst_bullet2,
		aux_bullet3 = pst_bullet3,

		aux_num_list1 = pst_numList1,
		aux_num_list2 = pst_numList2,
		aux_num_list3 = pst_numList3,

		aux_hori_sep = pst_horiSep,

		warning_box = pst_warn,

		aux_image = pst_img,

		db_coarse = pst_db_coarse,
	}

	-- Auxiliary data table.
	local data = {}

	-- Used with [img]
	data.image_embed = {}
	local texture = love.graphics.newImage("demo_res/image/furious_pumpkin.png")
	texture:setFilter("nearest", "nearest")
	data.image_embed["pumpkin"] = auxiliary.imageEmbed_newDef(texture)
	local def_pump = data.image_embed["pumpkin"]
	local def_pump_style = def_pump.b_style

	def_pump_style.f_sx = FSCALE(1.0)
	def_pump_style.f_sy = FSCALE(1.0)
	def_pump_style.d_sx = FSCALE(1.0)
	def_pump_style.d_sy = FSCALE(1.0)


	-- Used with [p-img]
	data.image_para = {}
	local tex2 = love.graphics.newImage("demo_res/image/openclipart-cat-rowing-a-boat-337658_REDUCED.png")
	local p_img_def = auxiliary.imagePara_newDef(tex2)
	
	p_img_def.w = FSCALE(p_img_def.w)
	p_img_def.h = FSCALE(p_img_def.h)
	p_img_def.sx = FSCALE(1.0)
	p_img_def.sy = FSCALE(1.0)

	data.image_para["catboat"] = p_img_def
	local def_cat = data.image_para["catboat"]
	local def_cat_style = def_cat.b_style



	rt = rtext.newInstance(font_groups, "norm", colors, word_styles, para_styles, pst_default, data)

	rt.tag_defs["*"] = auxiliary.tagDef_bullet1
	rt.tag_defs["**"] = auxiliary.tagDef_bullet2
	rt.tag_defs["***"] = auxiliary.tagDef_bullet3

	rt.tag_defs["n"] = auxiliary.tagDef_numList1
	rt.tag_defs["nn"] = auxiliary.tagDef_numList2
	rt.tag_defs["nnn"] = auxiliary.tagDef_numList3

	rt.tag_defs["hr"] = auxiliary.tagDef_horiSep

	rt.tag_defs["img"] = auxiliary.imageEmbed_tagDef

	rt.tag_defs["p-img"] = auxiliary.imagePara_tagDef

	--rt:setBlockGranularity("cluster")
	--rt.bad_tag_error = true
end


local demo_block_gran = "word"
local demo_limit_draw_range = false
local demo_update_doc = false


local function setupDocument()

	sample_i = math.max(1, math.min(sample_i, #samples))

	local sample = samples[sample_i]

	demo_block_gran = sample.block_granularity or "word"
	demo_limit_draw_range = sample.limit_draw_range or false
	demo_update_doc = sample.update_document or false

	rt:setBlockGranularity(demo_block_gran)

	document = rt:makeDocument(samples[sample_i].text, demo_doc_wrap_w)
	demo_doc_x1, demo_doc_y1, demo_doc_x2, demo_doc_y2 = document:getBoundingBox()

	-- Uncomment to print the source string to terminal.
	--[[
	io.write("\n\n-------------------------------------------------\n\n")
	print(samples[sample_i].text)
	--]]

	--print(inspect(document))
end
setupDocument()


function love.keypressed(kc, sc)

	local needs_update = false

	if kc == "escape" then
		love.event.quit()

	elseif kc == "left" then
		sample_i = math.max(1, sample_i - 1)
		demo_scroll_y = 0
		needs_update = true

	elseif kc == "right" then
		sample_i = math.min(#samples, sample_i + 1)
		demo_scroll_y = 0
		needs_update = true

	elseif kc == "up" then
		demo_scroll_y = demo_scroll_y - SCALE(40)

	elseif kc == "down" then
		demo_scroll_y = demo_scroll_y + SCALE(40)

	elseif kc == "pageup" then
		demo_scroll_y = demo_scroll_y - SCALE(120)

	elseif kc == "pagedown" then
		demo_scroll_y = demo_scroll_y + SCALE(120)

	elseif kc == "tab" then
		demo_debug_render = not demo_debug_render

	elseif kc == "0" then
		love.window.setVSync(math.max(0, 1 - love.window.getVSync()))
	end

	if needs_update then
		setupDocument()
	end
end


function love.wheelmoved(x, y)
	demo_scroll_y = demo_scroll_y - SCALE(y*40)
end


function love.mousefocus(focus)
	mouse_focus = focus
end


local cooldown, cooldown_top = 0, 1/50

function love.update(dt)

	if demo_update_doc then
		document:update(dt)
	end

	cooldown = math.max(0, cooldown - dt)
	if love.mouse.isDown(1) then
		demo_doc_x = love.mouse.getX()

	elseif love.mouse.isDown(2) then
		if cooldown == 0 then
			demo_doc_wrap_w = love.mouse.getX() - demo_doc_x
			setupDocument()

			cooldown = cooldown_top
		end
	end

	hover_para = false
	hover_line = false
	hover_block = false
	if mouse_focus then
		mouse_x, mouse_y = love.mouse.getPosition()
		local mx = mouse_x - demo_doc_x
		local my = mouse_y + demo_scroll_y

		hover_para = document:getParagraphAtPoint(mx, my) or false
		if hover_para then
			mx = mx - hover_para.x
			my = my - hover_para.y
			hover_line = hover_para:getWrapLineAtPoint(mx, my) or false
			if hover_line then
				mx = mx - hover_line.x
				hover_block = hover_line:getBlockAtPoint(mx) or false
			end
		end
	end
end


function love.draw()

	if love.keyboard.isDown("space") then
		love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
		love.graphics.scale(0.5, 0.5)
		love.graphics.translate(-love.graphics.getWidth()/2, -love.graphics.getHeight()/2)
	end

	love.graphics.setColor(demo_background_tint)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	love.graphics.setColor(demo_text_tint)

	local x1 = demo_doc_x
	local x2 = x1 + document.wrap_w

	local para1, para2 = 1, #document.paragraphs
	if demo_limit_draw_range then
		para1, para2 = math.huge, -math.huge

		local pad = love.graphics.getHeight()/6
		--local pad = 0

		-- Assumes all paragraphs are in top-to-bottom order
		local p
		for p = 1, #document.paragraphs do
			local paragraph = document.paragraphs[p]
			if paragraph.y + paragraph.h + pad >= demo_scroll_y then
				para1 = p
				break
			end
		end
		for p = para1, #document.paragraphs do
			local paragraph = document.paragraphs[p]
			if paragraph.y - pad <= demo_scroll_y + love.graphics.getHeight() then
				para2 = p
			else
				break
			end
		end
	end
	if demo_debug_render then
		document:debugDraw(x1, -demo_scroll_y, para1, para2)
	end
	document:draw(x1, -demo_scroll_y, para1, para2)

	-- Draw guides for left and right document edges.
	love.graphics.setColor(0, 0, 1, 1)
	love.graphics.line(
		x1 + 0.5,
		0.5,
		x1 + 0.5,
		love.graphics.getHeight() - 1 + 0.5
	)

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.line(
		x2 + 0.5,
		0.5,
		x2 + 0.5,
		love.graphics.getHeight() - 1 + 0.5
	)
	love.graphics.setColor(1,1,1,1)

	love.graphics.push("all")
	if hover_para then
		love.graphics.setColor(1,0,0,0.5)
		love.graphics.setLineWidth(2)
		love.graphics.setLineStyle("smooth")
		love.graphics.rectangle(
			"line",
			demo_doc_x + hover_para.x + 0.5,
			-demo_scroll_y + hover_para.y + 0.5,
			hover_para.w - 1,
			hover_para.h - 1
		)
		if hover_line then
			love.graphics.setColor(0,1,0,0.5)
			love.graphics.setLineWidth(2)
			love.graphics.setLineStyle("smooth")
			love.graphics.rectangle(
				"line",
				demo_doc_x + hover_para.x + hover_line.x + 0.5,
				-demo_scroll_y + hover_para.y + hover_line.y + 0.5,
				hover_line.w - 1,
				hover_line.h - 1
			)
			if hover_block then
				love.graphics.setColor(0,0,1,0.5)
				love.graphics.setLineWidth(2)
				love.graphics.setLineStyle("smooth")
				love.graphics.rectangle(
					"line",
					demo_doc_x + hover_para.x + hover_line.x + hover_block.x + 0.5,
					-demo_scroll_y + hover_para.y + hover_line.y + hover_block.y + 0.5,
					hover_block.w - 1,
					hover_block.h - 1
				)
			end
		end
	end
	love.graphics.pop()

	love.graphics.origin()
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, love.graphics.getHeight() - SCALE(48), love.graphics.getWidth(), SCALE(48))

	love.graphics.setColor(1,1,1,1)
	love.graphics.setFont(demo_font)

	qp:reset()
	qp:setOrigin(SCALE(8), love.graphics.getHeight() - SCALE(48) + SCALE(8))

	qp:write(
		"Left/Right: Select Document ", sample_i, "/", #samples,
		"\tLua Mem (KB): ", math.floor(collectgarbage("count") * 10) / 10,
		"\tFPS/Delta: ", love.timer.getFPS(), " ", love.timer.getAverageDelta()
	)

	love.graphics.setFont(rt.font_groups.norm[1].font)

	-- Test document bounding box
	--[[
	love.graphics.push("all")

	love.graphics.setColor(0, 1, 0, 0.5)
	love.graphics.rectangle(
		"fill",
		demo_doc_x + demo_doc_x1,
		demo_doc_y1 - demo_scroll_y,
		demo_doc_x2 - demo_doc_x1,
		demo_doc_y2 - demo_doc_y1
	)
	love.graphics.pop()
	--]]

	--print(collectgarbage("count"))
end


