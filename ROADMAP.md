# NTML Roadmap

## Version 0.5.0 — Core Primitives

### ✅ Reactive Attributes

- Bind attribute updates to subscriptions, not simple string interpolation.
- Handle boolean attributes correctly (e.g., `hidden=false` removes attribute).
- Examples: `hidden={signal}`, `class={derived(... )}`.

### ✅ Unmount Cleanup

- Dispose effects and subscriptions when control structures (`if`, `case`, `for`) remove branches.
- Prevent memory leaks and detached reactive updates.

### ✅ Operator Lowering for Expressions

- Ensure mixed signal/primitive expressions are consistently evaluated.
- Support deep boolean logic, e.g. `if count == 0 and fruit == "apples" or not isEven`.

### ✅ Form Element Bindings

- Enable two-way binding: `<input value={signal}>` updates automatically on input.
- Synchronize DOM and state seamlessly.

### ✅ Project Formatting

- Reorganize code into proper folder structure (`lib`, `examples`, etc.).
- Use `ntml.nim` as project index.
- Switch to absolute imports.

### ✅ Add All HTML Elements

- Define proper type mappings for all HTML elements.

### ✅ Styled Components

- Add styling support for HTML elements and user-defined components.

### ✅ Routing

- Implement `navigate()` method and basic routing logic.

---

## Version 0.6.0 — Stability & Scale

### ⬜️ Global Store / Dispatching

- Introduce global context and dispatch mechanism.
- Allow signals to propagate updates across components.

### ⬜️ Basic Error Handling

- Guard code with `when defined(js)`.
- Define minimal fallback or debug behavior.

### ⬜️ Project Examples

- Different example files showcasing project features
- Miniature app project with routing and CRUD.

### ⬜️ Add Typed HTML Components

- Generate typed component wrappers (e.g. `Div`, `H1`, etc.).
- Expose type-safe components matching HTML semantics.
- Ensure consistent attribute typing and auto-completion.

### ⬜️ Hot Reloading

- Hot reload project on save

---

## Version 1.0.0 — Production Ready

### ⬜️ Fine-Grained Reactivity

- Update only reactive expressions dependent on changed signals.
- Avoid unnecessary re-renders.
- Support selective propagation in structured data (objects, sequences).

### ⬜️ Keyed List Rendering

- Improve `for` rendering via keyed reconciliation.
- Update only changed elements to scale efficiently for large lists.

### ⬜️ Error Boundaries

- Catch signal/effect errors locally.
- Expose hooks or console outputs for debugging.

### ⬜️ Improve Dev Experience

- Make sure large projects compile quickly
- Add simple runtime diagnostics: debug mode with log triggered signals and effect runs.
- Hot reloading

### ⬜️ Better Type Ergonomics

- Simplify comparisons between signals and primitives.
- Clean up operator overloads and avoid nested `Signal[Signal[T]]` issues.

### ⬜️ Batch Updates

- Coalesce multiple signal updates in a microtask.
- Prevent redundant sequential DOM writes.

### ⬜️ Component Lifecycle Hooks

- Add `onMount(fn)` and `onCleanup(fn)`.
- Integrate with cleanup registry for automatic teardown.
- Enable safe use of timers, subscriptions, and observers within components.

### ⬜️ Hash Routing

- Have webpage auto scroll to relative fragment identifiers
