import ../src/nimbus

when isMainModule:
  type
    Feature = object
      title: string
      description: string
      accent: string

  let features = @[
    Feature(
      title: "Signals Everywhere",
      description: "Bind state directly to DOM structure and watch Nimbus keep everything in sync.",
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

  styled(Container, d):
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

  styled(ContentStack, d):
    """
      width: min(960px, 100%);
      display: flex;
      flex-direction: column;
      gap: 2.5rem;
    """

  styled(HeroPanel, section):
    """
      background: rgba(15, 23, 42, 0.65);
      border-radius: 32px;
      padding: 2.5rem;
      backdrop-filter: blur(14px);
      border: 1px solid rgba(148, 163, 184, 0.15);
      box-shadow: 0 25px 70px rgba(8, 12, 30, 0.55);
    """

  styled(HeroTitle, h1):
    """
      font-size: clamp(2.4rem, 4vw, 3.4rem);
      margin: 0 0 1rem;
    """

  styled(HeroCopy, p):
    """
      max-width: 640px;
      color: #cbd5f5;
      line-height: 1.8;
      margin: 0;
    """

  styled(HeroButton, button):
    """
      border: none;
      padding: 0.9rem 1.6rem;
      border-radius: 999px;
      font-weight: 600;
      cursor: pointer;
      transition: opacity .2s;
      box-shadow: 0 10px 25px rgba(0,0,0,0.12);
      color: white;
    """

  styled(FeatureGrid, d):
    """
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1.5rem;
    """

  styled(FeatureCard, d):
    """
      background: white;
      color: #0f172a;
      border-radius: 20px;
      padding: 1.5rem;
      box-shadow: 0 20px 35px rgba(15, 23, 42, 0.15);
      border-top: 4px solid transparent;
    """

  styled(FeatureHeading, h3):
    """
      margin: 0 0 0.75rem;
      font-size: 1.25rem;
      color: inherit;
    """

  styled(FeatureText, p):
    """
      margin: 0;
      color: #334155;
      line-height: 1.6;
    """

  styled(ParityBanner, d):
    """
      background: #f1f5f9;
      color: #0f172a;
      padding: 1rem 1.25rem;
      border-radius: 12px;
      font-weight: 600;
      text-align: center;
    """

  let app: Node =
    Container:
      ContentStack:
        HeroPanel:
          HeroTitle: "Nimbus Styled Components"

          HeroCopy:
            "Every element accepts a `css` attribute. Nimbus hashes the block, injects a scoped class, " &
            "and keeps your handwritten class names intact."

          HeroButton(
            style = derived(paletteIndex, proc(i: int): string =
              let c = accentPalette[i mod accentPalette.len]
              "background: " & c & ";"
            ),
            onClick = proc (e: Event) =
              paletteIndex.set((paletteIndex.get() + 1) mod accentPalette.len)
          ):
            "Cycle Accent Color"

        FeatureGrid:
          for feat in features:
            FeatureCard(
              style = "border-top-color: " & feat.accent & ";"
            ):
              FeatureHeading(style = "color: " & feat.accent & ";"):
                feat.title

              FeatureText:
                feat.description

        if derived(paletteIndex, proc (x: int): bool = x mod 2 == 0):
          ParityBanner:
            "Even palette index — mounted style, will unmount on Odd index."

  render(app)
