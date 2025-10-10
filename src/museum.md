```nim
# Working cleanup in shims rather than Nim code
proc registerCleanup*(el: Node, fn: Unsub)
  {.importjs: "((e,f)=>{(e.__nimbusC||(e.__nimbusC=[])).push(f)})(#,#)".}
proc runCleanups*(el: Node)
  {.importjs: "((e)=>{if(e.__nimbusC){for(var i=0;i<e.__nimbusC.length;i++){try{e.__nimbusC[i]();}catch(_){}} e.__nimbusC=[]}})(#)".}
```

```nim
# This has become obsolete now that children and attributes require macros to be fully reactive
# It's possible to achieve reactivity without macros, but I wanted to avoid helpers for loops, if and case statements
proc createElement*(tag: string, props: openArray[(string, string)] = [], children: varargs[Node]): Node =
  const BOOLEAN_ATTRS: array[8, string] = [
    "hidden", "disabled", "checked", "selected", "readonly", "multiple", "required", "open"
  ]
  let element = jsCreateElement(cstring(tag))

  proc propKey(attr: string): cstring =
    case attr.toLowerAscii()
    of "contenteditable": "contentEditable"
    of "for", "htmlfor": "htmlFor"
    of "maxlength": "maxLength"
    of "readonly": "readOnly"
    of "tabindex": "tabIndex"
    else: cstring(attr)

  proc toBoolStr(value: string): bool =
    let v = value.toLowerAscii()
    v != "" and v != "false" and v != "0" and v != "off" and v != "no"

  for (key, value) in props:
    let kLower = key.toLowerAscii()

    if kLower in BOOLEAN_ATTRS:
      let on: bool = toBoolStr(value)

      jsSetProp(element, propKey(kLower), on)

      if on:
        jsSetAttribute(element, cstring(kLower), "")

      else:
        jsRemoveAttribute(element, cstring(kLower))

    else:
      if value.len == 0:
        case kLower
        of "class", "style":
          discard
        else:
          jsSetProp(element, propKey(kLower), cstring(""))
        jsRemoveAttribute(element, cstring(kLower))

      else:
        case kLower
        of "class", "style":
          discard
        else:
          jsSetProp(element, propKey(kLower), cstring(value))

        jsSetAttribute(element, cstring(kLower), cstring(value))

  for c in children:
    discard jsAppendChild(element, c)

  element
```

```nim
# Interesting overloads for iterators
iterator items*[T](s: Signal[seq[T]]): lent T =
  for it in s.get():
    yield it

iterator pairs*[T](s: Signal[seq[T]]): (int, lent T) =
  var i = 0
  for it in s.get():
    yield (i, it)
    inc i
```

```nim
# Interesting way to debug, by passing the arg like `nim js -d:loopDebug nimbus.nim`
when defined(loopDebug):
  echo "=== LOWERED FOR ==="
  echo treeRepr(newTree(nnkStmtList,
    renderProc,
    newCall(ident"mountFor", parent, newCall(ident"toSeqAuto", iterExpr), renderFn)
  ))
```
