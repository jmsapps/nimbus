when defined(js):
  import std/[sequtils, strutils]
  import ../src/ntml

  type
    Todo = object
      id: int
      text: string
      done: bool

  proc TodoApp(): Node =
    let todos = signal(@[
      Todo(id: 1, text: "Wire up signals", done: false),
      Todo(id: 2, text: "Compose DOM with templates", done: false),
      Todo(id: 3, text: "Ship something reactive", done: true)
    ])
    let draft = signal("")
    let filter = signal("all")
    let nextId = signal(4)

    let remaining = derived(todos, proc (items: seq[Todo]): int =
      items.countIt(not it.done)
    )

    let filteredTodos = combine2(todos, filter, proc (items: seq[Todo], mode: string): seq[Todo] =
      case mode
      of "active":
        items.filterIt(not it.done)
      of "completed":
        items.filterIt(it.done)
      else:
        items
    )

    let hasCompleted = derived(todos, proc (items: seq[Todo]): bool =
      items.anyIt(it.done)
    )

    proc setFilter(mode: string) =
      filter.set(mode)

    proc filterClass(mode: string): Signal[string] =
      derived(filter, proc (current: string): string =
        if current == mode: "filter-btn is-active" else: "filter-btn"
      )

    proc toggle(id: int) =
      var items = todos.get()
      for todo in items.mitems:
        if todo.id == id:
          todo.done = not todo.done
          break
      todos.set(items)

    proc remove(id: int) =
      todos.set(todos.get().filterIt(it.id != id))

    proc clearCompleted() =
      todos.set(todos.get().filterIt(not it.done))

    proc addTodo() =
      let text = draft.get().strip()
      if text.len == 0:
        return

      var items = todos.get()
      items.add(Todo(id: nextId.get(), text: text, done: false))
      todos.set(items)
      draft.set("")
      nextId.set(nextId.get() + 1)

    d(class="todo-app"):
      h1(class="todo-title"): "NTML Todos"

      form(
        class="todo-form",
        onsubmit = proc (e: Event) =
          e.preventDefault()
          addTodo()
      ):
        input(
          class="todo-input",
          `type`="text",
          placeholder="What needs doing?",
          value=draft
        )
        button(`type`="submit", class="todo-submit"): "Add"

      p(class="todo-meta"):
        strong: remaining
        " item"
        if remaining != 1:
          "s"
        " left"

      nav(class="todo-filters"):
        button(`type`="button", class=filterClass("all"), onClick = proc (e: Event) = setFilter("all")):
          "All"
        button(`type`="button", class=filterClass("active"), onClick = proc (e: Event) = setFilter("active")):
          "Active"
        button(`type`="button", class=filterClass("completed"), onClick = proc (e: Event) = setFilter("completed")):
          "Completed"

      ul(class="todo-list"):
        for todo in filteredTodos:
          let todoId = todo.id
          li(class = (if todo.done: "todo-item is-done" else: "todo-item")):
            label(class="todo-row"):
              input(
                class="todo-checkbox",
                `type`="checkbox",
                checked=todo.done,
                onChange = proc (e: Event) = toggle(todoId)
              )
              span(class="todo-text"): todo.text

            button(
              class="todo-remove",
              `type`="button",
              onClick = proc (e: Event) = remove(todoId)
            ):
              "Remove"

      if hasCompleted:
        button(
          class="todo-clear",
          `type`="button",
          onClick = proc (e: Event) = clearCompleted()
        ):
          "Clear completed"

      style:
        """
          :root {
            background: #0f172a;
            color: #0f172a;
            font-family: 'Inter', system-ui, sans-serif;
          }

          body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: flex-start;
            justify-content: center;
            padding: 48px 16px;
            background: #0f172a;
          }

          .todo-app {
            width: min(480px, 100%);
            background: #0b1120;
            color: #e2e8f0;
            border-radius: 18px;
            box-shadow: 0 20px 55px rgba(15, 23, 42, 0.35);
            padding: 28px 32px;
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
          }

          .todo-title {
            margin: 0;
            font-size: 1.85rem;
            letter-spacing: -0.02em;
          }

          .todo-form {
            display: flex;
            gap: 0.75rem;
            align-items: center;
          }

          .todo-input {
            flex: 1;
            border-radius: 999px;
            border: none;
            padding: 0.8rem 1.1rem;
            background: rgba(148, 163, 184, 0.16);
            color: inherit;
            font-size: 1rem;
          }

          .todo-input::placeholder {
            color: rgba(148, 163, 184, 0.72);
          }

          .todo-submit {
            border: none;
            border-radius: 999px;
            padding: 0.75rem 1.4rem;
            font-weight: 600;
            background: linear-gradient(135deg, #2563eb, #38bdf8);
            color: #fff;
            cursor: pointer;
            transition: transform 0.15s, box-shadow 0.15s;
          }

          .todo-submit:hover {
            transform: translateY(-1px);
            box-shadow: 0 10px 25px rgba(56, 189, 248, 0.35);
          }

          .todo-meta {
            margin: 0;
            color: rgba(148, 163, 184, 0.85);
          }

          .todo-filters {
            display: flex;
            gap: 0.5rem;
          }

          .filter-btn {
            flex: 1;
            border: none;
            border-radius: 999px;
            padding: 0.55rem 0.75rem;
            background: rgba(148, 163, 184, 0.15);
            color: inherit;
            cursor: pointer;
          }

          .filter-btn.is-active {
            background: rgba(56, 189, 248, 0.25);
            color: #e0f2fe;
          }

          .todo-list {
            list-style: none;
            padding: 0;
            margin: 0;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
          }

          .todo-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: rgba(15, 23, 42, 0.6);
            border-radius: 14px;
            padding: 0.65rem 0.85rem 0.65rem 1rem;
            gap: 0.75rem;
          }

          .todo-item.is-done .todo-text {
            text-decoration: line-through;
            color: rgba(148, 163, 184, 0.6);
          }

          .todo-row {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            flex: 1;
          }

          .todo-checkbox {
            width: 18px;
            height: 18px;
            accent-color: #38bdf8;
          }

          .todo-text {
            flex: 1;
          }

          .todo-remove {
            border: none;
            cursor: pointer;
            background: transparent;
            color: rgba(148, 163, 184, 0.8);
            font-size: 1.1rem;
            line-height: 1;
            padding: 0.2rem 0.3rem;
          }

          .todo-remove:hover {
            color: #fca5a5;
          }

          .todo-clear {
            align-self: flex-end;
            border: none;
            background: rgba(248, 113, 113, 0.2);
            color: #fecaca;
            padding: 0.55rem 0.95rem;
            border-radius: 999px;
            cursor: pointer;
          }
        """

  when isMainModule:
    render(TodoApp())
