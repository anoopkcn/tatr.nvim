# remove the oil:// handling in buf_path()

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`lua/tatr/init.lua:33-37`.

oil was replaced by the builtin `:h dir` listing (Nvim 0.13), whose buffers are named by
their plain path. Checked: `:edit tasks` gives `ft=directory`, `bt=` and the plain path as
the name, so `start_dir()` and `current_task()` already work there.

Fix: drop the `gsub` and comment, use `nvim_buf_get_name(0)` directly.

Found in the Neovim 0.13 review on 2026-10-01.

## Resolution (2026-10-01)

`lua/tatr/init.lua`: `buf_path()` is removed, and `start_dir()` and `current_task()` call
`nvim_buf_get_name(0)` directly. Checked headless: `:edit tasks/<huid>` gives `ft=directory`,
and `:Tatr yank` copies the HUID. Dropped the oil.nvim mentions from README.md and `doc/tatr.txt`.
