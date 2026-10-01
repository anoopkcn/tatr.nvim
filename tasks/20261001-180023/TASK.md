# :Tatr todo keeps comment closers in the task title

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`lua/tatr/init.lua:133-139`.

The title is `(.*)$` to the end of the line, trimmed, so `<!-- TODO: fix tabs -->` creates
a task titled `fix tabs -->` and `/* TODO: x */` gives `x */`. The rewritten source line is
fine; only TASK.md's title is wrong.

Fix: strip a trailing comment closer from the title, taken from 'commentstring' (the part
after `%s`) or a small list (`-->`, `*/`).

Found in the Neovim 0.13 review on 2026-10-01.

## Resolution (2026-10-01)

`lua/tatr/init.lua`: new `strip_comment_closer()` drops a trailing closer taken from
'commentstring' (the part after `%s`), or else `-->` or `*/`. `M.todo()` uses the stripped
title for TASK.md and keeps the full title on the rewritten line. Checked headless:
`<!-- TODO: fix tabs -->` gives the title `fix tabs` and the line `<!-- TASK(<huid>): fix tabs -->`,
and `/* TODO: x */` gives `x`. Documented under `:Tatr-todo`.
