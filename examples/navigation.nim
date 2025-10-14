import ../src/nimbus

when isMainModule:
  let location = signal[cstring]("/")

  discard effect(proc () =
    window.history.pushState(nil, "", location.get())
    echo location.get()
  , [location])

  echo "Window loaded"

  let HomePage: Node = d:
    h1:
      "Homepage"

    button(
      onClick = proc (e: Event) =
        location.set("/logged-in")
    ):
      "login"

  let LoggedIn: Node = d:
    h1: "Logged in"

    button(
      onClick = proc (e: Event) =
        location.set("/")
    ):
      "Log out"

  let component: Node =
    d:
      case location
      of "/":
        HomePage

      of "/logged-in":
        LoggedIn

      else:
        h1: "404 Not Found"

  discard jsAppendChild(document.body, component)
