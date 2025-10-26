when defined(js):
  from dom import Node, document
  import
    macros,
    strutils,
    tables

  import
    shims,
    signals,
    types


  var
    styleNode: Node
    styleSignal: Signal[string]
    styleEntries: Table[string, StyleEntry] = initTable[string, StyleEntry]()
    styleOrder: seq[string] = @[]


  proc jsMarkStyled(el: Node; cls: cstring): bool {.importjs: """
    (function(el, cls){
      var prev = el.getAttribute('data-styled');
      if (!prev) {
        el.setAttribute('data-styled', cls);
        return true;
      }
      var tokens = prev.split(/\s+/).filter(Boolean);
      if (tokens.indexOf(cls) !== -1) return false;
      tokens.push(cls);
      el.setAttribute('data-styled', tokens.join(' '));
      return true;
    })(#,#)
  """.}


  proc jsUnionStyled(el: Node; incoming: cstring): cstring {.importjs: """
    (function(el, inc){
      var s = el.getAttribute('data-styled') || '';
      var combo = ((inc || '') + ' ' + s).trim();
      if (!combo) return '';
      var set = new Set(combo.split(/\s+/).filter(Boolean));
      return Array.from(set).join(' ');
    })(#,#)
  """.}


  proc ensureStyleNode() =
    if styleNode == nil:
      styleNode = jsCreateElement(cstring("style"))
      jsSetAttribute(styleNode, cstring("data-styled"), cstring("nimbus"))
      discard jsAppendChild(document.head, styleNode)
      styleSignal = signal("")
      discard effect(proc (): Unsub =
        jsSetProp(styleNode, cstring("textContent"), cstring(styleSignal.get()))
        return proc () = discard
      , [styleSignal])


  proc removeFromOrder(cls: string) =
    var i = 0
    while i < styleOrder.len:
      if styleOrder[i] == cls:
        styleOrder.delete(i)
        break
      inc i


  proc rewriteSheet() =
    ensureStyleNode()
    var buf = ""
    for cls in styleOrder:
      if cls in styleEntries:
        let entry = styleEntries[cls]
        if entry.count > 0:
          buf.add("." & cls & "{")
          buf.add(entry.css)
          buf.add("}\n")
    styleSignal.set(buf)


  proc ensureEntry(cls, css: string) =
    if cls notin styleEntries:
      styleEntries[cls] = StyleEntry(css: css, count: 0)
      styleOrder.add(cls)
    elif styleEntries[cls].css != css:
      styleEntries[cls].css = css
      if styleEntries[cls].count > 0:
        rewriteSheet()


  proc retainStyle(cls: string) =
    if cls notin styleEntries: return
    if styleEntries[cls].count == 0:
      styleEntries[cls].count = 1
      rewriteSheet()
    else:
      styleEntries[cls].count = styleEntries[cls].count + 1


  proc releaseStyle(cls: string) =
    if cls notin styleEntries: return
    if styleEntries[cls].count <= 1:
      styleEntries.del(cls)
      removeFromOrder(cls)
      rewriteSheet()
    else:
      styleEntries[cls].count = styleEntries[cls].count - 1


  proc injectCssOnce*(cls: string; css: string) =
    ensureEntry(cls, css)


  proc markStyledClass*(el: Node; cls: string) =
    # stash the styled class on a data-* so mount layer can union it
    if jsMarkStyled(el, cstring(cls)):
      retainStyle(cls)


  proc unionWithStyled*(el: Node; incoming: cstring): cstring =
    # merge incoming class string with data-styled before setting 'class'
    jsUnionStyled(el, incoming)


  proc jsReadStyled(el: Node): cstring {.importjs: """
    (function(el){
      if (!el || typeof el.getAttribute !== 'function') return '';
      return el.getAttribute('data-styled') || '';
    })(#)
  """.}


  proc releaseStyledFromNode(el: Node) =
    let attr = $jsReadStyled(el)
    if attr.len == 0:
      return

    for cls in attr.splitWhitespace():
      if cls.len > 0:
        releaseStyle(cls)

  addNodeDisposer(releaseStyledFromNode)


  macro styled*(Name, Base, CSS: untyped): untyped =
    # Defines a thin template wrapper that always injects a css attribute
    # before forwarding the rest of the arguments to the base element.
    result = quote do:
      template `Name`*(args: varargs[untyped]): untyped =
        `Base`(css = `CSS`, args)
