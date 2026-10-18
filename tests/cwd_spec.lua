vim.g.mapleader = " "

local cwd = require("ytret.cwd")
local tabs = require("ytret.tabs")

local function realpath(path) return vim.uv.fs_realpath(path) or path end

local function close_prompt()
    local st = cwd._state()
    if st and vim.api.nvim_win_is_valid(st.win) then
        vim.api.nvim_win_close(st.win, true)
    end
    if st and st.backdrop and vim.api.nvim_win_is_valid(st.backdrop) then
        vim.api.nvim_win_close(st.backdrop, true)
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

describe("cwd path helpers", function()
    describe("_split_component", function()
        local cases = {
            { "/a/luax/b", 6, { "/a/", "luax", 3, 7 } },
            { "/a/lua/", 6, { "/a/", "lua", 3, 6 } },
            { "/a/lua/", 7, { "/a/lua/", "", 7, 7 } },
            { "~/", 2, { "~/", "", 2, 2 } },
            { "/", 1, { "/", "", 1, 1 } },
            { "lu", 2, { "", "lu", 0, 2 } },
            { "", 0, { "", "", 0, 0 } },
        }
        for _, case in ipairs(cases) do
            local line, col, want = case[1], case[2], case[3]
            it(
                ("%s at %d"):format(vim.inspect(line), col),
                function() assert.are.same(want, { cwd._split_component(line, col) }) end
            )
        end
    end)

    describe("_resolve_base", function()
        it(
            "resolves an empty base to the current directory",
            function() assert.are.equal(vim.fs.normalize(vim.fn.getcwd()), cwd._resolve_base("")) end
        )

        it("resolves a relative base against the current directory", function()
            local base = vim.fn.fnamemodify("lua", ":p")
            assert.are.equal(vim.fs.normalize(base), cwd._resolve_base("lua/"))
        end)

        it(
            "resolves a leading ~ against $HOME",
            function() assert.are.equal(vim.fs.normalize(vim.env.HOME), cwd._resolve_base("~/")) end
        )

        it("rejects a missing base", function()
            local dir, err = cwd._resolve_base("/no/such/dir/")
            assert.is_nil(dir)
            assert.is_truthy(err:match("No such directory"))
        end)

        it("rejects a base that is a file", function()
            local dir, err = cwd._resolve_base("/usr/bin/env")
            assert.is_nil(dir)
            assert.is_truthy(err:match("Not a directory"))
        end)
    end)

    describe("_dir_candidates", function()
        it("lists only directories, sorted, including hidden ones", function()
            local names = cwd._dir_candidates(vim.env.HOME)
            assert.is_table(names)
            assert.is_true(vim.tbl_contains(names, ".config"))
            for i = 2, #names do
                assert.is_true(names[i - 1] < names[i])
            end
        end)

        it("excludes files", function()
            local names = cwd._dir_candidates("/usr/bin")
            for _, name in ipairs(names) do
                assert.are.equal(1, vim.fn.isdirectory("/usr/bin/" .. name))
            end
        end)

        it("reports an unreadable directory", function()
            local names, err = cwd._dir_candidates("/no/such/dir")
            assert.is_nil(names)
            assert.is_truthy(err)
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

    it("prefills the current dir for <leader>cs", function()
        run_map("<leader>cs")
        assert.are.equal(tabs.get_global_cwd(), prompt_line())
    end)

    it("prefills ~/ for <leader>cd", function()
        run_map("<leader>cd")
        assert.are.equal("~/", prompt_line())
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

    it("keeps a fixed width while the text changes", function()
        run_map("<leader>ca")
        local before = vim.api.nvim_win_get_config(cwd._state().win).width
        set_prompt_line("/usr/local/share/some/very/long/path")
        press("<M-b>")
        assert.are.equal(before, vim.api.nvim_win_get_config(cwd._state().win).width)
        assert.are.equal(math.floor(vim.o.columns * 0.6), before)
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

    describe("backdrop", function()
        local saved_hls

        ---Make the guard conditions hold without touching the real colorscheme.
        local function define_hls()
            vim.api.nvim_set_hl(0, "Normal", { bg = "#101010" })
            vim.api.nvim_set_hl(0, "FzfLuaBackdrop", { bg = "Black" })
            vim.api.nvim_set_hl(0, "FzfLuaNormal", { link = "Normal" })
            vim.api.nvim_set_hl(0, "FzfLuaBorder", { link = "Normal" })
        end

        before_each(function()
            saved_hls = vim.api.nvim_get_hl(0, { name = "Normal" })
            package.loaded["fzf-lua.config"] = nil
            define_hls()
        end)

        after_each(function()
            package.loaded["fzf-lua.config"] = nil
            vim.api.nvim_set_hl(0, "Normal", saved_hls)
            for _, name in ipairs({ "FzfLuaBackdrop", "FzfLuaNormal", "FzfLuaBorder" }) do
                pcall(vim.api.nvim_set_hl, 0, name, {})
            end
        end)

        describe("_backdrop_blend", function()
            it(
                "falls back to fzf's default of 60",
                function() assert.are.equal(60, cwd._backdrop_blend()) end
            )

            it("follows the value configured in fzf-lua", function()
                package.loaded["fzf-lua.config"] = { defaults = { winopts = { backdrop = 40 } } }
                assert.are.equal(40, cwd._backdrop_blend())
            end)

            it("is nil when fzf-lua's backdrop is disabled", function()
                package.loaded["fzf-lua.config"] = { defaults = { winopts = { backdrop = false } } }
                assert.is_nil(cwd._backdrop_blend())
            end)
        end)

        describe("_backdrop_supported", function()
            it(
                "is true with the highlight group and an opaque Normal",
                function() assert.is_true(cwd._backdrop_supported()) end
            )

            it("is false without fzf-lua's backdrop highlight group", function()
                vim.api.nvim_set_hl(0, "FzfLuaBackdrop", {})
                assert.is_false(cwd._backdrop_supported())
            end)

            it("is false when the background is transparent", function()
                vim.api.nvim_set_hl(0, "Normal", {})
                assert.is_false(cwd._backdrop_supported())
            end)
        end)

        it("dims the screen while the prompt is open", function()
            run_map("<leader>ca")
            local win = cwd._state().backdrop
            assert.is_true(vim.api.nvim_win_is_valid(win))
            local cfg = vim.api.nvim_win_get_config(win)
            assert.are.equal(0, cfg.row)
            assert.are.equal(0, cfg.col)
            assert.are.equal(vim.o.columns, cfg.width)
            assert.are.equal(vim.o.lines, cfg.height)
            assert.is_false(cfg.focusable)
            assert.are.equal(60, vim.wo[win].winblend)
            assert.are.equal("Normal:FzfLuaBackdrop", vim.wo[win].winhl)
        end)

        it("sits below the prompt", function()
            run_map("<leader>ca")
            local st = cwd._state()
            local bar = vim.api.nvim_win_get_config(st.win).zindex
            assert.is_true(vim.api.nvim_win_get_config(st.backdrop).zindex < bar)
        end)

        it("keeps the prompt focused", function()
            run_map("<leader>ca")
            assert.are.equal(cwd._state().win, vim.api.nvim_get_current_win())
        end)

        it("is not drawn when the background is transparent", function()
            vim.api.nvim_set_hl(0, "Normal", {})
            run_map("<leader>ca")
            assert.is_nil(cwd._state().backdrop)
        end)

        it("resizes with the terminal", function()
            run_map("<leader>ca")
            vim.o.columns = 120
            vim.o.lines = 40
            vim.api.nvim_exec_autocmds("VimResized", {})
            local cfg = vim.api.nvim_win_get_config(cwd._state().backdrop)
            assert.are.equal(120, cfg.width)
            assert.are.equal(40, cfg.height)
        end)

        it("is torn down with the prompt", function()
            run_map("<leader>ca")
            local st = cwd._state()
            local win, buf = st.backdrop, vim.api.nvim_win_get_buf(st.backdrop)
            press("<Esc>")
            assert.is_false(vim.api.nvim_win_is_valid(win))
            assert.is_false(vim.api.nvim_buf_is_valid(buf))
        end)

        it("paints the prompt with fzf-lua's own highlights", function()
            run_map("<leader>ca")
            local winhl = vim.wo[cwd._state().win].winhl
            assert.is_truthy(winhl:find("Normal:FzfLuaNormal", 1, true))
            assert.is_truthy(winhl:find("FloatBorder:FzfLuaBorder", 1, true))
        end)
    end)

    describe("_head_elide", function()
        it(
            "keeps short text as is",
            function() assert.are.equal("/usr/local", cwd._head_elide("/usr/local", 20)) end
        )

        it("keeps the tail of long text", function()
            local out = cwd._head_elide("/Users/ytret/dev/ytret", 14)
            assert.are.equal(14, #out)
            assert.are.equal("dev/ytret", out:sub(-#"dev/ytret"))
            assert.are.equal("\u{2026}", out:sub(1, #"\u{2026}"))
        end)

        it(
            "never exceeds a tiny budget",
            function() assert.are.equal("ret", cwd._head_elide("/Users/ytret/dev/ytret", 3)) end
        )
    end)

    it("registers a WinEnter hook that re-enters insert mode", function()
        run_map("<leader>ca")
        local st = cwd._state()
        local hooks = vim.api.nvim_get_autocmds({ event = "WinEnter", buffer = st.buf })
        assert.are.equal(1, #hooks)
        assert.is_function(hooks[1].callback)
        hooks[1].callback()
        assert.are.equal(st.win, vim.api.nvim_get_current_win())
    end)

    it("re-enters insert mode after another window (the picker) closes", function()
        run_map("<leader>ca")
        local st = cwd._state()
        local calls, orig = 0, cwd._reenter_insert
        cwd._reenter_insert = function()
            calls = calls + 1
            return orig()
        end
        local buf = vim.api.nvim_create_buf(false, true)
        local float = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = 20,
            height = 5,
            row = 5,
            col = 5,
            style = "minimal",
        })
        vim.api.nvim_win_close(float, true)
        cwd._reenter_insert = orig
        assert.are.equal(st.win, vim.api.nvim_get_current_win())
        assert.is_true(calls >= 1)
        assert.is_not_nil(cwd._state())
    end)

    it("re-enters insert mode only for the focused prompt", function()
        run_map("<leader>ca")
        local st = cwd._state()
        assert.is_true(cwd._reenter_insert())
        vim.cmd("new")
        assert.is_false(cwd._reenter_insert())
        vim.api.nvim_set_current_win(st.win)
        vim.cmd("close")
    end)

    it("enters insert mode without moving the cursor", function()
        run_map("<leader>ca")
        local st = set_prompt_line("~/dev")
        vim.api.nvim_win_set_cursor(st.win, { 1, 2 })
        local calls, orig = {}, vim.cmd
        vim.cmd = function(cmd)
            calls[#calls + 1] = cmd
            return orig(cmd)
        end
        local ok, err = pcall(function()
            assert.is_true(cwd._reenter_insert())
            vim.wait(100, function() return #calls > 0 end)
        end)
        vim.cmd = orig
        assert.is_true(ok, err)
        assert.is_true(#calls > 0)
        for _, cmd in ipairs(calls) do
            assert.are.equal("startinsert", cmd)
        end
        assert.are.equal(2, vim.api.nvim_win_get_cursor(st.win)[2])
    end)

    it("does not re-enter insert once the prompt is closed", function()
        run_map("<leader>ca")
        press("<Esc>")
        assert.is_nil(cwd._state())
        assert.is_false(cwd._reenter_insert())
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

    describe("completion", function()
        local calls

        before_each(function()
            calls = {}
            package.loaded["fzf-lua"] = {
                fzf_exec = function(items, opts) calls[#calls + 1] = { items = items, opts = opts } end,
            }
        end)

        after_each(function() package.loaded["fzf-lua"] = nil end)

        local function open_with(text)
            run_map("<leader>ca")
            local st = set_prompt_line(text)
            vim.api.nvim_win_set_cursor(st.win, { 1, #text })
            return st
        end

        local function accept(name)
            name = name or calls[#calls].items[1]
            local before = prompt_line()
            calls[#calls].opts.actions["default"]({ name })
            vim.wait(200, function() return prompt_line() ~= before end)
            return name
        end
        it("opens a picker of the subdirectories on <Tab>", function()
            open_with("/usr/")
            press("<Tab>")
            assert.are.equal(1, #calls)
            assert.is_true(vim.tbl_contains(calls[1].items, "local"))
            for _, name in ipairs(calls[1].items) do
                assert.are.equal(1, vim.fn.isdirectory("/usr/" .. name))
            end
        end)

        it("seeds the query with the partial component", function()
            open_with("/usr/lo")
            press("<Tab>")
            assert.are.equal("lo", calls[1].opts.query)
            assert.are.equal(" /usr/lo ", calls[1].opts.header)
        end)

        it("opens the whole level for an empty component", function()
            open_with("~/")
            press("<Tab>")
            assert.are.equal("", calls[1].opts.query)
            assert.is_true(#calls[1].items > 0)
        end)

        it("resolves a relative base against the current directory", function()
            open_with("lua/")
            press("<Tab>")
            assert.is_true(vim.tbl_contains(calls[1].items, "ytret"))
        end)

        it("inserts the choice and leaves the cursor after the slash", function()
            open_with("/usr/")
            press("<Tab>")
            accept("local")
            assert.are.equal("/usr/local/", prompt_line())
            assert.are.equal(#"/usr/local/", vim.api.nvim_win_get_cursor(cwd._state().win)[2])
        end)

        it("replaces only the component under the cursor", function()
            open_with("/usr/lo/locale")
            vim.api.nvim_win_set_cursor(cwd._state().win, { 1, #"/usr/lo" })
            press("<Tab>")
            assert.are.equal("lo", calls[1].opts.query)
            assert.are.equal(" /usr/lo/locale ", calls[1].opts.header)
            accept("local")
            assert.are.equal("/usr/local/locale", prompt_line())
        end)

        it("keeps the prompt open and reports a bad base dir", function()
            open_with("/no/such/dir/x")
            press("<Tab>")
            assert.are.equal(0, #calls)
            local cfg = vim.api.nvim_win_get_config(cwd._state().win)
            assert.is_truthy(cfg.footer[1][1]:match("No such directory"))
        end)

        it("reports an empty level without opening a picker", function()
            local empty = vim.fn.tempname()
            vim.fn.mkdir(empty, "p")
            open_with(empty .. "/")
            press("<Tab>")
            assert.are.equal(0, #calls)
            local cfg = vim.api.nvim_win_get_config(cwd._state().win)
            assert.is_truthy(cfg.footer[1][1]:match("No subdirectories"))
            vim.fn.delete(empty, "rf")
        end)

        it("docks the picker under the prompt, same width and left edge", function()
            open_with("/usr/")
            local cfg = vim.api.nvim_win_get_config(cwd._state().win)
            press("<Tab>")
            local winopts = calls[1].opts.winopts
            assert.is_false(winopts.fullscreen)
            assert.is_false(winopts.backdrop)
            assert.are.equal(cfg.width + 2, winopts.width)
            assert.are.equal(cfg.col, winopts.col)
            assert.are.equal(cfg.row + 2, winopts.row)
        end)

        it("sizes the picker to 16 rows", function()
            vim.o.lines = 60
            open_with("/usr/")
            press("<Tab>")
            assert.are.equal(16 + 2, calls[1].opts.winopts.height)
        end)

        it("shrinks the picker when the terminal is short", function()
            open_with("/usr/")
            local st = cwd._state()
            st.cfg.row = vim.o.lines - 8
            press("<Tab>")
            local winopts = calls[1].opts.winopts
            assert.is_true(winopts.height < 16 + 2)
            assert.is_true(winopts.row + winopts.height <= vim.o.lines)
        end)

        it("never runs the picker off the bottom of the screen", function()
            open_with("/usr/")
            local st = cwd._state()
            st.cfg.row = vim.o.lines - 2
            press("<Tab>")
            local winopts = calls[1].opts.winopts
            assert.is_true(winopts.row + winopts.height <= vim.o.lines)
        end)

        it("shows the whole path in the header", function()
            open_with("/usr/lo")
            press("<Tab>")
            assert.are.equal(" /usr/lo ", calls[1].opts.header)
        end)

        it("binds <Tab> in the prompt", function()
            run_map("<leader>ca")
            assert.is_function(prompt_map("<Tab>"))
        end)
    end)
end)
