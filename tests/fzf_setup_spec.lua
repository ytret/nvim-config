local mock_path = {
    entry_to_file = function() end,
    is_absolute = function(path) return path:sub(1, 1) == "/" end,
    join = function(paths) return table.concat(paths, "/") end,
}
local mock_utils = {
    cwd = function() return "/tmp" end,
}
local mock_actions = {}
-- top-level modules required by ytret.fzf-setup that are not on package.path
-- in the test harness (they are only provided by lazy.nvim at runtime)
local mock_fzf_lua = {
    files = function() end,
    live_grep = function() end,
}
local mock_win = {
    __SELF = function() end,
}

package.loaded["fzf-lua"] = mock_fzf_lua
package.loaded["fzf-lua.path"] = mock_path
package.loaded["fzf-lua.utils"] = mock_utils
package.loaded["fzf-lua.actions"] = mock_actions
package.loaded["fzf-lua.win"] = mock_win
package.loaded["ytret.fzf-setup"] = nil

local fzf_setup = require("ytret.fzf-setup")

local function get_has_real_target()
    local i = 1
    while true do
        local name, val = debug.getupvalue(fzf_setup.setup, i)
        if not name then
            break
        end
        if type(val) == "function" then
            local j = 1
            while true do
                local inner_name, inner_val = debug.getupvalue(val, j)
                if not inner_name then
                    break
                end
                if inner_name == "has_real_target" then
                    return inner_val
                end
                j = j + 1
            end
        end
        i = i + 1
    end
    error("has_real_target not found")
end

local has_real_target = get_has_real_target()

describe("has_real_target", function()
    before_each(function()
        mock_path.entry_to_file = function(_entry, _opts, _force_uri) return {} end
    end)

    it("returns false for nil selection", function() assert.is_false(has_real_target(nil, {})) end)

    it(
        "returns false for empty selection array",
        function() assert.is_false(has_real_target({}, {})) end
    )

    it(
        "returns false for selection with empty string",
        function() assert.is_false(has_real_target({ "" }, {})) end
    )

    it("returns false when entry_to_file errors", function()
        mock_path.entry_to_file = function() error("pcall target") end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns false when entry_to_file returns nil", function()
        mock_path.entry_to_file = function() return nil end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns true for entry with URI", function()
        mock_path.entry_to_file = function() return { uri = "file:///tmp/test.lua" } end
        assert.is_true(has_real_target({ "test" }, {}))
    end)

    it("returns true for entry with valid bufnr", function()
        local bufnr = vim.api.nvim_create_buf(true, false)
        mock_path.entry_to_file = function() return { bufnr = bufnr } end
        assert.is_true(has_real_target({ "test" }, {}))
    end)

    it("returns false for entry with invalid bufnr", function()
        mock_path.entry_to_file = function() return { bufnr = 99999 } end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns false when entry has no bufname or path", function()
        mock_path.entry_to_file = function() return {} end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns false when entry has empty bufname", function()
        mock_path.entry_to_file = function() return { bufname = "" } end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns true for absolute path that exists", function()
        local tmpfile = vim.fn.tempname()
        vim.fn.writefile({}, tmpfile)
        mock_path.entry_to_file = function() return { path = tmpfile } end
        assert.is_true(has_real_target({ "test" }, {}))
        vim.fn.delete(tmpfile)
    end)

    it("returns false for absolute path that does not exist", function()
        mock_path.entry_to_file = function() return { path = "/nonexistent_path_12345" } end
        assert.is_false(has_real_target({ "test" }, {}))
    end)

    it("returns true for relative path that resolves to existing file", function()
        local tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        local testfile = tmpdir .. "/test.lua"
        vim.fn.writefile({}, testfile)

        mock_path.entry_to_file = function() return { path = "test.lua", bufname = "test.lua" } end
        mock_utils.cwd = function() return tmpdir end

        assert.is_true(has_real_target({ "test" }, { cwd = tmpdir }))
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns false for relative path that does not exist", function()
        local tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")

        mock_path.entry_to_file = function()
            return { path = "nonexistent.lua", bufname = "nonexistent.lua" }
        end
        mock_utils.cwd = function() return tmpdir end

        assert.is_false(has_real_target({ "test" }, { cwd = tmpdir }))
        vim.fn.delete(tmpdir, "rf")
    end)
end)

describe("setup winopts", function()
    it("forces fullscreen windows", function()
        local opts = fzf_setup.setup({})
        assert.is_true(opts.winopts.fullscreen)
    end)

    it("puts the preview on the right at 50% of the width", function()
        local opts = fzf_setup.setup({})
        assert.equals("horizontal", opts.winopts.preview.layout)
        assert.equals("right:50%", opts.winopts.preview.horizontal)
    end)

    it("preserves existing user winopts", function()
        local opts = fzf_setup.setup({ winopts = { border = "none" } })
        assert.equals("none", opts.winopts.border)
        assert.is_true(opts.winopts.fullscreen)
        assert.equals("right:50%", opts.winopts.preview.horizontal)
    end)
end)
