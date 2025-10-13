# Create Element

This became obsolete once I decided that children and attributes required macros to be fully
reactive. It was possible to achieve reactivity without macros, but I wanted to avoid helpers
for if/case/for statements. I wonder at the point of writing this if I actually needed
macros or if I am just lacking experience with Nim. I would much prefer this simplicity.

```nim
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
