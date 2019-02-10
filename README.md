# truncate

Lets truncate HTML!

A few days ago I had the problem of trying to truncate HTML strings in a Rails APP.
Obviously, truncating HTML is not necessarily trivial because of HTML entities, tags and nesting... Its not like picking up a body of simple text and splitting it at a given index or word count..

So I sketched up this code.. IDK if it can be useful to anyone..

---

This code has been built as "the simplest thing that could work".
This means structurally this is very procedural..
But it is fully tested, so..
