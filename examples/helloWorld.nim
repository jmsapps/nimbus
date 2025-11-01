import ../src/ntml


when isMainModule:
  let component: Node =
    d:
      h1: "Hello world!"

  discard jsAppendChild(document.body, component)
