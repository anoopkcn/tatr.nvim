# show task titles in :Tatr find/ref completion (Nvim 0.13)

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`lua/tatr/init.lua:367-371`.

Nvim 0.13: `:command-completion-customlist` can return dicts with
`abbr`/`menu`/`info` for the popup menu. `:Tatr find <Tab>` and `:Tatr ref <Tab>` could
show the title next to each HUID, e.g. `{ word = huid, menu = t.title }` from
`task.list(db)`.

Unverified: check that the Lua `complete` callback of `nvim_create_user_command` accepts
dicts before building on it.

Found in the Neovim 0.13 review on 2026-10-01.

## Resolution (2026-10-01)

Verified on NVIM v0.13.0-dev-1755: a Lua `complete` callback of `nvim_create_user_command`
can return dicts. `getcompletion()` returns their `word`s, and non-string/non-dict items are
dropped. `M.complete()` now builds the find/ref candidates from `task.list(db)` (HUID
descending) as `{ word = huid, menu = title }` when `has("nvim-0.13")`, and plain HUIDs
otherwise, since older Nvim does not document dict items. The prefix filter handles both.
Side effect: HUID folders without a TASK.md are no longer offered. Documented in the README
and under `:Tatr`.
