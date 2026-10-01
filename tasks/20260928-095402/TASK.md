# tatr find should put items in a quickfix list

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`:Tatr find` with no HUID argument and none under the cursor opened a `vim.ui.select()`
picker of the open tasks. It should load them into the quickfix list instead.

## Resolution (2026-10-01)

`lua/tatr/init.lua`: `select_task()` is replaced by `open_tasks_to_quickfix()`, which loads
the open tasks into the quickfix list (title `tatr find`). Entries point at line 1 of each
TASK.md and are sorted and formatted like `tatr ls`: `OPEN [PRIORITY: 100] [tags] title`.
`:Tatr find <huid>` and the HUID under the cursor still open the task directly.
README.md and `doc/tatr.txt` (`:Tatr-find`) are updated.
