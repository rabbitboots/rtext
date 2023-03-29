# RText (the module)

`rtext.lua` is the main library interface.


## RText Markup Format

Markup tags provide formatting information within the flow of text:

```
"Allow [b]me[/b] to [i]interject.[/i]"
```

The RText parser is very simple. It does not support nested structuring of content beyond the arrangement of `Document -> Paragraph -> Wrap-Line -> Text Block`. Inline images, bulleted lists and other kinds of formatted text or mixed media require the implementation of custom Paragraph Styles. (Some of these are provided in `auxiliary.lua`, to be used at your discretion.) The built-in tags can be found in `tag_defs.lua`.

When an undefined tag is encountered, or when a tag function fails (maybe it tried to set a Font Group that isn't registered), the expected behavior is to place the tag string into the Document as content.

If you dislike the use of square brackets for tags, they can be changed to any pair of non-empty string literals with `rt:setTagPatterns()`. For example, if you never use curly braces in your text content, you could switch to those instead. Multiple characters may also be used, like `<<` and `>>`. It's a good idea to stick to one set of tag patterns for a whole project.

All whitespace is significant. A line feed (`\n`) starts a new Paragraph, and Paragraphs can be empty.


## Line and Paragraph State locking

Some state is locked on a per-wrap-line or per-paragraph basis. As soon as any text is processed, some state changes will not take effect until the end of the wrap-line or end of the paragraph.

Paragraph Style tags should be the very first thing to appear on a source line. Then you can set alignment, vertical alignment, word style, bold, italics, and so on.


## Issues, Tips

* (Unicode, LÖVE 12 c4aaab6) RTL is currently not supported.

* (LÖVE 12 c4aaab6) Placing tags *inside* of multi-code point characters (like ligatures) will break them. Internally, tags always cause text to be split into separate blocks.

* (Nuisance) Inconsistent kerning may be observed when breaking long words that are comprised of multiple blocks across wrap-lines. More specifically: the width of the last glyph in a wrap-line may have kerning applied against the glyph on the next line, when it shouldn't.

```
	aaaaaaa[foo]L
	Taaaaaaaaaaaa
```

* (Performance) Hard-wrapping words has a lot of overhead, especially when every letter of every word is wrapped. Prevent that from happening by enforcing a minimum document wrap-limit and maximum font size, and not making huge lines without any breaking whitespace.


# RText API

## rtext.newInstance

Creates a new RText state table.

`local rt = rtext.newInstance(font_groups, default_f_grp_id, colors, word_styles, para_styles, def_para_style, data)`

* `font_groups`: A table of Font Groups for the RText Parser to reference. Required.

* `default_f_grp_id`: The default Font Group ID to use. Required, and must match a key in `font_groups`.

* `colors`: *(Empty table)* Optional table of colors for the RText Parser to reference. Color tables are in the form of `{1, 1, 1, 1}`, with red, green, blue and alpha values occupying the first 4 numeric indices. When not provided, an empty table is assigned instead.

* `word_styles`: *(Empty table)* Optional table of Word Styles for the RText Parser to reference. When not provided, an empty table is assigned instead.

* `para_styles`: *(Empty table)* Optional table of Paragraph Styles for the RText Parser to reference. When not provided, an empty table is assigned instead.

* `def_para_style`: *(Factory-Default)* An optional default Paragraph Style to use at the beginning of Paragraphs. When not provided, a "factory-default" Paragraph Style is assigned instead.

* `data`: *(false)* Optional table of arbitrary data for custom tags to reference.

**Returns:** The new RText instance.


## rtext.newFontGroup (media.newFontGroup)

Creates a new Font Group table. This is a structure that arranges Block Style tables into regular, bold, italic and bold-italic categories. Regular is required, while the others are optional.

`local f_grp = rtext.newFontGroup(regular, bold, italic, bold_italic)`

* `regular` The regular Block Style. Required.

* `bold` *(nil)* Optional bold Block Style.

* `italic` *(nil)* The italic Block Style.

* `bold_italic` *(nil)* The bold and italic Block Style.

**Returns:** A Font Group table, which is an array of Block Styles arranged for access with `FontGroup:getFace()`.

### Notes

This is a wrapper for `media.newFontGroup`.


## rtext.newWordstyle (media.newWordStyle)

Creates a new Word Style.

`local word_style = rtext.newWordStyle(f_grp_id)`

* `f_grp_id`: String ID for a Font Group ID, which will be used to reference a Font Group within an RText Instance. Required. 

**Returns:** The new Word Style.

### Notes

This is a wrapper for `media.newWordStyle`.


## rtext.newParagraphStyle (media.newParagraphStyle)

Creates a new Paragraph Style.

Paragraph Styles are `__index` metatables for paragraphs. They also contain settings for the rtext parser.

`local para_style = rtext.newParagraphStyle(word_style, wrap_line_style)`

* `word_style`: The Word Style to use for this Paragraph Style. Required.

* `wrap_line_style`: *(Factory-Default)* An optional Wrap-Line style to use when creating Wrap-Lines in Paragraph Instances using this Style. As this is a fairly niche feature, you can leave this argument empty to create and use a "factory default" Wrap-Line Style instead.

**Returns:** The new Paragraph Style.

### Notes

This is a wrapper for `media.newParagraphStyle`.


## rt:applyWordStyle

Applies Word Style state to an RText Instance.

`rt:applyWordStyle(word_style)`

* `word_style`: The Word Style to apply.


## rt:setParagraphStyle

Sets the Paragraph Style for the next Paragraph.

`local success = rt:setParagraphStyle(para_style)`

* `para_style` The Paragraph Style to apply.

**Returns:** True on success, false if the Paragraph Style state was locked.

### Notes

Paragraph style declarations should be the very first thing to appear in a paragraph, and there should not be more than one paragraph style declaration per line.

Some paragraph style tags can modify the paragraph (otherwise it's difficult to transfer tag parameters). Those tags should check the return status of setParagraphStyle(), and fail if it returned false (as it means paragraph state was locked).

The default paragraph style is applied at the start of processing every paragraph, and so it should not mutate the paragraph in ways that might make other paragraph styles fail.


## rtext.newBlockStyle (textBlock.newBlockStyle)

Creates a new Block Style based on a LÖVE Font. Block Styles provide some additional modifiable metadata for fonts.

`local b_style = rtext.newBlockStyle(font)`

* `font`: The LÖVE Font to use.

**Returns:** A new Block Style with default settings.

### Notes

This is a wrapper for `textBlock.newBlockStyle`.


## rtext.newBlockStyleArbitrary (textBlock.newBlockStyleArbitrary)

Creates a new Arbitrary Block Style. Use when creating Arbitrary Blocks (for mixing non-text media).

`local arb_style = rtext.newBlockStyleArbitrary()`

**Returns:** The new Arbitrary Block Style.

### Notes

This is a wrapper for `textBlock.newBlockStyleArbitrary`.


## rtext.newWrapLineStyle (media.newWrapLineStyle)

*(Unrelated to love.graphics Line Styles.)*

Creates a new Wrap-Line Style, which serves as a metatable of default parameters for Wrap-Lines.

`local wrap_style = rtext.newWrapLineStyle()`

**Returns:** The new Wrap-Line Style.

### Notes

This is a wrapper for `media.newWrapLineStyle`.


## rt:refreshFont

Updates the Instance font. Call after changing the Font Group ID, or making a change to bold or italic state.

`local success = rt:refreshFont()`

**Returns:** true on success, false on failure (usually a bad Font Group ID).


## rt:setDefaultState

Prepares the RText Parser for working on a new Document.

`rt:setDefaultState()`

### Notes

Affected state:

* Internal variables related to cursor position, wrap-limit, indent and alignment (horizontal and vertical)

* Locks for changes to Wrap-Lines, Paragraphs and Paragraph Style state

Other settings are unchanged.


## rt:setTagPatterns

Sets the opening and closing tag patterns (initially `[` and `]`).

`rt:setTagPatterns(open, close)`

* `open`: The opening pattern. Must be at least one character in length.

* `close`: The closing pattern. Must be at least one character in length.

### Notes

1. Tag patterns should be configured during setup and not modified later. If you need to only occasionally insert the patterns as content, you can use the `t1` and `t2` tags.

2. The same string for both tags is not recommended.

3. The Tag patterns are string literals and not Lua search patterns.

4. Tag patterns are not reset by `rt:setDefaultState`.


## rt:setColor

Sets or clears the Instance text color.

`rt:setColor(id)`
`rt:setColor()`

* `id`: The color ID, which must be a string key populated in `rt.colors`. Pass nothing/nil to clear the current Instance color.

### Notes

It's an error to pass a non-nil, non-false color ID which isn't populated in the `rt.colors` table. The associated tag (`[color]`) performs an additional check, and will fail quietly instead.


## rt:setAlign

Sets the Instance horizontal alignment state.

`rt:setAlign(align)`

* `align`: The align enum. Can be `left`, `center`, `right`, or `justify`.

### Notes

Alignment state is locked whenever the Parser is working on a Wrap-Line. If you change alignment in the middle of a line, the change will be deferred to the start of the *next* Wrap-Line.


## rt:setVAlign

Sets the Instance vertical alignment state.

`rt:setVAlign(v_align)`

* `v_align`: The vertical align enum. Can be `top`, `ascent`, `middle`, `baseline` (default), `descent`, or `bottom`.

### Notes

1. You almost always want to use `baseline` vertical alignment.

2. Vertical alignment state is locked whenever the Instance is working on a Wrap-Line. If you change alignment in the middle of a line, the change will be deferred to the start of the *next* Wrap-Line.


## rt:makeDocument

Generates a Document from an input string.

`local document = rt:makeDocument(input, width)`

* `input`: The input string.

* `width`: *(math.huge)* Width of the document, used to determine the wrap-limit of paragraphs.

**Returns:** The Document structure.


## rt:makeParagraph

Generates one paragraph from an input string, from `i` to the next line feed or end of the string.

`local para, next_i = rt:makeParagraph(input, i, wrap_w`

* `input`: The input string.

* `i` *(1)* Starting byte position in the string. Needs to be on a UTF-8 start byte.

* `wrap_w`: *(math.huge)* Wrap-limit for the text.

**Returns:** The paragraph structure and index of the next unread byte. Work is complete when the next byte is greater than `#input`.


## rt:makeSimpleParagraph

Generates one Simple Paragraph from an input string, from `i` to the next line feed or end of the string.

`local s_para, next_i = rt:makeSimpleParagraph(input, i, wrap_w, align, b_style)`

* `input`: The input string.

* `i`: *(1)* Starting byte index in the string. Needs to be on a UTF-8 start byte.

* `wrap_w`: *(math.huge)* Wrap-limit for the text.

* `align`: *(left)* Horizontal align mode. Can be `left`, `center`, `right` or `justify`.

* `b_style`: The Block Style (font) to use.

**Returns:** The Simple Paragraph structure and index of the next unread byte. Work is complete when the next byte is greater than `#input`.


## rt:parseText

Work on a Document incrementally, appending up to `max_paragraphs` worth of content from an input string.

`local next_i = rt:parseText(input, document, i, max_paragraphs)`

* `input`: The input string.

* `document`: The work-in-progress Document.

* `i`: The starting byte position in `input`. Needs to be on a UTF-8 start byte.

* `max_paragraphs`: *(math.huge)* How many paragraphs to generate before returning.

**Returns:** Index of the next unprocessed byte in `input`. (`document` is modified in-place.)


## rt:pushTextQueue

Pushes a string onto the text queue. Tag Defs use this as a way to inject text into the document. Note that the ingress text is not parsed for tags. Any line feed other than the literal string "\n" will cause issues with formatting.

`rt:pushTextQueue(str)`

* `str`: The string to push as text content.

### Notes

You typically don't need to call this directly. Tags like `br`, `t1` and `t2` use it as a way to bypass the tag parsing system.


## rt:clearTextQueue

Clears the text queue.

`rt:clearTextQueue()`

### Notes

You typically don't need to call this directly. The Parser loop calls this automatically once it's finished reading the text queue.


## rt:setBlockGranularity

Sets the Instance block granularity level, which controls how text is split into blocks.

`rt:setBlockGranularity(level)`

* `level`: The block granularity level. Can be:

  * `word`: Break at whitespace and tags.

  * `cluster`: Break at grapheme cluster boundaries and tags.

  * `code-point`: Break at code point boundaries.

### Notes

1. You usually don't need to change this unless you want per-character incremental printing. It won't work well with multi-code point ligatures that aren't recognized as grapheme clusters, or writing systems where the characters change appearance depending on their position in a word. It will also use far more memory, and will be slower to draw.

2. All block granularity levels will pack trailing whitespace onto the end of the block. For example, the input string `AB   C` becomes `A`, `B   `, `C`.

3. Block granularity should not be modified in the middle of a parsing job.


