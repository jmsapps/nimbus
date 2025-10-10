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
    ): "Increment"
```

## Project Status

This project is still experimental. As such, it is not currently in a state that is deemed
ready for a production environment. A general roadmap can be found in `ROADMAP.md`.
