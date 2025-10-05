# Nimbus TODO

This is the roadmap toward a production-ready v1.0.
Features are grouped by priority and scope so we can focus on the “core primitives” first.

---

## Core Reactivity (highest priority)

- [ ] **Reactive attributes**

  - e.g. `hidden={signal}`, `class={derived(...)}`
  - Bind attribute updates to subscriptions, not just `$` stringify
  - Handle booleans specially (`hidden=false` → remove, not "false")

- [x] **Unmount cleanup**

  - Dispose effects/subscriptions when `if / case / for` branches are removed
  - Prevent memory leaks and ghost updates

- [x] **Operator lowering for expressions**
  - Ensure consistent handling of mixed signal/primitive logic
  - Deep boolean expressions (`if count == 0 and fruit == "apples" or not isEven`) should always work

---

## DOM & Rendering

- [ ] **Keyed list rendering**

  - Current `for` re-renders all children
  - Implement keyed reconciliation: only update changed elements
  - Crucial for scaling to large lists

- [ ] **Form element bindings**

  - `<input value={signal}>` + auto `onInput` → update signal
  - Two-way sync between DOM and state

- [ ] **Style/class ergonomics**
  - Allow reactive class/style props
  - Potentially array/object syntax (`class={["foo", cond && "bar"]}`)

---

## Performance & Stability

- [ ] **Batch updates (optional)**

  - If multiple signals change synchronously, schedule re-renders in a microtask
  - Prevent thrash from multiple sequential DOM writes

- [ ] **Error boundaries**
  - Catch errors in signals/effects instead of silent bubbling
  - Surface them in console or user-defined handler

---

## Developer Ergonomics

- [ ] **Effect debugging tools**

  - Simple logging: which signals triggered, when effects run
  - Possibly a dev-mode inspector panel

- [ ] **Better type ergonomics**
  - Helpers for comparing signals with non-signals
  - Cleaner operator overloads (avoid nesting `Signal[Signal[T]]` mistakes)

## Types

- [ ] **Add attribute types**
  - Investigate if I can get auto completion
  - If no auto completion, perhaps follow example of htmlgen
  - If no I don't follow htmlgen, perhaps I can just add typed Html Components (e.g. Div, H1, etc.)

## Styles

- [ ] **Styled Components**
  - Allow html elements or components to be styled

---

## Code cleanup

- [ ] **Project formatting**
  - Move code to appropriate folders
  - Use `nimbus.nim` only as an index for the project
  - create lib, examples
  - absolute imports

---

## v1.1+ Goals

- [ ] **SSR compatibility** (render to string)
- [ ] **Hydration** (re-use existing DOM instead of remounting)
- [ ] **Component lifecycle hooks** (`onMount`, `onCleanup`)
