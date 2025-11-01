
when isMainModule and defined(js):
  import ../src/nimbus

  type
    Credentials = object
      username: string
      password: string


  proc Form(): Node =
    let creds: Signal[Credentials] = signal(Credentials(username: "", password: ""))
    let submitted: Signal[bool] = signal(false)
    let loggedIn: Signal[bool] = signal(false)

    d:
      h1: "Login Form"

      form(onsubmit = proc(e: Event) =
          e.preventDefault()
          submitted.set(true)
          let c = creds.get()

          echo "Hint: username is 'user123' and password is 'pass123'"

          if c.username == "user123" and c.password == "pass123":
            loggedIn.set(true)
        ):

        label(`for`="username"): "Username:"; br()
        input(
          id="username",
          `type`="text",
          name="username",
          autocomplete="username",
          value=creds.username,
          # onInput=proc(e: Event) =
          #   let c = creds.get()
          #   creds.set(Credentials(username: $e.target.value, password: c.password))
        ); br()

        label(`for`="password"): "Password:"; br()
        input(
          id="password",
          `type`="password",
          autocomplete="current-password",
          name="password",
          value=creds.password,
          # onInput=proc(e: Event) =
          #   let c = creds.get()
          #   creds.set(Credentials(username: c.username, password: $e.target.value))
        );

        br()

        button(`type`="submit", style="margin-top: 8px"): "Submit"

      if submitted:
        br()
        let invalidCreds = derived(creds, proc(c: Credentials): bool =
          c.username != "user123" or c.password != "pass123"
        )
        if invalidCreds:
          i: "Incorrect login information"

        if loggedIn:
          i: "Logged in!"

      br(); br()

      button(
        `type`="button",
        style="margin-top: 8px",
        onClick=proc (e: Event) =
          creds.set(Credentials(username: "", password: ""))
          loggedIn.set(false)
          submitted.set(false)
      ): "Clear form"

  render(Form())
