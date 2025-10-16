when defined(js):
  import
    random

  import
    ../src/nimbus


  when isMainModule:
    randomize()

    let dice: Signal[int] = signal[int](rand(1..6))

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

    discard jsAppendChild(document.body, component)
