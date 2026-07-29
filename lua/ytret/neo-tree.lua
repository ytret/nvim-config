local M = {}

local tabs = require("ytret.tabs")

---@param state neotree.State
local function open_in_picked_tab(state)
    local tree = state.tree
    local node = tree:get_node()
    if not node then
        return
    end

    -- Directories: Ctrl-T does nothing — use <cr> or <space> to expand
    if node.type == "directory" then
        return
    end

    -- Files: open in a picked tab
    local path = node:get_id()
    if not path then
        return
    end

    tabs.open_in_picked_tab(function() vim.cmd.edit(vim.fn.fnameescape(path)) end)
end

function M.setup()
    require("neo-tree").setup({
        close_if_last_window = false,
        default_source = "filesystem",
        enable_git_status = true,
        enable_diagnostics = true,
        enable_modified_markers = true,
        enable_opened_markers = true,
        enable_refresh_on_write = true,
        git_status_async = true,
        hide_root_node = true,
        popup_border_style = "rounded",
        sort_case_insensitive = true,
        use_popups_for_input = true,

        window = {
            position = "float",
            popup = {
                size = {
                    width = "50%",
                    height = "80%",
                },
                position = "50%", -- centered
            },
        },

        filesystem = {
            bind_to_cwd = true,
            cwd_target = {
                sidebar = "tab",
                current = "window",
            },
            filtered_items = {
                visible = false,
                show_hidden_count = true,
                hide_dotfiles = false,
                hide_gitignored = true,
                hide_hidden = false,
                hide_by_name = {
                    ".DS_Store",
                    "thumbs.db",
                },
                never_show = {},
            },
            follow_current_file = {
                enabled = false,
                leave_dirs_open = false,
            },
            group_empty_dirs = false,
            hijack_netrw_behavior = "open_default",
            use_libuv_file_watcher = false,
            window = {
                mappings = {
                    ["<C-s>"] = "open_split",
                    ["<C-v>"] = "open_vsplit",
                    ["<C-t>"] = open_in_picked_tab,
                },
            },
        },

        -- Disable sources we don't use
        sources = { "filesystem" },

        default_component_configs = {
            indent = {
                indent_size = 2,
                padding = 1,
                with_markers = true,
                indent_marker = "│",
                last_indent_marker = "└",
            },
            icon = {
                folder_closed = "",
                folder_open = "",
                folder_empty = "󰉖",
                folder_empty_open = "󰷏",
            },
            git_status = {
                symbols = {
                    added = "✚",
                    deleted = "✖",
                    modified = "",
                    renamed = "󰁕",
                    untracked = "",
                    ignored = "",
                    unstaged = "󰄱",
                    staged = "",
                    conflict = "",
                },
                align = "right",
            },
            modified = {
                symbol = "[+] ",
                highlight = "NeoTreeModified",
            },
            name = {
                trailing_slash = false,
                highlight_opened_files = false,
                use_git_status_colors = true,
            },
        },

        source_selector = {
            winbar = false,
            statusline = false,
        },
    })
end

return M
