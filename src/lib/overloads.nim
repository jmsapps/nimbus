import signals

import types


proc combine2*[A, B, R](a: Signal[A], b: Signal[B], fn: proc(x: A, y: B): R): Signal[R] =
  let res = signal(fn(a.get(), b.get()))
  discard a.sub(proc(x: A) = res.set(fn(x, b.get())))
  discard b.sub(proc(y: B) = res.set(fn(a.get(), y)))
  res


proc `==`*[T](a: Signal[T], b: T): Signal[bool] =
  derived(a, proc(x: T): bool = x == b)


proc `==`*[T](a: T, b: Signal[T]): Signal[bool] =
  derived(b, proc(x: T): bool = a == x)


proc `==`*[T](a, b: Signal[T]): Signal[bool] =
  combine2(a, b, proc(x, y: T): bool = x == y)


proc `and`*(a: bool, b: Signal[bool]): Signal[bool] =
  derived(b, proc(y: bool): bool = a and y)


proc `and`*(a: Signal[bool], b: bool): Signal[bool] =
  derived(a, proc(x: bool): bool = x and b)


proc `and`*(a, b: Signal[bool]): Signal[bool] =
  combine2(a, b, proc(x, y: bool): bool = x and y)


proc `or`*(a, b: Signal[bool]): Signal[bool] =
  combine2(a, b, proc(x, y: bool): bool = x or y)


proc `or`*(a: bool, b: Signal[bool]): Signal[bool] =
  derived(b, proc(y: bool): bool = a or y)


proc `or`*(a: Signal[bool], b: bool): Signal[bool] =
  derived(a, proc(x: bool): bool = x or b)


proc `not`*(a: Signal[bool]): Signal[bool] =
  derived(a, proc(x: bool): bool = not x)


proc `&`*[T](a: string, b: Signal[T]): Signal[string] =
  derived(b, proc(x: T): string = a & $x)


proc `&`*[T](a: Signal[T], b: string): Signal[string] =
  derived(a, proc(x: T): string = $x & b)


proc `&`*[A, B](a: Signal[A], b: Signal[B]): Signal[string] =
  combine2(a, b, proc(x: A, y: B): string = $x & $y)


proc `[]`*[T](s: Signal[seq[T]], i: int): Signal[T] =
  derived(s, proc(xs: seq[T]): T = xs[i])


proc `[]`*(s: Signal[string], i: int): Signal[char] =
  derived(s, proc(xs: string): char = xs[i])
