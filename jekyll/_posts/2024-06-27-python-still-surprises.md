---
layout:      post
title:       "Python still surprises"
---

After the better part of 20 years working with Python, it still managed to
surprise me today.

I'm so used to languages treating `x += y` et al. as pure sugar for `x = x + y`
that it skipped my mind that some don't.

I'm not surprised that you _can_ override them separately in some languages (e.g.
I simply assume this to be the case in C++, and on checking it turns out to
be true --- but that seems fair enough given the scope of the language), but I
really am so accustomed to them being only sugar in Ruby that I assumed the same
would hold, at least in effect, in Python.

Thus my surprise on `some_list += x` modifying `some_list` in place (unlike
`some_list = some_list + x`), but once observed, I realised there'd be a
separately-overridden operator function --- namely `__iadd__` --- and so I
figured it "had" to be that way.

Or did it? I then found myself assuming it's because these operators can't
actually reassign the receiver, but in fact they can and do: the return value is
what's assigned to the LHS. So it's just a matter of convention.

