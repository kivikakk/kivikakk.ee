---
layout: post
title:  "Breaking homegrown crypto"
date:   2016-02-20T00:56:00Z
categories: cryptography
---

Note: this is a pretty long article which does a deep dive into breaking some amateur crypto.  I go on for quite a bit.  Make a cup of tea before reading, and get ready to read some code!

### introduction

Everyone knows it.  Rolling your own cryptography is a terrible idea.  Here's [Bruce Schneier writing about it in **1999**](https://www.schneier.com/essays/archives/1999/03/cryptography_the_imp.html).  Here's [an excellent answer on the Infosec Stack Exchange](http://security.stackexchange.com/a/18198/34825) about why you shouldn't do it.  Here's [another Scheiner post](https://www.schneier.com/blog/archives/2015/05/amateurs_produc.html) with an excellent opening sentence.

This, then, is a post about a broken homegrown cryptosystem; namely, that used in [CodeIgniter](https://www.codeigniter.com), pre-2.2.  This version was current until the release of CodeIgniter 2.2, on [the 5th of June, 2014](https://ellislab.com/blog/entry/codeigniter-2.2.0-released), and you can still find sites on it today.

The attack described in the post depends on a lot of things to go right (or wrong, if you will); it's not just that they used a bad cipher, but also the fact that they rolled their own session storage, and implemented a fallback, and a dozen other things.  This is probably typical for most bugs of this class; a bunch of bad decisions which aren't thought through find their logical conclusion in complete insecurity.

Let's get into it!

### what are sessions and why do you want them?

When you visit a website, you might want to log in, and have the website remember that you're logged in.

When I was 13, I wrote a website with a "login" feature; I didn't know about cookies, so instead the logged in part of the website just passed around your credentials in URL parameters.  To obscure them from the user, the login page was actually a POST form which rendered a frameset (!); this way you'd never see your password in the address bar.

It was a great idea!  But, all it took was someone right-clicking a link and selecting "copy" and along went their credentials too.  So, an imperfect idea.

I learned about cookies.

When I verified the user's credentials against the backend (and to be honest, it was probably SQLi-filled), I put a `user_id` cookie on their machine.  When they come back, if they have the cookie, they're in!

Modifying cookies didn't seem like the easiest or most obvious thing, but eventually I tried it, and found I could become whomever I wanted to be.

I learned about sessions.

PHP's implementation ran this way: we'll throw a cookie on the user's machine, maybe called `PHPSESSID`, which is just an opaque identifier.  Session variables accumulated throughout the script execution will then get written to storage keyed by that ID; often just files in `/tmp`.

This has a few advantages:

* The user can't modify their own session data.  No more setting `user_id` or `isAdmin` for you!
* The user can't _see_ their own session data.  This one might be less obviously bad, but in general the less data you (needlessly) expose the better.
* You can perform other tricks to verify the session owner.

For instance, you could — completely hypothetically — store the user's IP address or user agent in the session.  Then, when they use the session, you confirm the session data against their IP/UA.  This prevents an attack where someone sniffs or steals the `PHPSESSID` of another user and attempts to use it themselves.


### what happens when you don't have a good place to store session data?

Say you're on a weird shared host and `/tmp` is unwritable, or shared, or filled with piranhas.  Your database has a limit of one write per minute.  Where do you put your sessions?

"Maybe," you think, "maybe I put the sessions in the cookie I give to the user!?"

This is not a bad idea.  This is essentially "store everything in the cookie" per above, although it presumes a level of structure given by the session storage mechanism.  The key realisation is that you still want those three things above:

* The user can't modify their own session data.
* The user can't see their own session data.
* You can perform other tricks to verify the session owner.

How do we stop them modifying their own session data?  You [HMAC](https://en.wikipedia.org/wiki/Hash-based_message_authentication_code) it.
Of course, most people don't _actually_ use HMAC and instead just use
**H**(*k* \|\| *m*)
or
**H**(*k* \|\| *m* \|\| *k*)
or whatever their "instincts" told them to do; the latter getting the job done while admitting a few attacks that a Sufficiently Capable (or Cashed Up) Adversary can follow through on; the former practically negligent (see [length extension attack on Wikipedia](https://en.wikipedia.org/wiki/Length_extension_attack); thanks to [nikic for the correction](https://www.reddit.com/r/PHP/comments/46pv94/breaking_codeigniters_homegrown_crypto/d06ze0h)).

So, we transmit the MAC — maybe you just append or prepend it to the session, or put it in a separate cookie, whatever — and then when we get a session back we authenticate it.  If authentication fails, we don't touch it, we throw it away; certainly we don't try to e.g. unserialise it or anything.  We didn't produce it, so it's a live wire.

That done, we now have "the user can't modify their own session", and this is a pretty good start.  We have a secure storage mechanism, albeit one where the user can see their own session data.

We can tackle the "verify the session owner" point by storing IP and UA in the session as before; they can't modify these values themselves, so an attacker can't either.  That said, they can see these values and realise they're probably used in session authentication, which makes impersonating the user that much easier.

To finally achieve a desirable level of security, we might want to stop them from seeing their session data too.  Thus we symmetrically encrypt the session data.

Done!

### what's one good way to screw this up?

[Encryption without authentication](http://security.stackexchange.com/a/2210/34825).  In other words, the user can't see their session, but *can* modify it.

At first blush, this doesn't sound so bad: they can't know what they're changing the data to, so changes are essentially random and astronomically unlikely to produce a "working" result.

In reality, it's *quite* bad: if there's any pattern to the encrypted data (i.e. it's not indistinguishable from random noise), then it can be exploited; for example, to repeat or remove certain sections of the data. With enough analysis, you could even start crafting arbitrary results.

If the encryption algorithm used is reasonable, this shouldn't be possible; any change should cause the decryption to fail or produce garbage results.  This could still be a vector for an effective DoS, though.

### what if the encryption algorithm used isn't reasonable?

Let's finally turn our attention to CodeIgniter.  As a reminder, we're looking at the pre-2.2 code, the latest release then being 2.1.4.

First, let's look at their [session storage mechanism, system/libraries/Session.php](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Session.php).  It's highly configurable (probably a bad thing); note these options and their meanings:

* `$sess_encrypt_cookie` — do we encrypt the cookie?  Defaults to false, but I bet we want this turned on.
* `$sess_use_database` — do we stick the session data in the database?  Defaults to false.  Maybe it's fine to leave this.
* `$encryption_key` — sounds very important.

If we read the constructor, we see the encryption key is indeed required, regardless of whether the cookie itself is encrypted.  Why would that be?

If we scroll down to `_set_cookie`, we can see [something strange](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Session.php#L655-L663):

{% highlight php startinline %}
if ($this->sess_encrypt_cookie == TRUE)
{
    $cookie_data = $this->CI->encrypt->encode($cookie_data);
}
else
{
    // if encryption is not used, we provide an md5 hash to prevent userside tampering
    $cookie_data = $cookie_data.md5($cookie_data.$this->encryption_key);
}
{% endhighlight %}

Pay close attention to the comment: they prevent userside tampering **if** encryption is not used.  And if it is?  Let's have a look at [Encrypt.php](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Encrypt.php).

A brief scan of `encode` and `decode` strongly suggests that no authentication is done; this means we can change the data on the client-side with ease; there's no MAC protecting it.  The natural follow-up question is, can we make anything of this leeway?

### say no to fallback

The [header of `encode`](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Encrypt.php#L103-L109) has this to say about itself:

> Encodes the message string using bitwise XOR encoding. The key is combined
> with a random hash, and then it too gets converted using XOR. The whole thing
> is then run through mcrypt (if supported) using the randomized key. The end
> result is a double-encrypted message string that is randomized with each call
> to this function, even if the supplied message and key are the same.

Do you see what I see?

> Encodes the message string using bitwise XOR encoding. The key is combined
> with a random hash, and then it too gets converted using XOR. The whole thing
> is then run through mcrypt **(if supported)** using the randomized key. The end
> result is a double-encrypted message string that is randomized with each call
> to this function, even if the supplied message and key are the same.

mcrypt is old, and [gets bad press for very valid
reasons](https://paragonie.com/blog/2015/05/if-you-re-typing-word-mcrypt-into-your-code-you-re-doing-it-wrong),
but it provides some primitives that can work.

So if it's not supported, we're left with the rest of the trash in that
paragraph.  "The key is combined with a random hash, and then it too gets
converted using XOR".  Converted?? what does that mean???

It's worth calling out [CodeIgniter's own documentation](https://cdn.rawgit.com/bcit-ci/CodeIgniter/2.1.4/user_guide/libraries/encryption.html) here:

> If Mcrypt is not available on your server the encoded message will still
> provide a reasonable degree of security for encrypted sessions or other such
> "light" purposes.

What the hell is a "light" purpose of encryption?  Those inverted commas in the
quoted portion are verbatim, I should add.  Even they aren't convinced that a
"light" purpose of encryption exists, yet they claim encrypted sessions are
such a case.  Just the foundation of your site or app's security, nbd.

Let's find out just how bad an idea it is to have "fallback crypto" that you
cooked up yourself.  And here's the thing: **it's going to get called**.  You
don't add fallback code without someone using it.  This stuff is criminally bad; you can't say "oh well, it's a fallback, no-one should use it".  If that's the case, remove it; fail to work without the dependency.

This is exactly what they did in 2.2, but there was a good *eight years* while
this stuff was in `HEAD`.  The fallback code got called.

### how do you use key material? not like this... not like this.

Let's start with `encode`:

{% highlight php startinline %}
function encode($string, $key = '')
{
    $key = $this->get_key($key);
    if ($this->_mcrypt_exists === TRUE)
    {
        $enc = $this->mcrypt_encode($string, $key);
    }
    else
    {
        $enc = $this->_xor_encode($string, $key);
    }
    return base64_encode($enc);
}
{% endhighlight %}

`$key` wasn't passed from the session library, so `get_key` is called with an empty string; that, in turn, does the following:

* returns `$this->encryption_key` directly if it's set.  You can grep (or `ag`) the codebase quickly to find the only setter is `set_key` in the class, which isn't called by CI itself.
* fetches `'encryption_key'` from the CI config.  This is the same one that the Session class mandates is set, though Session doesn't use it itself in encrypted-cookie mode.
* surprisingly: returns the `md5()` of `$key`.

It's surprising because the comment says: "Returns it as MD5 in order to have an exact-length 128 bit key".  But PHP's `md5`, by default, returns the digest as a hexstring, not as raw data, meaning each byte will have *four* bits of entropy and not eight.  It also means the mcrypt codepath might well be ignoring half the key.

There is a noteworthy remark on the [`mcrypt_encrypt` changelog](http://php.net/manual/en/function.mcrypt-encrypt.php#refsect1-function.mcrypt-encrypt-changelog):

> Changed in: 5.6.0
>
> Invalid key and iv sizes are no longer accepted. **mcrypt_encrypt()** will now throw a warning and return **FALSE** if the inputs are invalid. Previously keys and IVs were padded with '\0' bytes to the next valid size.

[Outrageous](https://soundcloud.com/kivikakk/gems).

Let's move back to `encode`.  `$key` now has the hexed MD5 of our actual encryption key (i.e. it's a 32 byte string of hex digits).  We throw the plaintext string and that MD5 into `_xor_encode`, base64 the result, and that's our session cookie.

Let's look at `_xor_encode`.

### how not to use randomness

Reminder: `$string` is plaintext, `$key` is a 32-byte hexstring.

{% highlight php startinline %}
function _xor_encode($string, $key)
{
    $rand = '';
    while (strlen($rand) < 32)
    {
        $rand .= mt_rand(0, mt_getrandmax());
    }
    $rand = $this->hash($rand);
    $enc = '';
    for ($i = 0; $i < strlen($string); $i++)
    {
        $enc .= substr($rand, ($i % strlen($rand)), 1)
              . (substr($rand, ($i % strlen($rand)), 1) ^ substr($string, $i, 1));
    }
    return $this->_xor_merge($enc, $key);
}
{% endhighlight %}

Let's break it down:

* We generate random numbers and _concatenate_ them until we have more than 32 digits.  That's just bizarre.
* We then call `$this->hash` on the random number string, which by default will just `sha1()` it, *again* returning a hexstring, this time 40 characters long.
* We now iterate over each character of the plaintext and the `$rand` string, cycled.
  * We append to `$enc` the byte from the `$rand` string.
  * We then append to `$enc` the same byte XOR'd with the corresponding plaintext byte.
* We then `_xor_merge` the `$enc` with `$key`.

In other words, if:

* `$rand` looks like `"RRRRRRR..."`, and
* `$string` looks like `"xxxx"`, then
* `$enc` will look like `"R*R*R*R*"`,

where `'R'` ⊕ `'x'` = `'*'`.  We can XOR the pairs together to recover the plaintext.

Of course, we haven't even used the key material yet.  That's entirely the domain of `_xor_merge`.

`_xor_merge` is defined as a "key + string" combiner by the header doc.  Let's see what that means.

{% highlight php startinline %}
function _xor_merge($string, $key)
{
    $hash = $this->hash($key);
    $str = '';
    for ($i = 0; $i < strlen($string); $i++)
    {
        $str .= substr($string, $i, 1) ^ substr($hash, ($i % strlen($hash)), 1);
    }
    return $str;
}
{% endhighlight %}

`$key` as passed into the function is the hexstring of the MD5 of `encryption_key`.  We then produce the hexed SHA1 of _that_, and perform a 1-to-1 XOR of `$string[$i]` with `$hash[$i]` for all `$i`; the hash being a cycled 40 characters.  Remember that `$string` here is `$enc` above (`"R*R*R*R*"`).

It's important to note that these 40 hexadecimal characters are all that's left of the key material, and they're applied in [ECB mode](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Electronic_Codebook_.28ECB.29) (like Snapchat, [which I've written about](https://kivikakk.ee/2013/05/10/snapchat.html)).  The main implication of this is that later blocks aren't affected by earlier blocks; if we correctly decrypt byte *k* of the output, then we'll also get every byte (*k* + **W***n*), where **W** is the width of the block.

Usually — using a strong block cipher mode — getting any part of a block wrong would ensure every subsequent block would be corrupted, as the plaintext output of the earlier blocks are fed into later ones.  Not so with ECB, which they've unwittingly used. (Though "used" seems to be a bit of a stretch here.)

Call the hexed SHA1 key material `"kkkkkkk..."`.  We XOR this with the `"R*R*R*R*"` string, producing `"9A9A9A9A"`.  This is the final output.

Let's review the entire process key material and plaintext takes to be encrypted, with some simplifications to make it readable in English:

* A random SHA1 is produced (`"RRRRRRR..."`).
* We interleave characters of the plaintext (`"xxxx"`) with the random data, XORing each plaintext byte against the respective random byte (`"R*R*R*R*"`).
* We take the SHA1 of the MD5 of the key (`"kkkkkkk..."`).
* We bytewise XOR this SHA1 against each byte of the plaintext–random pairs (`"9A9A9A9A"`).

To recover the first byte of plaintext, then, looks like this:

1. Take the first two bytes of the ciphertext (`"9A"`).
2. Take the SHA1 of the MD5 of the key (`"kkkkkkk...")`).
3. XOR the ciphertext bytewise with the SHA1 (`"R*"`).
4. XOR the resulting pair of bytes (`"x"`).

Note that the key material is only ever used in SHA1(MD5(*key*)) form.  For our purposes, then, we only need to know the resulting SHA1; the source key doesn't matter.  To put it more clearly, we only need to recover the SHA1 output itself to break the effective key.

Looking at the above list of steps, we note that the SHA1 is only involved in the 3rd step; and moreover, this being a hexed SHA1, there's only 8 bits of entropy across the two bytes, each byte taking 16 values.

(If you do the math, there's actually only 6 bits; in the ASCII values of "0" through "9" and "a" through "f" bits 6 (always on) and 8 (always off) don't change.)

XORs commute and associate, so we can be lazy and define the plaintext byte *i* as:

> *p*[*i*] = *c*[2*i*] ^ *c*[2*i*+1] ^ *k*[2*i* mod 40] ^ *k*[2*i*+1 mod 40]

This is very straight forward.  Simplicity is often a nice thing in crypto, but this is the wrong kind of simple.

Let's say we *already know* *p*[*i*] for some *i*.

Knowing all of *c*, this tells us something about *k*[2*i* mod 40] and *k*[2*i*+1 mod 40].  Because there are some serious value restrictions on elements of *k* (being that there are only 16 possible values for a given element and not 256 like there should be), this lets us piece together *k* quite neatly, and thus all the elements of *p* we don't know.

### do we know the plaintext?

Do we know any *p*[*i*]?  Well, what's the plaintext?  [Session.php reveals all](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Session.php#L645-L676):

{% highlight php startinline %}
$cookie_data = $this->_serialize($cookie_data);
…
$cookie_data = $this->CI->encrypt->encode($cookie_data);
…
setcookie(
    $this->sess_cookie_name,
    $cookie_data,
    $expire,
    $this->cookie_path,
    $this->cookie_domain,
    $this->cookie_secure
);
{% endhighlight %}

`_serialize` massages the data in a way we can ignore for our purposes before passing it through to PHP's own [serialize](http://php.net/serialize).  So the session data is pure PHP serialised data.  What does this look like?

[Go up to `sess_write`](https://github.com/bcit-ci/CodeIgniter/blob/2.1.4/system/libraries/Session.php#L264-L273); you'll see `$cookie_userdata` is an array, which has keys set in a particular order: `'session_id'`, `'ip_address'`, `'user_agent'`, `'last_activity'`.

It's important to know that PHP arrays are both associative *and* ordered!  The same datatype is used for both key–value dictionaries as well as integer-indexed arrays.  This means order is present *and* preserved in `$cookie_userdata`, and this remains true for the serialised form.

If we fake our own `$cookie_userdata` in PHP and then serialise it, what would it look like?  Here's an example:

{% highlight php startinline %}
echo serialize(array(
    // Session.php:317 shows that session IDs are hexed MD5, so always 32 chars
    'session_id' => '1234567890abcdef1234567890abcdef',  
    'ip_address' => '0.0.0.0',
    'user_agent' => 'welp/1.0',
    'last_activity' => 1455953571,
));
{% endhighlight %}

Here's the output:

{% highlight php startinline %}
a:4:{s:10:"session_id";s:32:"1234567890abcdef1234567890abcdef";s:10:"ip_address";
s:7:"0.0.0.0";s:10:"user_agent";s:8:"welp/1.0";s:13:"last_activity";i:1455953571;}
{% endhighlight %}

The format is pretty simple to glean from this. Excuse my pseudo-not-even-BNF:

* *object* = *array* \| *string* \| *integer*
* *array* = `a` `:` number `:` `{` (*object* `;` *object* `;`)\* `}`
* *string* = `s` `:` number `:` `"` (any-char)\* `"`
* *integer* = `i` `:` number

So what do we have after all this? The first two bytes of our known plaintext: `a:`.

### let's put this together

Here's what we do: iterate over all 256 possible values of *k*[0] and *k*[1]; these correspond to *p*[0].  The rest of *k* doesn't matter.

  * For each *k*, we calculate *p*&prime; = decrypt(*k*, *c*).
  * Check *p*&prime;[0] == *p*[0].
  * If valid, we found *k*[0] and *k*[1]!  In an average of 128 decrypt operations (which are just a bunch of XORs)!  Continue on to *p*[1] and *k*[2] and *k*[3].

This can be done very, very fast.

This is actually slightly off; because of the weird keyspace and the fact that we're XORing two parts of the key for one byte, (*k*[*n*], *k*[*n*+1]) = (`'2'`, `'1'`) works the same as it would if it were equal to (`'3'`, `'0'`).  You don't necessarily get the exact SHA1 of the hex MD5 of the key, but you get one that works identically.

(In other words, there are even fewer distinct keys than there appear! Wow.)

We hit a slight hiccup because we don't necessarily know the size of the session array, so the third byte of plaintext is unknown.  But it doesn't take too long to realise that *k*[0] and *k*[1] correspond not only to *p*[0], but also *p*[20], *p*[40], etc., because the key material is cycled (see above re: ECB).

Let's align the known plaintext data in rows of 20 bytes:

> <tt>**a:**<span style="color: #777">4</span>**:{s:10:"session_i**</tt><br>
> <tt>**d";s:32:"**<span style="color: #777">1234567890a</span></tt><br>
> <tt><span style="color: #777">bcdef1234567890abcde</span></tt><br>
> <tt><span style="color: #777">f</span>**";s:10:"ip_address"**</tt>

In bold is everything we're sure about.  You can see that, in the first two blocks (rows) alone, we have enough known-plaintext to gather all 40 bytes of key data; we're missing the 3rd byte in the first block, but we have the 3rd byte in the second block.

There is the concern that the session array may have more than 9 keys, making the unknown part of the first block one byte greater, in which case it looks like this:

> <tt>**a:**<span style="color: #777">12</span>**:{s:10:"session_**</tt><br>
> <tt>**id";s:32:"**<span style="color: #777">1234567890</span></tt>

This is fine; we get both bytes 3 and 4 from the second block.  The same goes for many digits more, by which time we leave the realm of probability and cookie size limits.

And that's it.  We've done it.  You can write an automated cracker based on this alone.

Here's a PoC in action, artifically slowed down so you can watch its progress:

<img src="/img/codeigniter.gif">

Too simple!  Now that you have the key (or rather, the SHA1 of the MD5 hexstring of the key — good enough), you can feel free to change the data in the session, do what you like, and become whom you like.  Maybe even realise that PHP serialisation admits arbitrary objects, which you might be able to do something special with.

If you liked the article, please share!  I also welcome your feedback/thoughts on [Twitter](https://twitter.com/kivikakk).  Special thanks to Kairi for editing this article.

The PoC code follows.  Enjoy!

<script src="https://gist.github.com/kivikakk/c510b82a6ad828c3c5d3.js"></script>

