-- tatr.nvim: Neovim frontend for the tatr task tracker.
-- by @anoopkcn

local task = require("tatr.task")

local M = {}

local defaults = {
    -- PRIORITY of new tasks
    default_priority = 100,
    -- TAGS of new tasks
    default_tags = { "scope" },
    -- Extends new HUIDs, e.g. "akc" -> 20260921-101010-akc
    huid_suffix = nil,
    -- Command used to open TASK.md: "split", "vsplit", "edit", "tabedit", ...
    open_cmd = "split",
    -- Register :Tatr yank copies the HUID into
    register = "+",
    -- tatr executable used by :Tatr ls
    tatr_cmd = "tatr",
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
    M.config = vim.tbl_extend("force", vim.deepcopy(defaults), opts or {})
end

local function notify(msg, level)
    vim.notify("tatr: " .. msg, level or vim.log.levels.ERROR)
end

-- Directory the tasks/ lookup starts from: the buffer's directory, or the cwd
-- for buffers that are not backed by a file.
local function start_dir()
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" then
        if vim.fn.isdirectory(name) == 1 then return vim.fs.normalize(name) end
        local dir = vim.fs.dirname(name)
        if vim.fn.isdirectory(dir) == 1 then return vim.fs.normalize(dir) end
    end
    return vim.fn.getcwd()
end

local function get_db()
    local db = task.find_db(start_dir())
    if not db then notify("tasks/ folder was not found") end
    return db
end

-- HUID of the task folder the current buffer belongs to.
local function current_task()
    local db = task.find_db(start_dir())
    if db then return task.task_of(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), db) end
end

local function cursor_huid()
    return task.huid_at(vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1)
end

-- Opens `path`, focusing a window in the current tab that already shows it.
local function open(path)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
        if name ~= "" and vim.fs.normalize(name) == path then
            vim.api.nvim_set_current_win(win)
            return
        end
    end
    vim.cmd(M.config.open_cmd .. " " .. vim.fn.fnameescape(path))
end

-- Creates tasks/<huid>/TASK.md. Returns the HUID and the path to TASK.md.
local function create(db, title, huid)
    huid = huid or task.new_huid(M.config.huid_suffix)
    if not task.is_huid(huid) then
        notify(huid .. " is not a valid HUID")
        return
    end
    local dir = db .. "/" .. huid
    if vim.uv.fs_stat(dir) then
        notify(dir .. " already exists")
        return
    end
    local tags = table.concat(M.config.default_tags, ",")
    local path = dir .. "/TASK.md"
    local ok, err = pcall(function()
        vim.fn.mkdir(dir)
        vim.fn.writefile({
            "# " .. title,
            "",
            "- STATUS: OPEN",
            "- PRIORITY: " .. M.config.default_priority,
            "- TAGS:" .. (tags ~= "" and " " .. tags or ""),
            "",
            "No description.",
        }, path)
    end)
    if not ok then
        notify(tostring(err))
        return
    end
    return huid, path
end

-- Creates a task with `title`, prompting for it when omitted, and opens it.
function M.new(title)
    local db = get_db()
    if not db then return end
    local function go(t)
        t = vim.trim(t or "")
        if t == "" then return end
        local _, path = create(db, t)
        if path then open(path) end
    end
    if title and vim.trim(title) ~= "" then
        go(title)
    else
        vim.ui.input({ prompt = "Title: " }, go)
    end
end

-- Strips a trailing comment closer like `-->` or `*/` from a TODO title.
local function strip_comment_closer(title)
    local closers = { "-->", "*/" }
    local cs_end = vim.trim(vim.bo.commentstring:match("%%s(.*)$") or "")
    if cs_end ~= "" then table.insert(closers, 1, cs_end) end
    for _, closer in ipairs(closers) do
        if vim.endswith(title, closer) then
            return vim.trim(title:sub(1, -#closer - 1))
        end
    end
    return title
end

-- Turns `TODO: title` or `TODO(YYYY-MM-DD HH:MM:SS): title` on the current
-- line into a task and rewrites the line to `TASK(<huid>): title`.
function M.todo()
    local line = vim.api.nvim_get_current_line()
    local huid
    local prefix, y, mo, d, h, mi, s, title =
        line:match("^(.*)TODO%((%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)%):(.*)$")
    if prefix then
        huid = y .. mo .. d .. "-" .. h .. mi .. s
        local suffix = M.config.huid_suffix
        if suffix and suffix ~= "" then huid = huid .. "-" .. suffix end
    else
        prefix, title = line:match("^(.*)TODO:(.*)$")
    end
    if not prefix then
        notify("No TODO under cursor")
        return
    end
    title = vim.trim(title)
    -- The rewritten line keeps the closer, TASK.md's title does not.
    local task_title = strip_comment_closer(title)
    if task_title == "" then
        notify("TODO has no title")
        return
    end
    if not vim.bo.modifiable then
        notify("Buffer is not modifiable")
        return
    end

    local db = get_db()
    if not db then return end
    local path
    huid, path = create(db, task_title, huid)
    if not huid then return end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { ("%sTASK(%s): %s"):format(prefix, huid, title) })
    open(path)
end

-- Loads the open tasks into the quickfix list, sorted and formatted like
-- `tatr ls`.
local function open_tasks_to_quickfix(db)
    local tasks = vim.tbl_filter(function(t) return t.status ~= "CLOSED" end, task.list(db))
    if #tasks == 0 then
        notify("No open tasks", vim.log.levels.INFO)
        return
    end
    table.sort(tasks, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.huid > b.huid
    end)
    local items = {}
    for _, t in ipairs(tasks) do
        local tags = #t.tags > 0 and " [" .. table.concat(t.tags, ",") .. "]" or ""
        items[#items + 1] = {
            filename = t.path,
            lnum = 1,
            text = ("%s [PRIORITY: %d]%s %s"):format(t.status, t.priority, tags, t.title),
        }
    end
    vim.fn.setqflist({}, " ", { title = "tatr find", items = items })
    vim.cmd("botright copen")
end

-- Opens tasks/<huid>/TASK.md.
local function open_task(db, huid)
    if not task.is_huid(huid) then
        notify(huid .. " is not a valid HUID")
        return
    end
    local path = db .. "/" .. huid .. "/TASK.md"
    if vim.fn.filereadable(path) == 0 then
        notify(("Task %s was not found"):format(huid))
        return
    end
    open(path)
end

-- Opens the task `huid` or the HUID under the cursor. Without either, loads
-- the open tasks into the quickfix list.
function M.find(huid)
    local db = get_db()
    if not db then return end
    if not huid or huid == "" then huid = cursor_huid() end
    if not huid then return open_tasks_to_quickfix(db) end
    open_task(db, huid)
end

-- Opens the task under the cursor: the HUID under the cursor, or the
-- `TASK(<huid>)` reference on the current line.
function M.goto_task()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1
    local huid = task.huid_at(line, col) or task.task_ref_at(line, col)
    if not huid then
        notify("No task under cursor")
        return
    end
    local db = get_db()
    if not db then return end
    open_task(db, huid)
end

-- Runs `cmd` and loads its output into the quickfix list.
local function to_quickfix(cmd, opts, parse)
    vim.system(cmd, { cwd = opts.cwd, text = true }, vim.schedule_wrap(function(res)
        -- grep and rg exit with 1 when nothing matched
        local failed = res.code > 1 or (res.code == 1 and res.stderr ~= "")
        if failed then
            notify(vim.trim(res.stderr), res.stdout == "" and vim.log.levels.ERROR or vim.log.levels.WARN)
            if res.stdout == "" then return end
        end
        local what = { title = opts.title }
        if parse then
            what.items = parse(res.stdout)
        else
            what.lines = vim.split(res.stdout, "\n", { trimempty = true })
            what.efm = opts.efm
        end
        vim.fn.setqflist({}, " ", what)
        if #vim.fn.getqflist() == 0 then
            notify(opts.empty, vim.log.levels.INFO)
            return
        end
        vim.cmd("botright copen")
    end))
end

-- Greps the project for references to `huid`, the HUID under the cursor, or
-- the task the current buffer belongs to.
function M.ref(huid)
    if not huid or huid == "" then huid = cursor_huid() or current_task() end
    if not huid then
        notify("You are not in a task folder. Pass a HUID or put the cursor on one.")
        return
    end
    if not task.is_huid(huid) then
        notify(huid .. " is not a valid HUID")
        return
    end
    local db = get_db()
    if not db then return end
    local root = vim.fs.dirname(db)

    local cmd, efm
    if vim.fn.executable("rg") == 1 then
        -- --no-ignore: like `tatr ref`, search ignored files too
        cmd = { "rg", "--vimgrep", "--fixed-strings", "--hidden", "--no-ignore", "--glob", "!.git", "--", huid, root }
        efm = "%f:%l:%c:%m"
    else
        cmd = { "grep", "-rIn", "--fixed-strings", "--exclude-dir=.git", "--", huid, root }
        efm = "%f:%l:%m"
    end
    to_quickfix(cmd, {
        title = "tatr ref " .. huid,
        efm = efm,
        empty = "No references to " .. huid,
    })
end

-- Copies the HUID of the task the current buffer belongs to.
function M.yank()
    local huid = current_task()
    if not huid then
        notify("You are not in a task folder")
        return
    end
    vim.fn.setreg(M.config.register, huid)
    notify(("Copied %s to register %s"):format(huid, M.config.register), vim.log.levels.INFO)
end

-- Lists tasks matching a TQL query with `tatr ls` in the quickfix list.
function M.ls(args)
    args = args or {}
    if vim.fn.executable(M.config.tatr_cmd) == 0 then
        notify(("`%s` executable not found"):format(M.config.tatr_cmd))
        return
    end
    local db = get_db()
    if not db then return end
    local root = vim.fs.dirname(db)

    local cmd = vim.list_extend({ M.config.tatr_cmd, "ls" }, args)
    to_quickfix(cmd, {
        cwd = root,
        title = table.concat(cmd, " "),
        empty = "No tasks were found",
    }, function(stdout)
        -- tatr prints paths relative to its cwd, which is the project root.
        local items = {}
        for line in stdout:gmatch("[^\n]+") do
            local file, lnum, text = line:match("^(.-):(%d+):%s*(.*)$")
            if file then
                items[#items + 1] = {
                    filename = root .. "/" .. file:gsub("^%./", ""),
                    lnum = tonumber(lnum),
                    text = text,
                }
            end
        end
        return items
    end)
end

local subcommands = {
    new = function(rest) M.new(rest) end,
    todo = function() M.todo() end,
    find = function(_, args) M.find(args[1]) end,
    ["goto"] = function() M.goto_task() end,
    ref = function(_, args) M.ref(args[1]) end,
    yank = function() M.yank() end,
    ls = function(_, args) M.ls(args) end,
}

local usage = "Usage: :Tatr {new|todo|find|goto|ref|yank|ls} [args]"

-- Handler for the :Tatr user command.
function M.command(opts)
    local sub, rest = opts.args:match("^%s*(%S+)%s*(.-)%s*$")
    local fn = sub and subcommands[sub]
    if not fn then
        notify(sub and ("Unknown subcommand `%s`. %s"):format(sub, usage) or usage)
        return
    end
    fn(rest, vim.list_slice(opts.fargs, 2))
end

local ls_words = {
    "-c", "-a", "-id",
    "and", "or", "not", "any", "tagged", "priority",
    "lt", "le", "gt", "ge", "eq", "ne",
}

-- Completion for the :Tatr user command.
function M.complete(arglead, cmdline, cursorpos)
    local words = vim.split(cmdline:sub(1, cursorpos), "%s+", { trimempty = true })
    local n = #words + (arglead == "" and 1 or 0)
    local candidates = {}

    if n == 2 then
        candidates = vim.tbl_keys(subcommands)
        table.sort(candidates)
    else
        local sub = words[2]
        local db = task.find_db(start_dir())
        if db and (sub == "find" or sub == "ref") and n == 3 then
            local tasks = task.list(db)
            table.sort(tasks, function(a, b) return a.huid > b.huid end)
            -- Nvim 0.13 shows the `menu` of dict items in the popup menu.
            local dicts = vim.fn.has("nvim-0.13") == 1
            for _, t in ipairs(tasks) do
                candidates[#candidates + 1] = dicts and { word = t.huid, menu = t.title } or t.huid
            end
        elseif sub == "ls" then
            local seen = {}
            local tags = db and task.described_tags(db) or {}
            for _, t in ipairs(db and task.list(db) or {}) do
                vim.list_extend(tags, t.tags)
            end
            for _, tag in ipairs(tags) do
                if not seen[tag] then
                    seen[tag] = true
                    candidates[#candidates + 1] = ":" .. tag
                end
            end
            table.sort(candidates)
            vim.list_extend(candidates, ls_words)
        end
    end

    return vim.tbl_filter(function(c)
        return vim.startswith(type(c) == "table" and c.word or c, arglead)
    end, candidates)
end

return M
