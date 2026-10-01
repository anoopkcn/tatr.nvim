# :Tatr ref with rg skips gitignored files, tatr ref does not

- STATUS: CLOSED
- PRIORITY: 100
- TAGS:

`lua/tatr/init.lua:268-270`.

`rg` respects `.gitignore`; `tatr ref` runs `grep -Irn` excluding only `.git`. A HUID
mentioned only in a gitignored file (notes, build output) is found by the CLI but not by
the plugin.

Fix: add `--no-ignore-vcs` to match the CLI, or document the difference as intended.

Found in the Neovim 0.13 review on 2026-10-01.

## Resolution (2026-10-01)

`lua/tatr/init.lua` (`M.ref`): rg now runs with `--no-ignore`, not `--no-ignore-vcs`.
`tatr ref` (grep) also ignores `.ignore`/`.rgignore`, so this matches the CLI and the grep
fallback. `.git/` is still excluded. Checked headless: a HUID that only appears in a
gitignored `notes.txt` is found. Documented under `:Tatr-ref` and in the README.
