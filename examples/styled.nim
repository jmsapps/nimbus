when isMainModule and defined(js):
  import ../src/ntml

  type
    Feature = object
      title: string
      description: string
      accent: string

  let features = @[
    Feature(
      title: "Signals Everywhere",
      description: "Bind state directly to DOM structure and watch NTML keep everything in sync.",
      accent: "#6c63ff"
    ),
    Feature(
      title: "Composable Templates",
      description: "Return Nodes from plain Nim procs and nest them like regular components.",
      accent: "#ff6584"
    ),
    Feature(
      title: "Ergonomic Styling",
      description: "Drop CSS into the `css` attribute to scope styles automatically via hashes.",
      accent: "#22d3ee"
    )
  ]

  let accentPalette = @["#6c63ff", "#00b894", "#f39c12", "#ff6584"]
  let paletteIndex = signal(0)
  let accentSignal = derived(paletteIndex, proc(i: int): string = accentPalette[i mod accentPalette.len])
  let paritySignal = signal(true)

  styled Container = d:
    """
      min-height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #0f172a, #1e1b4b);
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: Inter, 'Helvetica Neue', sans-serif;
      color: #e2e8f0;
      padding: 3rem 1rem;
    """

  styled ContentStack = Container:
    """
      width: min(960px, 100%);
    """

  styled HeroPanel = section:
    """
      background: rgba(15, 23, 42, 0.65);
      border-radius: 32px;
      padding: 2.5rem;
      backdrop-filter: blur(14px);
      border: 1px solid rgba(148, 163, 184, 0.15);
      box-shadow: 0 25px 70px rgba(8, 12, 30, 0.55);
    """

  styled HeroTitle = h1:
    """
      font-size: clamp(2.4rem, 4vw, 3.4rem);
      margin: 0 0 1rem;
      color: #e2e8f0;
    """

  styled HeroCopy = p:
    """
      max-width: 640px;
      color: #cbd5f5;
      line-height: 1.8;
      margin-bottom: 12px;
    """

  styled HeroButton = button:
    """
      border: none;
      padding: 0.9rem 1.6rem;
      border-radius: 999px;
      font-weight: 600;
      cursor: pointer;
      transition: opacity .2s;
      box-shadow: 0 10px 25px rgba(0,0,0,0.12);
      color: white;
      background: var(--hero-bg, #6c63ff);
    """

  styled FeatureGrid = d:
    """
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1.5rem;
    """

  styled FeatureCard = d:
    """
      background: white;
      color: #0f172a;
      border-radius: 20px;
      padding: 1.5rem;
      box-shadow: 0 20px 35px rgba(15, 23, 42, 0.15);
      border-top: 4px solid transparent;
    """

  styled FeatureHeading = h3:
    """
      margin: 0 0 0.75rem;
      font-size: 1.25rem;
      color: inherit;
    """

  styled FeatureText = p:
    """
      margin: 0;
      color: #334155;
      line-height: 1.6;
    """

  styled ParityBanner = d:
    """
      color: #fff;
      border-radius: 12px;
      font-weight: 600;
      text-align: center;
    """

  let app: Node =
    Container:
      ContentStack(class="scoped_class"):
        HeroPanel:
          HeroTitle: "NTML Styled Components"

          HeroCopy:
            "Every element accepts a `css` attribute. NTML hashes the block, injects a scoped class, " &
            "and keeps your handwritten class names intact."

          HeroButton(
            styleVars = styleVars("--hero-bg" = accentSignal),
            onClick = proc (e: Event) =
              paletteIndex.set((paletteIndex.get() + 1) mod accentPalette.len)
          ):
            "Cycle Accent Color"

        FeatureGrid:
          for feat in features:
            FeatureCard(style = "border-top-color: " & feat.accent & ";"):
              FeatureHeading(style = "color: " & feat.accent & ";"):
                feat.title

              FeatureText:
                feat.description

        HeroButton(
          styleVars = styleVars("--hero-bg" = accentSignal),
          onClick = proc (e: Event) =
            paritySignal.set(not paritySignal.get())
            {.emit: """console.log(document.querySelector('[data-styled="ntml"]').sheet.cssRules);""".}
        ):
          if paritySignal: "Unmount style" else: "Mount style"

        HeroCopy:
          "View Devtools -> Console to see Stylesheets mount and unmount with the component below."

        if paritySignal:
          ParityBanner:
            "Style mounted!"

      style:
        """
          :root {
            background: linear-gradient(135deg, #0f172a, #1e1b4b);
          }

          .scoped_class {
            display: flex;
            flex-direction: column;
            gap: 2.5rem;
          }
        """

  render(app)
