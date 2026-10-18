vim.g.mapleader = " "

local cwd = require("ytret.cwd")
local tabs = require("ytret.tabs")

local function realpath(path) return vim.uv.fs_realpath(path) or path end

local function close_prompt()
    local st = cwd._state()
    if st and vim.api.nvim_win_is_valid(st.win) then
        vim.api.nvim_win_close(st.win, true)
    end
end

local function prompt_line()
    local st = cwd._state()
    return table.concat(vim.api.nvim_buf_get_lines(st.buf, 0, 1, false), "")
end

local function set_prompt_line(text)
    local st = cwd._state()
    vim.api.nvim_buf_set_lines(st.buf, 0, 1, false, { text })
    vim.api.nvim_win_set_cursor(st.win, { 1, #text })
    return st
end

---Find the buffer-local prompt mapping callback for `lhs`.
local function termcodes(lhs) return vim.api.nvim_replace_termcodes(lhs, true, false, true) end

local function prompt_map(lhs, mode)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode or "i")) do
        if termcodes(map.lhs) == termcodes(lhs) then
            return map.callback
        end
    end
end

---Invoke the buffer-local prompt mapping for `lhs`.
local function press(lhs, mode)
    local callback = prompt_map(lhs, mode)
    assert.is_function(callback, "no prompt mapping for " .. lhs)
    callback()
end

local function nmap(lhs)
    lhs = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    return vim.fn.maparg(lhs, "n", false, true)
end

local function run_map(lhs)
    local map = nmap(lhs)
    assert.is_function(map.callback, "no mapping for " .. lhs)
    map.callback()
end

describe("cwd path helpers", function()
    describe("_kill_component", function()
        local cases = {
            { "/a/b/c", 6, "/a/b/", 5 },
            { "/a/b/c/", 7, "/a/b/", 5 },
            { "/a/", 3, "/", 1 },
            { "/", 1, "/", 1 },
            { "foo", 3, "", 0 },
            { "~/", 2, "", 0 },
            -- Cursor mid-path: keep a single separator.
            { "/a/b/c", 4, "/a/c", 2 },
        }

        for _, case in ipairs(cases) do
            local line, col, want_line, want_col = unpack(case)
            it(("kills %q at %d"):format(line, col), function()
                local new_line, new_col = cwd._kill_component(line, col)
                assert.are.equal(want_line, new_line)
                assert.are.equal(want_col, new_col)
            end)
        end
    end)

    describe("_prev_boundary", function()
        it("walks back one component at a time", function()
            local line = "/a/b/c"
            local col = 6
            local seen = {}
            for _ = 1, 4 do
                col = cwd._prev_boundary(line, col)
                table.insert(seen, col)
            end
            assert.are.same({ 5, 3, 1, 0 }, seen)
        end)

        it(
            "skips a trailing slash",
            function() assert.are.equal(3, cwd._prev_boundary("/a/b/", 5)) end
        )

        it(
            "stays at 0 for a component without slashes",
            function() assert.are.equal(0, cwd._prev_boundary("~", 1)) end
        )
    end)

    describe("_next_boundary", function()
        it("walks forward one component at a time", function()
            local line = "/a/b/c"
            local col = 0
            local seen = {}
            for _ = 1, 3 do
                col = cwd._next_boundary(line, col)
                table.insert(seen, col)
            end
            assert.are.same({ 1, 3, 5 }, seen)
        end)

        it("stops at the end of the line", function()
            assert.are.equal(6, cwd._next_boundary("/a/b/c", 5))
            assert.are.equal(5, cwd._next_boundary("/a/b/", 4))
        end)
    end)

    describe("_resolve", function()
        it(
            "resolves an absolute directory",
            function() assert.are.equal("/usr", cwd._resolve("/usr")) end
        )

        it(
            "expands a leading tilde",
            function() assert.are.equal(vim.fs.normalize(vim.env.HOME), cwd._resolve("~/")) end
        )

        it("resolves a relative path against the cwd", function()
            local saved = vim.fn.getcwd()
            vim.cmd("cd /usr")
            assert.are.equal("/usr/share", cwd._resolve("share"))
            vim.cmd("cd " .. vim.fn.fnameescape(saved))
        end)

        it("rejects an empty path", function()
            local dir, err = cwd._resolve("  ")
            assert.is_nil(dir)
            assert.are.equal("Empty path", err)
        end)

        it("rejects a missing path", function()
            local dir, err = cwd._resolve("/no-such-dir-xyz")
            assert.is_nil(dir)
            assert.truthy(err:match("No such directory"))
        end)

        it("rejects a file", function()
            local dir, err = cwd._resolve("/etc/hosts")
            assert.is_nil(dir)
            assert.truthy(err:match("Not a directory"))
        end)
    end)
end)

describe("cwd prompt", function()
    local saved_cwd
    local saved_tabs
    local saved_cols
    local saved_lines

    before_each(function()
        saved_cwd = vim.fn.getcwd()
        saved_tabs = vim.fn.tabpagenr("$")
        saved_cols = vim.o.columns
        saved_lines = vim.o.lines
    end)

    after_each(function()
        close_prompt()
        vim.o.columns = saved_cols
        vim.o.lines = saved_lines
        while vim.fn.tabpagenr("$") > saved_tabs do
            vim.cmd("tabclose")
        end
        vim.cmd("tabnext 1")
        vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
    end)

    it("binds the three shortcuts", function()
        for _, lhs in ipairs({ "<leader>ca", "<leader>cs", "<leader>cd" }) do
            assert.is_function(nmap(lhs).callback, "no mapping for " .. lhs)
        end
    end)

    it("prefills / for <leader>ca", function()
        run_map("<leader>ca")
        assert.are.equal("/", prompt_line())
    end)

    it("prefills ~/ for <leader>cs", function()
        run_map("<leader>cs")
        assert.are.equal("~/", prompt_line())
    end)

    it("prefills the global cwd for <leader>cd", function()
        run_map("<leader>cd")
        assert.are.equal(tabs.get_global_cwd(), prompt_line())
    end)

    it("changes the global directory on <CR>", function()
        vim.cmd("cd /Library")
        run_map("<leader>ca")
        set_prompt_line("/usr")
        press("<CR>")
        assert.is_nil(cwd._state())
        assert.are.equal(realpath("/usr"), realpath(vim.fn.getcwd()))
    end)

    it("changes the tab-local directory on <C-e>", function()
        vim.cmd("cd /usr")
        vim.cmd("tabnew")
        run_map("<leader>ca")
        set_prompt_line("/Library")
        press("<C-e>")
        assert.is_nil(cwd._state())
        assert.are.equal(realpath("/Library"), realpath(vim.fn.getcwd()))
        assert.are.equal(realpath("/usr"), realpath(tabs.get_global_cwd()))
    end)

    it("changes the tab-local directory on <S-CR>", function()
        vim.cmd("cd /usr")
        vim.cmd("tabnew")
        run_map("<leader>ca")
        set_prompt_line("/Library")
        press("<S-CR>")
        assert.is_nil(cwd._state())
        assert.are.equal(realpath("/Library"), realpath(vim.fn.getcwd()))
    end)

    it("brings a tab-local tab along on a global <CR>", function()
        vim.cmd("cd /usr")
        vim.cmd("tabnew")
        vim.cmd("tcd /Library")
        run_map("<leader>ca")
        set_prompt_line("/usr")
        press("<CR>")
        assert.are.equal(realpath("/usr"), realpath(vim.fn.getcwd()))
    end)

    it("keeps the prompt open on an invalid path", function()
        vim.cmd("cd /usr")
        run_map("<leader>ca")
        set_prompt_line("/no-such-dir-xyz")
        press("<CR>")

        local st = cwd._state()
        assert.is_not_nil(st)
        assert.is_true(vim.api.nvim_win_is_valid(st.win))
        assert.are.equal(realpath("/usr"), realpath(vim.fn.getcwd()))
        local footer = vim.api.nvim_win_get_config(st.win).footer[1][1]
        assert.truthy(footer:match("No such directory"))
    end)

    it("closes without changing directory on <Esc>", function()
        vim.cmd("cd /usr")
        run_map("<leader>ca")
        set_prompt_line("/Library")
        press("<Esc>", "n")
        assert.is_nil(cwd._state())
        assert.are.equal(realpath("/usr"), realpath(vim.fn.getcwd()))
    end)

    it("centers the prompt", function()
        run_map("<leader>ca")
        local cfg = vim.api.nvim_win_get_config(cwd._state().win)
        assert.are.equal(math.floor((vim.o.lines - cfg.height - 2) / 2), cfg.row)
        assert.are.equal(math.floor((vim.o.columns - cfg.width - 2) / 2), cfg.col)
    end)

    it("is wide enough for the hint footer", function()
        run_map("<leader>cs")
        local cfg = vim.api.nvim_win_get_config(cwd._state().win)
        local hint = cfg.footer[1][1]
        assert.is_true(cfg.width >= #hint)
    end)

    it("recenters on terminal resize", function()
        run_map("<leader>ca")
        vim.o.columns = 120
        vim.o.lines = 40
        vim.api.nvim_exec_autocmds("VimResized", {})
        local cfg = vim.api.nvim_win_get_config(cwd._state().win)
        assert.are.equal(math.floor((120 - cfg.width - 2) / 2), cfg.col)
        assert.are.equal(math.floor((40 - cfg.height - 2) / 2), cfg.row)
    end)

    it("edits the path by component", function()
        run_map("<leader>ca")
        set_prompt_line("/usr/local/lib")
        vim.api.nvim_win_set_cursor(cwd._state().win, { 1, #prompt_line() })
        press("<C-w>")
        assert.are.equal("/usr/local/", prompt_line())
        press("<C-w>")
        assert.are.equal("/usr/", prompt_line())
        press("<M-b>")
        assert.are.equal(1, vim.api.nvim_win_get_cursor(cwd._state().win)[2])
        press("<M-f>")
        assert.are.equal(5, vim.api.nvim_win_get_cursor(cwd._state().win)[2])
    end)
end)
