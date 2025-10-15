import ../src/nimbus

when isMainModule:
  type
    SubObject = object
      subList: seq[int]

    Object = object
      subObject: SubObject

  let obj = signal[Object](Object(subObject: SubObject(subList: @[1, 2, 3, 4, 5])))

  let component: Node =
    d:
      h1: "For Statements"

      for i in track(obj, get(obj).subObject.subList):
        i

  discard jsAppendChild(document.body, component)
