when defined(js):
  import ../src/nimbus

  when isMainModule:
    type
      SubObj = object
        subList: seq[string]

      Object = object
        subObj: SubObj

    let obj = signal[Object](Object(subObj: SubObj(subList: @["*", "-", "-", "-", "-"])))

    static:
      doAssert obj.subObj is Signal[SubObj]
      doAssert obj.subObj.subList is Signal[seq[string]]
      doAssert not compiles(obj.n)

    let component: Node =
      d:
        h1: "For Statements"

        ul:
          for i, v in obj.subObj.subList:
            li: obj.subObj.subList[i]; v

        br(); br();

        button(onClick =
          proc (e: Event) =
            var oldList = get(obj).subObj.subList
            let popped = @[oldList.pop()]
            let newList = popped & oldList

            set(obj, Object(subObj: SubObj(subList: newList)))
        ):
          "Cycle list"

    discard jsAppendChild(document.body, component)
