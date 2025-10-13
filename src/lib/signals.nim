from dom import Node
import tables

import types

var cleanupRegistry = initTable[int, seq[Unsub]]()

when defined(js):
  proc nodeKey(n: Node): int
    {.importjs: """
    (function(x) {
      if (x.__nid === undefined) {
        if (window.__nid === undefined) window.__nid = 0;
        window.__nid = window.__nid + 1;
        x.__nid = window.__nid;
      }
      return x.__nid;
    })(#)
    """.}


proc registerCleanup*(el: Node, fn: Unsub) =
  let k = nodeKey(el)
  if k notin cleanupRegistry:
    cleanupRegistry[k] = @[]

  cleanupRegistry[k].add(fn)

proc runCleanups*(el: Node) =
  let k = nodeKey(el)

  if k in cleanupRegistry:
    for fn in cleanupRegistry[k]:
      if fn != nil: fn()

    cleanupRegistry.del(k)


proc signal*[T](initial: T): Signal[T] =
  new(result)
  result.value = initial
  result.subs = @[]


proc get*[T](src: Signal[T]): T =
  src.value


proc set*[T](src: Signal[T], newValue: T) =
  if newValue != src.value:
    src.value = newValue

    for f in src.subs:
      f(newValue)


proc sub*[T](src: Signal[T], fn: Subscriber[T]): Unsub =
  src.subs.add(fn)
  fn(src.value)

  result = proc() =
    var i: int = -1

    for idx, g in src.subs:
      if g == fn:
        i = idx
        break

    if i >= 0:
      src.subs.delete(i)


proc derived*[A, B](src: Signal[A], fn: proc(a: A): B): Signal[B] =
  let res = signal[B](fn(src.value))

  discard src.sub(proc(a: A) = res.set(fn(a)))

  res



proc effect*[T](fn: proc(): Unsub, deps: openArray[Signal[T]]): Unsub =
  var cleanup: Unsub

  proc run() =
    if cleanup != nil: cleanup()
    cleanup = fn()

  var unsubs: seq[Unsub] = @[]

  for d in deps:
    unsubs.add(d.sub(proc (v: type(d.value)) = run()))

  result = proc() =
    for u in unsubs:
      if u != nil: u()

    if cleanup != nil: cleanup()



proc effect*[T](fn: proc(): void, deps: openArray[Signal[T]]): Unsub =
  var cleanup: Unsub

  proc run() =
    if cleanup != nil: cleanup()
    fn()
    cleanup = nil

  var unsubs: seq[Unsub] = @[]

  for d in deps:
    unsubs.add(d.sub(proc (v: type(d.value)) = run()))

  result = proc() =
    for u in unsubs:
      if u != nil: u()

    if cleanup != nil:
      cleanup()



proc effect*(fn: proc(): Unsub): Unsub =
  var cleanup = fn()

  result = proc() =
    if cleanup != nil:
      cleanup()


proc effect*(fn: proc(): void): Unsub =
  fn()
  result = proc() = discard
