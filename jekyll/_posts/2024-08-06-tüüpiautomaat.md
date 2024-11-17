---
layout:      post
title:       "Tüüpiautomaat: automated testing of a compiler and target against each other"
categories:  ["zig"]
---

I'm currently working on a bit of a [long-winded project][ava] to recapture
[QuickBASIC][quickbasic], the environment I learned to program in, in a bit of
a novel way, while remaining highly faithful to the original. (I actually
started a related project [9 years ago][kyuubey] (!), and I'll be able to reuse
some of what I did back then!)

The new project involves compiling the BASIC down into a bytecode suitable for
a stack machine, and an implementation of such a stack machine. Importantly,
there'll soon be a second implementation which runs on a different architecture
entirely: namely, it'll be an implementation _of_ this architecture on an FPGA.
So the machine needs to be reasonably easy to implement in hardware --- if it
simplifies the gateware design, I'll happily take tradeoffs that involve making the
compiler more complicated, or the ISA more verbose.

The ISA started out with opcodes like:

```zig
pub const Opcode = enum(u8) {
    PUSH_IMM_INTEGER = 0x01,
    PUSH_IMM_LONG = 0x02,
    PUSH_IMM_SINGLE = 0x03,
    PUSH_IMM_DOUBLE = 0x04,
    PUSH_IMM_STRING = 0x05,
    PUSH_VARIABLE = 0x0a,
    // [...]
    OPERATOR_ADD = 0xd0,
    OPERATOR_MULTIPLY = 0xd1,
    OPERATOR_NEGATE = 0xd2,
    // [...]
};
```

For the binary operations, the stack machine would pop off two elements, and then
look at the types of those elements to determine how to add them. This is easy to
do in Zig, but this is giving our core a lot of work to do --- especially when we
consider how extensive the rules involved are:

![Screenshot of QuickBASIC 4.5 open to the "Type Conversions" help page.
It's scrolled some way down and yet the screen is full of text describing how
operands are converted to the same degree of precision, and further how result
types may affect that.](/assets/post-img/typeconversions.png)

Ideally, the executing machine doesn't _ever_ need to check the type of a value
on the stack before doing something with it --- the bytecode itself can describe
whatever needs to happen instead.

In other words, when compiling this[^highlighting]:

[^highlighting]: I will get some real BASIC highlighting up here by the next
                 post on this!

```zig
a% = 42       ' This is an INTEGER (-32768..32767).
b& = 32800    ' This is a LONG (-2147483648..2147483647).
c% = b& - a%  ' This should result in c% = 32758.  A smaller a% would result in overflow.
```

... instead of having an op stream like this:

```zig
PUSH_IMM_INTEGER(42)
LET(0)
PUSH_IMM_LONG(32800)
LET(1)
PUSH_VARIABLE(1)
PUSH_VARIABLE(0)
OPERATOR_SUBTRACT     // runtime determines it must promote RHS and do LONG subtraction
CAST_INTEGER          // runtime determines it has a LONG to demote
LET(2)
```

--- and so leaving the runtime environment to decide when to promote, or demote,
or coerce, and when to worry about under/overflow --- we instead have this:

```zig
PUSH_IMM_INTEGER(42)
LET(0)
PUSH_IMM_LONG(32800)
LET(1)
PUSH_VARIABLE(1)
PUSH_VARIABLE(0)
PROMOTE_INTEGER_LONG     // compiler knows we're about to do LONG subtraction
OPERATOR_SUBTRACT_LONG
COERCE_LONG_INTEGER      // compiler knows we're assigning to an INTEGER
LET(2)
```

A proliferation of opcodes results, but crucially it means most operations
execute unconditionally, resulting in a far simpler design when it comes to
putting this on a chip.

The upshot of this design, however, is that the compiler needs a far greater degree
of awareness and ability:

* It needs to be aware of what types the arguments to the binary operation are.

  In the example above, we have a LONG and an INTEGER. This appears trivial, but
  we need to keep in mind that the arguments can be arbitrary expressions.

  We need this in order to determine the opcode that gets emitted for the
  operation, and to know if any operand reconciliation is necessary.
  
* It needs to be able to reconcile different types of operands, where necessary.

  BASIC's rules here are simple: we coerce the lesser-precision
  value to the greater precision. In effect the rule is
  INTEGER&nbsp;<&nbsp;LONG&nbsp;<&nbsp;SINGLE&nbsp;<&nbsp;DOUBLE.
  
  STRING is not compatible with any other type --- there's no <nobr><code>"x" * 3 = "xxx"</code></nobr> here.

* It needs to be aware of what type a binary operation's result will be in.

  I started out with the simple rule that the result will be of the same type
  of the (reconciled) operands. This worked fine when I just had addition,
  subtraction and multiplication; above, we add a LONG and an INTEGER, the INTEGER
  gets promoted to a LONG, and the result is a LONG.
  
  Division broke this assumption, and resulted in the motivation for this
  write-up.

* It needs to be able to pass that information up the compilation stack.

  Having calculated the result is a LONG, we need to return that information to
  the procedure that compiled this expression, as it may make decisions based
  on what's left on the stack after evaluating it --- such as in the first
  dot-point here, or when assigning to a variable (which may be of any type, and
  so require a specific coercion).

This all kind of Just Worked, right up until I implemented division. I
discovered QuickBASIC actually has floating _and_ integer division! Young me
was not aware of the backslash "`\`" operator (or any need for it, I suppose).
Floating division always returns a floating-point number, even when the inputs
are integral. Integer division always returns an integral, even when the inputs
are floating. The precision of the types returned in turn depends on that of the
input types.

| operands | fdiv "`/`" | idiv "`\`" |
| -------: | ---------: | ---------: |
|  INTEGER |     SINGLE |    INTEGER |
|     LONG |     DOUBLE |       LONG |
|   SINGLE |     SINGLE |    INTEGER |
|   DOUBLE |     DOUBLE |       LONG |

<p><center><em>Output types of each division operation given (reconciled) input type.</em></center></p>

This presented a problem for the existing compiler, which assumed the result
would be the same type of the operands: having divided two INTEGERs, for
example, the bytecode emitted _assumed_ there would be an INTEGER left on the
stack, and so further emitted code would carry that assumption.

Upon realising how division was supposed to work, the first place I made the
change was in the actual stack machine: correct the behaviour by performing
floating division when floating division was asked for, regardless of the
operand type. Thus dividing two INTEGERs pushed a SINGLE. The (Zig) machine then
promptly asserted upon hitting any operation on that value at all, expecting an
INTEGER there instead. (The future gateware implementation would probably not
assert, and instead produce confusing garbage.)

And so opened up a new kind of bug to look out for: a mismatch between (a)
the assumptions made by the compiler about the effects on the stack of the
operations it was emitting, and (b) the actual effects on the stack produced by
those operations running on the stack machine.

Rather than just some isolated tests (though short of creating some whole
contract interface between compiler and machine --- maybe later), why not be
thorough while using the best witness for behaviour there is? Namely, the
compiler and stack machine themselves:

```zig
test "compiler and stack machine agree on binop expression types" {
    for (std.meta.tags(Expr.Op)) |op| {
        for (std.meta.tags(ty.Type)) |tyLhs| {
            for (std.meta.tags(ty.Type)) |tyRhs| {
                var c = try Compiler.init(testing.allocator, null);
                defer c.deinit();

                const compilerTy = c.compileExpr(.{ .binop = .{
                    .lhs = &Expr.init(Expr.Payload.oneImm(tyLhs), .{}),
                    .op = loc.WithRange(Expr.Op).init(op, .{}),
                    .rhs = &Expr.init(Expr.Payload.oneImm(tyRhs), .{}),
                } }) catch |err| switch (err) {
                    Error.TypeMismatch => continue, // keelatud eine
                    else => return err,
                };

                var m = stack.Machine(stack.TestEffects).init(
                    testing.allocator,
                    try stack.TestEffects.init(),
                    null,
                );
                defer m.deinit();

                const code = try c.buf.toOwnedSlice(testing.allocator);
                defer testing.allocator.free(code);

                try m.run(code);

                try testing.expectEqual(1, m.stack.items.len);
                try testing.expectEqual(m.stack.items[0].type(), compilerTy);
            }
        }
    }
}
```

We go as follows:

* For all binary operations, enumerate all permutations of left- and right-hand
  side types.

* For each such triple, try compiling the binary operation with the "one"-value[^one]
  of each type as its operands. (For integrals, it's literally the number one.)

  * If we get a type error from this attempt, skip it --- we don't care that we can't
    divide a DOUBLE by a STRING, or whatever.

  * If not, the `compileExpr` method returns to us the type of what it believes
    the result to be. This is the same information used elsewhere in the
    compiler to guide opcode and coercion decisions.

* Create a stack machine, and run the compiled code.

  * Seeing as we didn't actually compile a full statement, we expect the result
    of the operation to be left sitting on the stack. (Normally a statement
    would ultimately consume what's been pushed.)

* Assert that the type of the runtime value left on the stack is the same as
  what the compiler expects!

[^one]: I first used each type's zero value, but then we get division by zero errors while trying
        to execute the code!

I love how much this solution takes care of itself. While it lacks the
self-descriptive power of a more coupled approach to designing the compiler and
runtime, it lets the implementations remain quite clear and straightforward to
read. It also lets them stand alone, which is handy when a second implementation
of the runtime part is forthcoming, and is (by necessity) in a completely
different language environment.

There was greater value than just from floats, of course: relational operators
like equal "`=`", not equal "`<>`", etc. all return INTEGERs 0 or -1, but
can operate with any combination of numeric types, or with pairs of STRINGs.
Bitwise operators like `AND`, `OR`, `XOR`, `IMP` (!), etc. can operate with any
combination of numeric types, but coerce any floats to integrals before doing
so. I bet there'll be more to uncover, too.

Hope this was fun to read!

[ava]: https://github.com/charlottia/ava
[quickbasic]: https://en.wikipedia.org/wiki/QuickBASIC
[kyuubey]: https://github.com/kivikakk/kyuubey
