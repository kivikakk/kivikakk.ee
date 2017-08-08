---
layout: post
title: "Escapology: how, when and why to encode and escape"
date: 2012-04-18T11:10:00Z
categories: 
---

I originally published this post on a previous blog on this date.  That blog
has since been removed, but I think it's a decent enough post to revive.

----

As programmers, we spend a lot of time just carting data from one place to
another.  Sometimes that's the entire purpose of a program or library (data
conversion whatevers), but more often it's just something that needs to happen
in the course of getting a certain task done.  When we're sending a request,
using a library, executing templates or whatever, it's important to be 100%
clear on the format of the data, which is a fancy way of saying how the data is
encoded.

Let's do the tacky dictionary thing:

> **[encoding](http://en.wiktionary.org/wiki/encoding)** (*plural* encodings)
>
> 1. (computing) The way in which symbols are mapped onto bytes, e.g. in the
> rendering of a particular font, or in the mapping from keyboard input into
> visual text.
>
> 2. A conversion of plain text into a code or cypher form (for decoding by the
> recipient).

I think these senses are a bit too specific---if your data is in a computer in
any form, then it's already encoded.  The keyboard doesn't even have to come
into it.

If you're like me and you come from an English-speaking country, there's a good
chance that this might seem farfetched, or totally obvious but lacking in
depth.  The letter `A` is represented in ASCII by the integer 65, or hex `41`.

From hereon, if I refer to a number with regular formatting, it's decimal
unless specified otherwise; likewise with `code` formatting, it's hexadecimal.

You are also probably aware that non-Latin characters like `恋` do not have any
mapping in ASCII, that people all tried to make their own ways to get around
this---none of which interoperated particularly well---and that at some stage,
a bunch of smart people decided to create Unicode, which assigns a unique
integer codepoint to every character of every language (and then some), such
that the character just mentioned is `U+604b`, and that there are character
encodings, like UTF-8, which are used to represent the codepoints in a
bytestream, such that `恋` becomes `e6 81 8b`.

This is all well and good.  But what do you do with this stuff in your program?

Firstly, we need to straighten out what your environment does, or doesn't do,
with character encodings.  I'm going to use PHP, Erlang and HTML as my
examples, because they're things I work with at work, and they each have
slightly different ways of dealing with encoding [^php-silly] owing to their
internal representation of strings.

Secondly, I'm going to expand this beyond character encodings to **any
encoding**---which is ultimately what I want to talk about here.  We're not
just encoding the textual content for decoding into codepoints; we're also
often encoding data to put it within other data in a demarcated way.  In this
case, we tend to refer to **escaping**, but escaping and encoding are different
ways of talking about the same *process*.

## PHP

The best way to describe PHP's character encoding is with the words "not at
all".  Strings do not have metadata associated with encoding; to all string
manipulation functions, a string might as well be an array of bytes,
representing the raw bytes from the disk that occured between two ASCII `"`
(`22`) characters.

In other words, PHP treats the input PHP file as byte soup---nominally ASCII.

Say I want to store `恋は戦争` [^love-is-war] in a string in PHP.  I boot up my
editor, open a new file called `koi.php` and enter:

{% highlight php %}
<?

$koi = "恋は戦争";

echo $koi;

?>
{% endhighlight %}

What do I get?

![The text "恋は戦争" displays correctly in my
browser.](/img/koihasensou-utf8.png)

Hey, the text displays correctly!  PHP must be super-smart and it's doing
everything right!  Right?

Maybe.  My text-editor decided to save the file in UTF-8 by default.  If I was
in Japan and I dealt mostly with Japanese, it could be that I tended to save
files in some popular non-Unicode encodings, like
[Shift JIS](http://en.wikipedia.org/wiki/Shift_JIS) or
[ISO-2022-JP](http://en.wikipedia.org/wiki/ISO-2022-JP).

What happens if I resave the file in Shift JIS?

![Non-descript characters appear instead.](/img/koihasensou-sjis.png)

*[Mojibake!](http://en.wikipedia.org/wiki/Mojibake)*  Character encoding issues
are so common, Japanese has a word for it.

What happened?  PHP actually has no idea about what the text is, encoding,
whatever.  When it looks at the file, it sees this:

    0000000: 3c3f 0a0a 246b 6f69 203d 2022 97f6 82cd  <?..$koi = "....
    0000010: 90ed 9188 223b 0a0a 6563 686f 2024 6b6f  ....";..echo $ko
    0000020: 693b 0a0a 3f3e 0a                        i;..?>.

Note that we have a `22` at byte `0b`, indicating the start of a string, and
then another `22` at byte `14`.  I'm contending that the bytes between---i.e.
`97 f6 82 cd 90 ed 91 88`---are what gets stored in the string, without any
further knowledge.

If this were the case, then `strlen($koi)` should be equal to `8` (despite
there being `4` Japanese characters).  I modify `koi.php`, still in Shift JIS:

{% highlight php %}
<?

$koi = "恋は戦争";

echo strlen($koi) . "<br>\n";
echo $koi;

?>
{% endhighlight %}

And now?

![The number 8 prefaces the mojibake.](/img/koihasensou-sjislen.png)

*[Yappari](http://patrickmccoy.typepad.com/lost_in_translation/2006/02/yappari_thats_r_1.html)*.
PHP has *no clue* what encoding the string is in---it's just saving those
bytes, counting them, and throwing them back out.  So why does the UTF-8 one
look alright in the browser and the Shift JIS one doesn't?

The first tripping point is the webserver; the Apache on the machine I'm
testing has this directive in a conffile:

    AddDefaultCharset UTF-8

Sure enough, when we take a look at the headers sent on the wire:

    HTTP/1.1 200 OK
    Date: Wed, 18 Apr 2012 04:17:51 GMT
    Server: Apache/2.2.11 (Fedora)
    X-Powered-By: PHP/5.2.9
    Content-Length: 14
    Connection: close
    Content-Type: text/html; charset=UTF-8

So the browser is trying to read the Shift JIS as UTF-8, hence mojibake.  We
can force that by adding an appropriate [`header()`](http://php.net/header)
call, but it goes to show that PHP isn't cognisant of what's going on here.

Another grand example is using other built-in string functions.
[`str_replace()`](http://php.net/str_replace) and
[`substr()`](http://php.net/substr) are fraught with difficulty, no matter what
encoding you use.

We haven't even hit the fun stuff yet.  What happens if we use another popular
Japanese encoding, ISO-2022-JP?  ISO-2022, also known as ECMA-35, is a standard
for mechanisms for encoding foreign language text, and is used for Japanese in
ISO-2022-JP, Chinese in ISO-2022-CN, and more, including extensions of the
same.

Being a more complicated system, it fails to make some guarantees about the
encoded data which other encodings do make; Shift JIS, for instance, [does not use common ASCII special characters in its second byte](http://en.wikipedia.org/wiki/Shift_JIS#Shift_JIS_byte_map),
such as `$`.  This means a `$` symbol in Shift JIS-encoded text always means a
`$`, whereas the letter `A` could occur as either a literal `A`, or as the
second byte in a double-byte character [^mb-encoding].

Keeping in mind that ISO-2022-JP doesn't exercise such care, let's see what we
get ...

![We get a few "undefined variable" PHP
warnings.](/img/koihasensou-iso2022jp.png)

Uhhhh.  What's stored on the disk?

    0000000: 3c3f 0a0a 246b 6f69 203d 2022 1b24 424e  <?..$koi = ".$BN
    0000010: 7824 4f40 6f41 681b 2842 223b 0a0a 6563  x$O@oAh.(B";..ec
    0000020: 686f 2073 7472 6c65 6e28 246b 6f69 2920  ho strlen($koi) 
    0000030: 2e20 223c 6272 3e5c 6e22 3b0a 6563 686f  . "<br>\n";.echo
    0000040: 2024 6b6f 693b 0a0a 3f3e 0a               $koi;..?>.

The ISO-2022-JP encoding of `恋は戦争` contains the byte-sequence `24 42 4e 78
24 4f`, which is `$BNx$O` in ASCII---so PHP tries to interpolate variables so
named.

Of course, this means even scarier things are possible.  I replaced `恋は戦争`
with `あ`---the Japanese letter "a", essentially---and we get:

![A warning and a parse error.](/img/a-iso2022jp.png)

Whoops!  On the disk:

    0000000: 3c3f 0a0a 246b 6f69 203d 2022 1b24 4224  <?..$koi = ".$B$
    0000010: 221b 2842 223b 0a0a 6563 686f 2073 7472  ".(B";..echo str
    0000020: 6c65 6e28 246b 6f69 2920 2e20 223c 6272  len($koi) . "<br
    0000030: 3e5c 6e22 3b0a 6563 686f 2024 6b6f 693b  >\n";.echo $koi;
    0000040: 0a0a 3f3e 0a                             ..?>.

`あ` encodes as `1b 24 42 24 22 1b 28 42`.  Those playing at home will notice a
`22`---i.e. `"`---is stuck in the middle, so PHP thinks you've prematurely
terminated the string.

The solution is to encode your source files as UTF-8, because UTF-8 guarantees
that all ASCII characters---that is, values `00` through `7f`---are both mapped
to the same byte in UTF-8, *and* that those bytes will not occur in a UTF-8
stream as part of any other character.  UTF-8 is [marvelously
well-designed](http://en.wikipedia.org/wiki/UTF-8#Description) (actually).

This means that PHP won't do anything funny with your strings, though it still
treats it like a bag of bytes.  Next, use only the [multibyte string extension](http://php.net/manual/en/book.mbstring.php)
to do string operations.  For instance, let's revert back to the `恋は戦争`
example in UTF-8, and use [`mb_strlen()`](http://php.net/mb_strlen) instead of
the plain variety:

{% highlight php %}
<?

$koi = "恋は戦争";

echo mb_strlen($koi) . "<br>\n";
echo $koi;

?>
{% endhighlight %}

And we see:

![12!?](/img/koihasensou-utf8len.png)

Whoops.  That's raw bytes again!  The multibyte module has no idea what
encoding to use, so if we don't tell it, it behaves as usefully as
[`strlen()`](http://php.net/strlen). We have to tell it, and in a very PHP-like
manner, we set a **global** state for the interpreter.  Great.

{% highlight php %}
<?

mb_internal_encoding("UTF-8");

$koi = "恋は戦争";

echo mb_strlen($koi) . "<br>\n";
echo $koi;

?>
{% endhighlight %}

And finally:

![The number 4. Hallelujah.](/img/koihasensou-utf8lenmb.png)

Onto saner pastures.

## Erlang

Erlang is a funny language.  [It doesn't even *have*
strings](http://learnyousomeerlang.com/starting-out-for-real#lists)[^inconvenient-truth].
Instead, a string is a list of numbers; the REPL guesses that a list should be
pretty-printed as a string if they all look like printable ASCII:

{% highlight erlang %}
1> "Hello.".
"Hello."
2> [72, 101, 108, 108, 111, 46].
"Hello."
3>
{% endhighlight %}

lol!  Gnarly!  But seriously, this accidentally becomes great when you start
Unicoding it up like you're part of the UN:

{% highlight erlang %}
3> S = "恋は戦争".
[24651,12399,25126,20105]
4>
{% endhighlight %}

Huh!?  Well, they're not printable ASCII, so what *are* they?  Let's translate
those pesky decimals into something humans can read:

{% highlight erlang %}
4> [io:format("~4.16.0b, ", [N]) || N <- S], ok.
604b, 306f, 6226, 4e89, ok
5>
{% endhighlight %}

`604b`?  [Doesn't that sound familiar?](#604b).  It's actually interpreting
each Unicode *character* (not each *byte*) as its integer codepoint.  That
means all lovely things we want to assume hold true, like length calculation
and substrings:

{% highlight erlang %}
5> length(S).
4
6> io:format("~ts~n", [lists:sublist(S, 3, 2)]).
戦争
ok
7>
{% endhighlight %}

So Erlang provides a pretty good native data-type for storing Unicode
characters; pre-Unicode, we were just storing the numbers of ASCII characters
in a list, so now we just store the numbers of Unicode codepoints instead.

Unfortunately, the simplicity of *entry* does not extend to source files.
D'oh!  The Erlang manual specifies that source must be entered in
[ISO-8859-1](http://en.wikipedia.org/wiki/ISO/IEC_8859-1), also known as
"Latin-1" encoding.  Only the REPL is smart enough to do Unicode.  This is
detailed in [the Erlang manual](http://www.erlang.org/doc/apps/stdlib/unicode_usage.html#id62505).

So you could consider that it's difficult to get Unicode data *into*
Erlang---in that you can't enter it directly into the source---but once you
have it, it's much more straightforward to manange than with, say, PHP.  The
reality is, most Unicode data in your program will be coming from *without*
your program, not within---i.e. user input, API call results, etc.---so this
isn't as bad as it sounds.

Erlang doesn't store metadata about the encoding; it avoids the problem
entirely by letting strings represent Unicode natively.  Once you start sending
or receiving them on the wire, you'll usually want convert them to or from
binary strings with functions from the
[`unicode`](http://www.erlang.org/doc/man/unicode.html) module, which provides
helpers for various UTF encodings, and Latin-1.  Once so-converted, the data is
unambiguously opaque ... compared with PHP's "I don't have a clue *what* it is".

## HTML

This is a huge kludge.

HTML itself contains a way to declare its own encoding, using a [`<meta>` tag](http://en.wikipedia.org/wiki/Meta_element)
to declare the [Content-Type](http://en.wikipedia.org/wiki/MIME#Content-Type)
of the document.  The issue, if you weren't paying attention, is that reading
the `<meta>` tag implies you are able to make any sense of the document
whatsoever.  Valid HTML requires the `<meta>` to appear within the `<head>`,
i.e. for HTML 5:

{% highlight html %}
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  ...
{% endhighlight %}

This isn't a problem with sane encodings, because they tend to map ASCII
through; but things like UTF-16 and above require the server to declare the
content-type in the HTTP headers; interpreting
[UTF-32](http://en.wikipedia.org/wiki/UTF-32) as ASCII leads to madness.

For comparison's sake, the layout on disk of the above in UTF-8 (identical to
ASCII here):

    00000000: 3c21 646f 6374 7970 6520 6874 6d6c 3e0a  <!doctype html>.
    00000010: 3c68 746d 6c3e 0a3c 6865 6164 3e0a 2020  <html>.<head>.  
    00000020: 3c6d 6574 6120 6368 6172 7365 743d 2275  <meta charset="u
    00000030: 7466 2d38 223e 0a                        tf-8">.  ....

And in UTF-32:

    00000000: 0000 003c 0000 0021 0000 0064 0000 006f  ...<...!...d...o
    00000010: 0000 0063 0000 0074 0000 0079 0000 0070  ...c...t...y...p
    00000020: 0000 0065 0000 0020 0000 0068 0000 0074  ...e... ...h...t
    00000030: 0000 006d 0000 006c 0000 003e 0000 000a  ...m...l...>....
    00000040: 0000 003c 0000 0068 0000 0074 0000 006d  ...<...h...t...m
    00000050: 0000 006c 0000 003e 0000 000a 0000 003c  ...l...>.......<
    00000060: 0000 0068 0000 0065 0000 0061 0000 0064  ...h...e...a...d
    00000070: 0000 003e 0000 000a 0000 0020 0000 0020  ...>....... ... 
    00000080: 0000 003c 0000 006d 0000 0065 0000 0074  ...<...m...e...t
    ...

(it goes on like this)

Triples of `NUL`-bytes separating everything!  This is UTF-32's grand plan to
support everything without variable-width encoding, meaning operations like
string length, slicing and substring matching could be done fairly
cheaply[^utf-32-clusterfuck].

In these cases you should be ensuring the server sends the correct
`Content-Type`, implying the server has a clue---and if you're lucky, enough
users' browsers will guess.

This could be considered a non-solution.

The other thing HTML brings to the table, via SGML, is character entity
references, giving you the ability to [refer to any Unicode character by
codepoint](http://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references).
This doesn't make for happy editing, but it does mean that HTML can *represent*
arbitrary Unicode characters even when the HTML itself is ASCII, for instance.


## Representing Unicode characters

This is an important concept.  In HTML, one can enter:

{% highlight html %}
&#x604b;&#x306f;&#x6226;&#x4e89;
{% endhighlight %}

And get this in their browser:

![The text "恋は戦争".](/img/koihasensou-utf8.png)<!-- Yes, I'm reusing this
image. -->

This is without any other markup or declaration of encoding; we're telling the
browser to render the characters by Unicode codepoint directly.  This is
equivalent to entering them into a list in Erlang source directly:

{% highlight erlang %}
[16#604b, 16#306f, 16#6226, 16#4e89]
{% endhighlight %}

It's important to make clear a distinction here, however: HTML is *markup*, and
Erlang is a *programming language*.  HTML gives you an escape route to render a
given codepoint, which is good, but what we're talking about when we talk about
Erlang is actually an **internal representation**.

This is what I'm more interested in, so I'll put HTML to the side for now.

When data enters your Erlang program, it's most likely going to be encoded in
some form; whichever service receives that data is responsible for making sense
of it.  Imagine you're writing a webserver: people might submit forms in UTF-8,
UTF-16, Shift JIS, Latin-1, whatever.  No matter what you're doing with that
data---you might be spitting it right back in the response; hacking it up into
pieces; storing in a database, maybe for later hacking---you need to normalise
the format of the data *while you still know what format it's in*.

If you're coding in PHP and you receive a string full of bits, if you throw
that into a database without noting the encoding
[^whose-encoding-is-it-anyway], you've permanently lost the ability to say for
sure what the data actually is.

The solution, then, is to normalise the data at the point of entry, once, and
to normalise it into an *internal format* that makes sense.  In Erlang, you
might store a string as a codepoint list.  In PHP, you've little option but to
normalise it to another encoding like UTF-8, and to decide that UTF-8 *is* the
internal format for textual data.

## Check your blindspots

Do **not** fall into the trap of saying "well, I know my users will only enter
Latin-1 data, which happens to be the default, so I'll just save that and print
that."  Guess what?  That's what most of Japan said when they decided to use
Shift JIS.  Except for those who used ISO-2022-JP.  Or EUC-JP.  Good luck to
most of these people when people from other countries start submitting data.

If you won't listen to me, listen to the experience of the top 25 Japanese
websites according to Alexa.  [A forum post from
mid-2007](http://www.webmasterworld.com/printerfriendlyv5.cgi?forum=32&discussion=3373673&serial=3376486&user=)
detailed 10 of them using UTF-8.  When I check the other 15, 8 have moved to
UTF-8, leaving 7 not using UTF-8.  3 of those are on Shift JIS because they're
either tailored for the Japanese mobile market---which endemically tends to
only support Shift JIS (Japanese mobile phones are not like your mobile phones)
---or because they make heavy use of [Shift_JIS
art](http://en.wikipedia.org/wiki/Shift_JIS_art).

Storing data authentically is something that, as programmers, we need to get
used to, and clobbering data that doesn't conform to your expectation makes no
sense.

When data comes in, store it in a normal form.  If you're building a webservice
in a sane language or framework, it's probable that the environment has done
this work for you.

## Don't escape data

The key is to strongly mark the boundaries of keeping data in one format and
another.  Strongly-typed languages can distinguish this at compile time and
stop mistakes, but that's a rant for another day.

I'm going to start talking about another encoding process, often referred to as
escaping.

Pop-quiz: what's wrong with this PHP?

{% highlight php %}
<?

// Omitted: init.

$username = $_POST["username"];
$password = $_POST["password"];
mysql_query("INSERT INTO tblUsers VALUES ('$username', '$password')");

?>
{% endhighlight %}

A related question is "what's *not* wrong with this PHP?".  I can think of nine
separate issues with it [^php-issue-register], but let's look at the obvious
one: `$username` and `$password` are inserted into the query unescaped.  Maybe.

Unless you live under a rock, you'll recognise the [SQL injection attack](http://en.wikipedia.org/wiki/SQL_injection),
also known as **SQLi**.  The issue is because we're substituting
`$username`---which we should think of as user data---directly into the stream
of a MySQL command.  By doing so, we're essentially saying that the user data
*is* part of a MySQL command---because it is.  A user could enter `"'); DROP TABLE tblUsers; --`,
and because we failed to encode user data as user data (which really means
escaping here), it happens.

So how do we "encode" data?  The correct way is to let the layer of abstraction
handle that for you.  If you use [PDO](http://php.net/manual/en/book.pdo.php),
and put the laundry list of issues with the above code aside, it looks like
this:

{% highlight php %}
<?

// Omitted: init, database connection in $db.

$stmt = $db->prepare('INSERT INTO tblUsers VALUES (:username, :password)');

$stmt->execute(array(
	':username' => $_POST["username"],
	':password' => $_POST["password"],
));

?>
{% endhighlight %}

We let PDO deal with constructing the query---being the most-informed part of
the system to deal with query parameter encoding.  If we do it ourselves, we'll
probably make a mistake.

Note that **we are *not* escaping the data**---we're deciding that another part
of the system which knows how to do it should do it instead.  Knowing when
**not** to escape is often just as important as knowing when **to** escape.

### Caveat

Q. When will the above go terribly wrong?

A. [When a deficient language tries to automate security](http://php.net/manual/en/security.magicquotes.php),
and finds that's actually not possible according to the definition of security.

Hello, your database is now full of backslashes.  Unfortunately, magic quotes
is enabled at the level of the webserver, so if your host has it enabled, you
have to try to turn it off.  [Look at that Example #2.  Mmmmmm.](http://www.php.net/manual/en/security.magicquotes.disabling.php)

Do **not** rely on broken auto-escaping.  Your code will become unportable (and
insecure) if you end up hosting the same stuff elsewhere where this process
does not take place.  It's tantamount to assuming all data will come in encoded
in UTF-16 and being surprised when your application breaks at inopportune moments.

## The golden rule

So, what's the guiding principle?

**Data in your application should be *semantically pure***.

If this doesn't make any sense to you, read it once more, and I'll explain.

**Data in your application should be *semantically pure***.

Let's say you take a username as input in a web application.  When the client
makes the request and sends us this username, we receive it into a variable.
What does the variable contain, right from the start?  Is it the exact text
they entered?  Does it have quotes escaped?  Are characters like `<` and `>`
converted to HTML entities so we can output it back into the page if we need
to?

No.  The variable contains the username.  *Nothing* else.

It is not escaped.  It has no special encoding **other** than the normalisation
about textual data encoding we've already discussed.  It is in *no way* prepped
for output, because it is the *pure* username.

*When* we want to output it, we pass it to the presentation layer *pure*, and
let the presentation layer apply as many post-processing layers of encoding as
is required for the context.  It will probably convert special characters to
entities if they could cause issues.  If it's being put in a link URI it will
be URI encoded.  If it's ending up in some server-side generated JavaScript it
may need to be escaped appropriately.

*When* we want to do a match against the database, we pass it to the database
layer *pure*, and let the database layer perform the correct escaping for the
context.

Let's say you take a user's age as input in a web application.  You may have a
mind for UX, so you check that the field appears to contain a number.  Now,
before you start passing that variable around everywhere, what do you do?
**You represent it internally as a number**.  You call
[`intval`](http://php.net/intval) or `list_to_integer/1` and you **let the
presentation layer decide what to do with a number**.

Otherwise you're going to leave yourself open for all sorts of trouble.

The key is that the value is *semantically* pure---it carries the meaning of
the value in the programming language as it does in your mind.  No extra
backslashes in your mind?  Make sure the application sees that too.  This is
why we add structs, classes, new types and so forth; to better model the
semantics of the values in the programming language.

## MVC

The model is the purest part of the application.  You ask it for some value,
and it gives it to you, completely unadorned.  It's the controller's
responsibility to request data of the model, and to hand all requisite data so
gathered to the view; it's ultimately the view's responsibility to perform
encoding of data according to context.

Similarly, when the controller receives request data, it should parse it into
semantically meaningful values, which are then passed back to the view and into
models as appropriate.

If the view then, say, uses some of this data in a query string value, it URI
encodes it.  If it's including the data on the page directly, it converts HTML
entities to avoid [XSS](http://en.wikipedia.org/wiki/Cross-site_scripting).

And so on.

## Escape data, unescape data

I hope this entry might have shown you some of the parallels between
character-set encoding and escaping; they are both forms of processing data
into different formats, and it's nearly always a mistake to not know if this
form of processing has occurred yet on a given piece of data, anywhere in an
application.

Repeating the process (double-escaping or double-encoding) *without intending
to* means you're actually talking about those bytes that represent the encoded
data *in* the encoded data.  Without being sure of the state of your inputs,
this can happen easily, and the next time you type `恋は戦争`, you end up
seeing `æ<81><8b>ã<81>¯æ<88>¦äº<89>`---which is what happens if you interpret
the UTF-8 bytes of the string as a Latin-1 sequence[^encodeception].

Here are some other actions analogous to encoding.

* Shell escaping.
* Wrapping in the jQuery object[^jquery-idempotency].
* Quoting people in conversation.
* Editor's comments in a quote in a newspaper.

Ultimately, it's a matter of being certain about the *type* of data you're
handling, whereby type I mean anything relevant to parsing its semantic
content.  Both dynamically- and statically-typed languages are amenable to
annotating objects with metadata concerning the operations that have been
carried out with them.

I'm also trying to point out that this is not restricted to programming
languages---it's whenever you have different categories of things being spoken
of, or different levels of abstraction.

Golang's [html/template package](http://golang.org/pkg/html/template/),
effectively performing the role of the view in MVC, does automatic encoding of
data that has come from the controller, depending on the context.  This is a
nifty feature, as it allows you to forget about escaping---so long as you are
passing it semantically pure data, of course.

If you have the template `<p>{{ "{{." }}}}</p>`, then data to be substituted at
dot will have HTML entities inserted automatically, preventing XSS attacks.
Similarly, with the template fragment 
`<a href="/?action={{ "{{." }}}}">{{ "{{." }}}}</a>` dot's content will be URI
encoded in the first instance and have HTML entities inserted in the second.

As the package documentation explains:

> This package assumes that template authors are trusted, that Execute's data
> parameter is not, and seeks to preserve the properties below in the face of
> untrusted data:
>
> Structure Preservation Property: "... when a template author writes an HTML
> tag in a safe templating language, the browser will interpret the
> corresponding portion of the output as a tag regardless of the values of
> untrusted data, and similarly for other structures such as attribute
> boundaries and JS and CSS string boundaries."
>
> Code Effect Property: "... only code specified by the template author should
> run as a result of injecting the template output into a page and all code
> specified by the template author should run as a result of the same."
>
> Least Surprise Property: "A developer (or code reviewer) familiar with HTML,
> CSS, and JavaScript, who knows that contextual autoescaping happens should be
> able to look at a {{.}} and correctly infer what sanitization happens."

This provides a lot of reassurances that we want---but then if we *do* have
some data in the controller that we *really* want to be substituted in as HTML,
what's a cute programmer such as yourself to do?

The same package provides the
[`HTML` type](http://golang.org/pkg/html/template/#HTML)
---actually, a synonym for `string`.  In Golang, type synonyms are different
types with respect to method sets---we can't use a method of one on another
(methods are not inherited)---and there is no implicit conversion between them.
Objects of different types (even where the types are synonyms) are completely
different, except that we can
[convert between them](http://golang.org/ref/spec#Conversions) as they have the
same [underlying type](http://golang.org/ref/spec#Types).  This means that we
can take a `string` and turn it into a `HTML` with a simple conversion:

{% highlight go %}
// x is of type string
x := "<p>This is delicious!</p>"

// y is of type HTML
y := HTML(x)
{% endhighlight %}

Passing an object of type HTML to `html/template` tells it that the escaping
required to sanitise HTML has already been done, and so in a context where such
escaping is necessary, the content will be included verbatim.  Of course, this
also implies you don't let user input find its way into a `HTML`-typed object
without doing necessary encoding/normalisation yourself.  I refrain from using the word "sanitisation", as the term has plenty of bad connotations which I'm about to talk about.

There are a range of other types for indicating that you've taken on the
responsibility of validating the variable contents are safe for use in given
contexts, i.e. giving the developer an escape for getting some data in which
you know you don't want re-encoded.  The important thing is that you're
categorically stating that it's so---no part of the system will assume it
otherwise.  It's safe by default, but in a way that doesn't compare to "magic
quotes", because it's happening at the view, right before output, not at data
entry, contaminating your entire application.

## For the love of all that is good

[Don't do this](http://coding.smashingmagazine.com/2011/01/11/keeping-web-users-safe-by-sanitizing-input-data/).

This is an anti-pattern.  This is **the** anti-pattern.  The author's very
first suggestion is to tell you to set the server-wide configuration for PHP to
automatically do certain escaping on some variables.  The idea is that you can
now pretend that all your variables are ready to become a part of HTML
somewhere!

Of course, if you insert these (safely) into the database, you've just inserted
HTML-sanitised data into the database.  Your database is perfectly capable of
storing the text `kivi "owl" kakk`, but now you've got a row with the value
`kivi &quot;owl&quot; kakk`.  If you still think this is a good idea, you
should leave the classroom right now.

You read this out of the database.  Maybe you want to know how many characters
long it is.  `strlen()`?  26.  Never mind that the actual displayed string is
16 when shown in HTML.  Maybe you want to use this value in an API call to some
other webservice.  You wrap it in a few objects, maybe encode it to JSON.  Now
you have to remember to *decode* the entities before you use it in non-HTML
contexts.  Though if you want to put it into HTML to be part of a URI, you have
to remember to decode it, then re-encode it with URI (component) encoding.  You
lose.

If you treat data semantically to begin with, and only encode it as appropriate
for the output at the *time* of output, we don't have an issue.  Input
filtering is just a way to make sure you'll never really know what's in a
variable.

## Conclusion

Data in your application should *mean what it means*.

When data comes in, interpret its *meaning* once, according to context.

When data goes out, encode it *meaningfully* according to context.

This applies to charsets, escaping and more.

## Postscript: PHP strings

It's interesting to note here that there is neither a PHP type which represents
a string with a given encoding---
[the PHP string is a byte-buffer](http://www.php.net/manual/en/language.types.string.php#language.types.string.details)
and no more---nor a suitable sequence-like container for arbitrary codepoints;
you could follow the same approach that Erlang takes and store codepoints as
integers within arrays, but due to PHP's impressive array
type[^array-what-array], it would be incredibly inefficient.

I'm also not finding any way to take an arbitrary list of codepoints (or a
single codepoint) and return it in a given encoding; the data is always assumed
to have come in as a string in some encoding.  Of course, you could take your
codepoints and convert them to UTF-8 yourself, and *then* treat that with the
multibyte string module.  [This appears to not be
atypical](http://stackoverflow.com/questions/1805802/php-convert-unicode-codepoint-to-utf-8).
Oh, PHP.

[^php-silly]:
    Hint: the way PHP does it is silly.  See the part on "Text" in [Eevee's
    blog post about
    PHP](http://me.veekun.com/blog/2012/04/09/php-a-fractal-of-bad-design/).

[^love-is-war]:
    Japanese *koi wa sensou*, meaning ["love is war"](http://supercell.sc/koisen/).

[^mb-encoding]:
    All encodings mentioned so far, except ASCII, are examples of
    [variable-width
    encodings](http://en.wikipedia.org/wiki/Variable-width_encoding), or
    *multibyte encodings*.

[^inconvenient-truth]:
    Well, there are binaries, but **sshhhh**, I'm in the middle of pointmaking.

[^utf-32-clusterfuck]:
    Of course, they shot themselves in all thirty-two of their feet when
    English-language text in UTF-32 resembles UTF-16 so much that browsers
    trying to auto-detect encoding when the server doesn't declare it [detect
    it as UTF-16](http://en.wikipedia.org/wiki/UTF-32#Non-use_in_HTML5), not to
    mention endianness problems also found in UTF-16 and [the terrible kludges
    to work around
    them](http://en.wikipedia.org/wiki/Byte_order_mark).

    Given UTF-16 doesn't solve any problem (well), and creates many, I find
    myself wondering why they bothered.

[^whose-encoding-is-it-anyway]:
    And how do you know the encoding?  You don't.  The browser encodes it in
    the *same encoding as it determined the page to be*.  Think about what that
    means for a bit.

[^php-issue-register]: 
    1. may need to check [`get_magic_quotes_gpc()`](http://php.net/get_magic_quotes_gpc) to know if data is encoded.
    2. password stored unhashed.
    3. we don't specify a connection object.
    4. we're using an antique MySQL library.
    5. inputs are unescaped (maybe---see point 1).
    6. escape inputs when you could use placeholders? Doing so successfully means ensuring data is *not* escaped by now; see point 1.
    7. specifying columns; inserted columns *may* cause failure, or just data going in the wrong places.
    8. use placeholders when you can use an ORM?
    9. checking return value; because who cares about data integrity?

    This list itself is an example of poorly encoded data.  Note how it's
    inconsistent as to whether the items mentioned are the issues, or the fixes.

[^encodeception]:
    Of course, note that these characters are of course embedded in *this* document with UTF-8.

[^jquery-idempotency]:
    jQuery is special in that it's never a mistake to rewrap in jQuery; the
    jQuery wrapper function is idempotent.  This is because you can
    unambiguously distinguish between an wrapped object and a not-wrapped
    object; note that the same does not hold of arbitrary strings without
    metadata attached to the string describing what encoding it should be.
    Ruby's strings, for instance, have no issues, as they carry knowledge of
    their encoding.
    
    A common practice is to prefix a variable name with a `$` if it's known to
    be wrapped in jQuery---because you've guaranteed it at the point of naming
    the variable, typically.  This is a way of making the assertion about the
    encoding obvious. Because you can't accidentally overwrap an object in
    JavaScript, usually an absence of `$` prefix implies no guarantee---it may
    be wrapped or unwrapped, and the only way to guarantee e.g. a DOM object,
    is by wrapping and then using `get`.  The point is that you can never
    mistakenly assume something to be jQuery wrapped when it isn't; you'll
    always know.

[^array-what-array]:
    Hint: there is none.  I know where you can get a hash-table-y kinda thing,
    though.
