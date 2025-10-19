when defined(js):
  import
    random

  import
    ../src/nimbus


  when isMainModule:
    randomize()

    type
      LightState = enum
        on,
        off

      LightSwitch = object
        state: LightState

      Light = object
        switch: LightSwitch

    let dice: Signal[int] = signal[int](rand(1..6))
    let light: Signal[Light] = signal(Light(switch: LightSwitch(state: on)))

    let component: Node =
      d:
        h1: "If Statements"

        h2:
          if dice == 1 and dice != 2 or 1 == 2 or false or (true and false):
            "You rolled a 1"
          elif dice >= 2 and dice <= 6:
            "You rolled a "; dice
          else:
            "The die landed perfectly on its corner... what are the odds?"

        button(
          onClick = proc (e: Event) =
            let roll = rand(1..6)
            let fluke = rand(1..1000)

            dice.set((if fluke == 666: 7 else: roll))
        ):
          "Roll dice"

        br();br();
        "------------------------------"
        br();br();

        h2:
          if light.switch.state == on:
            "Light is on"
          else:
            "Light is off"

        button(onClick =
          proc (e: Event) =
            let state = get(light).switch.state
            light.set(Light(switch: LightSwitch(state: (if state == on: off else: on))))
        ):
          "Turn light "; if light.switch.state == on: "off" else: "on"

    discard jsAppendChild(document.body, component)
