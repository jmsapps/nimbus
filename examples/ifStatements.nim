when defined(js):
  import
    random

  import
    ../src/ntml


  when isMainModule:
    randomize()

    type
      LightState = enum
        on,
        off

      LightSwitch = object
        value: LightState

      Light = object
        switch: LightSwitch

    let dice: Signal[int] = signal[int](rand(1..6))
    let count: Signal[int] = signal[int](0)
    let light: Signal[Light] = signal(Light(switch: LightSwitch(value: on)))

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
            echo roll
            dice.set((if fluke == 666: 7 else: roll))
        ):
          "Roll dice"

        br();br();
        "------------------------------"
        br();br();

        h2:
          if light.switch.value == on:
            "Light is on"
          else:
            "Light is off"

        button(onClick =
          proc (e: Event) =
            let value = light().switch.value
            light.set(Light(switch: LightSwitch(value: (if value == on: off else: on))))
        ):
          "Turn light "; if light.switch.value == on: "off" else: "on"

        br();br();
        "------------------------------"
        br();br();

        h2:
          "count: "; count; br()
          if count < 5:
            "count is less than 5"
          elif count >= 5 and count < 10:
            "count is less than 10"
          else:
            "count is greater than 10"

        button(onClick =
          proc (e: Event) =
            count.set(if count() < 20: count() + 1 else: 1)
        ):
          "Increment count"

    discard jsAppendChild(document.body, component)
