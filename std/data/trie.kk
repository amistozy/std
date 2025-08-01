import std/data/linearmap
import std/core/unsafe
import std/core/undiv

type trie
  // We cache the count of the partial string to avoid recomputing it, we also keep track if this node represents a complete string
  Trie(part: string, pcount: int, value: string, full: bool, children: linearMap<char,trie>)

fun empty()
  Trie("", 0, "", False, LinearMap([]))

// Looking up a string from the trie
pub fun str/lookup(t: trie, k: string): maybe<string>
  with pretend-no-div
  t.lookup(k.slice, k.count)

inline fun lookup-child(m: linearMap<char,trie>, full: bool, v: string, kn: sslice, kncount: int): div maybe<string>
  match kn.next
    Nothing -> if full then Just(v) else Nothing
    Just((char, k')) ->
      val sub = m.lookup(char)
      match sub 
        Nothing -> Nothing
        Just(s) -> lookup(s, k', kncount - 1)

fun slice/lookup(t: trie, k: sslice, kcount: int): div maybe<string>
  match t
    Trie(p, pcount, v, full, m) -> 
      if k.is-prefixed-by(p.slice, kcount, pcount) then
        // TODO: Optimize, drop + prefixed both traverse the same part of the string.
        lookup-child(m, full, v, k.drop(pcount), kcount - pcount)
      else Nothing

// Adding a string to the trie
pub fun add(t: trie, s: string): trie
  with pretend-no-div
  bind(t, s.slice, s, s.slice.count)

inline fun bind-map(m: linearMap<char,trie>, full: bool, p: string, v: string, kchar: char, kn: sslice, ksfull: string, pcount: int, kcount': int): div trie
  val sub = m.lookup(kchar)
  match sub
    Nothing -> Trie(p, pcount, v, full, m.set(kchar, Trie(kn.string, kcount' - 1, ksfull, True, LinearMap([]))))
    Just(sub) -> Trie(p, pcount, v, full, m.set(kchar, bind(sub.pretend-decreasing, kn, ksfull, kcount' - 1)))

fun internal/bind(t: trie, k: sslice, original: string, kcount: int): div trie
  match t
    Trie(p, pcount, v, full, m) ->
      fun common-prefix(k': sslice, p': sslice, acc: sslice, acccount: int)
        match (k'.next, p'.next)
          (Just((chark, k'')), Just((charp, p''))) -> 
            if chark == charp then
              common-prefix(k''.pretend-decreasing, p'', acc.extend(1), acccount + 1)
            else
              val m' = LinearMap([
                (chark, Trie(k''.string, k''.count, original, True, LinearMap([]))),
                (charp, Trie(p''.string, p''.count, v, full, m)) 
              ])
              Trie(acc.string, acccount, v.slice.extend(0 - acccount).string, False, m')
          (Just((chark, k'')), Nothing) ->
            bind-map(m, full, p, v, chark, k'', original, pcount, kcount - pcount)
          (Nothing, Just((charp, p''))) ->
            Trie(k.string, kcount, original, True, LinearMap([(charp, Trie(p''.string, pcount - kcount - 1, v, True, m))]))
          (Nothing, Nothing) -> Trie(p, pcount, v, True, m)
          _ -> impossible()
      common-prefix(k, p.slice, k.truncate, 0)

fun is-prefixed-by(a: sslice, b: sslice, acount: int, bcount: int): bool
  bcount <= acount &&
    a.take(bcount) == b

fun trie/show(t: trie): div string
  match t
    Trie(p, pcount, v, full, m) -> "Trie(" ++ p.show ++ ", " ++ pcount.show ++ ", " ++ v.show ++ ", " ++ full.show ++ " " ++ m.show ++ ")"
