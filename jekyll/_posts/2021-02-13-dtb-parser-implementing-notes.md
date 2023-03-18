---
layout: post
title: DTB parser implementing notes
---

Ever find yourself needing to implement a [device tree
blob](https://devicetree-specification.readthedocs.io/en/latest/chapter5-flattened-format.html)
(aka FDT, flattened device tree) parser and want to save yourself some time?
Learn from my mistakes!


## If you try to do it in one pass, you will hurt yourself

<a id="more"></a>I charged headlong into writing
[dtb.zig](https://github.com/kivikakk/dtb.zig)
by starting at the top of the Devicetree Specification page on the "Flattened
Devicetree (DTB)" Format" and reading down. It looked delightfully simple. Keep
in mind, I still didn't know what I yet needed out of it, just that I probably
needed to reference the DTB to get it.  (I [kind of know better now](https://github.com/kivikakk/daintree/commit/1a65076a36301f0fb33748b8da644010a178b58e#diff-5e1ca02318cf3679c3aa9a422be7adfefe1fefdd76d297d676770edeacdb5e67R329-R349).)

<!--more-->

---

The tree was taking shape, and then I had to parse the contents of one field by
the contents of a prop in its parent ([`#address-cells` and
`#size-cells`](https://devicetree-specification.readthedocs.io/en/latest/chapter2-devicetree-basics.html#address-cells-and-size-cells)).
Add some contexts and derive them from their parent, allowing overriding for
children. Easy.

Then I needed to parse
[interrupts](https://devicetree-specification.readthedocs.io/en/latest/chapter2-devicetree-basics.html#interrupts-and-interrupt-mapping).
It turns out the `interrupts` property of a node has its format defined by the
`#interrupt-cells` of the "binding of the interrupt domain root".  It turns out
your ["interrupt
parent"](https://devicetree-specification.readthedocs.io/en/latest/chapter2-devicetree-basics.html#interrupt-parent)
might be defined _forward_ in the file, as referenced by its phandle.

You find out the same thing about clocks, though the documentation is [harder
to
find](https://android.googlesource.com/kernel/msm.git/+/android-msm-shamu-3.10-lollipop-mr1/Documentation/devicetree/bindings/clock/clock-bindings.txt).
A clock provider specifies `#clock-cells`, which is usually 0 or 1. When
another node refers to a clock on that node, it addresses the phandle of the
clock provider, followed by `#clock-cells` worth of cells to index which clock
on that provider.

In other words, a `clocks` like this:

```
00000000: 00000085 0000001c 0000002e
```

could refer to either:

* one clock specified by phandle `0x85`, with a `#clock-cells` of 2, the index
  being `0x1c 0x2e`,
* two clocks;
  * either a clock at phandle `0x85` with a `#clock-cells` of 1 indexed by
    `0x1c`, and a clock at `0x2e` with no index, or,
  * a clock at `0x85` with no index, and a clock at `0x1c` indexed by `0x2e`;
    or,
* three clocks, all with no index; `0x85`, `0x1c`, `0x2e`.

You need to be able to look up the clocks and obtain their properties to
interpret this, so you **need** a second pass, or delayed/on-time resolution of
fields, or whatever.  There end up being [quite a few
props](https://github.com/kivikakk/dtb.zig/blob/9bc32d41ae83586a422dd5f10c943021592613cd/src/parser.zig#L133-L142)
that need a second pass.


## How big?

It's worth noting all numbers and indexes in DTB are in big-endian, unsigned
32-bit integer cells. That makes hexdumps easier, since you can read them
byte-by-byte or in groups of 4 and don't need to rearrange them in your head.

You'll see `#address-cells` of 2 and similar for most 64-bit devices. I saw an
`#address-cells` of 3 once in a PCIe node and it scared me.


### Strings are NUL-terminated, and NUL padded

This tripped me up.  Strings are NUL-terminated, and then the field will be
padded with NULs (if needed) to align on a `u32` (i.e. offset divisible by 4).
This is helpful, because a `u32` is literally what will always follow, and Arm
devices (which DTBs are often used on) don't like unaligned reads.

So, when you need to read a NUL-terminated string, don't do what I did first:

{% highlight zig %}
var name_end: usize = 0;
while (index[name_end] != 0) : (name_end += 1) {}
const name = index[0..name_end];
index = index[(name_end + 3) & ~@as(usize, 3) ..];
{% endhighlight %}

It seems reasonable at first blush: count the NULs ([there's a much better
way](https://github.com/ziglang/zig/blob/9270aae071a4ee840193afe1162b24945cbd6d9e/lib/std/mem.zig#L680-L711)),
then advance the index past the name, plus align to advance past padding.
(Hack for aligning to a power of two, `n`: add `n-1`, then logical AND with
`n-1`.)

The problem is that I never advanced past the NUL terminator, which is still
part of the string.  Here are some example NUL-terminated strings:

```
00000000: 6100                                 a.
00000000: 616200                               ab.
00000000: 61626300                             abc.
00000000: 61626364 00                          abcd.
```

Here are the same strings padded with NULs to align on `u32`:

```
00000000: 61000000                             a...
00000000: 61620000                             ab..
00000000: 61626300                             abc.
00000000: 61626364 00000000                    abcd....
```

Here's the corrected code:

{% highlight zig %}
var name_end: usize = 0;
while (index[name_end] != 0) : (name_end += 1) {}
const name = index[0..name_end];
name_end += 1; // advance past NUL byte
index = index[(name_end + 3) & ~@as(usize, 3) ..];
{% endhighlight %}


## That's all for now

I ended up separating dtb.zig into two parts, given it's used in boot-time code where allocating memory can mess around with things:

* allocator-free
  [`Traverser`](https://github.com/kivikakk/dtb.zig/blob/9bc32d41ae83586a422dd5f10c943021592613cd/src/traverser.zig),
  which emits events SAX style. I tried using Zig's `suspend`/`resume` here,
  and it works pretty well.
* allocating
  [`Parser`](https://github.com/kivikakk/dtb.zig/blob/9bc32d41ae83586a422dd5f10c943021592613cd/src/parser.zig)
  which uses the `Traverser` and creates an AST, parsing props into an
  immediately usable AST in two passes.

The `Traverser` is used in [daintree](https://github.com/kivikakk/daintree)'s
bootloader,
[dainboot](https://github.com/kivikakk/daintree/blob/209782a93de9088cba20808644c89cd9898ddada/dainboot/src/dtb.zig),
to find a probable serial UART device. I'll use the `Parser` later in the OS
proper to bring up more devices.
