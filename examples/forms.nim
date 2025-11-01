
when isMainModule and defined(js):
  import ../src/ntml

  type
    Credentials = object
      username: string
      password: string


  proc Form(): Node =
    let creds: Signal[Credentials] = signal(Credentials(username: "", password: ""))
    let submitted: Signal[bool] = signal(false)
    let loggedIn: Signal[bool] = signal(false)

    d(class="layout"):
      section(class="auth-card"):
        h1(class="auth-title"): "Login Form"

        form(
          class="auth-form",
          onsubmit = proc(e: Event) =
            e.preventDefault()
            submitted.set(true)
            let c = creds.get()

            echo "Hint: username is 'user123' and password is 'pass123'"

            if c.username == "user123" and c.password == "pass123":
              loggedIn.set(true)
        ):

          label(`for`="username", class="auth-label"): "Username"
          input(
            id="username",
            class="auth-input",
            `type`="text",
            name="username",
            autocomplete="username",
            value=creds.username,
          )

          label(`for`="password", class="auth-label"): "Password"
          input(
            id="password",
            class="auth-input",
            `type`="password",
            autocomplete="current-password",
            name="password",
            value=creds.password,
          )

          button(`type`="submit", class="auth-submit"): "Submit"

        if submitted:
          let invalidCreds = derived(creds, proc(c: Credentials): bool =
            c.username != "user123" or c.password != "pass123"
          )
          if invalidCreds:
            p(class="auth-alert is-error"): "Incorrect login information"

          if loggedIn:
            p(class="auth-alert is-success"): "Logged in!"

        button(
          `type`="button",
          class="auth-reset",
          onClick=proc (e: Event) =
            creds.set(Credentials(username: "", password: ""))
            loggedIn.set(false)
            submitted.set(false)
        ): "Clear form"

      style:
        """
          :root {
            background: #020617;
            color: #f8fafc;
            font-family: 'Inter', system-ui, sans-serif;
          }

          body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 3rem 1rem;
            background: radial-gradient(circle at 0% 0%, rgba(59,130,246,0.25), transparent 55%),
                        radial-gradient(circle at 100% 100%, rgba(16,185,129,0.2), transparent 52%),
                        #020617;
          }

          .layout {
            width: min(440px, 100%);
          }

          .auth-card {
            backdrop-filter: blur(18px);
            background: rgba(15, 23, 42, 0.72);
            border-radius: 20px;
            padding: 2.5rem;
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
            box-shadow: 0 28px 45px rgba(15, 23, 42, 0.35);
            border: 1px solid rgba(148, 163, 184, 0.2);
          }

          .auth-title {
            margin: 0;
            font-size: 2rem;
            letter-spacing: -0.02em;
          }

          .auth-form {
            display: flex;
            flex-direction: column;
            gap: 1rem;
          }

          .auth-label {
            font-size: 0.9rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: rgba(226, 232, 240, 0.72);
          }

          .auth-input {
            border: none;
            border-radius: 12px;
            padding: 0.85rem 1rem;
            background: rgba(71, 85, 105, 0.28);
            color: inherit;
            font-size: 1rem;
          }

          .auth-input:focus {
            outline: 2px solid rgba(59, 130, 246, 0.55);
            background: rgba(30, 41, 59, 0.75);
          }

          .auth-submit {
            margin-top: 0.4rem;
            border: none;
            border-radius: 999px;
            padding: 0.85rem 1.25rem;
            background: linear-gradient(135deg, #2563eb, #38bdf8);
            color: #ffffff;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.12em;
            cursor: pointer;
            transition: transform 0.15s ease, box-shadow 0.15s ease;
          }

          .auth-submit:hover {
            transform: translateY(-1px);
            box-shadow: 0 15px 30px rgba(37, 99, 235, 0.35);
          }

          .auth-alert {
            margin: 0;
            padding: 0.75rem 1rem;
            border-radius: 12px;
            font-size: 0.95rem;
            font-weight: 500;
          }

          .auth-alert.is-error {
            background: rgba(239, 68, 68, 0.18);
            color: #fecaca;
          }

          .auth-alert.is-success {
            background: rgba(74, 222, 128, 0.22);
            color: #bbf7d0;
          }

          .auth-reset {
            align-self: flex-start;
            border: none;
            background: transparent;
            color: rgba(148, 163, 184, 0.85);
            font-size: 0.95rem;
            font-weight: 500;
            cursor: pointer;
            text-decoration: underline;
            text-underline-offset: 4px;
            margin-top: 0.5rem;
          }

          .auth-reset:hover {
            color: rgba(226, 232, 240, 0.9);
          }
        """

  render(Form())
