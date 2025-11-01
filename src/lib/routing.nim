when defined(js):
  import macros
  from dom import window, Event
  from strutils import startsWith, endsWith, strip, split, join

  import
    signals,
    shims,
    types

  var routeSignal: Signal[string]
  var listenersRegistered = false
  var routeListener: proc (e: Event)


  proc isExternalUrl(path: string): bool =
    path.startsWith("http://") or path.startsWith("https://") or path.startsWith("//")


  proc normalizePath(path: string): string =
    var res = path

    if res.len == 0:
      return "/"

    if isExternalUrl(res) or res[0] == '#':
      return res

    if res[0] != '/':
      res = "/" & res

    if res.len > 1 and res.endsWith("/"):
      res = res[0 ..< res.len-1]

    result = res


  proc currentPath*(): string =
    var res = jsLocationPathname("/")
    if res.len == 0:
      res = "/"

    let q = jsLocationSearch("")

    if q.len > 0:
       res.add(q)

    let h = jsLocationHash("")

    if h.len > 0:
      res.add(h)

    normalizePath(res)


  proc registerRouteListeners() =
    if listenersRegistered:
      return

    routeListener = proc(e: Event) =
      if routeSignal != nil:
        routeSignal.set(currentPath())

    jsAddEventListener(window, cstring("popstate"), routeListener)
    jsAddEventListener(window, cstring("hashchange"), routeListener)

    listenersRegistered = true


  proc ensureRouteSignal*(): Signal[string] =
    if routeSignal == nil:
      routeSignal = signal(currentPath())
      registerRouteListeners()

    routeSignal


  proc router*(): Router =
    Router(location: ensureRouteSignal())


  proc navigate*(path: string, replace = false) =
    var normalized = normalizePath(path)
    let base = ensureRouteSignal().get()

    if path.startsWith("+/"):
      let rel = path[2..^1]               # remove "+/"
      let joined = (if base.endsWith("/"): base & rel else: base & "/" & rel)
      normalized = normalizePath(joined)

    if path.startsWith("-/"):
      let rel = path[2..^1]
      var parts = base.strip(chars={'/'}).split("/")
      if parts.len > 0: discard parts.pop()    # go up one level
      let joined = "/" & (if parts.len > 0: parts.join("/") & "/" & rel else: rel)
      normalized = normalizePath(joined)

    if isExternalUrl(normalized):
      jsLocationAssign(normalized)

      return

    if replace:
      jsHistoryReplaceState(normalized)

    else:
      jsHistoryPushState(normalized)

    ensureRouteSignal().set(normalized)


macro Routes*(location: typed; body: untyped): untyped =
  proc joinPath(base, seg: string): string =
    if seg.len == 0: return (if base.len == 0: "/" else: base)
    if seg[0] == '/': return seg
    if base.len == 0 or base == "/": return "/" & seg
    (if base.endsWith("/"): base & seg else: base & "/" & seg)

  var branches: seq[NimNode] = @[]
  var elseBody: NimNode = nil

  proc walk(n: NimNode; base: string) =
    for stmt in n:
      if stmt.kind in {nnkCall, nnkCommand} and $stmt[0] == "Route":
        var pathStr = ""
        var compExpr: NimNode = nil
        var children: NimNode = nil

        for i in 1 ..< stmt.len:
          let a = stmt[i]

          case a.kind
          of nnkExprEqExpr:
            let name = $a[0]

            if name == "path":
              if a[1].kind != nnkStrLit:
                error("Route path must be a string literal", a[1])

              pathStr = a[1].strVal

            elif name == "component":
              compExpr = a[1]

          of nnkStmtList:
            children = a

          else:
            discard

        if pathStr.len == 0:
          error("Route requires path=\"...\"", stmt)

        if compExpr.isNil and (children.isNil or children.len == 0):
          error("Route requires component=... or nested child Routes", stmt)

        if pathStr == "*":
          if compExpr.isNil:
            error("Wildcard Route(path=\"*\") requires component=...", stmt)

          elseBody = compExpr

          continue

        let full = joinPath(base, pathStr)

        if not compExpr.isNil:
          branches.add(newTree(nnkOfBranch, newStrLitNode(full), compExpr))

        if not children.isNil and children.len > 0:
          walk(children, full)

      else:
        error("Only Route(...) entries are allowed inside Routes", stmt)

  walk(body, "")

  var caseStmt = newTree(nnkCaseStmt, location)

  for b in branches:
    caseStmt.add(b)

  caseStmt.add(newTree(
    nnkElse,
    (if elseBody.isNil: newTree(nnkDiscardStmt, newEmptyNode()) else: elseBody)
  ))

  result = quote do:
    fragment:
      `caseStmt`
