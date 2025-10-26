when defined(js):
  from dom import document, Node, Event, Window

  # render
  proc render*(node: Node) {.importjs: "document.body.appendChild(#)".}

  # Elements
  proc jsCreateElement*(s: cstring): Node {.importjs: "document.createElement(#)".}
  proc jsCreateFragment*(): Node {.importjs: "document.createDocumentFragment()".}
  proc jsCreateTextNode*(s: cstring): Node {.importjs: "document.createTextNode(#)".}
  proc jsAppendChild*(p: Node, c: Node): Node {.importjs: "#.appendChild(#)".}
  proc jsRemoveChild*(p: Node, c: Node): Node {.importjs: "#.removeChild(#)".}
  proc jsInsertBefore*(p: Node, newChild: Node, refChild: Node): Node {.importjs: "#.insertBefore(#,#)".}

  # Attributes
  proc jsSetAttribute*(el: Node, k: cstring, v: cstring) {.importjs: "#.setAttribute(#,#)".}
  proc jsRemoveAttribute*(el: Node, k: cstring) {.importjs: "#.removeAttribute(#)".}

  # Event listeners
  proc jsAddEventListener*(el: Node, t: cstring, cb: proc (e: Event)) {.importjs: "#.addEventListener(#,#)".}
  proc jsAddEventListener*(w: Window; t: cstring; cb: proc (e: Event)) {.importjs: "#.addEventListener(#,#)".}
  proc jsRemoveEventListener*(el: Node, t: cstring, cb: proc (e: Event)) {.importjs: "#.removeEventListener(#,#)".}
  proc jsRemoveEventListener*(w: Window; t: cstring; cb: proc (e: Event)) {.importjs: "#.removeEventListener(#,#)".}

  # Props
  proc jsGetProp*(el: Node, k: cstring): cstring {.importjs: "String(#[#])".}
  proc jsGetStringProp*(el: Node, k: cstring): cstring {.importjs: "String(#[#])".}
  proc jsGetNodeProp*(el: Node, k: cstring): Node {.importjs: "#[#]".}
  proc jsGetIntProp*(el: Node, k: cstring): int {.importjs: "Number(#[#])".}
  proc jsGetBoolProp*(el: Node, k: cstring): bool {.importjs: "Boolean(#[#])".}
  proc jsSetProp*(el: Node, k: cstring, v: bool) {.importjs: "#[#] = #".}
  proc jsSetProp*(el: Node, k: cstring, v: cstring) {.importjs: "#[#] = #".}
  proc jsSetProp*(el: Node, k: cstring, v: int) {.importjs: "#[#] = #".}
  proc jsSetProp*(el: Node, k: cstring, v: float) {.importjs: "#[#] = #".}

  # Routing
  proc jsLocationPathname*(default: string = "/"): string {.importjs: "cstrToNimstr(window.location.pathname || toJSStr(#))".}
  proc jsLocationSearch*(default: string = ""): string {.importjs: "cstrToNimstr(window.location.search || toJSStr(#))".}
  proc jsLocationHash*(default: string = ""): string {.importjs: "cstrToNimstr(window.location.hash || toJSStr(#))".}
  proc jsHistoryPushState*(url: string) {.importjs: "window.history.pushState(null, '', toJSStr(#))".}
  proc jsHistoryReplaceState*(url: string) {.importjs: "window.history.replaceState(null, '', toJSStr(#))".}
  proc jsLocationAssign*(url: string) {.importjs: "window.location.assign(toJSStr(#))".}
