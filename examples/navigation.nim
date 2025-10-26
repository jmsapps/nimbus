import ../src/nimbus

when isMainModule:
  type
    Credentials = object
      username: string
      password: string

  let router = router()
  let location = router.location

  let NotFound: Node = d:
    d(style="padding:32px; text-align:center"):
      h1(style="color:#c00"): "404"
      p: "This page does not exist."
      button(onClick = proc(e: Event) = navigate("/")): "Go Home"

  let HomePage: Node = d:
    h1: "Home"
    p: "Welcome to Nimbus Routing Demo!"

    button(onClick = proc(e: Event) = navigate("/login")):
      "Login"

    button(onClick = proc(e: Event) = navigate("/about")):
      "About"

  let LoginPage: Node = block:
    let creds: Signal[Credentials] = signal(Credentials(username: "", password: ""))
    let submitted: Signal[bool] = signal(false)

    d:
      h1: "Login Form"

      form(onsubmit = proc(e: Event) =
          e.preventDefault()
          submitted.set(true)
          let c = creds.get()

          echo "Hint: username is 'user123' and password is 'pass123'"

          if c.username == "user123" and c.password == "pass123":
            navigate("/logged-in")
        ):

        label(`for`="username"): "Username:"; br()
        input(
          id="username",
          `type`="text",
          name="username",
          autocomplete="username",
          value=derived(creds, proc(c: Credentials): string = c.username),
          onInput=proc(e: Event) =
            let c = creds.get()
            creds.set(Credentials(username: $e.target.value, password: c.password))
        ); br()

        label(`for`="password"): "Password:"; br()
        input(
          id="password",
          `type`="password",
          autocomplete="current-password",
          name="password",
          value=derived(creds, proc(c: Credentials): string = c.password),
          onInput=proc(e: Event) =
            let c = creds.get()
            creds.set(Credentials(username: c.username, password: $e.target.value))
        ); br()

        button(`type`="submit", style="margin-top: 8px"): "Submit"

      if submitted:
        br()
        let invalidCreds = derived(creds, proc(c: Credentials): bool =
          c.username != "user123" or c.password != "pass123"
        )
        if invalidCreds:
          i: "Incorrect login information"

      br(); br()
      button(onClick = proc(e: Event) = navigate("/")): "Back Home"

  let LoggedInPage: Node = d:
    h1: "Welcome, you are logged in!"
    p: "You successfully submitted the form."


    button(onClick = proc(e: Event) = navigate("+/settings")):
      "Go to settings"
    button(onClick = proc(e: Event) = navigate("/")):
      "Log out"

  let SettingsPage: Node = d:
    h1: "User Settings"

    button(onClick = proc(e: Event) = navigate("+/sub-settings")):
      "Go to sub settings"
    button(onClick = proc(e: Event) = navigate("/logged-in")):
      "Go back"

  let SubSettingsPage: Node = d:
    h1: "Sub User Settings"

    button(onClick = proc(e: Event) = navigate("-/")):
      "Go back"

  let AboutPage: Node = d:
    h1: "About"
    p: "This demo shows a simple case-based router integrated with reactive Nimbus forms."
    button(onClick = proc(e: Event) = navigate("/")):
      "Back Home"

  let app: Node =
    Routes(location):
      Route(path="/", component=HomePage)

      Route(path="/login", component=LoginPage)

      Route(path="/logged-in", component=LoggedInPage):

        Route(path="settings", component=SettingsPage):

          Route(path="sub-settings", component=SubSettingsPage)

      Route(path="/about", component=AboutPage)

      Route(path="*", component=NotFound)

  render(app)
