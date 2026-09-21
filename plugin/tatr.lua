if vim.g.loaded_tatr then
    return
end
vim.g.loaded_tatr = 1

vim.api.nvim_create_user_command("Tatr", function(opts)
    require("tatr").command(opts)
end, {
    nargs = "*",
    complete = function(...)
        return require("tatr").complete(...)
    end,
    desc = "tatr task tracker",
})
