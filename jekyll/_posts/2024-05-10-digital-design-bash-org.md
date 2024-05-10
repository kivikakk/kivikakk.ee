---
layout:      post
title:       "Digital design bash.org"
---

Identities changed to protect the innocent.

<code style="font-family: monospace;">
<span style="opacity: 0.6">&lt;</span><span style="color: green">pestopasta</span><span style="opacity: 0.6">&gt;</span> How do you do 128bit memory buses and stuff like that<br>
<span style="opacity: 0.6">&lt;</span><span style="color: green">pestopasta</span><span style="opacity: 0.6">&gt;</span> Like what is going on in those 128 bits<br>
<span style="opacity: 0.6">&lt;</span><span style="color: orange">Rice</span><span style="opacity: 0.6">&gt;</span> uh, data that's being read from or written to memory?<br>
<span style="opacity: 0.6">&lt;</span><span style="color: orange">Rice</span><span style="opacity: 0.6">&gt;</span> What is the issue you're not understanding<br>
<span style="opacity: 0.6">&lt;</span><span style="color: green">pestopasta</span><span style="opacity: 0.6">&gt;</span> <span style="opacity: 0.6">@</span><span style="color: orange">Rice</span> What is transferred over it<br>
<span style="opacity: 0.6">&lt;</span><span style="color: pink">HamSandwich</span><span style="opacity: 0.6">&gt;</span> data that's being read from or written to memory 👀<br>
<span style="opacity: 0.6">&lt;</span><span style="color: green">pestopasta</span><span style="opacity: 0.6">&gt;</span> <span style="opacity: 0.6">@</span><span style="color: pink">HamSandwich</span> Yea. How do you manage 128 bits though. That's a lot<br>
<span style="opacity: 0.6">&lt;</span><span style="color: pink">HamSandwich</span><span style="opacity: 0.6">&gt;</span> They are written to and from caches via the cache controller, not the core. The core has a maximum of 32-bit access.<br>
<span style="opacity: 0.6">&lt;</span><span style="color: orange">Rice</span><span style="opacity: 0.6">&gt;</span> <span style="opacity: 0.6">@</span><span style="color: green">pestopasta</span> ...the same way you handle 32 or 64 bits of data, just double or quadruple?<br>
<span style="opacity: 0.6">&lt;</span><span style="color: green">pestopasta</span><span style="opacity: 0.6">&gt;</span> I don't know what you mean. Is there a video explaining this?
</code>