when defined(js):
  from dom import window, Event
  from strutils import startsWith

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
    if path.len == 0:
      return "/"

    if isExternalUrl(path) or path[0] == '#':
      return path

    if path[0] == '/':
      return path

    result = "/" & path


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

    res


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
    let normalized = normalizePath(path)

    if isExternalUrl(normalized):
      jsLocationAssign(normalized)

      return

    if replace:
      jsHistoryReplaceState(normalized)
    else:
      jsHistoryPushState(normalized)

    ensureRouteSignal().set(normalized)
