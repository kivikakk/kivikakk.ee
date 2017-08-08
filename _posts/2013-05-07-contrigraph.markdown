---
layout: post
title:  "Contrigraph: drawing in GitHub"
date:   2013-05-07T00:08:00Z
categories:
---

Here's [**Contrigraph**](https://github.com/contrigraph), a "data
visualisation" (?) created by generating commits to match the [Contribution
Graph Shirt](http://shop.github.com/products/contribution-graph-shirt) from
GitHub.

It was pretty much a hack; first, I read the colours straight off the shirt,
producing a big block of data like

    0002342
    2223322
    2323241
    2224333
    3322122
    2242231
    ...

Then we read that in one digit at a time, work out what day to start on so
everything aligns correctly, and how many commits on a given day produce each
gradient of colour.  The result isn't pretty:

{% highlight ruby %}

start = Time.new 2012, 4, 23, 12, 0, 0, 0

tbl = {"0" => 0, "1" => 0, "2" => 1, "3" => 9, "4" => 14, "5" => 23}

3.times do 
  dbd.each do |n|
    tbl[n].times do
      `echo 1 >> graafik`
      `git commit -a -m 'contrigraph' --date='#{start.to_s[0..9]}T12:00:00'`
    end
    start += 86400
  end
end

{% endhighlight %}

Three times so this thing will scroll on for the next few years.  Other values
for `tbl` would work too; I just didn't bother to do anything better.  I've
written clearer code, but that wasn't really the point either.

I actually screwed this up twice: first I didn't remember to treat the `0`
entries correctly (i.e. I should have skipped those days, whereas I ignored
them entirely); second, it seemed like I was getting hit by timezone issues
where everything was shifted up a block.

In retrospect, I should have first produced a mini-contributions graph
generator (i.e. one that takes a Git repository and produces what GitHub would
do), validate that against an existing user/repo, then use that to ensure it'd
work the first time.  I did a similar thing to ensure I had the data correct,
by producing a graph directly from the data:

<style type="text/css">
  table.contrigraph {
    margin-left: auto;
    margin-right: auto;
  }

  table.contrigraph td {
    width: 8px;
    height: 8px;
  }

  /* Shown on a Saturday. (Last day is Friday.) */
  table.contrigraph td.cell1 { background-color: #eeeeee; } /* 0 */
  table.contrigraph td.cell2 { background-color: #d6e685; } /* 1 */
  table.contrigraph td.cell3 { background-color: #8cc665; } /* 9 */
  table.contrigraph td.cell4 { background-color: #44a340; } /* 14 */
  table.contrigraph td.cell5 { background-color: #1e6823; } /* 23 */
</style>

<table class="contrigraph">
  <tbody>
    <tr>
      <td class='cell0'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
    </tr>
    <tr>
      <td class='cell0'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
    </tr>
    <tr>
      <td class='cell0'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
    </tr>
    <tr>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell4'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
    </tr>
    <tr>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
    </tr>
    <tr>
      <td class='cell4'></td>
      <td class='cell2'></td>
      <td class='cell4'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell4'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell5'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
    </tr>
    <tr>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell1'></td>
      <td class='cell2'></td>
      <td class='cell2'></td>
      <td class='cell3'></td>
      <td class='cell1'></td>
      <td class='cell0'></td>
    </tr>
  </tbody>
</table>
