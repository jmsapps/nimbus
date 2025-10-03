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

# ------------------- Overloaded operators -------------------
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


template makeTag(name: untyped) =
  macro `name`*(args: varargs[untyped]): untyped =
    var tagName = astToStr(name).replace("`","")

    if tagName == "d":
      tagName = "div"

    let keyValues = newTree(nnkBracket)
    var children: seq[NimNode] = @[]
    var eventNames: seq[string] = @[]
    var eventHandlers: seq[NimNode] = @[]

    # ----- helpers -----
    proc pushChild(node: NimNode) {.compileTime.} =
      children.add(node)

    proc handleAttr(keyRaw: string, value: NimNode) {.compileTime.} =
      var key = keyRaw
      if key == "className":
        key = "class"

      let keyLowered = key.toLowerAscii()

      if keyLowered.len >= 3 and keyLowered.startsWith("on"):
        let event = keyLowered[2..^1]
        eventNames.add(event)
        eventHandlers.add(value)

      else:
        let strValue = (
          if value.kind in {nnkStrLit, nnkRStrLit}: value else: newCall(ident"$", value)
        )

        keyValues.add(newTree(nnkPar, newLit(key), strValue))

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
              branch.add(lit)
            branch.add(toExpr(br[^1]))
            caseNode.add(branch)

          of nnkElse:
            caseNode.add(newTree(nnkElse, toExpr(br[0])))

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
        result = newCall(ident"mountChild", parent, node)
    # ----------------------------------------------------------------

    for a in args:
      case a.kind
      of nnkStmtList, nnkStmtListExpr:
        for it in a: pushChild(it)

      of nnkExprEqExpr:
        handleAttr($a[0], a[1])

      of nnkInfix:
        if a[0].kind == nnkIdent and $a[0] == "=":
          handleAttr($a[1], a[2])
        else: pushChild(a)

      of nnkIdent:
        keyValues.add(newTree(nnkPar, newLit($a), newLit("true")))

      else: pushChild(a)

    let node = genSym(nskLet, "node")
    let statements = newTree(nnkStmtListExpr)

    statements.add(
      newLetStmt(node, newCall(ident"el", newLit(tagName), newTree(nnkPrefix, ident"@", keyValues)))
    )

    # lower mount children
    for child in children:
      statements.add(lowerMount(node, child))

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

makeTag `d`
makeTag `h1`
makeTag `section`
makeTag `button`
makeTag `br`
makeTag `ul`
makeTag `li`
makeTag `style`
makeTag `b`
makeTag `p`

when isMainModule:
  type
    Props = object of RootObj
      class: string = ""
      children: Node

    ComponentProps = object of Props
      title: string

    NestedComponentProps = object
      id: string

  let styleTag =
    style:
      """
        ._div_container_a {
          background-color: #eee;
          padding: 12px;
          border-radius: 8px;
          font-family: sans-serif;
        }

        ._div_container_b {
          background-color: #ff0000ff;
          padding: 12px;
          border-radius: 8px;
        }
      """

  template NestedComponent(props: NestedComponentProps, children: untyped): Node =
    d(id=props.id):
      children

  template Component(props: ComponentProps): Node =
    let count: Signal[int] = signal(0)
    let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))

    let isEven: Signal[bool] = derived(count, proc (x: int): bool =
      if x mod 2 == 0: true else: false
    )

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

    discard effect(proc (): void =
      echo "effect ran, doubled = ", doubled.get()
    , [doubled])

    let unsub = effect(proc (): Unsub =
      echo "one-time effect ran"
      return proc() = echo "cleanup ran later"
    )

    unsub()

    d(id="hero", class=(if props.class != "": props.class else: "_div_container_a")):
      h1: props.title

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
        "Count is even"
      else:
        "Count is odd"

      br();br();

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

      "(fruit == \"apples\" and not isEven) or (fruit == \"bananas\"): "
      if (fruit == "apples" and not isEven) or (fruit == "bananas"):
        "Match"
      else:
        "No match"

      br();br()

      NestedComponent(NestedComponentProps(
        id: "nested_component")
      ):
        "This is a nested component"

      props.children

  let component: Node = Component(
    ComponentProps(
      title: "Nimbus Test Playground",
      # class: "_div_container_b",
      children: block:
        ul:
          for i in 1..3:
            li: i
    )
  )

  discard jsAppendChild(document.head, styleTag)
  discard jsAppendChild(document.body, component)
