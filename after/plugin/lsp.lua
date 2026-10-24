local window_picker = require("yt-window-picker")
local yt_path = require("ytret.path")

local function other_or_new_win()
    local wins = vim.tbl_filter(function(win)
        local config = vim.api.nvim_win_get_config(win)
        return config.relative == ""
            and config.focusable
            and not config.hide
            and not config.external
    end, vim.api.nvim_tabpage_list_wins(0))

    if #wins == 1 then
        vim.cmd("vsplit")
        wins = vim.tbl_filter(function(win)
            local config = vim.api.nvim_win_get_config(win)
            return config.relative == ""
                and config.focusable
                and not config.hide
                and not config.external
        end, vim.api.nvim_tabpage_list_wins(0))
    end

    if #wins > 2 then
        return window_picker.pick_window()
    end

    local curr_win = vim.api.nvim_tabpage_get_win(0)
    local target_win = nil
    for _, win in ipairs(wins) do
        if win ~= curr_win then
            target_win = win
        end
    end

    assert(target_win ~= nil)
    return target_win
end

local function goto_tab(tabnr)
    local last_tabnr = vim.fn.tabpagenr("$")
    if tabnr < 1 or tabnr > last_tabnr then
        print(string.format("Tab %d does not exist", tabnr))
        return false
    end

    vim.cmd.tabnext(string.format("%d", tabnr))
    return true
end

local function def_in_target(open_target)
    local curr_pos = vim.lsp.util.make_position_params(0, "utf-8")
    local handler = function(err, result, _)
        if err then
            print(err)
            return
        end
        if result == nil then
            print("No definitions found")
            return
        end

        local def = result
        if vim.islist(result) then
            if #result == 0 then
                print("No definitions found")
                return
            end
            def = result[1]
        end

        local def_uri = def.uri or def.targetUri
        local def_range = def.targetSelectionRange or def.range or def.targetRange
        if def_uri == nil or def_range == nil then
            print("Definition result has unsupported shape")
            return
        end

        -- Push current position onto the jumplist before doing anything
        vim.cmd("normal! m'")

        local target_win = open_target()
        if target_win == nil then
            return
        end

        vim.api.nvim_set_current_win(target_win)

        local def_path = vim.uri_to_fname(def_uri)
        local def_bufnr = yt_path.bufadd_prefer_rel(def_path)
        local def_row = def_range.start.line + 1
        local def_col = def_range.start.character

        -- If the target window already has the right buffer, just move the cursor.
        -- Otherwise set the buffer first, then push a jumplist entry in that new
        -- location so Ctrl-O lands on the definition (not some stale position).
        if vim.api.nvim_win_get_buf(target_win) ~= def_bufnr then
            if not yt_path.set_buf_listed(def_bufnr) then
                return
            end
        end

        vim.api.nvim_win_set_cursor(target_win, { def_row, def_col })
        vim.fn.feedkeys("zz")
    end
    vim.lsp.buf_request(0, "textDocument/definition", curr_pos, handler)
end

local function def_in_other_win() return def_in_target(other_or_new_win) end

local function def_in_tab(tabnr)
    return def_in_target(function()
        if not goto_tab(tabnr) then
            return nil
        end

        return vim.api.nvim_get_current_win()
    end)
end

local function def_in_new_tab()
    return def_in_target(function()
        vim.cmd.tabnew()
        return vim.api.nvim_get_current_win()
    end)
end

local function switch_src_hdr(oth_win)
    oth_win = oth_win or false

    local doc_id = vim.lsp.util.make_text_document_params()
    local handler = function(err, result, _)
        if err then
            print(err)
            return
        end
        if result == nil or result == "" then
            print("corresponding file cannot be determined")
            return
        end

        if oth_win then
            local target_win = other_or_new_win()
            vim.api.nvim_set_current_win(target_win)
        end

        local abs_path = vim.uri_to_fname(result)
        local target_bufnr = yt_path.bufadd_prefer_rel(abs_path)
        yt_path.set_buf_listed(target_bufnr)
    end

    vim.lsp.buf_request(0, "textDocument/switchSourceHeader", doc_id, handler)
end

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP actions",
    callback = function(args)
        local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
        local function opts(desc) return { buffer = args.buf, remap = false, desc = desc } end

        vim.keymap.set("n", "go", def_in_other_win, opts("Definition in another window"))
        vim.keymap.set("n", "gtn", def_in_new_tab, opts("Definition in new tab"))
        vim.keymap.set("n", "gto", def_in_new_tab, opts("Definition in new tab"))
        vim.keymap.set("n", "gt1", function() def_in_tab(1) end, opts("Definition in tab 1"))
        vim.keymap.set("n", "gt2", function() def_in_tab(2) end, opts("Definition in tab 2"))
        vim.keymap.set("n", "gt3", function() def_in_tab(3) end, opts("Definition in tab 3"))
        vim.keymap.set("n", "gt4", function() def_in_tab(4) end, opts("Definition in tab 4"))
        vim.keymap.set("n", "gt5", function() def_in_tab(5) end, opts("Definition in tab 5"))
        vim.keymap.set("n", "gt6", function() def_in_tab(6) end, opts("Definition in tab 6"))
        vim.keymap.set("n", "gt7", function() def_in_tab(7) end, opts("Definition in tab 7"))
        vim.keymap.set("n", "gt8", function() def_in_tab(8) end, opts("Definition in tab 8"))
        vim.keymap.set("n", "gt9", function() def_in_tab(9) end, opts("Definition in tab 9"))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover documentation"))
        vim.keymap.set(
            "n",
            "<leader>vd",
            vim.diagnostic.open_float,
            opts("Show diagnostic details")
        )
        vim.keymap.set(
            "n",
            "[d",
            function() vim.diagnostic.jump({ count = -1, float = true }) end,
            opts("Previous diagnostic")
        )
        vim.keymap.set(
            "n",
            "]d",
            function() vim.diagnostic.jump({ count = 1, float = true }) end,
            opts("Next diagnostic")
        )
        vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, opts("Code action"))
        vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts("Rename symbol"))
        vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts("Signature help"))

        if client.name == "clangd" then
            vim.keymap.set("n", "<leader>o", switch_src_hdr, opts("Switch source/header"))
            vim.keymap.set(
                "n",
                "<leader>O",
                function() switch_src_hdr(true) end,
                opts("Switch source/header in another window")
            )
        end
    end,
})

require("mason").setup({})
require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "pylsp",
    },
})

local query_drivers = {
    "/usr/bin/arm-none-eabi-gcc",
    "i686-elf-gcc",
    "/nix/**/i686-elf-gcc",
    "/nix/**/clang*",
    "/usr/bin/gcc",
    "/usr/bin/clang",
    "/home/omp.ru/y.tretyakov/dev/**/*gcc",
}

vim.lsp.config("clangd", {
    flags = {
        allow_incremental_sync = false,
    },
    cmd = {
        "/usr/bin/env",
        "clangd",
        "--query-driver=" .. table.concat(query_drivers, ","),
        "--header-insertion=never",
    },
})

vim.lsp.config("pylsp", {
    settings = {
        pylsp = {
            plugins = {
                flake8 = {
                    enabled = true,
                    maxLineLength = 100,
                },
                pycodestyle = {
                    enabled = false,
                },
                black = {
                    enabled = false,
                },
                pylsp_mypy = {
                    enabled = false,
                    live_mode = false,
                },
            },
        },
    },
})

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            format = {
                enable = false,
            },
        },
    },
})
