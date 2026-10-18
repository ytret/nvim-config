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

    it("adapts equal-sized preview panes to the available width", function()
        local opts = fzf_setup.setup({})
        assert.equals("flex", opts.winopts.preview.layout)
        assert.equals(120, opts.winopts.preview.flip_columns)
        assert.equals("right:50%", opts.winopts.preview.horizontal)
        assert.equals("down:50%", opts.winopts.preview.vertical)
    end)

    it("toggles native grep path sorting without replacing its reload bindings", function()
        local opts = fzf_setup.setup({})
        local action = opts.grep.actions["alt-s"]
        local reopened
        local original = {
            cwd = "/usr",
            hidden = true,
            no_ignore = false,
            search_paths = { "example.lua" },
            actions = { ["ctrl-g"] = function() end },
        }
        local resolved = {
            rg_opts = "--color=always --line-number --column -e",
            hls = { title = "FzfLuaTitle", title_flags = "FzfLuaTitleFlags" },
            winopts = { title = { { "Grep" }, { " h " } } },
            __call_opts = original,
            __call_fn = function(args) reopened = args end,
        }
        action.fn({}, resolved)
        assert.is_true(action.reuse)
        assert.is_true(reopened.resume)
        assert.is_true(reopened._path_sorted)
        assert.equals("--sort=path " .. resolved.rg_opts, reopened.rg_opts)
        -- Exercise the trailing -e used by fzf-lua's real defaults, not just option strings.
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "fo" }, dir .. "/z.txt")
        vim.fn.writefile({ "fo" }, dir .. "/a.txt")
        local output =
            vim.fn.system("rg " .. reopened.rg_opts .. " 'fo' " .. vim.fn.shellescape(dir))
        local status = vim.v.shell_error
        vim.fn.delete(dir, "rf")
        assert.equals(0, status)
        local plain = output:gsub("\27%[[%d;]*m", "")
        assert.is_truthy(plain:find("a.txt:1:1:fo", 1, true))
        assert.is_truthy(plain:find("z.txt:1:1:fo", 1, true))
        assert.is_true(plain:find("a.txt", 1, true) < plain:find("z.txt", 1, true))
        assert.is_truthy(output:find("\27[", 1, true))
        assert.is_true(reopened.fzf_opts["--no-sort"])
        assert.same({
            { "Grep", "FzfLuaTitle" },
            { " s ", "FzfLuaTitleFlags" },
        }, reopened.winopts.title)
        assert.is_true(reopened.hidden)
        assert.is_false(reopened.no_ignore)
        assert.same(original.search_paths, reopened.search_paths)
        assert.equals(original.actions["ctrl-g"], reopened.actions["ctrl-g"])
        assert.is_nil(opts.grep.keymap)
        assert.is_nil(opts.grep.fzf_opts["--no-sort"])
        assert.is_true(opts.actions.files[1])
        assert.is_false(opts.actions.files["alt-f"])

        -- Simulate a native Alt-I toggle/restart while sorting is enabled.
        reopened.no_ignore = true
        local sorted = vim.deepcopy(reopened)
        sorted.__call_opts = vim.deepcopy(reopened)
        sorted.__call_fn = resolved.__call_fn
        sorted.hls = resolved.hls
        sorted.winopts.title = {
            { "Grep", "FzfLuaTitle" },
            { " s ", "FzfLuaTitleFlags" },
            { " h ", "FzfLuaTitleFlags" },
            { " i ", "FzfLuaTitleFlags" },
        }
        action.fn({}, sorted)
        assert.is_false(reopened._path_sorted)
        assert.is_false(reopened.fzf_opts["--no-sort"])
        assert.equals(resolved.rg_opts, reopened.rg_opts)
        assert.equals("Grep", reopened.winopts.title)
        assert.is_true(reopened.no_ignore)
        assert.is_true(reopened.hidden)
        assert.is_nil(original.rg_opts)
    end)

    it("preserves existing user winopts", function()
        local opts = fzf_setup.setup({ winopts = { border = "none" } })
        assert.equals("none", opts.winopts.border)
        assert.is_true(opts.winopts.fullscreen)
        assert.equals("flex", opts.winopts.preview.layout)
        assert.equals("right:50%", opts.winopts.preview.horizontal)
    end)
end)

describe("files and grep TUI state", function()
    local grep_opts, files_opts, window, opts

    local function set_window(pos, size, fullscreen, hidden)
        window = {
            fullscreen = fullscreen,
            preview_hidden = hidden,
            winopts = { preview = vim.deepcopy(opts.winopts.preview) },
            normalize_preview_layout = function()
                return { pos = pos, size = size, str = pos .. ":" .. size * 100 .. "%" }
            end,
        }
    end

    before_each(function()
        opts = fzf_setup.setup({})
        grep_opts, files_opts = nil, nil
        mock_win.__SELF = function() return window end
        mock_fzf_lua.live_grep = function(args) grep_opts = args end
        mock_fzf_lua.files = function(args) files_opts = args end
        set_window("right", 0.5, true, false)
    end)

    after_each(function()
        mock_win.__SELF = function() end
        mock_fzf_lua.live_grep = function() end
        mock_fzf_lua.files = function() end
    end)

    for _, selection in ipairs({ {}, { "example.lua" } }) do
        local scope = #selection == 0 and "unscoped" or "scoped"
        it("preserves flex across the " .. scope .. " files/grep round trip", function()
            opts.files.actions["ctrl-g"](selection, {
                cwd = "/usr",
                last_query = "original query",
                winopts = vim.deepcopy(opts.winopts),
            })

            assert.equals("flex", grep_opts.winopts.preview.layout)
            assert.equals(120, grep_opts.winopts.preview.flip_columns)
            assert.equals("right:50%", grep_opts.winopts.preview.horizontal)
            assert.equals("down:50%", grep_opts.winopts.preview.vertical)
            assert.is_true(grep_opts.winopts.fullscreen)
            assert.is_false(grep_opts.winopts.preview.hidden)
            if #selection > 0 then
                assert.same(selection, grep_opts.search_paths)
            end

            -- Simulate resizing to a narrow terminal and toggling fullscreen/visibility.
            set_window("down", 0.6, false, true)
            grep_opts.actions["ctrl-g"]()

            assert.equals("flex", files_opts.winopts.preview.layout)
            assert.equals(120, files_opts.winopts.preview.flip_columns)
            assert.equals("right:50%", files_opts.winopts.preview.horizontal)
            assert.equals("down:60%", files_opts.winopts.preview.vertical)
            assert.is_false(files_opts.winopts.fullscreen)
            assert.is_true(files_opts.winopts.preview.hidden)
            assert.equals("original query", files_opts.query)
            assert.equals("Files", files_opts.winopts.title)
        end)
    end

    for _, pos in ipairs({ "up", "down", "left", "right" }) do
        it("restores " .. pos .. " in the correct flex orientation", function()
            set_window(pos, 0.6, false, false)
            opts.files.actions["ctrl-g"]({}, { winopts = vim.deepcopy(opts.winopts) })

            local preview = grep_opts.winopts.preview
            assert.equals("flex", preview.layout)
            if pos == "up" or pos == "down" then
                assert.equals(pos .. ":60%", preview.vertical)
                assert.equals("right:50%", preview.horizontal)
            else
                assert.equals(pos .. ":60%", preview.horizontal)
                assert.equals("down:50%", preview.vertical)
            end
            assert.is_false(grep_opts.winopts.fullscreen)
            assert.is_false(preview.hidden)
            -- The snapshot must not mutate the source window's preview options.
            assert.same(opts.winopts.preview, window.winopts.preview)
        end)
    end

    it("clears hidden and fullscreen state when returning to files", function()
        set_window("right", 0.5, true, true)
        local original = vim.deepcopy(opts.winopts)
        original.preview.hidden = true
        opts.files.actions["ctrl-g"]({}, { winopts = original })

        set_window("right", 0.5, false, false)
        grep_opts.actions["ctrl-g"]()
        assert.is_false(files_opts.winopts.fullscreen)
        assert.is_false(files_opts.winopts.preview.hidden)
    end)

    it("leaves defaults untouched when no fzf window is available", function()
        window = nil
        opts.files.actions["ctrl-g"]({}, { cwd = "/usr" })
        assert.is_nil(grep_opts.winopts)
    end)
end)
