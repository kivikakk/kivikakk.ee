---
layout: post
title:  "Time zones in .NET"
date:   2013-09-12T06:48:00Z
categories: 
code: true
---

I'm a fairly new .NET developer.  I worked with the framework a bit in 2005--6,
but hadn't really touched it since then.  In the meantime, I've been sticking
to the Linux ecosystem, and a little OS X, as [mentioned in a previous
article](https://kivikakk.ee/2013/05/13/inefficiency.html).

So, time zones.  I know they're a sore point for many environments, but most
seem to dig themselves out of the hole and provide something that is, in the
end, usable.  

Ruby's builtin `Time` is actually pretty darn good, and if you use Rails,
ActiveSupport makes it even better.  `pytz` seems .. alright.  Databases
generally have their heads screwed on straight.  A lot of the time you can get
away with just storing seconds since the epoch and call it a day, because
there's nothing more intrinsic built into the system.

Then I got [my new job](https://draftable.com), and it was time get back into
.NET.  A lot has changed since 2006; it had only hit 2.0 then, mind.

So I felt confident I was using the latest, modern stuff.  We target 4.0 and
4.5 across our projects, and there's plenty nice about it.

Then I had to work with `System.DateTime`.  Oh.  Oh, gosh.

I quote the manual at you.

> ### DateTime.Kind Property
>
> Gets a value that indicates whether the time represented by this instance is
> based on local time, Coordinated Universal Time (UTC), or neither.

`Kind` is the **lone** field on a `DateTime` which has anything to do with time
zones.  It can take the value `Local`, `Universal`, or `Unspecified`.  What
does that even MEAN.  Note that `Kind` is ignored in comparisons, too, which
can only mean more fun for application developers.

---

It would be remiss of me to fail to note the paragraph in the docs which state:

> An alternative to the DateTime structure for working with date and time
> values in particular time zones is the DateTimeOffset structure. The
> DateTimeOffset structure stores date and time information in a private
> DateTime field and the number of minutes by which that date and time differs
> from UTC in a private Int16 field. This makes it possible for a
> DateTimeOffset value to reflect the time in a particular time zone, whereas a
> DateTime value can unambiguously reflect only UTC and the local time zone's
> time. For a discussion about when to use the DateTime structure or the
> DateTimeOffset structure when working with date and time values, see
> [Choosing Between DateTime, DateTimeOffset, and
> TimeZoneInfo.](http://msdn.microsoft.com/en-us/library/bb384267.aspx)

The linked page states that "although the DateTimeOffset type includes most of
the functionality of the DateTime type, it is not intended to replace the
DateTime type in application development."

Intention or not, it should **ALWAYS** be used.  It lists as a suitable
application for the `DateTimeOffset`:

> * Uniquely and unambiguously identify a single point in time.

Because we don't want that at any other time?  When do you want a `DateTime`
which non-specifically and ambiguously identifies several points in time?

On the other hand, listed as suitable for `DateTime`:

> Retrieve date and time information from sources outside the .NET Framework,
> such as SQL databases. Typically, these sources store date and time
> information in a simple format that is compatible with the DateTime
> structure.

No fucking comment.

It continues:

> Unless a particular DateTime value represents UTC, that date and time value
> is often ambiguous or limited in its portability. For example, if a DateTime
> value represents the local time, it is portable within that local time zone
> (that is, if the value is deserialized on another system in the same time
> zone, that value still unambiguously identifies a single point in time).
> Outside the local time zone, that DateTime value can have multiple
> interpretations. If the value's Kind property is DateTimeKind.Unspecified, it
> is even less portable: it is now ambiguous within the same time zone and
> possibly even on the same system on which it was first serialized. Only if a
> DateTime value represents UTC does that value unambiguously identify a single
> point in time regardless of the system or time zone in which the value is
> used.

Completely useless.  So, we'll use `DateTimeOffset` in our application code,
right?

Only the ecosystem hasn't caught up.

---

Enter [Npgsql](http://npgsql.projects.pgfoundry.org/), a Postgres driver for
.NET with a frightening amount of code.  It only works with `DateTime` objects
when sending or receiving timestamps to or from Postgres.

Postgres has two column types: `timestamp with time zone` and `timestamp
without time zone` (or `timestamptz` and `timestamp`, respectively).  The
former is about as good as a `DateTime`, but without trying to be more than it
can: it doesn't have `Kind`, which improves its usability by an order of
magnitude.  You can make a policy decision like "we'll always store UTC
`timestamp`s", and you've solved timezones in your application.  They mark a
specific point in time unambiguously.

Or you can just use `timestamptz` and they still unambiguously mark a specific
point in time.  It's magic!

So how does Npgsql deal with this?

The genesis of this post was because we were noting strange behaviour: we had
read a `timestamptz` out of the database, and then later `SELECT`ed all rows
where that column was strictly less than the value we read out.  And yet that
same row would be included in the result.  It made no sense.

Turns out it really did make no sense.

The rest of this blog is a sequence of test cases which demonstrate just how
bad the situation is.

{% highlight csharp %}
[SetUp]
public void SetUp()
{
    _connection = new NpgsqlConnection(
        "Host=localhost; Port=5432; Database=time_zones_in_dot_net; " +
        "User ID=time_zones_in_dot_net");
    _connection.Open();
}

[TearDown]
public void TearDown()
{
    _connection.Close();
}

[Test]
public void TimeZonesSane()
{
    // introduction
    // ------------

    // This test assumes the *local* machine (running NUnit) has local time of +10.
    // It's agnostic to the time zone setting on the database server.
    // In other words, Postgres +1, .NET -100000000.

    // Render UTC (+0), Postgres (+3) and .NET (+10) distinguishable.
    _connection.Execute("SET TIME ZONE '+3'");

    // In the below tests we assert that the queries yield a .NET DateTime object
    // which, when .ToUniversal() is called on it, produces the given date in
    // "mm/dd/yyyy HH:MM:SS" format.

    // After that is the non-.ToUniversal() date in parenthesis.  This is *always* 10
    // hours ahead for a Local or Unspecified, and the same for Utc.  DateTime
    // objects have no knowledge of offset, only Kind.

    // There's also a character appended to represent what time zone "kind" it came
    // back with; "L" for Local, "?" for Unspecified, "U" for Universal.

    // As noted below, ToUniversal() on a Local or Unspecified returns a new DateTime
    // with Kind set to Universal, and unilaterally subtracts the time zone offset of
    // the machine the code is running on.


    // tests using string literals
    // ---------------------------

    // Not useful in themselves, because we'll never use string literals, but help to
    // demonstrate some initial weirdness.

    // string timestamp time zone unspecified: assumed to be in database local time.
    // Returns with Local Kind.
    QueryEqual("09/11/2013 03:47:03 (09/11/2013 13:47:03) L",
               "SELECT '2013-09-11 06:47:03'::timestamp with time zone");

    // string timestamp with time zone: should come back with the correct universal
    // value, with Local Kind.
    QueryEqual("09/11/2013 05:47:03 (09/11/2013 15:47:03) L",
               "SELECT '2013-09-11 06:47:03+1'::timestamp with time zone");


    // string timestamp without time zone: comes back 'unspecified' with the exact
    // datetime specified.  ToUniversal() assumes unspecified = local, so -10.
    // Returns with Unspecified Kind.
    QueryEqual("09/10/2013 20:47:03 (09/11/2013 06:47:03) ?",
               "SELECT '2013-09-11 06:47:03'::timestamp without time zone");

    // string timestamp with time zone, coerced to not have a time zone: as if the
    // time zone wasn't in the string.  Returns with Unspecified Kind.
    QueryEqual("09/10/2013 20:47:03 (09/11/2013 06:47:03) ?",
               "SELECT '2013-09-11 06:47:03+1'::timestamp without time zone");


    // tests using .NET values as parameters
    // -------------------------------------

    // These represent what we'll usually do.  They're also really messed up.

    // unadorned parameter: regardless of the DateTimeKind, the date is treated as
    // without time zone; the exact date given comes back, but with Unspecified Kind,
    // and so is as good as forced to local time.
    DateTimesEqual("09/10/2013 20:47:03 (09/11/2013 06:47:03) ?",
                   "SELECT @DateTime",
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Local),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Unspecified),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Utc));

    // parameter specified as with time zone: regardless of the DateTimeKind, the
    // date is treated as in the database local time.  It comes back with Local Kind.
    DateTimesEqual("09/11/2013 03:47:03 (09/11/2013 13:47:03) L",
                   "SELECT (@DateTime)::timestamp with time zone",
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Local),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Unspecified),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Utc));

    // parameter specified as without time zone: as for unadorned parameter.
    DateTimesEqual("09/10/2013 20:47:03 (09/11/2013 06:47:03) ?",
                   "SELECT (@DateTime)::timestamp without time zone",
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Local),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Unspecified),
                   new DateTime(2013, 9, 11, 6, 47, 3, DateTimeKind.Utc));


    // discussion
    // -----------

    // DateTime parameters' kinds are ignored completely, as shown above, and are
    // rendered into SQL as a 'timestamp' (== 'timestamp without time zone').  When a
    // comparison between 'timestamp with time zone' and timestamp without time zone'
    // occurs, the one without is treated as being in database local time.

    // Accordingly, you should set your database time zone to UTC, to prevent
    // arbitrary adjustment of incoming DateTime objects.

    // The next thing to ensure is that all your DateTime objects should be in
    // Universal time when going to the database; their Kind will be ignored by
    // npgsql.  If you send a local time, the local time will be treated as the
    // universal one.

    // Note that, per the second group just above, 'timestamp with time zone' comes
    // back as a DateTime with Local Kind.  If you throw that right back into npgsql,
    // as above, the Kind will be summarily ignored and the *local* rendering of that
    // time treated as UTC.  Ouch.


    // conclusions
    // -----------

    // 'timestamp with time zone' is read as DateTime with Local Kind.  Note that the
    // actual value is correct, but it's invariably transposed to local time (i.e.
    // +10) with Local Kind, regardless of the stored time zone.  Calling
    // .ToUniversal() yields the correct DateTime in UTC.

    // DateTime's Kind property is ignored.  To work around, set database or session
    // time zone to UTC and always call ToUniversal() on DateTime parameters.

    // Don't use 'timestamp without time zone' in your schema.
}

private void DateTimesEqual(string expectedUtc, string query,
                            params DateTime[] dateTimes)
{
    foreach (var dateTime in dateTimes) {
        var cursor = _connection.Query<DateTime>(query, new {DateTime = dateTime});
        DatesEqual(expectedUtc, cursor.Single());
    }
}

private void QueryEqual(string expectedUtc, string query)
{
    DatesEqual(expectedUtc, _connection.Query<DateTime>(query).Single());
}

private static void DatesEqual(string expectedUtc, DateTime date)
{
    var code = "_";
    switch (date.Kind) {
        case DateTimeKind.Local:
            code = "L";
            break;
        case DateTimeKind.Unspecified:
            code = "?";
            break;
        case DateTimeKind.Utc:
            code = "U";
            break;
    }

    var uni = date.ToUniversalTime();
    Assert.AreEqual(expectedUtc,
                    string.Format("{0} ({1}) {2}",
                                  uni.ToString(CultureInfo.InvariantCulture),
                                  date.ToString(CultureInfo.InvariantCulture),
                                  code));
}
{% endhighlight %}
