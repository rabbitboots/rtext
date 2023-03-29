# Text Blocks

Text Blocks represent a chunk of printable text. Usually, this in the form of `[word][space]`, where `word` is a run of non-whitespace code points and `space` is a trailing run of whitespace.

Text Blocks use *Block Style* tables to provide default settings via the `__index` metamethod. Fields beginning with `f_` are reserved for use by the Block Style, and should be treated as read-only by the Text Block.

*Arbitrary Blocks* provide a way to insert non-text media into a run of text. While they're not guaranteed to actually have any text content, they do require vertical font metrics for correct placement within a Wrap-Line.


## Transform and Color Parameters

Text Blocks have optional transform and color parameter fields. They are applied by the the default draw methods, while basic methods ignore them.

Transform parameters:

* `d_x`
* `d_y`
* `d_r`
* `d_sx`
* `d_sy`
* `d_ox`
* `d_oy`
* `d_kx`
* `d_ky`

Color Parameters:

* `c_r` -> Red
* `c_g` -> Green
* `c_b` -> Blue
* `c_a` -> Alpha


## Fields: Text Block Instance

Fields marked with `(*)` *should* have defaults provided by the Block Style, which the instance can override. Fields marked `(**)` *can* have Block Style defaults, but should probably be left empty. All other fields should be left to the Text Block instance to assign.

```
block.text
	For monochrome text: A string: "Hello"
	For colorized text: A `coloredtext` sequence: { {1, 1, 1, 1}, "Hello", ... }

block.x
block.y
block.w
block.h
	The block's position (relative to the line) and dimensions, excluding
	trailing space on the end.

block.ws_w
	Width of any trailing space at the end of `block.text`.

block.has_ws
	Boolean indicating if this block has trailing whitespace. Needed for support
	of zero-width space characters.

(*)block:draw()
(*)block:drawToTextBatch()
(*)block:debugDraw()
(*)block:renderText()
(*)block:renderBackground()
(*)block:renderUnderline()
(*)block:renderStrikethrough()
	Text Block render methods.

(*)block.d_x
(*)block.d_y
(*)block.d_r
(*)block.d_sx
(*)block.d_sy
(*)block.d_ox
(*)block.d_oy
(*)block.d_kx
(*)block.d_ky
	Optional transform parameters used in the default draw function.

(*)block.c_r
(*)block.c_g
(*)block.c_b
(*)block.c_a
	Optional color parameters used in the default draw function. Mixes with the colors of text and shapes.

(*)block.ul_ox
(*)block.ul_oy
	X and Y offsets when drawing underlines.

(*)block.ul_width
(*)block.ul_style
	Underline width and style.

(*)block.st_ox
(*)block.st_oy
	X and Y offsets when drawing strikethrough lines.

(*)block.st_width = 1.0
(*)block.st_style = "smooth"
	Strikethrough width and style.

(*)block.bg_ox
(*)block.bg_oy
	X and Y offsets when drawing background rectangles. Added to 'f_ox' and 'f_oy'.

(*)block.bg_ext_w
(*)block.bg_ext_h
	Extend or shorten the dimensions of background rectangles when drawing.

(**)block.color_bg
(**)block.color_ul
(**)block.color_st
	Background, underline and strike-through color tables. These features are disabled
	when false/nil.
--]]
```


## Fields: Block Style

Block Styles serve as a metatable for Block Text instances.

```
style.f_type = "text"
	Identifies the Block as text (as opposed to an Arbitrary Block).

style.font
	The LÖVE Font object this Block Style is built around.

style.f_ox = 0
style.f_oy = 0
	Base font offsets when rendering.

style.f_sx = 1.0
style.f_sy = 1.0
	X and Y scale when constructing and drawing blocks. Non-integral values may lead to
	off-the-pixel-grid positioning of blocks -> blurry text

style.f_height = font:getHeight()
style.f_baseline = font:getBaseline()
style.f_ascent = font:getAscent()
style.f_descent = font:getDescent()
	Cached vertical font metrics. Allows tweaking the metrics of LÖVE ImageFonts.

style:draw()
style:drawToTextBatch()
style:debugDraw()
style.renderText()
style.renderBackground()
style.renderUnderline()
style.renderStrikethrough()
	Drawing functions. See Block Instance fields for info.

style.ul_ox
style.ul_oy
style.ul_width
style.ul_style
style.st_ox
style.st_oy
style.st_width
style.st_style
style.bg_ox
style.bg_oy
style.bg_ext_w
style.bg_ext_h
	Default shape parameters. See Block Instance fields for more info.

style.d_x = 0
style.d_y = 0
style.d_r = 0
style.d_sx = 1.0
style.d_sy = 1.0
style.d_ox = 0
style.d_oy = 0
style.d_kx = 0
style.d_ky = 0
	Default draw parameters. See Block Instance fields for info.

style.c_r
style.c_g
style.c_b
style.c_a
	Default color parameters. See Block Instance fields for info.
```


## Arbitrary Block Fields

```
block.x
block.y
block.w
block.h
	The block's position (relative to the line) and dimensions. Doesn't
	necessarily have to be the dimensions of what you intend to draw.

block.has_ws = <always nil or false>
block.ws_w = <always 0>
block:draw(): A function that draws the block.
```


## Arbitrary Block Style Fields

```
block.type = <"arbitrary" by default. Anything that isn't "text">
	Identifies the block as not being a Text Block.
```

## Notes

* Multiple lines in a Text Block are not fully supported. They will break vertical height measurements, and formatting shapes (like underlines) will only appear on the first line.


# API


## textBlock.newBlockStyle

Creates a new Block Style based on a LÖVE Font. Block Styles provide some additional modifiable metadata for fonts.

`local b_style = textBlock.newBlockStyle(font)`

* `font`: The LÖVE Font to use.

**Returns:** A new Block Style with default settings.


## textBlock.newTextBlock

Creates a new Text Block.

`local block = textBlock.newTextBlock(text, b_style, x, y, w, h, ws_w, has_ws, color, color_ul, color_st, color_bg)`

**WARNING:** This function takes many parameters and does no error checking. It should not be used directly in most cases, but rather called through a parser or other wrapper.

* `text`: The block's text. Must be a string, not a `coloredtext` sequence.

* `b_style`: The Block Style to use.

* `x`: The Block's X offset.

* `y`: The Block's Y offset.

* `w`: The Block's width, not including trailing whitespace.

* `h`: The Block's height.

* `ws_w`: *(nil)* Width of the block's trailing (and breaking) whitespace.

* `has_ws`: *(nil)* Should be true if the block contains trailing whitespace. This is needed because some breaking whitespace characters can have a width of zero.

* `color`: *(nil)* An optional color table for the text, in the form of `{1, 1, 1, 1}`. When absent, the text is white.

* `color_ul`: *(nil)* An optional underline color table. When absent, there is no underline.

* `color_st`: *(nil)* An optional strikethrough color table. When absent, there is no strikethrough line.

* `color_bg`: *(nil)* An optional background color table. When absent, there is no background.

**Returns:** The new Text Block.


## textBlock.extend / TextBlock:extend

Extends an existing Text Block with new text. The underline, strikethrough, background, and Block Style parameters are left unaltered, but you can specify a new color for the added text.

`textBlock.extend(self, new_text, color)`
`TextBlock:extend(new_text, color)`

* `self`: The Text Block to extend.

* `new_text`: The text to add. Must be a string, not a `coloredtext` sequence.

* `color`: *(nil)* An optional color table to apply to the added text.

### Notes

This function is assigned to default Block Styles as `BlockStyle:extend()`.

The caller is responsible for updating `self.w`, `self.has_ws` (if in use) and `self.ws_w` (if in use).

The extend method is not used in RText by default because it breaks justify alignment in Wrap-Lines with mixed Block Styles. Additionally, the previous and new text, when combined, may have a different width because of ligatures or other text-shaping reasons.


## textBlock.newBlockStyleArbitrary

Creates a new Arbitrary Block Style. Use when creating Arbitrary Blocks (for mixing non-text media).

`local arb_style = textBlock.newBlockStyleArbitrary()`

**Returns:** The new Arbitrary Block Style.


## textBlock.renderText / Block:renderText

The default Text Block rendering function for text.

`textBlock.renderText(self, x, y)`
`Block:renderText(x, y)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.

### Notes

Called within `Block:draw()`.


## textBlock.renderBackground / Block:renderBackground

The default Text Block rendering function for backgrounds.

`textBlock.renderBackground(self, x, y, w, h, color)`
`Block:renderBackground(x, y, w, h, color)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.

* `w`: Width of the background rectangle.

* `h`: Height of the background rectangle.

* `color`: The background color, in table form (`{1, 1, 1, 1}`).

### Notes

Called within `Block:draw()`.


## textBlock.renderUnderline / Block:renderUnderline

The default Text Block rendering function for underlines.

`textBlock.renderUnderline(self, x1, y1, x2, y2, color)`
`Block:renderUnderline(x1, y1, x2, y2, color)`

* `self`: The Text Block.

* `x1`: Starting X position.

* `y1`: Starting Y position.

* `x2`: Ending X position.

* `y2`: Ending Y position.

* `color`: The underline color, in table form (`{1, 1, 1, 1}`).

### Notes

Called within `Block:draw()`.


## textBlock.renderStrikethrough / Block:renderStrikethrough

The default Text Block rendering function for strikethrough lines.

`textBlock.renderStrikethrough(self, x1, y1, x2, y2, color)`
`Block:renderStrikethrough(x1, y1, x2, y2, color)`

* `self`: The Text Block.

* `x1`: Starting X position.

* `y1`: Starting Y position.

* `x2`: Ending X position.

* `y2`: Ending Y position.

* `color`: The strikethrough color, in table form (`{1, 1, 1, 1}`).

### Notes

Called within `Block:draw()`.


## textBlock.default_draw / Block:draw

The default draw function for Text Blocks.

`textBlock.default_draw(self, x, y)`
`Block:draw(x, y)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.

### Notes

The default draw method supports:

* Transform parameters (`d_x`, `d_y`, `d_r`, ...)

* Color parameters (`c_r`, `c_g`, `c_b`, `c_a`)

* Callbacks:
  * `cb_drawFirst(self, x, y)` (just after transform)
  * `cb_drawLast(self, x, y)`


## textBlock.basic_draw

A cut-down drawing method that ignores transform and color parameters.

Usage: overwrite the `draw` method in a Text Block or Block Style.

`textBlock.basic_draw(self, x, y)`
`Block:draw(x, y)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.


## textBlock.default_drawToTextBatch / Block:drawToTextBatch

The default draw function for adding Text Block contents to a LÖVE TextBatch.

`textBlock.default_drawToTextBatch(self, text_batch, x, y)`
`Block:drawToTextBatch(text_batch, x, y)`

* `self`: The Text Block.

* `text_batch`: The LÖVE TextBatch to add to.

* `x`: The X drawing position within the TextBatch.

* `y`: The Y drawing position within the TextBatch.

### Notes

The callbacks (`cb_drawFirst`, `cb_drawLast`) are not supported.

Shapes are not included.

The Block Style font (`self.font`) should match the TextBatch font.


## textBlock.basic_drawToTextBatch

A pared-down version of drawToTextBatch. (There isn't really much to pare down, but it ignores Transform parameters to behave like the other 'basic' methods.)

`textBlock.basic_drawToTextBatch(self, text_batch, x, y)`

* `self`: The Text Block.

* `text_batch`: The LÖVE TextBatch to add to.

* `x`: The X drawing position within the TextBatch.

* `y`: The Y drawing position within the TextBatch.


## textBlock.debugDraw / Block:debugDraw()

A debug-render function for Text Blocks. Draws the bounding box and vertical font metrics.

`textBlock.debugDraw(self, x, y)`
`Block:debugDraw(x, y)`

* `self`: The Text Block.

* `x`: Drawing X position.

* `y`: Drawing Y position.

### Notes

Does not apply the Block's transform parameters.

Arbitrary Blocks do not have a debugDraw method by default. Check for the method's presence in a Block before calling it:

```lua
if blk.debugDraw then
	blk:debugDraw(x, y)
end
```


# Callbacks

These callbacks may be placed in the Block Style or the Block Text instance.


## block.cb_drawFirst

Called in `textBlock.default_draw` after applying the transformation, and before rendering any text or shapes.

`local function cb_drawFirst(self, x, y)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.


## block.cb_drawLast

Called in `textBlock.default_draw` after rendering text and shapes.

`local function cb_drawLast(self, x, y)`

* `self`: The Text Block.

* `x`: X drawing offset.

* `y`: Y drawing offset.


## block.cb_update

Called when a higher-level structure runs its *update* method.

`local function cb_update(self, dt)`

* `self`: The Text Block.

* `dt`: Typically the frame delta time.


