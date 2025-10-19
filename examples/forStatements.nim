when defined(js):
  import ../src/nimbus

  when isMainModule:
    type
      SubObj = object
        subList: seq[string]

      Object = object
        subObj: SubObj

    let obj = signal[Object](Object(subObj: SubObj(subList: @["*", "-", "-", "-", "-"])))
    let list = signal[seq[string]](@["-"])

    static:
      doAssert obj.subObj is Signal[SubObj]
      doAssert obj.subObj.subList is Signal[seq[string]]
      doAssert not compiles(obj.n)

    discard jsAppendChild(document.head, block:
      style:
        """
        .div_container {
          display: flex;
          flex-direction: column;
          width: fit-content;
          gap: 0.5rem;
        }
        """
    )

    let component: Node =
      d:
        h1: "For Statements"

        ul:
          for i, v in obj.subObj.subList:
            li: obj.subObj.subList[i]; v

        button(onClick =
          proc (e: Event) =
            var oldList = get(obj).subObj.subList
            let popped = @[oldList.pop()]
            let newList = popped & oldList

            set(obj, Object(subObj: SubObj(subList: newList)))
        ):
          "Cycle list"

        br();br();
        "------------------------------"
        br();

        h2:
          "Number of items in list: "; len(list)

        d(class="div_container"):
          button(onClick =
            proc (e: Event) =
              list.set(list() & @["-"])
          ):
            "Add to list"

          button(
            onClick=(proc (e: Event) =
              list.set(list()[0 ..< max(0, len(list()) - 1)])
            ),
            disabled=(len(list) == 0)
          ):
            "Remove from list"

        ul:
          for i in list:
            li: i

    discard jsAppendChild(document.body, component)
