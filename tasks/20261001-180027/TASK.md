# minor: :Tatr new writes no body; tatr new writes `No description.`

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`lua/tatr/init.lua:95-101`.

`tatr new` writes `No description.` as the body; `:Tatr new` writes none. Harmless; add the
line only if TASK.md files should be identical to the CLI's.

Found in the Neovim 0.13 review on 2026-10-01.

## Resolution (2026-10-01)

`lua/tatr/init.lua` (`create()`): TASK.md now ends with a blank line and `No description.`,
as `tatr new` writes it. This covers `:Tatr new` and `:Tatr todo`. The template in
`doc/tatr.txt` (`:Tatr-new`) is updated. Also repaired this TASK.md, whose title line had
the description merged into it.
