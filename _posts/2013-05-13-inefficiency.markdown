---
layout: post
title:  "Inefficiences and insufficiencies: C++, others"
date:   2013-05-13T04:08:00Z
categories:
---

Lately I've been [game programming](https://github.com/nvdiao/gundrey).  A
few things have been coming to mind:

* The [Sapir&ndash;Whorf
  hypothesis](https://en.wikipedia.org/wiki/Linguistic_relativity) is totally
  true when it comes to programming languages.
* Dynamically typed languages encourage a whole lot of waste.
* There's some sweet spot of expressivity, low level and
  non-shoot-yourself-in-the-footness in language that's missing.

I will attempt to expound.

The languages I end up using on a day-to-day basis tend to be higher level.
Non-scientific demonstration by way of my [GitHub account's contents at time of
writing](https://github.com/kivikakk):

    15 Ruby
    9 OCaml
    6 Go
    6 Javascript
    4 C
    3 C++
    2 Clojure
    3 Perl
    2 Haskell
    ...

In my professional career, I've concentrated on JavaScript, PHP, Erlang, Python
and C#.  The lowest level of these is, by far, Erlang.  Perhaps it's fairer to
say that Erlang keeps me in check, perf-wise, more than any of the others.

So my mind has been a fairly high-level sort of mindset.  I've made occasional
trips to lower-level code, but there hasn't been much of that lately,
particularly as I've changed jobs and needed to concentrate solely on work
stuff for a while.

Choosing C++ to write a game wasn't too hard; it's fairly standard in the
industry, and I know it quite well.  Bindings to libraries are plentiful, and
getting the same codebase compiling on Windows, OS X and Linux is a
well-understood problem that's known to be solvable.

The thing is, C++ makes it abundantly clear when you're doing something costly.
This is something that occurs particularly to me now as I've not done this
lower-level stuff in a while.

You wrote the copy constructor yourself, so you know exactly how expensive
pushing a bunch of objects into a `vector` is.  You chose a `vector`, and not a
list, so you know exactly why you don't want to call `push_front` so many
times.  You're creating a `ostringstream` to turn all this junk into a string:
it has a cost.  Are we putting this on the stack or in the heap?  Shall we use
reference counting?

You make hundreds of tiny decisions all the time you're using it; ones which
are usually being abstracted away from you in higher level languages.  It's why
they're higher level.

And that's basically all I have to say on that: the language makes you feel the
cost of what you choose to do.  Going to use a pointer?  Better be sure the
object doesn't get moved around.  Maybe I'll just store an ID to that thing and
store lookups in a `map`.  How costly is the hashing function on the map key?
You add such a lookup table in Ruby without a moment's notice; here, you're
forced to consider your decision a moment.  Every time you access the data,
you're reminded as well; it's not something that ever goes out of mind.

Moreover, the ahead-of-time compilation means you can't do costly runtime
checks or casts unless you *really* want to (e.g. `dynamic_cast`), but again,
the cost of doing so means you'll never be caught unaware by slowing
performance.  In many (dynamic) higher level languages, basically every
operation is laced with these.

So it's suited for games programming, because performance is usually pretty
important, and the language keeping performance on your mind means it's not
hard to consistently achieve high performance.

But C++'s deficiencies [are also
well-documented](http://www.fefe.de/c++/c++-talk.pdf).  It's awful.  It's
waiting to trip you up at every turn.  After re-reading those talk slides, I
figured I'd just port the code to C -- until I remembered how much I used
`std::string`, `std::vector`, `std::list`, and moreover, enjoyed the type- and
memory-safety they all bring.  I'm not particularly fond of giving that up and
implementing a bunch of containers myself, or using generic containers and
throwing away my type checks.

I *think* I'm after C with templates for structs (and associated functions),
but I'm not sure yet.  If you think I want C++, you probably need to [re-read
those notes](http://www.fefe.de/c++/c++-talk.pdf).

The other solution is to only use as much of C++ as I like, and that's
basically what I do -- but the language is still waiting to trip me up, no
matter how much I try not to use it.

Time to think a bit about what the issues at hand really are.
