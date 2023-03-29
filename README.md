**Version 0.1.0** (Beta)

# RText

RText (Rich Text) is a text formatting and display library for the LÖVE Framework.


## Features

* Mixed fonts in the same line

* Font groups (regular, bold, italic, bold-italic)

* Text coloring

* Underlines, strikethrough lines and background (highlight) rectangles, with support for colors independent of the text

* Horizontal alignment: `left`, `center`, `right`, `justify`

* Vertical alignment: `top` `ascent`, `middle`, `descent`, `baseline` (recommended), `bottom`

* Per-font tweak support (scaling, overriding vertical metrics)

* Optional Transform parameters for animating portions of Documents


Check out `demo.lua` for some examples.


![rtext_pic_1](https://user-images.githubusercontent.com/23288188/228692208-606d9a76-1804-4fea-9efd-2647af27aac2.png)


## About This Package

The `rtext` subdirectory is all that's needed when integrating RText into a project. The rest of this repo consists of demos, testing and documentation.


## What's missing?

* RTL text flow is not supported.

* Documentation is barebones and needs an overhaul.

* Needs a tutorial that walks through the setup process.

* Needs a "Ready-To-Go" setup template, fonts included, that covers basic usage.

* Maybe better support for simple documents, with a line-oriented parser (as opposed to tags within paragraphs).


# MIT License

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
