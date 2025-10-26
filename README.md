![Nimbus Logo](./src/assets/nimbus_logo.png)

Nimbus is a reactive client-side single page application (SPA) renderer written in Nim. It provides a lightweight signal and effect system, and a JSX-like DSL for composing DOM nodes with reactive updates.

---

## Features

- **Signals**: reactive primitives for state management.
- **Derived Signals**: automatically compute values from other signals.
- **Effects**: side effects that run in response to signal changes.
- **DOM Helpers**: simple wrappers for element creation and updates.
- **Control Flow**: templates for `if`, `case`, and loops inside the DSL.
- **Component Props**: composable component definitions with inheritance support.
- **Routing**: simple and intuitive routing with `navigate()`.
- **Styled Components**: reactive `styled` macro keeps components clean and organized.

---

## Example

```nim
var count: Signal[int] = signal(0)
let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))

let component: Node =
  d(id="hero", class="container"):
    "Count: "; count; br(); "Doubled: "; doubled; br(); br();
    button(
      class="btn",
      onClick = proc (e: Event) = count.set(count.get() + 1)
    ):
      "Increment"
```

## Runnable Examples

Runnable examples are available in the `examples` directory. First start a server at the project root:

```bash
npx serve --single .
```

Add an index.html file at the project root:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Run Nim-Generated JS</title>
  </head>
  <body>
    <script src="/index.js"></script>
  </body>
</html>
```

Run an example:

```bash
nim js --verbosity:1 --hints:off --out:index.js examples/helloWorld.nim
```

## Project Status

This project is still experimental. As such, it is not currently in a state that is deemed
ready for a production environment. A roadmap can be found in `ROADMAP.md`.
