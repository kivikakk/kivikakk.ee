---
layout: post
title:  "Being sorta useful in vim"
date:   2014-04-19T10:09:00Z
categories:
---

### a strange guide

This is a semi-comprehensive, non-prosaic (but hardly poetic) reference to vim.  Approach with caution.

Modes:

* [**normal**](#normal): move the cursor, delete, enter insert mode, delete then insert, enter visual mode, yank and put (copy and paste)
* [**insert**](#insert): type stuff, move the cursor, scroll, put
* [**visual**](#visual): do things to the selected area, move your cursor about within it

And more:

* [**registers**](#registers): where your deleted and yanked text goes
* [**text objects**](#text-objects): even more ways to select text
* [**what else?**](#what-else): what haven't I covered?
* [**CC0**](#cc0): this text is in the public domain



### normal

[move the cursor](#move-the-cursor), [delete](#delete), [enter insert mode](#enter-insert-mode), [delete then insert](#delete-then-insert), [enter visual mode](#enter-visual-mode), [yank and put](#yank-and-put) (copy and paste)



#### move the cursor

`hjkl` move the cursor left-down-up-right respectively.  It's good to remember these, but no big deal if you don't; cursor keys usually work too.  On Dvorak, you have `jk` on your left hand for vertical movement, and `hl` on your right for horizontal.

`w` moves a word forward.  `b` moves a word backward.  These stop at punctuation, too; if you want to skip a "word" where a word is just anything that's not whitespace, `W` and `B` do the trick.

`e` moves forward until the end of a word, instead of the start of a word.  `E` has the same rule as above.

These are a good start: using `wbWB` are pretty good for getting around quickly.

You can prefix any command with a number; `5w` moves 5 words, `10B` moves backwards 10, uh, 'big', words.  These work on `hjkl` as well (and almost anything, honestly).

Go to the start and end of the line with `^$`.

Go anywhere by searching with regular expressions; type `/`, and then complete the regular expression in the buffer beneath.  `n` and `N` then find the next and previous match.  These all function as movement commands in the below contexts, too.  `?` is the same as `/`, but backwards.  Note that `n` and `N` are reversed when you're in such a reverse search!

You can also go quickly to the *following* given character on the current line; `f` followed by the character instantly goes there.  `fa` will put the cursor on the next `a`.  `Fa` goes backwards. You can also go *'til* the next character, i.e. to the character immediately before, with `t`; `ta` puts the cursor just before the following `a`, and `Ta` just after the preceding one.

(You'll note here that uppercase commands *tend* to vary the lowercase equivalents, by degree, inversion, or other shift in meaning.  I do say "tend", though, because there are plenty that don't.)

`<Enter>` is another way of saying `j`, and `<Space>` another way of saying `l`.

`)` and `(` move a sentence forward and backward respectively.  `}` and `{` move by paragraphs instead.

`])` and `[(` move to the next and previous unmatched `)` and `(` respectively, as do `]}` and `[{` for `}` and `{`.  More understandably put: they move out to the next parenthesis or brace level in the given direction; they go "up" a level.

`%` moves to (and including) the matching token under the cursor; if your cursor is on a `(`, it'll move to the matching `)`, etc.

`G` moves to the end of the document.  If you prefix a number, it moves to that numbered line; `1G` to the very top.



#### delete

`d` deletes stuff.  You have to tell it what by following with a movement command: it deletes from the cursor position up to where you tell it.  `dw` deletes the word you're on, up to the start of the next word.  `dl` deletes up to the following character; i.e. the single character your cursor is on.

Note that if you've hit `d` and change your mind, `<Escape>` will abort that command.

Operations spanning lines are a bit different.  `dd` will delete the entirety of the current line.  This repetition of a command to mean 'this line' is a pattern.  You can use a number: `2dd` will delete this line and the one after it.  On that, `3dw` deletes 3 words.  (So does `d3w`.)

`dj` (delete down) will delete this *and* the next line.  `dk` will delete this *and* the previous line.

`D` is the same as `d$`; it deletes to the end of the line.

`d/blah<Return>` will delete from the cursor until the next `blah` in the file.  `d?blah<Return>` deletes back to the previous `blah`, including the entire matching word itself.

`dta` deletes from the cursor up to and not including the following `a`.  `dfa` would include the `a` in its deletion.  `2dta` deletes up to and not including the second following `a`, etc.

`x` deletes a single character, as a handy shorthand.  If you have the word `programmer` and the cursor positioned at the start, `10x` will delete the whole word.

`d)` will delete to the end of the sentence; as will `d}` the paragraph.  `d%` deletes the entirety of whatever the token under the cursor delimits; if your cursor is on a matched brace, the entire brace will be deleted, and so on.



#### enter insert mode

`i` will enter insert mode, leaving the cursor where it is.

`a` will enter insert mode, but places the cursor after the current character, i.e. appends.

`I` and `A` enter insert mode, but first move the cursor to the start or end of the line respectively.  (These are handy.)  They're the same as `^i` or `$a` respectively.

Note that numbers work with these too: `3i` will enter insert mode, and whatever you type will be inserted thrice in total, once you leave the mode.

`o` and `O` enter insert mode, "opening" a line as they do.  `o` opens a new line underneath (same as `A<Return>`), and `O` opens a line on the current line (same as `I<Return><Escape>ki`, or just `ko` if there's a line above).  You might need a mnemonic to remember which is which; `O` reaches higher up the screen than `o`, and so opens the line higher.

`R` enters replace mode; like insert, but overwriting text instead of inserting before it.



#### delete then insert

You can delete then insert in the same command; this is called "changing" text.  Just use `c` instead of `d`, and it functions nearly identically as for deleting, and then enters insert mode on the spot.  (`cw` is the same as `dei`; `cc` is the same as `^Di`; the differences are that the *whole* object isn't removed, that is to say, trailing spaces or newlines are kept. `ce` and `cw` do the same thing.)

`C` functions as `Di`.  Change is often handy as `c/`, `ct`, `cT`, etc.

Note that numbers before change commands affect *only* the delete portion of the command; `2cw` is literally like `2dei`, not `2dei2i`, in that it removes two words (excluding the trailing space), and then enters insert mode, but what you insert isn't entered twice.  This is almost always what you want.

`s` is like `cl`; it'll change a character on your cursor. `10s` erases the ten characters from under your cursor and enters insert.  `S` is the same as `cc` (since otherwise what would it do different to `C`?).

`r` is like `s` but only for a single character; it waits for you to enter the character, which the one under the cursor will be replaced with. `10ra` replaces the current and following 9 characters with the letter `a`.



#### enter visual mode

`v` enters visual mode.  The cursor position at the time of entering visual mode becomes one end of the selection, and now you move the other.

Visual mode selects a range of text, traversing newlines as they occur sequentially in the text.

`V` enters visual line mode; this selects whole lines at a time, inclusive of both ends of the selection.

`CTRL-V` enters visual block mode; this selects a physical rectangular block of text.  It can be a bit weird at first, especially with its behaviour crossing lines and empty lines, but quite useful, especially in combination with `r`, `c`, and `s`.

`gv` will enter visual mode with the last selection you had already made.  (Note that your cursor won't necessarily be anywhere near where it ends up.)



#### yank and put

`y` takes a movement like other commands; `yy` (copies) yanks the current line, `yj` the current and next, `y2w` (or `2yw`) the two words from the cursor position onward, etc.

`p` puts (pastes) what was yanked *after* the cursor position.  If you yanked *linewise* (like the first two examples above), the put is linewise: they are put as whole lines underneath the current one, as if you'd used `o` to open.

`P` yanks at the current cursor position, as if you used `i` to insert the text.  If you yanked linewise, it puts as if you used `O` to open.

All delete commands, including change commands `c`, `s` and so on, actually have been the equivalent of "cut" operations.  If you e.g. use `cw` to change a word, `p` will then put the deleted word.

See [below](#registers) about different registers in case you want to save some text without it getting clobbered by subsequent yanks or deletes.



### insert

[type stuff](#type-stuff), [move the cursor](#move-the-cursor), [scroll](#scroll), [put](#put)



#### type stuff

Type stuff!  Go on!



#### move the cursor

If cursor keys are enabled, they probably will let you move the cursor in vim without exiting insert mode.

`<Escape>` will leave insert mode, by the way.



#### scroll

There's a submode of insert mode that seems to be called expand mode; `<CTRL-X>` enables it.  Any keypress not recognised by the mode will just be handled by regular insert mode and quit the expand mode; of note are `<CTRL-E>` and `<CTRL-Y>`, which scroll the window down and up respectively.  Just start typing to exit the mode.

It's worth noting these scroll in normal mode, too.



#### put

You can also put text while in insert mode.  `<CTRL-R>"` will put whatever you last deleted or yanked; see below about [registers](#registers) for more on this; the `"` is specifying the register to put.

You can get help on insert-mode keys, by they way, by typing something like `:help i_CTRL-R`.



### visual

[do things to the selected area](#do-things-to-the-selected-area), [move your cursor about within it](#move-your-cursor-about-within-it)



#### do things to the selected area

Any command, like `c` and `d`, will affect the selected mode en masse.



#### move your cursor about within it

Pressing `o` will change the end of the selection you're moving to the other end; useful to adjust the selection.

The three visual modes, accessed with `v`, `V` and `CTRL-V`, are exited by pressing the appropriate key again.  You can switch *between* visual modes by pressing the key for any other visual mode while already in one.



### registers

When you delete or yank text, it's put in a register; a clipboard, essentially.  Each register is identified by a character, and they're referred to by prefixing a `"`.  `"a` is the a register, `"F` the F register, etc.  There are special registers; the unnamed register, `""` (i.e. the register name is double-quote), is what's used by default by yank, delete and put.

To perform any register-affecting command with a given register, prefix the entire command with the register reference; `"ay$` yanks the rest of the line into the `"a` register.  `"ap` puts that.  (Note that `dcsxy` *always* affect the `""` register, *as well* as any specified one.)

`"_` is the blackhole register; it causes the command to affect *no* registers.  (This is the only exception to the parenthesis prior to this.  Ahem.)

Per [put in insert](#put), `<CTRL-R>` waits for a register name; `<CTRL-R>a` in insert mode will put the contents of the `"a` register.

Registers `"0` thru `"9` have special meaning; see `|quote_number|` (type `:help quote_number` in normal mode) for more information.

If you specify a letter-named register with lowercase letters, you replace the contents; `"ayw` sets the contents of the `"a` register to the word from the cursor on.  The same register reference but uppercase causes that register to be appended to.

More special registers exist; see `|registers|`.



### text objects

Text objects are another way to select areas of text.  They can't be used as movement commands in normal mode in and of themselves, as they refer to regions; they may only be movement command arguments to commands that do something to regions, such as `d` and `c`.  They are, however, very useful.

I lied, though: they can be used directly in visual mode, which selects the region they refer to.  Experimenting with this is a good way to see how they work.

Text object commands start with either `i` or `a`; the former selects an object not including surrounding whitespace ("inner"), the latter includes surrounding whitespace.  (Much like `i` leaves the cursor put when entering insert mode, but `a` moves it forward.  It sort of makes sense.)

After that, you specify the kind of object; they're based roughly on movement commands.  `iw`, for instance, refers to the word your cursor is on top of.  `diw` deletes the word your cursor is on.  Note how this differs (usefully) from `dw`; `dw` deletes forwards from the cursor until the start of the next word, whereas `diw` deletes the entire word under the cursor, regardless of your cursor's position.

Some common use cases: change the word under the cursor: `ciw`.  Delete the word under the cursor entirely, closing any gaps: `daw`.  Same, but take any punctuation touching the word with it, too: `daW`.

Sentences and paragraphs are accessed with `s` and `p`, again, following `i` or `a`.  Give some of these a try in visual mode to see what I mean: enter visual mode, then try `iw`, then `aw`.  Try `ip`, then `ap`.  (Note that these will put you in visual line mode.)

Some of the most useful are the matching token operators: `i[` (or `i]` ­ there's no difference) will select the contents of the nearest matching `[...]`, but not the `[]` themselves.  `a[` (or `a]`) include the tokens themselves.

Same works for `{`, `(`, `<`, `"`, `'`, <code>`</code>.  Changing a string or HTML attribute quickly?  `ci"`.  Want to quickly start a selection with a given block of code?  `va{`.

Repetition works: `2di(` deletes everything in the second-closest pair of parentheses, but not those parentheses themselves.

Editing HTML, `t` will work on HTML tags; `it` the contents of the nearest tag, `at` the contents and opening and closing tags themselves.

These are really lovely.  See `|text-objects|` for more.



### what else?

This is not even close to an exhaustive list of things in vim.

There are recordings (macros), which can be extraordinarily powerful; see `|recording|`.  Note that they record and execute into and of the same registers that you paste in, meaning you can paste out a recording, modify in the text, then yank it back into the register for execution.

There are even more movement commands: <code>*</code> and `#` search for the word under the cursor, `;` and `,` repeat your last `tTfF` command forward and backward (again with confusing reversing behaviour), <code>`</code> and `'` operate on marks set by `m` (see `|mark|`), and there are a million more commands prefixed by `g` (see `|g|`) that either modify the behaviour of the non `g`-prefixed command, or do something totally different.  It's worth a look.

Further, there's the entire command-line mode, accessed by pressing `:` in normal mode.  There are an enormous number of commands, many operating on ranges (pressing `:` in visual will start the command-line with a range matching the visually-selected lines); a useful one is `s` (see `|:s|`), for search-and-replace.

There's `.`, which repeats your last command.  Learn how it behaves in different circumstances and use it.

Keyword completion, triggered directly with `CTRL-N` and `CTRL-P` or through expand (`^X`) mode (see `|i_CTRL-N|`, `|i_CTRL-X_CTRL-N|`) just does a lookup based on tokens in open files.  There's omnicomplete (`|compl-omni|`, `|i_CTRL-X_CTRL-O|`), which can use plugins to intelligently autocomplete (like IntelliSense).

And a heck of a lot more, too.

Good luck!



### thanks

Thanks to Nethanel Elzas for emailing in fixes and suggestions!



### CC0

<p xmlns:dct="http://purl.org/dc/terms/" xmlns:vcard="http://www.w3.org/2001/vcard-rdf/3.0#">
  <a rel="license" href="https://creativecommons.org/publicdomain/zero/1.0/">
    <img src="https://i.creativecommons.org/p/zero/1.0/88x31.png" style="border-style: none;" alt="CC0" />
  </a>
  <br>
  To the extent possible under law,
  <a rel="dct:publisher" href="https://kivikakk.ee">
    <span property="dct:title">kivikakk</span></a>
  has waived all copyright and related or neighboring rights to
  <span property="dct:title">&ldquo;Being sorta useful in vim&rdquo;</span>.
  This work is published from:
  <span property="vcard:Country" datatype="dct:ISO3166" content="AU" about="https://kivikakk.ee">
    Australia</span>.
</p>

