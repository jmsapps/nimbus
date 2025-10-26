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
    styleEntries: Table[string, StyleEntry] = initTable[string, StyleEntry]()


  proc jsInsertCssRule(el: Node; rule: cstring; index: int): int {.importjs: """
    (function(el, rule, index){
      if (!el || !el.sheet) return -1;
      var sheet = el.sheet;
      var target = (typeof index === 'number' && index >= 0)
        ? Math.min(index, sheet.cssRules.length)
        : sheet.cssRules.length;
      try {
        return sheet.insertRule(rule, target);
      } catch (err) {
        console.error(err);
        return -1;
      }
    })(#,#,#)
  """.}


  proc jsSetRuleCss(el: Node; index: int; css: cstring) {.importjs: """
    (function(el, index, css){
      if (!el || !el.sheet) return;
      var sheet = el.sheet;
      var rule = sheet.cssRules[index];
      if (rule && rule.style) {
        rule.style.cssText = css || '';
      }
    })(#,#,#)
  """.}


  proc jsDeleteCssRule(el: Node; index: int) {.importjs: """
    (function(el, index){
      if (!el || !el.sheet) return;
      var sheet = el.sheet;
      if (typeof index === 'number' && index >= 0 && index < sheet.cssRules.length) {
        sheet.deleteRule(index);
      }
    })(#,#)
  """.}


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


  proc jsReadStyled(el: Node): cstring {.importjs: """
    (function(el){
      if (!el || typeof el.getAttribute !== 'function') return '';
      return el.getAttribute('data-styled') || '';
    })(#)
  """.}


  proc ensureStyleNode() =
    if styleNode == nil:
      styleNode = jsCreateElement(cstring("style"))
      jsSetAttribute(styleNode, cstring("data-styled"), cstring("nimbus"))
      discard jsAppendChild(document.head, styleNode)


  proc ensureEntry(cls, css: string) =
    ensureStyleNode()
    if cls notin styleEntries:
      styleEntries[cls] = StyleEntry(css: css, ruleIndex: -1, count: 0)
    elif styleEntries[cls].css != css:
      var entry = styleEntries[cls]
      entry.css = css
      if entry.count > 0 and entry.ruleIndex >= 0:
        jsSetRuleCss(styleNode, entry.ruleIndex, cstring(css))
      styleEntries[cls] = entry


  proc retainStyle(cls: string) =
    if cls notin styleEntries:
      return
    var entry = styleEntries[cls]
    if entry.count == 0:
      ensureStyleNode()
      entry.ruleIndex = jsInsertCssRule(
        styleNode,
        cstring("." & cls & "{" & entry.css & "}"),
        -1
      )
    entry.count = entry.count + 1
    styleEntries[cls] = entry


  proc releaseStyle(cls: string) =
    if cls notin styleEntries:
      return
    var entry = styleEntries[cls]
    if entry.count <= 1:
      let removedIdx = entry.ruleIndex
      styleEntries.del(cls)
      if removedIdx >= 0:
        jsDeleteCssRule(styleNode, removedIdx)
        for _, other in styleEntries.mpairs():
          if other.ruleIndex > removedIdx:
            other.ruleIndex = other.ruleIndex - 1
    else:
      entry.count = entry.count - 1
      styleEntries[cls] = entry


  proc injectCssOnce*(cls: string; css: string) =
    ensureEntry(cls, css)


  proc markStyledClass*(el: Node; cls: string) =
    # stash the styled class on a data-* so mount layer can union it
    if jsMarkStyled(el, cstring(cls)):
      retainStyle(cls)


  proc unionWithStyled*(el: Node; incoming: cstring): cstring =
    # merge incoming class string with data-styled before setting 'class'
    jsUnionStyled(el, incoming)


  proc releaseStyledFromNode(el: Node) =
    if el == nil:
      return

    let attr = $jsReadStyled(el)
    if attr.len > 0:
      for cls in attr.splitWhitespace():
        if cls.len > 0:
          releaseStyle(cls)

    var child = jsGetNodeProp(el, cstring("firstChild"))
    while child != nil:
      let nxt = jsGetNodeProp(child, cstring("nextSibling"))
      releaseStyledFromNode(child)
      child = nxt

  addNodeDisposer(releaseStyledFromNode)


  macro styled*(Name, Base, CSS: untyped): untyped =
    # Defines a thin template wrapper that always injects a css attribute
    # before forwarding the rest of the arguments to the base element.
    result = quote do:
      template `Name`*(args: varargs[untyped]): untyped =
        `Base`(css = `CSS`, args)
