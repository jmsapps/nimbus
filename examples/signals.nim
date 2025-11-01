import ../src/ntml


when isMainModule:
  type
    Person = object
      firstname: string
      favoriteFood: string

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
      class=props.class & " playground"
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
        class="btn primary",
        onClick = proc (e: Event) =
          count.set(count.get() + 1)
      ): "Increment"

      ul(class="future-list"):
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

      d(
        class="notice",
        hidden=(derived(isEven, proc(x: bool): bool = not x))
      ):
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

      d(class="toggle-stack"):
        button(
          class="btn ghost",
          onClick = proc(e: Event) =
            showSection.set(not showSection.get())
        ): "Toggle Section"

        if showSection:
          p(class="status-chip is-active"): "Reactive section visible!"
        else:
          p(class="status-chip"): "Section hidden."

      br();br();

      form(
        class="form-card",
        onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Submitted: ", formValue.get()
        ):
        label(`for`="firstname", class="form-label"): "First name"
        input(
          id="firstname",
          class="form-input",
          `type`="text",
          name="firstname",
          value=formValue
        )
        button(`type`="submit", class="btn primary", disabled=formValue == ""): "Submit"

      br();br();

      form(
        class="form-card",
        onsubmit = proc (e: Event) =
          e.preventDefault()
          echo "Accepted? ", accepted.get()
        ):
        label(`for`="terms", class="form-checkbox-label"):
          input(
            id="terms",
            class="form-checkbox",
            `type`="checkbox",
            name="terms",
            checked=accepted
          )
          span: "Accept terms and conditions"
        button(`type`="submit", class="btn primary", disabled=not accepted): "Submit"

      br();br()

      button(
        class="btn ghost",
        onClick = proc (e: Event) =
          people.set(@[people.get()[1], people.get()[0]])
      ): "Swap People"

      ul(class="people-list"):
        for i, person in people:
          li(class="people-item"):
            span(class="muted"): "#" & $(i + 1)
            span: person.firstname
            span(class="muted"): "likes " & person.favoriteFood


  let component: Node = Component(Props(
    title: "NTML Test Playground",
    class: "_div_container_a"
  )):
    NestedComponent(Props(id: "nested_component")):
      b:
        "This is a nested component"

  let styleTag: Node =
    style:
      """
        :root {
          background: #0f172a;
          color: #e2e8f0;
          font-family: 'Inter', system-ui, sans-serif;
        }

        body {
          margin: 0;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 3.5rem 1.5rem;
          background: radial-gradient(circle at 10% 15%, rgba(59,130,246,0.22), transparent 55%),
                      radial-gradient(circle at 85% 85%, rgba(56,189,248,0.22), transparent 55%),
                      #0f172a;
        }

        .playground {
          width: min(720px, 100%);
          background: rgba(15, 23, 42, 0.72);
          border-radius: 24px;
          padding: 2.4rem;
          display: flex;
          flex-direction: column;
          gap: 1.4rem;
          box-shadow: 0 32px 60px rgba(8, 15, 35, 0.45);
          border: 1px solid rgba(148, 163, 184, 0.2);
        }

        .btn {
          border: none;
          border-radius: 999px;
          padding: 0.8rem 1.4rem;
          font-weight: 600;
          letter-spacing: 0.04em;
          cursor: pointer;
          transition: transform 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
        }

        .btn.primary {
          background: linear-gradient(135deg, #2563eb, #38bdf8);
          color: #fff;
        }

        .btn.primary:hover {
          transform: translateY(-1px);
          box-shadow: 0 16px 34px rgba(37, 99, 235, 0.32);
        }

        .btn.ghost {
          background: transparent;
          color: inherit;
          border: 1px solid rgba(148, 163, 184, 0.35);
        }

        .btn.ghost:hover {
          background: rgba(148, 163, 184, 0.16);
        }

        .future-list,
        .people-list {
          margin: 0;
          padding: 0;
          list-style: none;
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }

        .future-list li {
          padding: 0.65rem 0.9rem;
          border-radius: 12px;
          background: rgba(148, 163, 184, 0.12);
          border: 1px solid rgba(148, 163, 184, 0.2);
        }

        .people-item {
          display: flex;
          gap: 0.7rem;
          align-items: center;
          padding: 0.65rem 0.9rem;
          border-radius: 14px;
          background: rgba(30, 41, 59, 0.65);
          border: 1px solid rgba(148, 163, 184, 0.18);
        }

        .muted {
          color: rgba(148, 163, 184, 0.72);
        }

        .notice {
          padding: 0.85rem 1rem;
          border-radius: 16px;
          background: rgba(16, 185, 129, 0.2);
          color: #bbf7d0;
          font-weight: 600;
        }

        .toggle-stack {
          display: flex;
          flex-direction: column;
          gap: 0.6rem;
        }

        .status-chip {
          margin: 0;
          align-self: flex-start;
          padding: 0.45rem 0.85rem;
          border-radius: 999px;
          font-size: 0.9rem;
          background: rgba(148, 163, 184, 0.18);
          color: rgba(226, 232, 240, 0.85);
        }

        .status-chip.is-active {
          background: rgba(16, 185, 129, 0.22);
          color: #bbf7d0;
        }

        .form-card {
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
          padding: 1.1rem;
          border-radius: 18px;
          background: rgba(15, 23, 42, 0.7);
          border: 1px solid rgba(148, 163, 184, 0.18);
        }

        .form-label {
          font-size: 0.8rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: rgba(148, 163, 184, 0.78);
        }

        .form-input {
          border: none;
          border-radius: 12px;
          padding: 0.75rem 1rem;
          background: rgba(30, 41, 59, 0.75);
          color: inherit;
        }

        .form-input:focus {
          outline: 2px solid rgba(56, 189, 248, 0.45);
        }

        .form-checkbox-label {
          display: flex;
          align-items: center;
          gap: 0.7rem;
          font-size: 0.95rem;
          color: rgba(226, 232, 240, 0.9);
        }

        .form-checkbox {
          width: 18px;
          height: 18px;
          accent-color: #38bdf8;
        }
      """

  discard jsAppendChild(document.head, styleTag)
  discard jsAppendChild(document.body, component)
