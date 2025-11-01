import ../src/ntml


when isMainModule:
  let component: Node =
    h1: "Hello world!"

  discard jsAppendChild(document.body, component)
