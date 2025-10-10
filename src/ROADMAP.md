# Nimbus Roadmap

---

## Version 0.5.0 — Core Primitives

### [x] Reactive Attributes

- Bind attribute updates to subscriptions, not simple string interpolation.
- Handle boolean attributes correctly (e.g., `hidden=false` removes attribute).
- Examples: `hidden={signal}`, `class={derived(... )}`.

### [x] Unmount Cleanup

- Dispose effects and subscriptions when control structures (`if`, `case`, `for`) remove branches.
- Prevent memory leaks and detached reactive updates.

### [x] Operator Lowering for Expressions

- Ensure mixed signal/primitive expressions are consistently evaluated.
- Support deep boolean logic, e.g. `if count == 0 and fruit == "apples" or not isEven`.

### [x] Form Element Bindings

- Enable two-way binding: `<input value={signal}>` updates automatically on input.
- Synchronize DOM and state seamlessly.

### [ ] Add All HTML Elements

- Define proper type mappings for all HTML elements.
- Generate typed component wrappers (e.g. `Div`, `H1`, etc.).

### [ ] Add Typed HTML Components

- Expose type-safe components matching HTML semantics.
- Ensure consistent attribute typing and auto-completion.

### [ ] Project Formatting

- Reorganize code into proper folder structure (`lib`, `examples`, etc.).
- Use `nimbus.nim` as project index.
- Switch to absolute imports.

### [ ] Styled Components

- Add styling support for HTML elements and user-defined components.

### [ ] Routing

- Implement `navigate()` method and basic routing logic.

### [ ] Global Store / Dispatching

- Introduce global context and dispatch mechanism.
- Allow signals to propagate updates across components.

### [ ] Basic Error Handling

- Guard code with `when compiles(js)`.
- Define minimal fallback or debug behavior.

---

## Version 1.0.0 — Stability & Scale

### [x] Fine-Grained Reactivity

- Update only reactive expressions dependent on changed signals.
- Avoid unnecessary re-renders.
- Support selective propagation in structured data (objects, sequences).

### [ ] Keyed List Rendering

- Improve `for` rendering via keyed reconciliation.
- Update only changed elements to scale efficiently for large lists.

### [ ] Error Boundaries

- Catch signal/effect errors locally.
- Expose hooks or console outputs for debugging.

### [ ] Effect Debugging Tools

- Add simple runtime diagnostics: log triggered signals and effect runs.
- Explore optional dev inspector UI.

### [ ] Better Type Ergonomics

- Simplify comparisons between signals and primitives.
- Clean up operator overloads and avoid nested `Signal[Signal[T]]` issues.

### [ ] Batch Updates

- Coalesce multiple signal updates in a microtask.
- Prevent redundant sequential DOM writes.

### [ ] Component Lifecycle Hooks

- Add `onMount(fn)` and `onCleanup(fn)`.
- Integrate with cleanup registry for automatic teardown.
- Enable safe use of timers, subscriptions, and observers within components.
