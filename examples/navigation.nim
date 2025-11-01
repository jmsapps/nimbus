
when isMainModule and defined(js):
  import ../src/ntml

  type
    Credentials = object
      username: string
      password: string

  let router = router()
  let location = router.location

  proc NotFound(): Node =
    d(class="page-shell not-found"):
      h1(class="page-title"): "404"
      p(class="page-copy"): "This page does not exist."
      button(class="primary-btn", onClick = proc(e: Event) = navigate("/")): "Go Home"

  proc HomePage(): Node =
    d(class="page-shell"):
      h1(class="page-title"): "Home"
      p(class="page-copy"): "Welcome to NTML Routing Demo!"

      d(class="button-row"):
        button(class="primary-btn", onClick = proc(e: Event) = navigate("/login")):
          "Login"

        button(class="secondary-btn", onClick = proc(e: Event) = navigate("/about")):
          "About"

  proc LoginPage(): Node =
    let creds: Signal[Credentials] = signal(Credentials(username: "", password: ""))
    let submitted: Signal[bool] = signal(false)

    d(class="page-shell"):
      h1(class="page-title"): "Login"

      form(
        class="form-card",
        onsubmit = proc(e: Event) =
          e.preventDefault()
          submitted.set(true)
          let c = creds.get()

          echo "Hint: username is 'user123' and password is 'pass123'"

          if c.username == "user123" and c.password == "pass123":
            navigate("/logged-in")
      ):
        label(`for`="username", class="form-label"): "Username"
        input(
          id="username",
          class="form-input",
          `type`="text",
          name="username",
          autocomplete="username",
          value=creds.username,
        )

        label(`for`="password", class="form-label"): "Password"
        input(
          id="password",
          class="form-input",
          `type`="password",
          autocomplete="current-password",
          name="password",
          value=creds.password,
        )

        button(`type`="submit", class="primary-btn"): "Submit"

      if submitted:
        let invalidCreds = derived(creds, proc(c: Credentials): bool =
          c.username != "user123" or c.password != "pass123"
        )
        if invalidCreds:
          p(class="status-chip is-error"): "Incorrect login information"

      d(class="button-row"):
        button(class="secondary-btn", onClick = proc(e: Event) = navigate("/")): "Back Home"

  proc LoggedInPage(): Node =
    d(class="page-shell"):
      h1(class="page-title"): "Welcome, you are logged in!"
      p(class="page-copy"): "You successfully submitted the form."

      d(class="button-row"):
        button(class="primary-btn", onClick = proc(e: Event) = navigate("+/settings")):
          "Go to settings"
        button(class="secondary-btn", onClick = proc(e: Event) = navigate("/")):
          "Log out"

  proc SettingsPage(): Node =
    d(class="page-shell"):
      h1(class="page-title"): "User Settings"

      d(class="button-row"):
        button(class="primary-btn", onClick = proc(e: Event) = navigate("+/sub-settings")):
          "Go to sub settings"
        button(class="secondary-btn", onClick = proc(e: Event) = navigate("/logged-in")):
          "Go back"

  proc SubSettingsPage(): Node =
    d(class="page-shell"):
      h1(class="page-title"): "Sub User Settings"

      d(class="button-row"):
        button(class="secondary-btn", onClick = proc(e: Event) = navigate("-/")):
          "Go back"

  proc AboutPage(): Node =
    d(class="page-shell"):
      h1(class="page-title"): "About"
      p(class="page-copy"): "This demo shows a simple case-based router integrated with reactive NTML forms."
      button(class="secondary-btn", onClick = proc(e: Event) = navigate("/")):
        "Back Home"

  proc App(): Node =
    Routes(location):
      Route(path="/", component=HomePage)

      Route(path="/login", component=LoginPage)

      Route(path="/logged-in", component=LoggedInPage):

        Route(path="settings", component=SettingsPage):

          Route(path="sub-settings", component=SubSettingsPage)

      Route(path="/about", component=AboutPage)

      Route(path="*", component=NotFound)

  let globalStyles: Node =
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
          padding: 4rem 1.5rem;
          background: radial-gradient(circle at 15% 20%, rgba(59,130,246,0.18), transparent 55%),
                      radial-gradient(circle at 85% 80%, rgba(16,185,129,0.2), transparent 60%),
                      #020617;
        }

        .page-shell {
          width: min(520px, 100%);
          background: rgba(15, 23, 42, 0.78);
          border-radius: 22px;
          padding: 2.4rem 2.2rem;
          box-shadow: 0 32px 60px rgba(8, 15, 35, 0.45);
          border: 1px solid rgba(148, 163, 184, 0.22);
          display: flex;
          flex-direction: column;
          gap: 1.4rem;
        }

        .not-found {
          align-items: center;
          text-align: center;
          gap: 1rem;
        }

        .page-title {
          margin: 0;
          font-size: clamp(2rem, 4vw, 2.6rem);
          letter-spacing: -0.03em;
        }

        .page-copy {
          margin: 0;
          color: rgba(148, 163, 184, 0.85);
          line-height: 1.7;
        }

        .button-row {
          display: flex;
          flex-wrap: wrap;
          gap: 0.75rem;
        }

        .primary-btn,
        .secondary-btn {
          border-radius: 999px;
          padding: 0.75rem 1.45rem;
          font-weight: 600;
          letter-spacing: 0.05em;
          cursor: pointer;
          transition: transform 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
        }

        .primary-btn {
          border: none;
          background: linear-gradient(135deg, #2563eb, #38bdf8);
          color: #fff;
        }

        .primary-btn:hover {
          transform: translateY(-1px);
          box-shadow: 0 18px 36px rgba(37, 99, 235, 0.32);
        }

        .secondary-btn {
          border: 1px solid rgba(148, 163, 184, 0.35);
          background: transparent;
          color: inherit;
        }

        .secondary-btn:hover {
          background: rgba(148, 163, 184, 0.18);
        }

        .form-card {
          display: flex;
          flex-direction: column;
          gap: 0.9rem;
          padding: 1.3rem;
          border-radius: 18px;
          background: rgba(15, 23, 42, 0.75);
          border: 1px solid rgba(148, 163, 184, 0.2);
        }

        .form-label {
          font-size: 0.85rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: rgba(148, 163, 184, 0.8);
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

        .status-chip {
          margin: 0;
          padding: 0.65rem 0.95rem;
          border-radius: 14px;
          font-size: 0.9rem;
          font-weight: 500;
          background: rgba(239, 68, 68, 0.15);
          color: #fecaca;
        }

        .status-chip.is-error {
          background: rgba(239, 68, 68, 0.2);
          color: #fecaca;
        }
      """

  discard jsAppendChild(document.head, globalStyles)
  render(App())
