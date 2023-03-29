# RText Troubleshooting + Tips


## Tags are appearing as text.

* Check that there is a handler for the tag. Unhandled tags are passed along as text.

* Tags must open and close on the same line in the source string (ie be part of the same Paragraph).

* Tags cannot be nested within other tags.

* Make sure that any whitespace you use inside of tags is of the legacy *ASCII* variety, excluding line feeds. The other whitespace code points will be treated like non-whitespace, and won't act as delimiters between the tag ID and parameters.


## Tags are silently failing.

Some built-in tags fail silently by design, like `[i]` if italic state is already active. Most tags which accept color or font IDs are treated as text if there is a parsing failure (with the exception of tags where the parameter is optional). Check the tag handler functions to be sure.


## How do I escape tag patterns?

You can use `[t1]` For the tag-open pattern and `[t2]` for the tag-close pattern. The patterns are injected as single Text Blocks, so if you need to insert them frequently in your project, consider changing the tag patterns to something else with `rt:setTagPatterns()`.


## How do I insert new lines in a paragraph without starting a new paragraph?

`[br]` will finish the current wrap-line, and start a new line within the same paragrph.


## Align is not working.

If the text isn't appearing at all with `center` and `right` alignment: those modes place text relative to the wrap-limit, which defaults to infinity (`math.huge`). Ensure a reasonable wrap-limit is assigned.

A paragraph has the wrong alignment: RText locks some state for the duration of a paragraph or wrap-line. `[align]` and `[valign]` should be placed at the start of a paragraph, before any content, including whitespace. The moment any text is parsed, alignment state is locked until the wrap-line is finalized.

Placing `[align]` in the middle of lines should be avoided. It will change alignment of the next Wrap-Line, not the next Paragraph. You can place it after a `[br]`, though.


## Paragraph Style changes are not working.

* A Paragraph Style may only be assigned at the very beginning of a Paragraph, before any content text (including whitespace) is parsed. The moment a Paragraph Style is assigned or some text content is encountered, further Paragraph Style assignments are locked until the Paragraph is complete.


## RTL text is not working

* RTL is not supported yet.


## Performance

* Ensure you are only recreating the Document when its content or the dimensions change. Creating the Document requires generating many tables and sub-strings, which can be resource-intensive. A cooldown period between recreations, say 50 milliseconds or so, might help reduce overhead from continuous actions like resizing the document viewport.

* For long Documents, ensure that you are only drawing paragraphs which are visible within your game's viewport. You can specify a start and end paragraph index when drawing. For linear documents, this can be determined by looping through paragraphs and noting the first and last ones within viewport range.

* RText will struggle with huge documents. Whenever possible, split the content into smaller segments.

* The `code-point` and `cluster` block granularity settings are much less efficient than `word`. Stick to `word` unless you really need every character to be a separate Text Block.

* For text that rarely changes, you can render it once to a canvas and draw that instead.

