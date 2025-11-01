# Nimbus v0.1.0

This was the first implementation of this library before I moved things to `src/lib`. A number of
examples at the bottom tested various features such as basic signal support for children,
attributes, and if/case/for statements. Repo was changed to `NTML` to avoid name collision
with the Status ETH blockchain.

```nim
import macros, dom, strutils, tables

# ------------------- Signals -------------------
type
  Unsub* = proc ()
  Subscriber*[T] = proc (v: T)
  Signal*[T] = ref object
    value: T
    subs: seq[Subscriber[T]]

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

# fn returns Unsub
proc effect*[T](fn: proc(): Unsub, deps: openArray[Signal[T]]): Unsub =
  var cleanup: Unsub
  proc run() =
    if cleanup != nil: cleanup()
    cleanup = fn()
  var unsubs: seq[Unsub] = @[]
  for d in deps:
    unsubs.add d.sub(proc (v: type(d.value)) = run())
  result = proc() =
    for u in unsubs:
      if u != nil: u()
    if cleanup != nil: cleanup()

# fn returns void
proc effect*[T](fn: proc(): void, deps: openArray[Signal[T]]): Unsub =
  var cleanup: Unsub
  proc run() =
    if cleanup != nil: cleanup()
    fn()
    cleanup = nil
  var unsubs: seq[Unsub] = @[]
  for d in deps:
    unsubs.add d.sub(proc (v: type(d.value)) = run())
  result = proc() =
    for u in unsubs:
      if u != nil: u()
    if cleanup != nil:
      cleanup()

# No-deps variants
proc effect*(fn: proc(): Unsub): Unsub =
  var cleanup = fn()
  result = proc() =
    if cleanup != nil:
      cleanup()

proc effect*(fn: proc(): void): Unsub =
  fn()
  result = proc() = discard

# ------------------- Signal cleanup -------------------
var cleanupRegistry = initTable[int, seq[Unsub]]()

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

# ------------------- Constants -------------------
const BOOLEAN_ATTRS: array[8, string] = [
  "hidden", "disabled", "checked", "selected", "readonly", "multiple", "required", "open"
]

# ------------------- DOM shims -------------------
proc jsCreateElement*(s: cstring): Node {.importjs: "document.createElement(#)".}
proc jsCreateFragment*(): Node {.importjs: "document.createDocumentFragment()".}
proc jsCreateTextNode*(s: cstring): Node {.importjs: "document.createTextNode(#)".}
proc jsAppendChild*(p: Node, c: Node): Node {.importjs: "#.appendChild(#)".}
proc jsRemoveChild*(p: Node, c: Node): Node {.importjs: "#.removeChild(#)".}
proc jsInsertBefore*(p: Node, newChild: Node, refChild: Node): Node {.importjs: "#.insertBefore(#,#)".}
proc jsSetAttribute*(el: Node, k: cstring, v: cstring) {.importjs: "#.setAttribute(#,#)".}
proc jsAddEventListener*(el: Node, t: cstring, cb: proc (e: Event)) {.importjs: "#.addEventListener(#,#)".}
proc jsRemoveAttribute*(el: Node, k: cstring) {.importjs: "#.removeAttribute(#)".}
proc jsGetProp*(el: Node, k: cstring): cstring {.importjs: "String(#[#])".}
proc jsGetBoolProp*(el: Node, k: cstring): bool {.importjs: "Boolean(#[#])".}
proc jsSetProp*(el: Node, k: cstring, v: bool) {.importjs: "#[#] = #".}
proc jsSetProp*(el: Node, k: cstring, v: cstring) {.importjs: "#[#] = #".}
proc jsSetProp*(el: Node, k: cstring, v: int) {.importjs: "#[#] = #".}
proc jsSetProp*(el: Node, k: cstring, v: float) {.importjs: "#[#] = #".}

# ------------------- DOM helpers -------------------
# Child mount utils
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

template guardSeq(x): untyped =
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

# ----- checked (checkbox/radio) -----
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
# ------------------- Operator overloads -------------------
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

template createHtmlElement(name: untyped) =
  macro `name`*(args: varargs[untyped]): untyped =
    var tagName = astToStr(name).replace("`","")
    let node = genSym(nskLet, "node")
    let statements = newTree(nnkStmtListExpr)

    if tagName == "d":
      tagName = "div"
    elif tagName == "obj":
      tagName = "object"
    elif tagName == "tmpl":
      tagName = "template"
    elif tagName == "v":
      tagName = "var"

    let keyValues = newTree(nnkBracket)
    var children: seq[NimNode] = @[]
    var eventNames: seq[string] = @[]
    var eventHandlers: seq[NimNode] = @[]
    var attrSetters: seq[NimNode] = @[]

    # ----- helpers -----
    proc pushChild(node: NimNode) {.compileTime.} =
      children.add(node)

    proc lowerMountAttributes(keyRaw: string, value: NimNode) {.compileTime.} =
      var key = keyRaw

      if key == "className":
        key = "class"

      let keyLowered = key.toLowerAscii()
      let kLit = newLit(key)

      # 1) EVENTS (early return)
      if keyLowered.len >= 3 and keyLowered.startsWith("on"):
        let event = keyLowered[2..^1]
        eventNames.add(event)
        eventHandlers.add(value)

        return

      # inside lowerMountAttributes, right after the events branch:
      if keyLowered == "value":
        attrSetters.add newCall(ident"bindValue", node, value)

        return

      elif keyLowered == "checked":
        attrSetters.add newCall(ident"bindChecked", node, value)

        return

      # 2) IF in attributes
      if value.kind == nnkIfExpr or value.kind == nnkIfStmt:
        var cond, thenExpr, elseExpr: NimNode
        let head = value[0]

        cond = head[0]
        thenExpr = (if head[1].kind == nnkStmtList and head[1].len > 0: head[1][^1] else: head[1])
        elseExpr = newLit("")

        for br in value[1..^1]:
          if br.kind in {nnkElse, nnkElseExpr}:
            let body = br[0]
            elseExpr = (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)

        attrSetters.add(newCall(ident"mountAttrIf", node, kLit, cond, thenExpr, elseExpr))

        return

      # 3) CASE in attributes
      if value.kind == nnkCaseStmt:
        let disc = value[0]
        let sel  = ident"caseDisc"
        var caseNode = newTree(nnkCaseStmt, sel)

        for br in value[1..^1]:
          case br.kind
          of nnkOfBranch:
            var branch = newTree(nnkOfBranch)

            for lit in br[0..^2]:
              branch.add(lit)

            let body = br[^1]
            let expr = (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)

            branch.add(expr)
            caseNode.add(branch)

          of nnkElse:
            let body = br[0]
            let expr = (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)
            caseNode.add(newTree(nnkElse, expr))

          else: discard

        attrSetters.add(newCall(ident"mountAttrCase", node, kLit, disc, caseNode))

        return

      attrSetters.add(newCall(ident"mountAttr", node, kLit, value))

    proc lowerMountChildren(parent, node: NimNode): NimNode {.compileTime.} =
      case node.kind
      of nnkStmtList, nnkStmtListExpr, nnkBlockStmt:
        result = newTree(nnkStmtList)
        for it in node:
          result.add(lowerMountChildren(parent, it))

      of nnkIfStmt:
        proc toExpr(body: NimNode): NimNode {.compileTime.} =
          (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)

        var hasElif = false

        for k, br in node:
          if k > 0 and br.kind == nnkElifBranch:
            hasElif = true

        if hasElif:
          let ifNode = newTree(nnkIfStmt)

          for br in node:
            case br.kind
            of nnkElifBranch:
              ifNode.add(newTree(nnkElifBranch, br[0], lowerMountChildren(parent, br[1])))
            of nnkElse:
              ifNode.add(newTree(nnkElse, lowerMountChildren(parent, br[0])))
            else: discard

          result = ifNode

        else:
          let head = node[0]
          let cond = head[0]
          let thenExpr = toExpr(head[1])
          var elseExpr: NimNode = newLit("")

          for br in node[1..^1]:
            if br.kind == nnkElse: elseExpr = toExpr(br[0])

          # Defer dispatch (bool vs Signal[bool]) to overload resolution
          result = newCall(ident"mountChildIf", parent, cond, thenExpr, elseExpr)

      of nnkCaseStmt:
        proc toExpr(body: NimNode): NimNode {.compileTime.} =
          (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)

        let disc = node[0]
        let sel = ident"caseDisc" # this matches the injected name above

        let caseNode = newTree(nnkCaseStmt, sel)

        for br in node[1..^1]:
          case br.kind
          of nnkOfBranch:
            var branch = newTree(nnkOfBranch)
            for lit in br[0..^2]:
              branch.add(lit)
            branch.add(toExpr(br[^1]))
            caseNode.add(branch)

          of nnkElse:
            caseNode.add(newTree(nnkElse, toExpr(br[0])))

          else: discard

        result = newCall(ident"mountChildCase", parent, disc, caseNode)

      of nnkForStmt:
        # ForStmt: <name(s)> ... <iterExpr> <StmtList>
        var bodyIdx = -1

        for i in countdown(node.len - 1, 0):
          if node[i].kind == nnkStmtList:
            bodyIdx = i
            break

        let bodyNode = node[bodyIdx]
        var iterExpr = node[bodyIdx - 1]

        var names: seq[NimNode] = @[]
        for i in 0 ..< bodyIdx - 1:
          names.add(node[i])

        let renderFn = genSym(nskProc, "render")
        let itSym = genSym(nskParam, "it")
        let frag = genSym(nskLet,  "frag")

        # build binding defs
        var bindDefs: NimNode
        if names.len == 1:
          # let <name> = it
          bindDefs = newTree(nnkIdentDefs, names[0], newEmptyNode(), itSym)
        else:
          # enumerate: convert iterable to seq[(int,T)] or Signal[seq[(int,T)]]
          iterExpr = newCall(ident"toIndexSeq", iterExpr)
          # (i, x) = it    via VarTuple
          bindDefs = newTree(nnkVarTuple)
          for nm in names: bindDefs.add(nm)
          bindDefs.add(newEmptyNode()) # type slot
          bindDefs.add(itSym)          # rhs

        let renderProc = newProc(
          renderFn,
          params = [ident"Node", newIdentDefs(itSym, ident"auto")],
          body = newTree(nnkStmtList,
            newLetStmt(frag, newCall(ident"jsCreateFragment")),
            newTree(nnkLetSection, bindDefs),
            lowerMountChildren(frag, bodyNode),
            frag
          )
        )

        result = newTree(nnkStmtList,
          renderProc,
          newCall(ident"mountChildFor", parent, newCall(ident"guardSeq", iterExpr), renderFn)
        )

      of nnkWhileStmt:
        let loop = copy(node)
        loop[^1] = lowerMountChildren(parent, node[^1])
        result = loop

      of nnkLetSection, nnkVarSection, nnkConstSection, nnkAsgn, nnkDiscardStmt:
        result = node

      else:
        result = newCall(ident"mountChild", parent, node)
    # ----------------------------------------------------------------

    for a in args:
      case a.kind
      of nnkStmtList, nnkStmtListExpr:
        for it in a:
          pushChild(it)

      of nnkExprEqExpr:
        lowerMountAttributes($a[0], a[1])

      of nnkInfix:
        if a[0].kind == nnkIdent and $a[0] == "=":
          lowerMountAttributes($a[1], a[2])

        else:
          pushChild(a)

      of nnkIdent:
        attrSetters.add newCall(ident"mountAttr", node, newLit($a), newLit("true"))

      else:
        pushChild(a)

    let createExpr =
      if tagName == "fragment":
        newCall(ident"jsCreateFragment")
      else:
        newCall(ident"jsCreateElement", newCall(ident"cstring", newLit(tagName)))

    statements.add(newLetStmt(node, createExpr))

    # set attributes
    for s in attrSetters:
      statements.add(s)

    # lower mount children
    for child in children:
      statements.add(lowerMountChildren(node, child))

    # hoist events
    for i in 0 ..< eventNames.len:
      let cbSym = genSym(nskLet, "cb")

      statements.add(newLetStmt(cbSym, eventHandlers[i]))
      statements.add(
        newCall(
          ident"jsAddEventListener", node, newCall(ident"cstring", newLit(eventNames[i])), cbSym
        )
      )

    statements.add(node)

    result = statements

createHtmlElement `a`
createHtmlElement `abbr`
createHtmlElement `address`
createHtmlElement `area`
createHtmlElement `article`
createHtmlElement `aside`
createHtmlElement `audio`
createHtmlElement `b`
createHtmlElement `base`
createHtmlElement `bdi`
createHtmlElement `bdo`
createHtmlElement `blockquote`
createHtmlElement `body`
createHtmlElement `br`
createHtmlElement `button`
createHtmlElement `canvas`
createHtmlElement `caption`
createHtmlElement `cite`
createHtmlElement `code`
createHtmlElement `col`
createHtmlElement `colgroup`
createHtmlElement `data`
createHtmlElement `datalist`
createHtmlElement `dd`
createHtmlElement `del`
createHtmlElement `details`
createHtmlElement `dfn`
createHtmlElement `dialog`
createHtmlElement `d` # div
createHtmlElement `dl`
createHtmlElement `dt`
createHtmlElement `em`
createHtmlElement `embed`
createHtmlElement `fieldset`
createHtmlElement `figcaption`
createHtmlElement `figure`
createHtmlElement `footer`
createHtmlElement `form`
createHtmlElement `fragment`
createHtmlElement `h1`
createHtmlElement `h2`
createHtmlElement `h3`
createHtmlElement `h4`
createHtmlElement `h5`
createHtmlElement `h6`
createHtmlElement `head`
createHtmlElement `header`
createHtmlElement `hr`
createHtmlElement `html`
createHtmlElement `i`
createHtmlElement `iframe`
createHtmlElement `img`
createHtmlElement `input`
createHtmlElement `ins`
createHtmlElement `kbd`
createHtmlElement `label`
createHtmlElement `legend`
createHtmlElement `li`
createHtmlElement `link`
createHtmlElement `main`
createHtmlElement `map`
createHtmlElement `mark`
createHtmlElement `menu`
createHtmlElement `meta`
createHtmlElement `meter`
createHtmlElement `nav`
createHtmlElement `noscript`
createHtmlElement `obj` # object
createHtmlElement `ol`
createHtmlElement `optgroup`
createHtmlElement `option`
createHtmlElement `output`
createHtmlElement `p`
createHtmlElement `param`
createHtmlElement `picture`
createHtmlElement `pre`
createHtmlElement `progress`
createHtmlElement `q`
createHtmlElement `rp`
createHtmlElement `rt`
createHtmlElement `ruby`
createHtmlElement `s`
createHtmlElement `samp`
createHtmlElement `script`
createHtmlElement `section`
createHtmlElement `select`
createHtmlElement `slot`
createHtmlElement `small`
createHtmlElement `source`
createHtmlElement `span`
createHtmlElement `strong`
createHtmlElement `style`
createHtmlElement `sub`
createHtmlElement `summary`
createHtmlElement `sup`
createHtmlElement `svg`
createHtmlElement `table`
createHtmlElement `tbody`
createHtmlElement `td`
createHtmlElement `tmpl`  # template
createHtmlElement `textarea`
createHtmlElement `tfoot`
createHtmlElement `th`
createHtmlElement `thead`
createHtmlElement `time`
createHtmlElement `title`
createHtmlElement `tr`
createHtmlElement `track`
createHtmlElement `u`
createHtmlElement `ul`
createHtmlElement `v`  # var
createHtmlElement `video`
createHtmlElement `wbr`


when isMainModule:
  type
    Props = object of RootObj
      accesskey: string = ""        #	Keyboard shortcut to activate/focus an element
      autocapitalize: string = ""   #	Controls text capitalization in forms (none, sentences, etc.)
      autofocus: string = ""        #	Automatically focus element when page loads
      class: string = ""            #	CSS class list
      contenteditable: string = ""  #	Makes element’s content editable
      dir: string = ""              #	Text direction (ltr, rtl, auto)
      draggable: string = ""        #	Whether element can be dragged (true / false)
      enterkeyhint: string = ""     #	Suggests enter key label on virtual keyboards
      hidden: string = ""           #	Hides the element
      id: string = ""               #	Unique element identifier
      inert: string = ""            #	Prevents interaction/focus (newer browsers)
      inputmode: string = ""        #	Virtual keyboard type (numeric, email, etc.)
      `is`: string = ""             # Used for customized built-in elements
      itemid: string = ""           # Microdata attribute
      itemprop: string = ""         # Microdata attribute
      itemref: string = ""          # Microdata attribute
      itemscope: string = ""        # Microdata attribute
      itemtype: string = ""         # Microdata attribute
      lang: string = ""             #	Language of element content
      nonce: string = ""            #	CSP nonce for inline scripts/styles
      part: string = ""             # Shadow DOM parts
      popover: string = ""          #	Popover behavior (manual, auto)
      slot: string = ""             # Slot name for Web Components
      spellcheck: string = ""       # Enable/disable spell checking
      style: string = ""            #	Inline CSS styles
      tabindex: string = ""         #	Tab order for focus
      title: string = ""            #	Tooltip / advisory text
      translate: string = ""        #	Whether to translate the element’s text (yes / no)

    Person = object
      firstname: string
      favoriteFood: string

  let styleTag =
    style:
      """
        ._div_container_a {
          background-color: #eee;
          padding: 24px;
          border-radius: 20px;
          font-family: sans-serif;
        }
      """

  proc NestedComponent(props: Props, children: Node): Node =
    d(id=props.id):
      children

  proc Component(props: Props, children: Node): Node =
    let count: Signal[int] = signal(0)
    let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))
    let showSection = signal(true)
    let isEven: Signal[bool] = derived(count, proc (x: int): bool =
      if x mod 2 == 0: true else: false
    )
    let formValue: Signal[cstring] = signal(cstring(""))
    let accepted: Signal[bool] = signal(false)
    let people: Signal[seq[Person]] = signal(@[
      Person(firstname: "Axel", favoriteFood: "pizza"),
      Person(firstname: "Synn", favoriteFood: "pasta"),
    ])

    let fruit: Signal[string] = signal("apple")
    let fruitIndex: Signal[int] = signal(0)

    discard effect(proc (): Unsub =
      proc cleanup() =
        echo "cleanup ran"

      echo "effect ran, count = ", count.get()

      let fruitBasket = @["apples", "bananas", "cherries", "dates"]
      fruit.set(fruitBasket[fruitIndex.get()])

      let newFruitIndex = (if fruitIndex.get() < 3: fruitIndex.get() + 1 else: 0)

      fruitIndex.set(newFruitIndex)

      result = cleanup
    , [count])

    discard effect(proc(): Unsub =
      echo "signal mounted!"
      result = proc() =
        echo "cleanup ran"
    , [showSection])

    let unsub = effect(proc (): Unsub =
      echo "one-time effect ran"
      return proc() = echo "cleanup ran later"
    )

    unsub()

    d(id=
        case fruit:
        of "apples", "cherries": "red"
        of "bananas": "yellow"
        else: "it depends",
      class=props.class
    ):
      h1(
        `data-even`=
        if (isEven and 1+1 == 2) or (1+1 == 4):
          "even"
        else:
          "odd"
      ): props.title

      "Count: "; count; br(); "Doubled: "; doubled; br(); br();
      button(
        class="btn",
        onClick = proc (e: Event) =
          count.set(count.get() + 1)
      ): "Increment"

      ul:
        li: derived(count, proc (x: int): string = $(x*2 + 1))
        li: derived(count, proc (x: int): string = $(x*2 + 2))
        li: derived(count, proc (x: int): string = $(x*2 + 3))

      "Jebbrel wants to eat "
      case fruit:
      of "apples":
        fruit.get
      of "bananas":
        fruit.get
      of "cherries":
        fruit.get
      of "dates":
        fruit.get
      else:
        ""

      br();br();

      if isEven:
        "Count is even"
      else:
        "Count is odd"

      i: " (Almanda becomes shy when Count is odd)"

      br();br()

      d(hidden=(derived(isEven, proc(x: bool): bool = not x))):
        "Hi, I'm Almanda!"

        br();br();

      "(fruit == \"apples\" and not isEven) or (fruit == \"bananas\"): "
      if (fruit == "apples" and not isEven) or (fruit == "bananas"):
        "Match"
      else:
        "No match"

      br();br()

      children

      br();

      d:
        button(onClick = proc(e: Event) =
          showSection.set(not showSection.get())
        ): "Toggle Section"

        br(); br();

        if showSection:
          "Reactive section visible!"
        else:
          "Section hidden."

      br();br();

      form(onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Submitted: ", formValue.get()
        ):
        label(`for`="firstname"): "First name:"; br()
        input(
          id="firstname",
          `type`="text",
          name="firstname",
          value=formValue
        ); br()
        button(`type`="submit", disabled=formValue == "", style="margin-top: 8px"): "Submit"

      br();br();

      form(onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Accepted? ", accepted.get()
        ):
        label(`for`="terms"): "Accept terms and conditions"; br()
        input(
          id="terms",
          `type`="checkbox",
          name="terms",
          checked=accepted
        ); br()
        button(`type`="submit", disabled=not accepted, style="margin-top: 8px"): "Submit"

      br();br()

      button(
        class="btn",
        onClick = proc (e: Event) =
          people.set(@[people.get()[1], people.get()[0]])
      ): "Swap People"

      ul:
        for i, person in people:
          li:
            i; " "; person.firstname; " likes "; person.favoriteFood;

  let component: Node = Component(Props(
    title: "Nimbus Test Playground",
    class: "_div_container_a"
  )):
    NestedComponent(Props(id: "nested_component")):
      b:
        "This is a nested component"

  discard jsAppendChild(document.head, styleTag)
  discard jsAppendChild(document.body, component)
```
