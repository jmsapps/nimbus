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
      d(class="layout"):
        header(class="hero"):
          h1(class="hero-title"): "If Statements"
          p(class="hero-copy"): "Simple conditional rendering examples with signals and button interactions."

        d(class="card-grid"):
          d(class="card"):
            h2(class="card-title"): "Dice Roller"
            p(class="card-result"):
              if dice == 1 and dice != 2 or 1 == 2 or false or (true and false):
                "You rolled a 1"
              elif dice >= 2 and dice <= 6:
                "You rolled a "
                span(class="highlight"): dice
              else:
                "The die landed perfectly on its corner... what are the odds?"

            button(
              class="primary-btn",
              onClick = proc (e: Event) =
                let roll = rand(1..6)
                let fluke = rand(1..1000)
                echo roll
                dice.set((if fluke == 666: 7 else: roll))
            ):
              "Roll dice"

          d(class="card"):
            h2(class="card-title"): "Ambient Light"
            p(class="card-result"):
              if light.switch.value == on:
                "Light is on"
              else:
                "Light is off"

            button(class="primary-btn", onClick =
              proc (e: Event) =
                let value = light().switch.value
                light.set(Light(switch: LightSwitch(value: (if value == on: off else: on))))
            ):
              "Turn light "; if light.switch.value == on: "off" else: "on"

          d(class="card"):
            h2(class="card-title"): "Counter"
            p(class="metric"):
              "Count: "
              span(class="highlight"): count
            p(class="card-result"):
              if count < 5:
                "Count is less than 5"
              elif count >= 5 and count < 10:
                "Count is less than 10"
              else:
                "Count is greater than 10"

            button(class="primary-btn", onClick =
              proc (e: Event) =
                count.set(if count() < 20: count() + 1 else: 1)
            ):
              "Increment count"

        style:
          """
            :root {
              background: #020617;
              color: #e2e8f0;
              font-family: 'Inter', system-ui, sans-serif;
            }

            body {
              margin: 0;
              min-height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
              padding: 3rem 1.5rem;
              background: radial-gradient(circle at 20% 20%, rgba(59,130,246,0.18), transparent 55%),
                          radial-gradient(circle at 80% 80%, rgba(139,92,246,0.18), transparent 60%),
                          #020617;
            }

            .layout {
              width: min(720px, 100%);
              display: flex;
              flex-direction: column;
              gap: 2.25rem;
            }

            .hero {
              display: flex;
              flex-direction: column;
              gap: 0.6rem;
            }

            .hero-title {
              margin: 0;
              font-size: clamp(2.4rem, 6vw, 3.1rem);
              letter-spacing: -0.03em;
            }

            .hero-copy {
              margin: 0;
              color: rgba(148, 163, 184, 0.85);
              max-width: 560px;
              line-height: 1.7;
            }

            .card-grid {
              display: grid;
              gap: 1.25rem;
              grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            }

            .card {
              background: rgba(15, 23, 42, 0.78);
              border-radius: 20px;
              padding: 1.6rem;
              border: 1px solid rgba(148, 163, 184, 0.18);
              box-shadow: 0 24px 45px rgba(8, 15, 35, 0.4);
              display: flex;
              flex-direction: column;
              gap: 1rem;
            }

            .card-title {
              margin: 0;
              font-size: 1.3rem;
              letter-spacing: -0.01em;
            }

            .card-result,
            .metric {
              margin: 0;
              line-height: 1.6;
            }

            .metric {
              font-weight: 600;
            }

            .highlight {
              color: #38bdf8;
              font-weight: 700;
            }

            .primary-btn {
              align-self: flex-start;
              border: none;
              border-radius: 999px;
              padding: 0.75rem 1.45rem;
              font-weight: 600;
              letter-spacing: 0.05em;
              background: linear-gradient(135deg, #2563eb, #38bdf8);
              color: #fff;
              cursor: pointer;
              transition: transform 0.15s ease, box-shadow 0.15s ease;
            }

            .primary-btn:hover {
              transform: translateY(-1px);
              box-shadow: 0 16px 32px rgba(37, 99, 235, 0.32);
            }
          """

    discard jsAppendChild(document.body, component)
