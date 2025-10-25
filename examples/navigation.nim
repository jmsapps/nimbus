import ../src/nimbus

when isMainModule:
  type
    Credentials = object
      username: string
      password: string

  let router = router()
  let location = router.location

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
        let c = creds.get()
        br()
        if c.username != "user123" or c.password != "pass123":
          i: "Incorrect login information"

      br(); br()
      button(onClick = proc(e: Event) = navigate("/")): "Back Home"

  let LoggedInPage: Node = d:
    h1: "Welcome, you are logged in!"
    p: "You successfully submitted the form."

    button(onClick = proc(e: Event) = navigate("/")):
      "Log out"

  let AboutPage: Node = d:
    h1: "About"
    p: "This demo shows a simple case-based router integrated with reactive Nimbus forms."
    button(onClick = proc(e: Event) = navigate("/")):
      "Back Home"

  let component: Node = d:
    case location
    of "/":
      HomePage
    of "/login":
      LoginPage
    of "/logged-in":
      LoggedInPage
    of "/about":
      AboutPage
    else:
      h1: "404 Not Found"

  discard jsAppendChild(document.body, component)
