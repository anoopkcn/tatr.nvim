-- Helpers for the tatr tasks/ database: HUIDs, lookup and TASK.md parsing.
-- See https://github.com/tsoding/tatr for the spec.

local M = {}

-- Short HUID. The full format is [0-9]{8}-[0-9]{6}(-[a-zA-Z0-9-]*)?
local HUID = "%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d"

function M.is_huid(s)
    if type(s) ~= "string" then return false end
    return s:match("^" .. HUID .. "$") ~= nil
        or s:match("^" .. HUID .. "%-[%w%-]*$") ~= nil
end

-- Current UTC time as a HUID, optionally extended with `suffix`.
function M.new_huid(suffix)
    local huid = os.date("!%Y%m%d-%H%M%S")
    if suffix and suffix ~= "" then
        huid = huid .. "-" .. suffix
    end
    return huid
end

-- Returns the HUID in `line` that covers the 1-based byte column `col`.
function M.huid_at(line, col)
    local init = 1
    while true do
        local s, e = line:find("%f[%w]" .. HUID .. "%f[%D]", init)
        if not s then return nil end
        local suffix = line:match("^%-[%w%-]*", e + 1)
        if suffix then e = e + #suffix end
        if col >= s and col <= e then
            return line:sub(s, e)
        end
        init = e + 1
    end
end

-- Walks up from `dir` looking for a tasks/ folder.
function M.find_db(dir)
    return vim.fs.find("tasks", { upward = true, type = "directory", path = dir, limit = 1 })[1]
end

-- Returns the HUID of the task folder `path` lives in, if it is inside `db`.
function M.task_of(path, db)
    local prefix = db .. "/"
    if path:sub(1, #prefix) ~= prefix then return nil end
    local huid = path:sub(#prefix + 1):match("^[^/]+")
    if M.is_huid(huid) then return huid end
end

-- Parses the lines of a TASK.md the same way tatr does: a `# title`, then a
-- block of `- KEY: value` properties. Duplicated properties keep the last value.
function M.parse(lines)
    local i = 1
    while lines[i] and lines[i]:match("^%s*$") do i = i + 1 end
    local title = lines[i] and lines[i]:match("^%s*#%s*(.-)%s*$")
    local props = {}
    if title then
        i = i + 1
        while lines[i] and lines[i]:match("^%s*$") do i = i + 1 end
        while lines[i] do
            local key, value = lines[i]:match("^%s*%-%s*(%w+)%s*:(.*)$")
            if not key then break end
            props[key] = vim.trim(value)
            i = i + 1
        end
    else
        title = "!!! INVALID: TASK TITLE MUST START WITH # !!!"
    end

    local tags = {}
    for tag in (props.TAGS or ""):gmatch("[^%s,]+") do
        tags[#tags + 1] = tag
    end

    return {
        title = title,
        status = props.STATUS or "OPEN",
        -- Unset priority is super high so you don't forget to set it
        priority = tonumber((props.PRIORITY or "999999"):match("^[+-]?%d+")) or 0,
        tags = tags,
        properties = props,
    }
end

-- All tasks in `db` that have a TASK.md.
function M.list(db)
    local tasks = {}
    for name in vim.fs.dir(db) do
        if M.is_huid(name) then
            local path = db .. "/" .. name .. "/TASK.md"
            if vim.fn.filereadable(path) == 1 then
                local t = M.parse(vim.fn.readfile(path))
                t.huid, t.path = name, path
                tasks[#tasks + 1] = t
            end
        end
    end
    return tasks
end

-- Tag names documented in tasks/tags (`<tag-name> [,] <tag-description>`).
function M.described_tags(db)
    local path = db .. "/tags"
    local tags = {}
    if vim.fn.filereadable(path) == 1 then
        for _, line in ipairs(vim.fn.readfile(path)) do
            local tag = line:match("^%s*([^%s,]+)")
            if tag then tags[#tags + 1] = tag end
        end
    end
    return tags
end

return M
