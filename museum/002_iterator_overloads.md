# Iterator overloads

I wrote these when trying to implement the handling of for loops in children elements.
Before I started this project I didn't know much about overloading functions or how the
Nim compiler checks between methods with the same name.

```nim
iterator items*[T](s: Signal[seq[T]]): lent T =
  for it in s.get():
    yield it

iterator pairs*[T](s: Signal[seq[T]]): (int, lent T) =
  var i = 0
  for it in s.get():
    yield (i, it)
    inc i
```
