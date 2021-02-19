---
layout: post
title: Inkplate done quick
---

I recently received an [Inkplate](https://inkplate.io), and while I'm in the
middle of a few interesting projects already, I couldn't let it sit there
unused.  Until I get a longer chunk of time to turn it into something really
nifty --- maybe an embedded debugging helper of some kind --- it can at least
mean I no longer need to have Mail.app open.

[kmlyink](https://github.com/kivikakk/kmlyink)'s README explains:

> This repo has two parts:
>
> - a Dockerised IMAP proxy written in Ruby.
>
>   It speaks plain HTTP, like an ESP can manage. It just fetches your Inbox
>   listing and puts it in JSON.
>
> -  a MicroPython module that connects to your wifi, speaks to the IMAP proxy,
>    and formats it into the display.

It took just a few hours to get it all up and running.  Delightful!

![A photo of kmlyink in action. There's some emails listed on an e-ink
display.](/assets/post-img/kmlyink.jpg)

