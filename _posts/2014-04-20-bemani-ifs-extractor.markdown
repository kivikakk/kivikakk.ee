---
layout: post
title:  "Bemani IFS extractor"
date:   2014-04-20T12:31:00Z
categories:
---

[I made an extractor for Bemani IFS files.](https://github.com/kivikakk/ifsexplorer/tree/master)  It's been done a few times before, but this one's reasonably usable compared to "drag and drop one file on this program, which spawns 50 files more, each of which you drag on this program to decompress, then each decompressed file to another program which spits up a window and has you drag a slider around until it looks right."

Features:

* You can open an IFS file and browse the data therein without saving them all out to a file.
* You can export images as BMP, GIF, JPEG, PNG or TIFF.
* The index used for guessing the aspect ratio of the image is saved and used automatically when browsing other images with the same pixel count.

It's a .NET 2.0 application, and is in the [public domain](http://unlicense.org).

![A screenshot!](https://cloud.githubusercontent.com/assets/1915/2750529/5b30d642-c885-11e3-8903-52f03f52d3a0.jpg)
