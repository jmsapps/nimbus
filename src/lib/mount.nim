when defined(js):
  from dom import Node, Event
  import
    strutils

  import
    constants,
    shims,
    signals

  import types


  # Chilren mount utils
  proc toNode*(n: Node): Node = n
  proc toNode*(s: string): Node = jsCreateTextNode(cstring(s))
  proc toNode*(s: cstring): Node = jsCreateTextNode(s)
  proc toNode*(x: int): Node = jsCreateTextNode(cstring($x))
  proc toNode*(x: float): Node = jsCreateTextNode(cstring($x))
  proc toNode*(x: bool): Node = jsCreateTextNode(cstring($x))


  proc removeBetween*(parent: Node, startN, endN: Node) =
    var n = startN.nextSibling
    while n != endN and n != nil:
      let nxt = n.nextSibling
      runCleanups(n)
      discard jsRemoveChild(parent, n)
      n = nxt


  template guardSeq*(x): untyped =
    when x is seq or x is Signal[seq]:
      x
    else:
      {.error: "mountChildFor expects seq[T] or Signal[seq[T]]".}


  proc toIndexSeq*[T](xs: seq[T]): seq[(int, T)] =
    result = @[]
    for i, v in xs: result.add((i, v))


  proc toIndexSeq*[T](xs: Signal[seq[T]]): Signal[seq[(int, T)]] =
    derived(xs, proc(s: seq[T]): seq[(int, T)] =
      var outSeq: seq[(int, T)] = @[]
      for i, v in s: outSeq.add((i, v))
      outSeq
    )

  # Child mounts
  proc mountChild*(parent: Node, child: Node) =
    discard jsAppendChild(parent, child)


  proc mountChild*(parent: Node, child: string) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring(child)))


  proc mountChild*(parent: Node, child: cstring) =
    discard jsAppendChild(parent, jsCreateTextNode(child))


  proc mountChild*(parent: Node, child: int) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*(parent: Node, child: float) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*(parent: Node, child: bool) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*[T](parent: Node, s: Signal[T]) =
    let startN = jsCreateTextNode(cstring(""))
    let endN   = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    proc render(v: T) =
      removeBetween(parent, startN, endN)
      discard jsInsertBefore(parent, toNode(v), endN)

    render(s.get())
    let unsub = s.sub(proc(v: T) = render(v))
    registerCleanup(startN, unsub)


  template mountChildIf*(parent: Node, cond: bool, thenN, elseN: untyped) =
    if cond:
      mountChild(parent, thenN)
    else:
      mountChild(parent, elseN)


  template mountChildIf*(parent: Node, cond: Signal[bool], thenN, elseN: untyped) =
    mountChild(parent,
      derived(cond, proc (v: bool): auto = (if v: thenN else: elseN))
    )


  template mountChildCase*[T](parent: Node, disc: T, body: untyped) =
    block:
      let tmp {.inject.} = disc
      mountChild(parent, (block:
        let caseDisc {.inject.} = tmp
        body
      ))


  template mountChildCase*[T](parent: Node, disc: Signal[T], body: untyped) =
    mountChild(parent,
      derived(disc, proc(v: T): auto = (block:
        let caseDisc {.inject.} = v
        body
      ))
    )


  proc mountChildFor*[T](parent: Node, items: seq[T], render: proc (it: T): Node) =
    let startN = jsCreateTextNode(cstring(""))
    let endN   = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)


    proc rerender(xs: seq[T]) =
      removeBetween(parent, startN, endN)
      let frag = jsCreateFragment()
      for it in xs:
        discard jsAppendChild(frag, render(it))
      discard jsInsertBefore(parent, frag, endN)

    rerender(items)


  proc mountChildFor*[T](parent: Node, items: Signal[seq[T]], render: proc (it: T): Node) =
    let startN = jsCreateTextNode(cstring(""))
    let endN   = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    proc rerender(xs: seq[T]) =
      removeBetween(parent, startN, endN)
      let frag = jsCreateFragment()
      for it in xs:
        discard jsAppendChild(frag, render(it))
      discard jsInsertBefore(parent, frag, endN)

    rerender(items.get())
    let unsub = items.sub(proc (xs: seq[T]) = rerender(xs))
    registerCleanup(startN, unsub)


  # Attribute mount utils
  proc isBooleanAttr(k: string): bool =
    let kl = k.toLowerAscii()
    for b in BOOLEAN_ATTRS:
      if b == kl: return true
    false


  proc propKey(attr: string): cstring =
    case attr.toLowerAscii()
    of "contenteditable": "contentEditable"
    of "for", "htmlfor": "htmlFor"
    of "maxlength": "maxLength"
    of "readonly": "readOnly"
    of "tabindex": "tabIndex"
    else: cstring(attr)


  proc toBoolStr(value: string): bool =
    let v = value.toLowerAscii()
    v != "" and v != "false" and v != "0" and v != "off" and v != "no"


  proc setBooleanAttr(el: Node, k: string, on: bool) =
    jsSetProp(el, propKey(k), on)
    if on:
      jsSetAttribute(el, cstring(k), "")
    else:
      jsRemoveAttribute(el, cstring(k))


  proc setStringAttr(el: Node, key: string, value: string) =
    let keyLowered = key.toLowerAscii()
    case keyLowered
    of "value":
      jsSetProp(el, propKey(keyLowered), cstring(value))
    of "checked":
      jsSetProp(el, propKey(keyLowered), toBoolStr(value))

    else:
      if isBooleanAttr(keyLowered):
        setBooleanAttr(el, keyLowered, toBoolStr(value))
      else:
        if value.len == 0:
          case keyLowered
          of "class", "style":
            discard
          else:
            jsSetProp(el, propKey(keyLowered), cstring(""))
          jsRemoveAttribute(el, cstring(keyLowered))
        else:
          case keyLowered
          of "class", "style":
            discard
          else:
            jsSetProp(el, propKey(keyLowered), cstring(value))
          jsSetAttribute(el, cstring(keyLowered), cstring(value))

  # Attribute bind utils
  proc bindValue*(el: Node, v: string) = setStringAttr(el, "value", v)
  proc bindValue*(el: Node, v: cstring) = setStringAttr(el, "value", $v)
  proc bindValue*(el: Node, v: int) = setStringAttr(el, "value", $v)
  proc bindValue*(el: Node, v: float) = setStringAttr(el, "value", $v)


  proc bindValue*(el: Node, s: Signal[string]) =
    setStringAttr(el, "value", s.get())
    let u = s.sub(proc(x: string) = jsSetProp(el, cstring("value"), cstring(x)))
    registerCleanup(el, u)
    let onInput = proc (e: Event) = s.set($jsGetProp(el, cstring("value")))
    jsAddEventListener(el, cstring("input"), onInput)
    jsAddEventListener(el, cstring("change"), onInput)


  proc bindValue*(el: Node, s: Signal[cstring]) =
    setStringAttr(el, "value", $s.get())
    let u = s.sub(proc(x: cstring) = jsSetProp(el, cstring("value"), x))
    registerCleanup(el, u)
    let onInput = proc (e: Event) = s.set(jsGetProp(el, cstring("value")))
    jsAddEventListener(el, cstring("input"), onInput)
    jsAddEventListener(el, cstring("change"), onInput)


  proc bindChecked*(el: Node, v: bool) = setBooleanAttr(el, "checked", v)

  proc bindChecked*(el: Node, s: Signal[bool]) =
    setBooleanAttr(el, "checked", s.get())
    let u = s.sub(proc(x: bool) = jsSetProp(el, cstring("checked"), x))
    registerCleanup(el, u)
    jsAddEventListener(el, cstring("change"), proc (e: Event) =
      s.set(jsGetBoolProp(el, cstring("checked")))
    )


  # Attribute mounts
  proc mountAttr*(el: Node, k: string, v: string) = setStringAttr(el, k, v)
  proc mountAttr*(el: Node, k: string, v: cstring) = setStringAttr(el, k, $v)
  proc mountAttr*(el: Node, k: string, v: bool) = setBooleanAttr(el, k, v)
  proc mountAttr*(el: Node, k: string, v: int) = setStringAttr(el, k, $v)
  proc mountAttr*(el: Node, k: string, v: float) = setStringAttr(el, k, $v)
  proc mountAttr*[T](el: Node, k: string, v: T) = setStringAttr(el, k, $v) # fallback


  proc mountAttr*(el: Node, k: string, s: Signal[string]) =
    setStringAttr(el, k, s.get())
    let u = s.sub(proc(x: string) = setStringAttr(el, k, x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[cstring]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: cstring) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[bool]) =
    setBooleanAttr(el, k, s.get())
    let u = s.sub(proc(x: bool) = setBooleanAttr(el, k, x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[int]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: int) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[float]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: float) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*[T](el: Node, k: string, s: Signal[T]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: T) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  template mountAttrIf*(el: Node, k: string, cond: bool, thenV, elseV: untyped) =
    mountAttr(el, k, (if cond: thenV else: elseV))


  template mountAttrIf*(el: Node, k: string, cond: Signal[bool], thenV, elseV: untyped) =
    mountAttr(el, k, derived(cond, proc (v: bool): auto = (if v: thenV else: elseV)))


  template mountAttrCase*[T](el: Node, k: string, disc: T, body: untyped) =
    mountAttr(el, k, (block:
      let caseDisc {.inject.} = disc
      body
    ))


  template mountAttrCase*[T](el: Node, k: string, disc: Signal[T], body: untyped) =
    mountAttr(el, k, derived(disc, proc(v: T): auto = (block:
      let caseDisc {.inject.} = v
      body
    )))
