when defined(js):
  from dom import Node, document
  import
    macros,
    tables

  import
    shims,
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


  proc ensureEntry(cls, css: string) =
    ensureStyleNode()
    if cls notin styleEntries:
      let rule = "." & cls & "{" & css & "}"
      let idx = jsInsertCssRule(styleNode, cstring(rule), -1)
      styleEntries[cls] = StyleEntry(css: css, ruleIndex: idx)
    elif styleEntries[cls].css != css:
      var entry = styleEntries[cls]
      entry.css = css
      if entry.ruleIndex >= 0:
        jsSetRuleCss(styleNode, entry.ruleIndex, cstring(css))
      else:
        entry.ruleIndex = jsInsertCssRule(styleNode, cstring("." & cls & "{" & css & "}"), -1)
      styleEntries[cls] = entry


  proc injectCssOnce*(cls: string; css: string) =
    ensureEntry(cls, css)


  proc markStyledClass*(el: Node; cls: string) =
    # stash the styled class on a data-* so mount layer can union it
    discard jsMarkStyled(el, cstring(cls))


  proc unionWithStyled*(el: Node; incoming: cstring): cstring =
    # merge incoming class string with data-styled before setting 'class'
    jsUnionStyled(el, incoming)


  macro styled*(Name, Base, CSS: untyped): untyped =
    # Defines a thin template wrapper that always injects a css attribute
    # before forwarding the rest of the arguments to the base element.
    result = quote do:
      template `Name`*(args: varargs[untyped]): untyped =
        `Base`(css = `CSS`, args)
