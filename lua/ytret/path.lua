local M = {}

local uv = vim.uv or vim.loop

local function canonical_path(path)
    return uv.fs_realpath(path) or vim.fs.normalize(path)
end

local function find_buffer_by_path(path)
    local target = canonical_path(path)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" and canonical_path(name) == target then
            return bufnr
        end
    end
end

function M.rename_buffer_prefer_rel(abs_path)
    local rel_path = vim.fs.relpath(vim.fn.getcwd(), abs_path)
    local existing_bufnr = find_buffer_by_path(abs_path)

    if existing_bufnr ~= nil then
        if rel_path ~= nil and vim.api.nvim_buf_get_name(existing_bufnr) ~= rel_path then
            pcall(vim.api.nvim_buf_set_name, existing_bufnr, rel_path)
        end
    end

    return existing_bufnr
end

function M.bufadd_prefer_rel(abs_path)
    local rel_path = vim.fs.relpath(vim.fn.getcwd(), abs_path)
    local target_path = rel_path or abs_path
    local existing_bufnr = M.rename_buffer_prefer_rel(abs_path)

    if existing_bufnr ~= nil then
        return existing_bufnr
    end

    return vim.fn.bufadd(target_path)
end

return M
