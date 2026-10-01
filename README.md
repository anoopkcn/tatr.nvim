# tatr.nvim

A Neovim plugin for the [tatr](https://github.com/tsoding/tatr) issue tracker.

tatr keeps tasks in a `tasks/` folder at the root of your project, one
`tasks/<HUID>/TASK.md` per task. This plugin lets you create, find and
cross-reference those tasks without leaving the editor. It is a port of the
Emacs `tatr.el` workflow.

## Features

- Create a task from a title, or from a `TODO:` comment under the cursor
  (the comment is rewritten to `TASK(<HUID>): ...`)
- Jump to a task by the HUID under the cursor or by argument, or list the
  open tasks into the quickfix list
- Grep the project for references to a task into the quickfix list
- List tasks with a [TQL](https://github.com/tsoding/tatr#tatr-query-language-tql)
  query into the quickfix list
- Supports extended HUIDs like `20260830-000838-rexim`

## Requirements

- Neovim >= 0.10
- [`tatr`](https://github.com/tsoding/tatr) on `$PATH`, only for `:Tatr ls`
- [`rg`](https://github.com/BurntSushi/ripgrep) for `:Tatr ref` (falls back to `grep`)

## Installation

With `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({ { src = "https://github.com/anoopkcn/tatr.nvim" } })
```

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "anoopkcn/tatr.nvim", opts = {} }
```

Calling `setup()` is optional. The `:Tatr` command works with the defaults.

## Commands

| Command | Description |
|-|-|
| `:Tatr new [title]` | Create a task and open its `TASK.md`. Prompts for the title if omitted. |
| `:Tatr todo` | Turn the `TODO: title` or `TODO(YYYY-MM-DD HH:MM:SS): title` on the current line into a task and rewrite the line to `TASK(<HUID>): title`. The timestamped form uses the timestamp as the HUID. |
| `:Tatr find [huid]` | Open a task. Uses the argument, then the HUID under the cursor. Without either, loads the open tasks into the quickfix list. |
| `:Tatr goto` | Open the task under the cursor: the HUID under the cursor, or the `TASK(<HUID>)` reference on the current line. |
| `:Tatr ref [huid]` | Grep the project for a HUID into the quickfix list. Uses the argument, then the HUID under the cursor, then the task the current buffer belongs to. Like `tatr ref`, gitignored files are searched too. |
| `:Tatr yank` | Copy the HUID of the task the current buffer belongs to. |
| `:Tatr ls [query]` | Run `tatr ls [query]` and load the result into the quickfix list, e.g. `:Tatr ls :bug and not :ui` or `:Tatr ls -c`. |

Subcommands, HUIDs, tags and TQL keywords complete with `<Tab>`. On Neovim
0.13+ the popup menu shows the task title next to each HUID.

The `tasks/` folder is found by walking up from the current buffer's
directory, or from the working directory for buffers that are not files.

## Configuration

Defaults:

```lua
require("tatr").setup({
    default_priority = 100,     -- PRIORITY of new tasks
    default_tags = { "scope" }, -- TAGS of new tasks
    huid_suffix = nil,          -- e.g. "akc" -> 20260921-101010-akc
    open_cmd = "split",         -- how TASK.md is opened: "split", "vsplit", "edit", "tabedit"
    register = "+",             -- register :Tatr yank copies into
    tatr_cmd = "tatr",          -- executable used by :Tatr ls
})
```

## Keymaps

No keymaps are set by default. For example:

```lua
vim.keymap.set("n", "<leader>tn", "<CMD>Tatr new<CR>", { desc = "tatr: new task" })
vim.keymap.set("n", "<leader>tt", "<CMD>Tatr todo<CR>", { desc = "tatr: TODO to task" })
vim.keymap.set("n", "<leader>tf", "<CMD>Tatr find<CR>", { desc = "tatr: find task" })
vim.keymap.set("n", "<leader>tg", "<CMD>Tatr goto<CR>", { desc = "tatr: go to task under cursor" })
vim.keymap.set("n", "<leader>tr", "<CMD>Tatr ref<CR>", { desc = "tatr: task references" })
vim.keymap.set("n", "<leader>ty", "<CMD>Tatr yank<CR>", { desc = "tatr: yank HUID" })
vim.keymap.set("n", "<leader>tl", "<CMD>Tatr ls<CR>", { desc = "tatr: list tasks" })
```

The same actions are available from Lua: `require("tatr").new(title)`,
`.todo()`, `.find(huid)`, `.goto_task()`, `.ref(huid)`, `.yank()` and `.ls(args)`.

## Coming from tatr.el

| tatr.el | tatr.nvim |
|-|-|
| `tatr-create-from-title` | `:Tatr new` |
| `tatr-create-from-todo-at-point` | `:Tatr todo` |
| `tatr-find-by-huid` | `:Tatr find` |
| `tatr-grep-referers` | `:Tatr ref` |
| `tatr-copy-huid-to-clipboard` | `:Tatr yank` |
