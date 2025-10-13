import ../src/nimbus


when isMainModule:
  type
    Person = object
      firstname: string
      favoriteFood: string

  let styleTag: Node =
    style:
      """
        ._div_container_a {
          background-color: #eee;
          padding: 24px;
          border-radius: 20px;
          font-family: sans-serif;
        }
      """

  proc NestedComponent(props: Props, children: Node): Node =
    d(id=props.id):
      children

  proc Component(props: Props, children: Node): Node =
    let count: Signal[int] = signal(0)
    let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))
    let showSection: Signal[bool] = signal(true)
    let isEven: Signal[bool] = derived(count, proc (x: int): bool =
      if x mod 2 == 0: true else: false
    )
    let formValue: Signal[cstring] = signal(cstring(""))
    let accepted: Signal[bool] = signal(false)
    let people: Signal[seq[Person]] = signal(@[
      Person(firstname: "Axel", favoriteFood: "pizza"),
      Person(firstname: "Synn", favoriteFood: "pasta"),
    ])

    let fruit: Signal[string] = signal("apple")
    let fruitIndex: Signal[int] = signal(0)

    discard effect(proc (): Unsub =
      proc cleanup() =
        echo "cleanup ran"

      echo "effect ran, count = ", count.get()

      let fruitBasket: seq[string] = @["apples", "bananas", "cherries", "dates"]
      fruit.set(fruitBasket[fruitIndex.get()])

      let newFruitIndex: int = (if fruitIndex.get() < 3: fruitIndex.get() + 1 else: 0)

      fruitIndex.set(newFruitIndex)

      result = cleanup
    , [count])

    discard effect(proc(): Unsub =
      echo "signal mounted!"
      result = proc() =
        echo "cleanup ran"
    , [showSection])

    let unsub: Unsub = effect(proc (): Unsub =
      echo "one-time effect ran"
      return proc() = echo "cleanup ran later"
    )

    unsub()

    d(id=
        case fruit:
        of "apples", "cherries": "red"
        of "bananas": "yellow"
        else: "it depends",
      class=props.title
    ):
      h1(
        `data-even`=
        if (isEven and 1+1 == 2) or (1+1 == 4):
          "even"
        else:
          "odd"
      ): props.title

      "Count: "; count; br(); "Doubled: "; doubled; br(); br();
      button(
        class="btn",
        onClick = proc (e: Event) =
          count.set(count.get() + 1)
      ): "Increment"

      ul:
        li: derived(count, proc (x: int): string = $(x*2 + 1))
        li: derived(count, proc (x: int): string = $(x*2 + 2))
        li: derived(count, proc (x: int): string = $(x*2 + 3))

      "Jebbrel wants to eat "
      case fruit:
      of "apples":
        fruit.get()
      of "bananas":
        fruit.get()
      of "cherries":
        fruit.get()
      of "dates":
        fruit.get()
      else:
        ""

      br();br();

      if isEven:
        "Count is even"
      else:
        "Count is odd"

      i: " (Almanda becomes shy when Count is odd)"

      br();br()

      d(hidden=(derived(isEven, proc(x: bool): bool = not x))):
        "Hi, I'm Almanda!"

        br();br();

      "(fruit == \"apples\" and not isEven) or (fruit == \"bananas\"): "
      if (fruit == "apples" and not isEven) or (fruit == "bananas"):
        "Match"
      else:
        "No match"

      br();br()

      children

      br();

      d:
        button(onClick = proc(e: Event) =
          showSection.set(not showSection.get())
        ): "Toggle Section"

        br(); br();

        if showSection:
          "Reactive section visible!"
        else:
          "Section hidden."

      br();br();

      form(onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Submitted: ", formValue.get()
        ):
        label(`for`="firstname"): "First name:"; br()
        input(
          id="firstname",
          `type`="text",
          name="firstname",
          value=formValue
        ); br()
        button(`type`="submit", disabled=formValue == "", style="margin-top: 8px"): "Submit"

      br();br();

      form(onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Accepted? ", accepted.get()
        ):
        label(`for`="terms"): "Accept terms and conditions"; br()
        input(
          id="terms",
          `type`="checkbox",
          name="terms",
          checked=accepted
        ); br()
        button(`type`="submit", disabled=not accepted, style="margin-top: 8px"): "Submit"

      br();br()

      button(
        class="btn",
        onClick = proc (e: Event) =
          people.set(@[people.get()[1], people.get()[0]])
      ): "Swap People"

      ul:
        for i, person in people:
          li:
            i; " "; person.firstname; " likes "; person.favoriteFood;


  let component: Node = Component(Props(
    title: "Nimbus Test Playground",
    class: "_div_container_a"
  )):
    NestedComponent(Props(id: "nested_component")):
      b:
        "This is a nested component"

  discard jsAppendChild(document.head, styleTag)
  discard jsAppendChild(document.body, component)
