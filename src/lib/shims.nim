when defined(js):
  from dom import document, Node, Event


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
