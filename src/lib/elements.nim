import
  dom,
  macros,
  strutils

import
  mount,
  shims,
  overloads,
  signals,
  routing

import
  types


macro defineHtmlElement*(tagNameLit: static[string]; args: varargs[untyped]): untyped =
  var tagName: string = tagNameLit
  let node: NimNode = genSym(nskLet, "node")
  let statements: NimNode = newTree(nnkStmtListExpr)

  case tagName
  of "d": tagName = "div"
  of "obj": tagName = "object"
  of "tmpl": tagName = "template"
  of "v": tagName = "var"
  else: discard

  var children: seq[NimNode] = @[]
  var eventNames: seq[string] = @[]
  var eventHandlers: seq[NimNode] = @[]
  var attrSetters: seq[NimNode] = @[]

  proc pushChild(node: NimNode) {.compileTime.} =
    children.add(node)

  proc lowerMountAttributes(keyRaw: string, value: NimNode) {.compileTime.} =
    var key = keyRaw

    if key == "className":
      key = "class"

    let keyLowered = key.toLowerAscii()
    let kLit = newLit(key)

    if keyLowered.len >= 3 and keyLowered.startsWith("on"):
      let event = keyLowered[2..^1]
      eventNames.add(event)
      eventHandlers.add(value)

      return

    if keyLowered == "value":
      attrSetters.add newCall(ident"bindValue", node, value)

      return

    elif keyLowered == "checked":
      attrSetters.add newCall(ident"bindChecked", node, value)

      return

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
    proc toExpr(body: NimNode): NimNode {.compileTime.} =
      let cont = genSym(nskLet, "cont")
      result = newTree(nnkStmtList,
        newLetStmt(cont, newCall(ident"jsCreateElement", newCall(ident"cstring", newLit("span")))),
        newCall(ident"setStringAttr", cont, newLit("style"), newLit("display: contents"))
      )
      if body.kind in {nnkStmtList, nnkStmtListExpr}:
        for stmt in body:
          result.add(lowerMountChildren(cont, stmt))
      else:
        result.add(lowerMountChildren(cont, body))

      result.add(cont)

    case node.kind
    of nnkStmtList, nnkStmtListExpr, nnkBlockStmt:
      result = newTree(nnkStmtList)
      for it in node:
        result.add(lowerMountChildren(parent, it))

    of nnkIfStmt:
      var conds: seq[NimNode] = @[]
      var bodies: seq[NimNode] = @[]
      var elseBody: NimNode

      for br in node:
        case br.kind
        of nnkElifBranch:
          conds.add(br[0])
          bodies.add(toExpr(br[1]))

        of nnkElse:
          elseBody = toExpr(br[0])

        else:
          discard

      let anyPrior: NimNode = genSym(nskVar, "anyPrior")
      var stmts: NimNode = newStmtList(
        newVarStmt(anyPrior, newCall(ident"signal", newLit(false)))
      )

      for i in 0 ..< conds.len:
        let ciSig: NimNode = conds[i]

        let gated: NimNode =
          if i == 0:
            ciSig
          else:
            newCall(ident"and", newCall(ident"not", anyPrior), ciSig)

        stmts.add(newCall(
          ident"mountChildIf",
          parent,
          gated,
          bodies[i],
          newCall(ident"jsCreateFragment")
        ))

        stmts.add(newAssignment(anyPrior, newCall(ident"or", anyPrior, ciSig)))

      if not elseBody.isNil:
        let elseCond: NimNode = newCall(ident"not", anyPrior)
        stmts.add(newCall(
          ident"mountChildIf",
          parent,
          elseCond,
          elseBody,
          newCall(ident"jsCreateFragment")
        ))

      result = stmts

    of nnkCaseStmt:
      let disc = node[0]
      let sel = ident"caseDisc"

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
      attrSetters.add(newCall(ident"mountAttr", node, newLit($a), newLit("true")))

    else:
      pushChild(a)

  let createExpr =
    if tagName == "fragment":
      newCall(ident"jsCreateFragment")
    else:
      newCall(ident"jsCreateElement", newCall(ident"cstring", newLit(tagName)))

  statements.add(newLetStmt(node, createExpr))

  for s in attrSetters:
    statements.add(s)

  for child in children:
    statements.add(lowerMountChildren(node, child))

  for i in 0 ..< eventNames.len:
    let eventNameExpr: NimNode = newCall(ident"cstring", newLit(eventNames[i]))
    let eventTypeSym: NimNode = genSym(nskLet, "eventType")
    let handlerSym: NimNode = genSym(nskLet, "handler")

    statements.add(newLetStmt(eventTypeSym, eventNameExpr))
    statements.add(newLetStmt(handlerSym, eventHandlers[i]))
    statements.add(newCall(ident"jsAddEventListener", node, eventTypeSym, handlerSym))
    statements.add(newCall(
      ident"registerCleanup",
      node,
      newProc(body = newCall(ident"jsRemoveEventListener", node, eventTypeSym, handlerSym))
    ))

  statements.add(node)

  result = statements


macro defineHtmlElements*(names: varargs[untyped]): untyped =
  result = newStmtList()

  proc tagNameOf(n: NimNode): string {.compileTime.} =
    case n.kind
    of nnkAccQuoted: $n[0]
    of nnkIdent: $n
    else: astToStr(n)

  for n in names:
    let s = tagNameOf(n)

    result.add(quote do:
      macro `n`*(args: varargs[untyped]): untyped =
        var call = newCall(ident"defineHtmlElement")
        call.add(newLit(`s`))

        for it in args:
          call.add(it)
        result = call
    )


defineHtmlElements a,
  abbr,
  address,
  area,
  article,
  aside,
  audio,
  b,
  base,
  bdi,
  bdo,
  blockquote,
  body,
  br,
  button,
  canvas,
  caption,
  cite,
  code,
  col,
  colgroup,
  data,
  datalist,
  dd,
  del,
  details,
  dfn,
  dialog,
  d,  # div
  dl,
  dt,
  em,
  embed,
  fieldset,
  figcaption,
  figure,
  footer,
  form,
  fragment,
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  head,
  header,
  hr,
  html,
  i,
  iframe,
  img,
  input,
  ins,
  kbd,
  label,
  legend,
  li,
  link,
  main,
  map,
  mark,
  menu,
  meta,
  meter,
  nav,
  noscript,
  obj,  # object
  ol,
  optgroup,
  option,
  output,
  p,
  param,
  picture,
  pre,
  progress,
  q,
  rp,
  rt,
  ruby,
  s,
  samp,
  script,
  section,
  select,
  slot,
  small,
  source,
  span,
  strong,
  style,
  sub,
  summary,
  sup,
  svg,
  table,
  tbody,
  td,
  tmpl,  # template
  textarea,
  tfoot,
  th,
  thead,
  time,
  title,
  tr,
  track,
  u,
  ul,
  v,  # var
  video,
  wbr

export
  dom,
  macros

export
  mount,
  shims,
  overloads,
  signals,
  routing,
  types
