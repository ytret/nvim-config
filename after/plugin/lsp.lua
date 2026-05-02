local window_picker = require("yt-window-picker")

local function other_or_new_win()
    local wins = vim.tbl_filter(function(win)
        local config = vim.api.nvim_win_get_config(win)
        return config.relative == "" and config.focusable and not config.hide and not config.external
    end, vim.api.nvim_tabpage_list_wins(0))

    if #wins == 1 then
        vim.cmd("vsplit")
        wins = vim.tbl_filter(function(win)
            local config = vim.api.nvim_win_get_config(win)
            return config.relative == "" and config.focusable and not config.hide and not config.external
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

local function def_in_other_win()
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

        local target_win = other_or_new_win()
        if target_win == nil then
            return
        end

        vim.api.nvim_set_current_win(target_win)

        local def_bufnr = vim.uri_to_bufnr(def_uri)
        local def_row = def_range.start.line + 1
        local def_col = def_range.start.character

        -- If the target window already has the right buffer, just move the cursor.
        -- Otherwise set the buffer first, then push a jumplist entry in that new
        -- location so Ctrl-O lands on the definition (not some stale position).
        if vim.api.nvim_win_get_buf(target_win) ~= def_bufnr then
            vim.api.nvim_win_set_buf(target_win, def_bufnr)
        end

        vim.api.nvim_win_set_cursor(target_win, { def_row, def_col })
        vim.fn.feedkeys("zz")
    end
    vim.lsp.buf_request(0, "textDocument/definition", curr_pos, handler)
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
        local rel_path = vim.fs.relpath(vim.fn.getcwd(), abs_path)
        local target_bufnr
        if rel_path == nil then
            target_bufnr = vim.fn.bufadd(abs_path)
        else
            target_bufnr = vim.fn.bufadd(rel_path)
        end
        vim.api.nvim_set_current_buf(target_bufnr)
    end

    vim.lsp.buf_request(0, "textDocument/switchSourceHeader", doc_id, handler)
end

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP actions",
    callback = function(args)
        local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
        local opts = { buffer = args.buf, remap = false }

        vim.keymap.set("n", "go", def_in_other_win, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts)
        vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)

        if client.name == "clangd" then
            vim.keymap.set("n", "<leader>o", switch_src_hdr, opts)
            vim.keymap.set("n", "<leader>O", function() switch_src_hdr(true) end, opts)
        end
    end,
})

local cmp = require("cmp")
local cmp_select = { behavior = cmp.SelectBehavior.Select }
cmp.setup({
    snippet = {
        expand = function(args) require("luasnip").lsp_expand(args.body) end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),

        ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),

        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "nvim_lua" },
        { name = "luasnip" },
    }),
})

require("mason").setup({})
require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "pylsp",
    },
})

vim.lsp.config("clangd", {
    flags = {
        allow_incremental_sync = false,
    },
    cmd = {
        "/usr/bin/clangd",
        "--query-driver=/usr/bin/arm-none-eabi-gcc,i686-elf-gcc,/nix/**/i686-elf-gcc,/usr/bin/gcc,/usr/bin/clang",
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
