---
layout: post
title:  "VSTO and COM objects"
date:   2014-04-05T04:23:00Z
categories:
---

It's impressive how hard it is to use VSTO correctly.

When a COM handle crosses from unmanaged into managed code for the first time,
a ["runtime callable wrapper" is created for
it](http://msdn.microsoft.com/en-us/library/8bwh56xe.aspx).  This wrapper
maintains a reference count, [incremented whenever the object is newly
requested across the boundary](http://stackoverflow.com/a/5771301/499609).

The wrapper releases the COM object behind it when its finalizer is run, but
this relies on all .NET references to the RCW itself becoming inaccessible to
the GC and for the GC to pick it up.  This may not reliably happen.

You can force the matter by decrementing the reference count on the RCW
yourself:
[Marshal.ReleaseComObject](http://msdn.microsoft.com/en-us/library/system.runtime.interopservices.marshal.releasecomobject.aspx)
does this, and should the reference count drop to zero, the COM object will get
released immediately.  This means taking a lot of care, though, since it's not
always obvious which VSTO calls result in the counter being incremented and
which don't.  Something like the following can help work it out:

{% highlight csharp %}
var refs = new object[3];
for (var i = 0; i < 3; ++i)
    refs[i] = my.VSTO.Call();
for (var i = 0; i < 3; ++i)
    Debug.WriteLine(Marshal.ReleaseComObject(refs[i]).ToString());
{% endhighlight %}

If each call to
[Marshal.ReleaseComObject](http://msdn.microsoft.com/en-us/library/system.runtime.interopservices.marshal.releasecomobject.aspx)
 returns the same number, it implies each call is incrementing the reference
 count; if the return values are decreasing, the call is not incrementing the
 count.

VSTO event callbacks are [said to not need references released on passed-in COM
objects](http://stackoverflow.com/a/10484930/499609), but [an MSDN blog
disagrees](http://blogs.msdn.com/b/mstehle/archive/2007/12/06/oom-net-part-1-introduction-why-events-stop-firing.aspx).
There is no consensus here.  For anything else at least: remember to release
COM objects when you're done with them, otherwise it can get painful.
