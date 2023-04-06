# Media

Provides structures that build on top of Text Blocks and Block Styles.


## Draw Parameters (Transform, Color) and Callbacks

Documents, Full Paragraphs, Simple Paragraphs and Wrap-Lines have the same transform parameters, color parameters and draw callbacks (`cb_drawFirst`, `cb_drawLast`) as Text Blocks which are used in the default draw methods. For more info, see 'docs/text\_block.md', *Transform and Color Parameters* and *Callbacks*.

They also support `cb_update`, a callback that is called through update methods.


# Documents

## media.newDocument

Creates an empty Document container.

`local document = media.newDocument()`

**Returns:** The new Document.


## Document:draw

Draws the document.

`Document:draw(x, y, para1, para2)`

* `x`: X drawing offset.

* `y`: Y drawing offset.

* `para1`: *(1)* Index of the first paragraph to draw.

* `para2`: *(last paragraph)* Index of the last paragraph to draw.


## media.basic_documentDraw

A cut-down version of the Document draw method. It ignores transform and color parameters, and does not run `cb_drawFirst` or `cb_drawLast`.

`media.basic_documentDraw(self, x, y, para1, para2)`

* `self`: The Document.

* `x`: X drawing offset.

* `y`: Y drawing offset.

* `para1`: *(1)* Index of the first paragraph to draw.

* `para2`: *(last paragraph)* Index of the last paragraph to draw.


### Notes

Usage: Overwrite the draw method in a Document Instance or within the Document metatable (note that the latter will affect *all* Document structures).


## Document:debugDraw

Draws debug information for the document.

`Document:debugDraw(x, y, para1, para2)`

* `x`: X drawing offset.

* `y`: Y drawing offset.

* `para1`: *(1)* Index of the first paragraph to debug-draw.

* `para2`: *(last paragraph)* Index of the last paragraph to debug-draw.

### Notes

Transform parameters are not applied to the debug visualization.


## Document:getParagraphAtPoint

Gets the first paragraph found at a coordinate relative to the document upper-left, starting at index `n`.

`local paragraph, index = Document:getParagraphAtPoint(x, y, n)`

* `x`: X position, relative to document left.

* `y`: Y position, relative to document top.

* `n`: *(1)* Index of the first paragraph to check.

**Returns:** The first match and its index, or nil if there was no match.

### Notes

This method does not take Transform parameters into account.


## Document:getBoundingBox

Gets the bounding box coordinates for all paragraphs in a document in the format of `x1, y1, x2, y2`. The values can be used to calculate the document width and height (`w = x2 - x1`) and the box's offset from origin. Text may spill out beyond the horizontal boundaries in some cases, such as when words are broken with a wrap-limit that is too narrow.

`local x1, y1, x2, y2 = Document:getBoundingBox()`

**Returns:** The combined left, top, right and bottom boundaries (`x1`, `y1`, `x2`, `y2`) of all Paragraphs in the Document.


## Document:update

Calls `cb_update` (if present) on the Document, and then calls `update` on all Paragraphs, which in turn calls `cb_update` on itself, and then on structures further down the tree (Wrap-Lines, Text Blocks).

`Document:update(dt)`

* `dt`: Typically the frame delta time from `love.update`.


# Paragraphs

Paragraphs represent a wrapped line of source text.

Behavior and appearance varies depending on the style metatable attached. The default methods are described here.


## media.newParagraph

Creates a new paragraph based on a Paragraph Style.

`local paragraph = media.newParagraph(para_style)`

* `para_style`: The Paragraph Style to use.

**Returns:** The new Paragraph instance.


## media.newParagraphStyle

Creates a new Paragraph Style.

Paragraph Styles are `__index` metatables for paragraphs. They also contain settings for the RText parser.

`local para_style = media.newParagraphStyle(word_style, wrap_line_style)`

* `word_style`: The Word Style to use for this Paragraph Style. Required.

* `wrap_line_style`: *(default Wrap-Line style)* An optional Wrap-Line style to use when creating Wrap-Lines in Paragraph Instances using this Style. As this is a fairly niche feature, you can leave this argument empty to create and use a default Wrap-Line Style instead.

**Returns:** The new Paragraph Style.


## media.default_paraDraw / Paragraph:draw

Draws the paragraph.

`media.default_paraDraw(self, x, y)`
`Paragraph:Draw(x, y)`

* `self`: The Paragraph.

* `x`: X drawing offset.

* `y`: Y drawing offset.


## media.basic_paraDraw

A cut-down Paragraph draw function. It ignores transform and color parameters, and does not run `cb_drawFirst` or `cb_drawLast`.

`media.basic_paraDraw(self, x, y)`

* `self`: The Paragraph.

* `x`: X drawing offset.

* `y`: Y drawing offset.

### Notes

Usage: overwrite the draw method in a Paragraph Style or Paragraph Instance.


## media.paraDebugDraw / Paragraph:debugDraw

Draws debug information for the paragraph.

`media.paraDebugDraw(self, x, y)`
`Paragraph:debugDraw(x, y)`

* `self`: The Paragraph.

* `x`: X drawing offset.

* `y`: Y drawing offset.

### Notes

Transform parameters are not applied.


## media.paraGetWrapLineAtPoint / Paragraph:getWrapLineAtPoint

Checks for the first Wrap-Line at a point within a paragraph.

`media.paraGetWrapLineAtPoint(self, x, y, n)`
`Paragraph:getWrapLineAtPoint(x, y, n)`

* `self`: The Paragraph.

* `x` X position relative to paragraph left.

* `y` Y position relative to paragraph top.

* `n` (1) The start index.

**Returns:** The first match and its index, or nil if none were found.

### Notes

This function does not account for Transform parameters.


# Wrap-Lines

A wrapped line of text within a paragraph. Wrap-Lines contain Text Blocks that have been arranged and wrapped by the Line Placer.


## media.newWrapLine

Creates a new Wrap-Line.

`local wrap_line = media.newWrapLine(wrap_line_style)`

* `wrap_line_style`: The Wrap-Line Style (metatable) to use for this Wrap-Line. Required.

**Returns:** The new Wrap-Line.


## media.newWrapLineStyle

*(Unrelated to love.graphics Line Styles.)*

Creates a new Wrap-Line Style, which serves as a metatable of default parameters for Wrap-Lines.

`local wrap_style = media.newWrapLineStyle()`

**Returns:** The new Wrap-Line Style.


## media.wrapLineGetBlockAtPoint / WrapLine:getBlockAtPoint

Looks for a block at an X position relative to the Wrap-Line's left side. If multiple blocks overlap the coordinate, the first match is returned.

`media.wrapLineGetBlockAtPoint(self, x, n)`
`WrapLine:getBlockAtPoint(x, n)`

* `self`: The Wrap-Line.

* `x`: X position relative to Wrap-Line's left side.

* `n`: *(1)* Optional starting index.

**Returns:** The first overlapping block and its index, or `nil` if no match was found.


## media.wrapLineUpdate / WrapLine:update

Calls `cb_update` (if present) on a Wrap-Line and all of its Text Blocks.

`media.wrapLineUpdate(self, dt)`
`WrapLine:update(dt)`

* `self`: The Wrap-Line.

* `dt`: Typically, the frame delta time from `love.update`.


## media.default_wrapLineDraw / WrapLine:draw

Draws the Wrap-Line.

`media.default_wrapLineDraw(self, x, y)`
`WrapLine:draw(self, x, y)`

* `self`: The Wrap-Line.

* `x`: X drawing offset.

* `y`: Y drawing offset.


## media.basic_wrapLineDraw

A cut-down draw method for Wrap-Lines. It doesn't apply transform or color parameters, and doesn't call `cb_drawFirst` or `cb_drawLast`.

`media.basic_wrapLineDraw(self, x, y)`

* `self`: The Wrap-Line.

* `x`: X drawing offset.

* `y`: Y drawing offset.

### Notes

Usage: overwrite the draw method in the Wrap-Line Style or in a Wrap-Line Instance.


# Simple Paragraphs

Simple Paragraphs are essentially just wrappers for `love.graphics.printf()`. They use fewer resources than full RText paragraphs, and are good for displaying large amounts of text which don't require formatting beyond color and alignment.

Simple Paragraphs do not support underlines, backgrounds or strike-through lines. A Block Style is required, but it's used solely to get the font object and associated metadata.

The default Simple Paragraph draw method supports Transform and Color parameters, and the `cb_drawFirst` and `cb_drawLast` callbacks.

As of v0.1.1, RText does not provide a way to generate Simple Paragraphs from markup.


## media.newSimpleParagraph

Creates a new Simple Paragraph.

`local s_para = media.newSimpleParagraph(x, y, text, b_style, align, wrap_limit)`

* `x`: The Simple Paragraph X offset.

* `y`: The Simple Paragraph Y offset.

* `text`: The string or `coloredtext` sequence to be displayed.

* `b_style`: The Text Block style to use for font details.

* `align`: The [LÖVE AlignMode](https://love2d.org/wiki/AlignMode) to use when printing.

* `wrap_limit`: The horizontal wrap limit to apply when printing with `love.graphics.printf()`.

**Returns:** A new Simple Paragraph.


## SimpleParagraph:draw

Draws the Simple Paragraph.

`SimpleParagraph:draw(x, y)`

* `x`: Drawing X offset (added to `s_para.x`).

* `y`: Drawing Y offset (added to `s_para.y`).


## media.basic_simpleParaDraw

A cut-down version of `SimpleParagraph:draw()` that doesn't use transform parameters, color parameters, or drawing callbacks.

`media.basic_simpleParaDraw(self, x, y)`

* `self`: The Simple Paragraph.

* `x`: Drawing X offset (added to `s_para.x`).

* `y`: Drawing Y offset (added to `s_para.y`).

### Notes

To use: overwrite the default draw method, either in the Simple Paragraph instance or in its metatable (affecting all Simple Paragraphs).


## SimpleParagraph:refreshSize

Refreshes the Simple Paragraph width and height values. Call if you change the text of an existing Simple Paragraph.

`SimpleParagraph:refreshSize()`

### Notes

This method generates a small amount of garbage to calculate the height. Avoid calling it if the Simple Paragraph's size hasn't changed.


## SimpleParagraph:update

Runs `cb_update`, if present.

`SimpleParagraph:update(dt)`

* `dt`: Typically the delta time from `love.update`.

### Notes

This method is included to be compatible with Full Paragraphs, which also have an update method that ticks Wrap-Lines and Text Blocks.


# Font Group

Holds Block Styles representing regular, bold, italic and bold-italic Block Styles (fonts). Every Font Group must have a Regular Block Style, while the others are optional.


## media.newFontGroup

Creates a new Font Group table.

`local f_grp = media.newFontGroup(regular, bold, italic, bold_italic)`

* `regular` The regular Block Style. Required.

* `bold` *(nil)* Optional bold Block Style.

* `italic` *(nil)* The italic Block Style.

* `bold_italic` *(nil)* The bold and italic Block Style.

**Returns:** A Font Group table, which is an array of Block Styles arranged for access with `FontGroup:getFace()`.


## FontGroup:getFace

Gets a Block Style from a Font Group, based on the requested bold and italic state.

`local b_style = FontGroup:getFace(bold, italic)`

* `bold` The desired bold state. (boolean)

* `italic` The desired italic state. (boolean)

**Returns:** The desired Block Style, or the regular Block Style as a fallback if the category isn't populated.


# Word Style

Word Styles are a bundle of the following RText Parser state: Font Group ID, bold, italic, text color, strikethrough state/color, underline state/color, and background state/color.


## media.newWordStyle

Creates a new Word Style.

`local word_style = media.newWordStyle(f_grp_id)`

* `f_grp_id`: String ID for a Font Group ID, which will be used to reference a Font Group within an RText Instance. Required. 

**Returns:** The new Word Style.


# Label

Labels are minimal containers for Text Blocks. They have no transform or color parameters, and their alignment support is limited (basically just Vertical Alignment).

Labels cannot be generated by the RText Parser.


## media.newLabel

Creates a new Label.

`local label = media.newLabel()`

**Returns:** A new empty label object.


## Label:clear

Removes all Text Blocks from a label.

`Label:clear()`


## Label:appendText

Creates a Text Block and appends it to the right end of the Label.

`Label:appendText(str, block_style, color, color_ul, color_st, color_bg)`

* `str`: The text to append. (Must be a string, not a `coloredtext` array.)

* `block_style`: The Block Style to use.

* `color`: *(nil)* An optional text color table (in the form of `{1, 1, 1, 1}`).

* `color_ul`: *(nil)* An optional underline color table.

* `color_st`: *(nil)* An optional strikethrough color table.

* `color_bg`: *(nil)* An optional background color table.

**Returns:** The new Text Block for additional tweaking.


## Label:extendLastBlock

Extends the last Text Block in the label with additional text. A new color may be specified for the new text, but underline, background and strikethrough state are not modified.

`Label:extendLastBlock(str, color)`

* `str`: The text to add into the Text Block. (Must be a string, not a `coloredtext` array.)

* `color`: An optional text color table (in the form of `{1, 1, 1, 1}`).


## Label:appendBlock

Adds a Text Block or Arbitrary Block to the end of a Label.

`Label:appendBlock(block)`

* `block`: The Text Block or Arbitrary Block to add.

### Notes

Block instances should not appear multiple times in a Label.


## Label:arrange

Arranges all Blocks in a Label from left to right, and optionally applies vertical alignment.

`Label:arrange(v_align)`

* `v_align`: *("baseline")* The vertical alignment enum (see *line_placer.md*).


## Label:draw

Draws all Text Blocks within a Label using a simple loop.

`Label:draw(x, y)`

* `x`: X drawing offset.

* `y`: Y drawing offset.


