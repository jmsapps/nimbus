import ../src/nimbus

when isMainModule:
  let light = signal[bool](true)

  let component: Node =
    d:
      h1: "If Statements"

      if track(light, get(light)) == true:
        h2: "Light is on"
      else:
         h2: "Light is off"

      button(
        onClick = proc (e: Event) =
          light.set((if get(light) == true: false else: true))
      ):
        "Flip switch"

  discard jsAppendChild(document.body, component)
