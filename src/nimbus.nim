import macros, dom, strutils

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

# ------------------- JS DOM shims -------------------
proc jsCreateElement*(s: cstring): Node {.importjs: "document.createElement(#)".}
proc jsCreateTextNode*(s: cstring): Node {.importjs: "document.createTextNode(#)".}
proc jsAppendChild*(p: Node, c: Node): Node {.importjs: "#.appendChild(#)".}
proc jsRemoveChild*(p: Node, c: Node): Node {.importjs: "#.removeChild(#)".}
proc jsInsertBefore*(p: Node, newChild: Node, refChild: Node): Node {.importjs: "#.insertBefore(#,#)".}
proc jsSetAttribute*(el: Node, k: cstring, v: cstring) {.importjs: "#.setAttribute(#,#)".}
proc jsAddEventListener*(el: Node, t: cstring, cb: proc (e: Event)) {.importjs: "#.addEventListener(#,#)".}

# ------------------- DOM helpers -------------------
proc el*(tag: string, props: openArray[(string, string)] = [], children: varargs[Node]): Node =
  let element = jsCreateElement(cstring(tag))
  for (k, v) in props:
    if v.len > 0: jsSetAttribute(element, cstring(k), cstring(v))
  for c in children: discard jsAppendChild(element, c)
  element

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
    discard jsRemoveChild(parent, n)
    n = nxt

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
  discard s.sub(proc(v: T) = render(v))

template mountIf*(parent: Node, cond: bool, thenN, elseN: untyped) =
  if cond:
    mountChild(parent, thenN)
  else:
    mountChild(parent, elseN)

template mountIf*(parent: Node, cond: Signal[bool], thenN, elseN: untyped) =
  mountChild(parent,
    derived(cond, proc (v: bool): auto = (if v: thenN else: elseN))
  )

template mountCase*[T](parent: Node, disc: T, body: untyped) =
  block:
    let tmp {.inject.} = disc
    mountChild(parent, (block:
      let caseDisc {.inject.} = tmp
      body
    ))

template mountCase*[T](parent: Node, disc: Signal[T], body: untyped) =
  mountChild(parent,
    derived(disc, proc(v: T): auto = (block:
      let caseDisc {.inject.} = v
      body
    ))
  )



template makeTag(name: untyped) =
  macro `name`*(args: varargs[untyped]): untyped =
    var tagName = astToStr(name).replace("`","")
    if tagName == "d":
      tagName = "div"

    let kvs = newTree(nnkBracket)
    var kids: seq[NimNode] = @[]
    var evtNames: seq[string] = @[]
    var evtHandlers: seq[NimNode] = @[]

    proc pushChild(n: NimNode) {.compileTime.} = kids.add n
    proc handleAttr(kRaw: string, v: NimNode) {.compileTime.} =
      var k = kRaw
      if k == "className": k = "class"
      let kl = k.toLowerAscii()
      if kl.len >= 3 and kl[0..1] == "on":
        let evt = kl[2..^1]
        evtNames.add evt
        evtHandlers.add v
      else:
        let vv = (if v.kind in {nnkStrLit, nnkRStrLit}: v else: newCall(ident"$", v))
        kvs.add newTree(nnkPar, newLit(k), vv)

    # ----- NEW: lower control-flow to mountChild(parent, expr) -----
    proc lowerMount(parent, node: NimNode): NimNode {.compileTime.} =
      case node.kind
      of nnkStmtList, nnkStmtListExpr, nnkBlockStmt:
        result = newTree(nnkStmtList)
        for it in node:
          result.add(lowerMount(parent, it))

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
              ifNode.add(newTree(nnkElifBranch, br[0], lowerMount(parent, br[1])))
            of nnkElse:
              ifNode.add(newTree(nnkElse, lowerMount(parent, br[0])))
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
          result = newCall(ident"mountIf", parent, cond, thenExpr, elseExpr)


      of nnkCaseStmt:
        proc toExpr(body: NimNode): NimNode {.compileTime.} =
          (if body.kind == nnkStmtList and body.len > 0: body[^1] else: body)

        let disc = node[0]
        let sel  = ident"caseDisc"     # this matches the injected name above

        let caseNode = newTree(nnkCaseStmt, sel)
        for br in node[1..^1]:
          case br.kind
          of nnkOfBranch:
            var branch = newTree(nnkOfBranch)
            for lit in br[0..^2]:
              branch.add lit
            branch.add toExpr(br[^1])
            caseNode.add branch
          of nnkElse:
            caseNode.add newTree(nnkElse, toExpr(br[0]))
          else: discard

        result = newCall(ident"mountCase", parent, disc, caseNode)




      of nnkForStmt, nnkWhileStmt:
        let loop = copy node
        loop[^1] = lowerMount(parent, node[^1])
        result = loop

      # allow variable defs/assignments inline without mounting
      of nnkLetSection, nnkVarSection, nnkConstSection, nnkAsgn, nnkDiscardStmt:
        result = node

      else:
        # Any expression -> mount it
        result = newCall(ident"mountChild", parent, node)
    # ----------------------------------------------------------------

    for a in args:
      case a.kind
      of nnkStmtList, nnkStmtListExpr:
        for it in a: pushChild(it)
      of nnkExprEqExpr: handleAttr($a[0], a[1])
      of nnkInfix:
        if a[0].kind == nnkIdent and $a[0] == "=": handleAttr($a[1], a[2]) else: pushChild(a)
      of nnkIdent: kvs.add newTree(nnkPar, newLit($a), newLit("true"))
      else: pushChild(a)

    let n = genSym(nskLet, "n")
    let stmts = newTree(nnkStmtListExpr)
    stmts.add newLetStmt(n, newCall(ident"el", newLit(tagName), newTree(nnkPrefix, ident"@", kvs)))

    # use lowerMount for everything
    for c in kids: stmts.add lowerMount(n, c)

    # events (hoisted)
    for i in 0 ..< evtNames.len:
      let cbSym = genSym(nskLet, "cb")
      stmts.add newLetStmt(cbSym, evtHandlers[i])
      stmts.add newCall(ident"jsAddEventListener", n, newCall(ident"cstring", newLit(evtNames[i])), cbSym)

    stmts.add n
    result = stmts



makeTag `d`
makeTag `h1`
makeTag `section`
makeTag `button`
makeTag `br`
makeTag `ul`
makeTag `li`
makeTag `style`
makeTag `b`


when isMainModule:
  var count: Signal[int] = signal(0)
  let doubled: Signal[system.string] = derived(count, proc (x: int): string = $(x*2))

  let isEven: Signal[system.bool] = derived(count, proc (x: int): bool =
    if x mod 2 == 0: true else: false
  )
  var name: Signal[string] =  derived(isEven, proc (x: bool): string =
    if x == true: "Jebbrel" else: "Almanda"
  )

  let styleTag =
    style:
      """
        ._div_container_87897126 {
          background-color: #eee;
          padding: 12px;
          border-radius: 8px;
        }
      """

  let component: Node =
    d(id="hero", class="_div_container_87897126"):
      "Count: "; count; br(); "Doubled: "; doubled; br(); br();
      button(
        class="btn",
        onClick = proc (e: Event) = count.set(count.get() + 1)
      ): "Increment"

      ul:
        li: derived(count, proc (x: int): string = $(x*2 + 1))
        li: derived(count, proc (x: int): string = $(x*2 + 2))
        li: derived(count, proc (x: int): string = $(x*2 + 3))

      if isEven:
        h1: "EVEN"
      else:
        b: "ODD"

      case name:
      of "Jebbrel":
        h1: "Jebbrel"
      else:
        h1: "Almanda"

      ul:
        for i in 1..3:
          li: doubled

  discard jsAppendChild(document.head, styleTag)
  discard jsAppendChild(document.body, component)
