---
layout:      post
title:       "Chisel and C++, together at last"
categories:  ["digital"]
---

I gave a lightning talk at last night's [Yosys Users Group] about combining
Chisel and <nobr>C++</nobr> with Yosys/CXXRTL. ~~I think there'll be a recording
of them that goes up on YouTube eventually?~~

<iframe width="560" height="315" src="https://www.youtube.com/embed/_-oqnf9gYuE?si=sOh9tujGCab9fHcZ" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

[Yosys Users Group]: https://blog.yosyshq.com/p/yosys-users-group/

Here's my [slides]; the transcript follows.

[slides]: https://f.hrzn.ee/chiselcxx.pdf

<a id="more"></a>

<!--more-->

![Chisel and C++, together at last. Yosys% speedrun. 2024.05.27 — @kivikakk](/assets/post-img/chiselcxx/slides.001.jpeg)

Hi folks! I’m kivikakk, and I’m here to talk about connecting Chisel and C++,
leaning on Yosys for all the hard work.

<br>

![@kivikakk — no verilog pls. Senior systems engineer; no EE/DD background. Australian startups, agencies, GitHub. Started playing with FPGAs early 2023, OSS toolchains only. ~40 commits in Yosys, mostly in support of CXXRTL and alternative frontends. To the right of the slide is a snapshot of my GitHub profile showing recent work, and an excerpt of my commits in Yosys.](/assets/post-img/chiselcxx/slides.002.jpeg)

In the workplace I’m a “systems engineer”, which usually means weaving together
low- and high- level languages in dark ways; think writing Erlang C nodes,
combining Ruby, Go and C++, that kind of thing.

In open source, I’m regrettably best-known for my work with Markdown. I have
zero electrical or digital background — or formal education — but after
microcontrollers failed to capture my interest, FPGAs succeeded, and I started
exploring in earnest last year.

Now, this is something I do for fun, which meant Verilog and VHDL were
completely capable of turning me off this path forever. I’m really into
programming language theory and design, and uh, well, Verilog sure could’ve used
some of either. I found Amaranth (formerly nMigen) pretty quickly, and so I
started hacking on Yosys too. I’ve particularly enjoyed working on CXXRTL, which
is the focus of this talk. I spent about 9 months learning with Amaranth, but—

<br>

![A labrador in a science lab wearing safety goggles, pouring a beaker into a mug, with the text superimposed: "I have no idea what I'm doing."](/assets/post-img/chiselcxx/slides.003.jpeg)

I’m still this dog, and there are more perspectives out there.

<br>

![Screenshot of the Chisel homepage, an excerpt of Chisel code, and the SystemVerilog generated from that code.](/assets/post-img/chiselcxx/slides.004.jpeg)

I decided to learn Chisel, which is an HDL in Scala like Amaranth is an HDL in
Python. These aren’t high-level synthesis tools, you still describe hardware in
them, just using DSLs embedded in a regular programming language.

You write code which generates hardware, in a metaprogramming kind of way,
except the metaprogramming is regular programming and the programming is circuit
definition instead. You run your code,

and out pops something that can go into your toolchain’s frontend. Chisel
outputs SystemVerilog, and is easily configured to avoid constructs Yosys
doesn’t like.

<br>

![Screenshot of SystemVerilog code with an arrow pointing to the Yosys cat logo. From the Yosys logo arrows point to a Lattice iCE40 chip with the associated text "Project IceStorm, nextpnr-ice40", a Lattice ECP5 chip with the text "Project Trellis, nextpnr-ecp5", and a cute C++ logo.](/assets/post-img/chiselcxx/slides.005.jpeg)

So we have our Verilog, and we feed it into Yosys.

Using the rest of the suite, we can synthesise for iCE40, ECP5 and more, but we can also target C++!

Yosys has its own C++ backend, CXXRTL. It’s similar to Verilator, but has some
unique advantages. For starters, if you’re using Yosys anyway, we can avoid
adding another tool. Moreover, the C++ comes directly from Yosys’ internal RTL
model — you can perform transforms and optimisations and then generate the
simulation without a Verilog roundtrip. It also supports runtime introspection
of the design, as well as exposing its API to C. This makes it feasible to use
the generated simulations from any language with C FFI, like Rust or Zig.

<br>

![Screenshot of Chisel code describing an instruction set for a stack machine and the core logic of the stack machine, as well as some code that shows a memory read port generated from a static ROM.](/assets/post-img/chiselcxx/slides.006.jpeg)

One of the most fun parts, though, is the ability to instantiate blackboxes
anywhere in your hierarchy, which you implement in C++. I’m going to show you
real fast what that can look like.

Here’s a tiny stack machine. It knows how to read and write bytes on UART, some
trivial stack manipulation, and how to jump back to zero. The implementation
itself isn’t very challenging, but the important part is that it gets its
instructions from a synchronous memory.

For unit tests  in Chisel, I instantiate a vector like a ROM, and implement the
other side side of the read port, making sure to return data in the right cycle.
So far so good.

<br>

![C++ logo in the middle with a small flash chip above it. Three dot points are listed: A. Emulate in gateware. B. Emulate in C++ by monitoring the top-level IO pins. C. Emulate in C++ with a "whitebox" implementation that responds to your module's IOs.](/assets/post-img/chiselcxx/slides.007.jpeg)

Let’s initialise our instruction memory from SPI flash. The iCEBreaker I’m using
as a dev board puts its bitstream on one, and there’s plenty of room left for
user data. So I flash my little “ROM” into the upper half, and on reset the
gateware’s SPI reader module populates the memory from it before starting the
stack machine.

What about our C++ simulation? We have a few options that are more interesting
than “ignore the flash reader”:

A, we can do like we did with the static memory and emulate the SPI flash in
gateware, and put that into the design when elaborating for CXXRTL.

This approach is fine for simple external interfaces, but for more complex ones,
such an implementation may not be feasible, and writing gateware for sim means
writing testbenches for your sim gateware. It’s also going to run as slow as any
other logic.

B, we can emulate the SPI flash in C++ by watching the top-level output pins and
toggling input pins as necessary. This is straight-forward, though it means you
have to co-simulate your peripheral at the same time as stepping the design.

C, we can drop a blackbox into the design, and hook up the SPI reader module to
the blackbox instead of external IO. Then, we implement the blackbox internals
in C++.

<br>

![Chisel code sample that describes a whitebox, pointing to a C++ class definition that matches it with no implementation details, pointing in turn to a subclass of that class which overrides and fills out the logic.](/assets/post-img/chiselcxx/slides.008.jpeg)

This is where CXXRTL’s blackbox support comes in: you give it a module interface
definition, and it generates a C++ class for it the same way it would for any
other non-flattened module in your design. Then you subclass it, implementing
logic internal to the blackbox in C++, reacting to events at the simulation step
level, without having to rewrite your whole simulation driver into an event
loop.

This is super powerful, and it’s a lot easier to implement a peripheral in
full-blown C++ than it is in gateware.

<br>

![C++ logo in the middle with the flash chip again. Now a fourth point is added: D. Simulate the module itself with a blackbox implementation that produces the right IOs.](/assets/post-img/chiselcxx/slides.009.jpeg)

Now, I tend to call this approach a “whitebox” implementation, to contrast with—

D, take the SPI reader out of the design, and drop in a blackbox which emulates
the reader’s interface instead.

<br>

![Chisel code sample that dsecribes a blackbox, and the C++ logic in its subclass.](/assets/post-img/chiselcxx/slides.010.jpeg)

So whereas the whitebox watches chip-select and data-in and toggles data-out
accordingly, painstakingly pretending to be a real flash module, this blackbox
goes one level higher, and monitors the read strobe from your design and
responds to it directly. This can significantly speed up your simulation,
particularly if your design clock rate is high but the peripheral’s is much
lower, like in I²C.

As with the other non-gateware options, you can source the data from a file on
disk, a buffer compiled in, or from the network or whatever you like, it’s your
C++ code.

<br>

![Chisel code sample showing target specific wiring for three platforms: IceBreaker, CXXRTL whitebox, CXXRTL blackbox.](/assets/post-img/chiselcxx/slides.011.jpeg)

This is the target-specific gateware for this example, all in the top-level
module. Most of this depends on my little framework for Chisel, but it’s all
just ergonomics and instrumenting Yosys really.

For iCEBreaker, we instantiate a real UART driver and wire it up to the IO pins;
its control interface is connected to the stack machine. The CXXRTL targets skip
the UART and just expose the control interface at the top level. Those are what
the C++ sim driver interacts with.

Similarly, for iCEBreaker we instantiate the flash reader, connect its pins and
hook its control interface to a wire bundle. The whitebox also instantiates the
flash reader and wires the control interface, but connects its pins to the C++
whitebox module instead. The blackbox skips the reader entirely, and instead
connects the control interface wire bundle to the C++ blackbox module.

<br>

![Two README screenshots both demonstrating hardware and matching software simulations. On the left is a photograph of a 4-digit 7-segment display spelling out the word "pong". Underneath is a screenshot of software showing the same display and the same output. On the right is a screenshot of some software demonstrating a 128x128 OLED with some text and ASCII drawing characters on it. There's a photograph of an OLED display wired up to an IceBreaker showing the same output.](/assets/post-img/chiselcxx/slides.012.jpeg)

So, I really enjoy this approach! It’s a lot of fun, and being able to stub out
my design at various levels turns out to be really handy as my logic gets more
involved. CXXRTL’s simulation isn’t as fast as Verilator’s, but it’s within the
same order of magnitude, and it lets me make these changes essentially
hot-swappable, because the blackboxes are instantiated if and where they occur
in the design.

<br>

![A list of links and acknowledgements, included below the text that follows.](/assets/post-img/chiselcxx/slides.013.jpeg)

And that’s it! The main takeaway really is that you can do this kind of thing
with Yosys with any HDL — none of this is Chisel specific, it’s just what I
happened to pick. Thanks all.

* [SPI flash reader example](https://github.com/kivikakk/spifrbb)
* [Chryse, experimental framework for Chisel/Yosys](https://github.com/chryse-hdl/chryse)
* [CXXRTL primer (a little out of date now)](https://tomverbeure.github.io/2020/08/08/CXXRTL-the-New-Yosys-Simulation-Backend.html)
* [C++ logo by Sawaratsuki](https://x.com/sawaratsuki1004)
