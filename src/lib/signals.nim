when defined(js):
  from dom import Node
  import tables

  import
    shims,
    types

  var
    cleanupRegistry: Table[system.int, seq[Unsub]] = initTable[int, seq[Unsub]]()
    nodeDisposers*: seq[NodeDisposer] = @[]
    nextId = 0


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
        if fn != nil:
          fn()

      cleanupRegistry.del(k)

    for hook in nodeDisposers:
      if hook != nil:
        hook(el)


  proc cleanupSubtree*(el: Node) =
    if el == nil:
      return

    runCleanups(el)

    var child = jsGetNodeProp(el, cstring("firstChild"))
    while child != nil:
      let next = jsGetNodeProp(child, cstring("nextSibling"))
      cleanupSubtree(child)
      child = next


  proc debugId(): string =
    inc(nextId)

    return "signal_" & $nextId


  proc signal*[T](initial: T): Signal[T] =
    new(result)
    result.signalId = debugId()
    result.signalValue = initial
    result.signalSubs = @[]


  proc get*[T](src: Signal[T]): T =
    src.signalValue


  proc set*[T](src: Signal[T], newValue: T) =
    if newValue != src.signalValue:
      src.signalValue = newValue

      # prevents subs mutation during assignment
      let snapshot = src.signalSubs

      for f in snapshot:
        f(newValue)


  proc sub*[T](src: Signal[T], fn: Subscriber[T]): Unsub =
    src.signalSubs.add(fn)
    fn(src.signalValue)

    result = proc() =
      var i: int = -1

      for idx, g in src.signalSubs:
        if g == fn:
          i = idx
          break

      if i >= 0:
        src.signalSubs.delete(i)


  proc derived*[A, B](src: Signal[A], fn: proc(a: A): B): Signal[B] =
    let res = signal[B](fn(src.signalValue))

    discard src.sub(proc(a: A) = res.set(fn(a)))

    res


  template track*(src, expr: untyped): untyped =
    derived(src, proc(_: typeof(src.signalValue)): auto = expr)


  proc effect*[T](fn: proc(): Unsub, deps: openArray[Signal[T]]): Unsub =
    var cleanup: Unsub

    proc run() =
      if cleanup != nil: cleanup()
      cleanup = fn()

    var unsubs: seq[Unsub] = @[]

    for d in deps:
      unsubs.add(d.sub(proc (v: type(d.signalValue)) = run()))

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
      unsubs.add(d.sub(proc (v: type(d.signalValue)) = run()))

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


  proc addNodeDisposer*(hook: NodeDisposer) =
    nodeDisposers.add(hook)
