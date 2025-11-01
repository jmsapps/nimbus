![NTML Logo](./src/assets/ntml_logo.png)

# NTML

## The next-gen-reactive template markup language.

NTML is a reactive client-side single page application (SPA) renderer written in Nim. It provides a lightweight signal and effect system, and a JSX-like DSL for composing DOM nodes with reactive updates.

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
- **Form Bindings**: built-in `bindValue`/`bindChecked` wire signals to form inputs for two-way updates.
- **Lifecycle Cleanup**: automatic teardown releases subscriptions, event listeners, and styled classes when nodes unmount.
- **Signal Operators**: rich overloads let you compose comparisons and boolean logic directly on `Signal`s.
- **Reactive CSS Vars**: the `styleVars` helper keeps CSS custom properties in step with live signal data.

---

## Code Sample

```nim
var count: Signal[int] = signal(0)
let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))

let component: Node =
  d(id="container"):
    "Count: "; count; br();
    "Doubled: "; doubled; br(); br();

    button(
      type="button",
      onClick = proc (e: Event) =
        count.set(count() + 1)
    ):
      "Increment"
```

## Getting started

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

Hello world:

```bash
nim js --out:index.js examples/helloWorld.nim
```

### Runnable Examples

- **Hello World** (`examples/helloWorld.nim`): smallest possible component render, useful for sanity-checking your toolchain.
- **Todos** (`examples/todos.nim`): reactive list management with `mountChildFor`, derived filters, two-way `<input>` bindings, and dynamic styling.
- **Forms** (`examples/forms.nim`): showcases nested signals, validation hints, and `bindValue`/`bindChecked` helpers.
- **Routing** (`examples/navigation.nim`): leverages `navigate()` and route signals to orchestrate multipage flows.
- **Styling** (`examples/styled.nim`): demonstrates the `styled` macro, scoped CSS hashing, and reactive `styleVars`.

## Project Status

This project is still experimental. As such, it is not currently in a state that is deemed
ready for a production environment. A roadmap can be found in `ROADMAP.md`.
