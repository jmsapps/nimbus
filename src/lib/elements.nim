import
  dom,
  macros,
  strutils

import
  mount,
  shims,
  overloads,
  signals

import
  types


template createHtmlElement*(name: untyped) =
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


export
  dom,
  macros

export
  mount,
  shims,
  overloads,
  signals,
  types
