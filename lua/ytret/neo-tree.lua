local M = {}

local tabs = require("ytret.tabs")
local window_picker = require("yt-window-picker")

-- Count normal (non-floating) windows in the current tabpage.
local function count_normal_windows()
    local count = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == "" then
            count = count + 1
        end
    end
    return count
end

-- Open a file node, using the window picker when there are multiple windows.
-- Mirrors nvim-tree's built-in behavior: <cr> on a file picks A/B/C if needed.
-- Closes the floating neo-tree window during the pick so it doesn't obstruct labels.
local function open_with_possible_picker(state)
    local node = state.tree:get_node()
    if not node or node.type ~= "file" then
        return
    end
    local path = node:get_id()
    if not path then
        return
    end

    if count_normal_windows() <= 1 then
        vim.cmd.edit(vim.fn.fnameescape(path))
    else
        vim.cmd("Neotree close")
        local win = window_picker.pick_window()
        if win then
            vim.api.nvim_set_current_win(win)
            vim.cmd.edit(vim.fn.fnameescape(path))
        else
            vim.cmd("Neotree filesystem toggle float")
        end
    end
end

-- Always use the window picker when opening a file.
-- Closes the floating neo-tree window during the pick so it doesn't obstruct labels.
local function open_with_picker(state)
    local node = state.tree:get_node()
    if not node or node.type ~= "file" then
        return
    end
    local path = node:get_id()
    if not path then
        return
    end

    vim.cmd("Neotree close")
    local win = window_picker.pick_window()
    if win then
        vim.api.nvim_set_current_win(win)
        vim.cmd.edit(vim.fn.fnameescape(path))
    else
        vim.cmd("Neotree filesystem toggle float")
    end
end

---@param state neotree.State
local function open_in_picked_tab(state)
    local tree = state.tree
    local node = tree:get_node()
    if not node then
        return
    end

    -- Directories: toggle expand/collapse
    if node.type == "directory" then
        local cc = require("neo-tree.sources.common.commands")
        cc.toggle_node(state, node)
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
        -- use_default_mappings = false, -- we define mappings explicitly below

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
                --[[
                mappings = {
                    ["<C-t>"] = function(state) open_in_picked_tab(state) end,
                    ["<Tab>"] = "select",
                    ["<C-;>"] = "clear_selection",
                    ["<space>"] = { "toggle_node", nowait = false },
                    ["<2-LeftMouse>"] = "open",
                    ["<cr>"] = open_with_possible_picker,
                    ["<esc>"] = "cancel",
                    ["P"] = { "toggle_preview", config = { use_float = true } },
                    ["<C-f>"] = { "scroll_preview", config = { direction = -10 } },
                    ["<C-b>"] = { "scroll_preview", config = { direction = 10 } },
                    ["l"] = "focus_preview",
                    ["S"] = "open_split",
                    ["s"] = "open_vsplit",
                    ["t"] = "open_tabnew",
                    ["w"] = open_with_picker,
                    ["C"] = "close_node",
                    ["z"] = "close_all_nodes",
                    ["R"] = "refresh",
                    ["a"] = { "add", config = { show_path = "none" } },
                    ["A"] = "add_directory",
                    ["d"] = "delete",
                    ["T"] = "trash",
                    ["u"] = "undo",
                    ["U"] = "restore_from_trash",
                    ["r"] = "rename",
                    ["y"] = "copy_to_clipboard",
                    ["x"] = "cut_to_clipboard",
                    ["p"] = "paste_from_clipboard",
                    ["<C-r>"] = "clear_clipboard",
                    ["c"] = "copy",
                    ["m"] = "move",
                    ["e"] = "toggle_auto_expand_width",
                    ["q"] = "close_window",
                    ["?"] = "show_help",
                    ["<"] = "prev_source",
                    [">"] = "next_source",
                    ["H"] = "toggle_hidden",
                    ["/"] = "fuzzy_finder",
                    ["D"] = "fuzzy_finder_directory",
                    ["#"] = "fuzzy_sorter",
                    ["f"] = "filter_on_submit",
                    ["<C-x>"] = "clear_filter",
                    ["<bs>"] = "navigate_up",
                    ["."] = "set_root",
                    ["[g"] = "prev_git_modified",
                    ["]g"] = "next_git_modified",
                    ["i"] = "show_file_details",
                    ["b"] = "rename_basename",
                    ["o"] = {
                        "show_help",
                        nowait = false,
                        config = { title = "Order by", prefix_key = "o" },
                    },
                    ["oc"] = { "order_by_created", nowait = false },
                    ["od"] = { "order_by_diagnostics", nowait = false },
                    ["og"] = { "order_by_git_status", nowait = false },
                    ["om"] = { "order_by_modified", nowait = false },
                    ["on"] = { "order_by_name", nowait = false },
                    ["os"] = { "order_by_size", nowait = false },
                    ["ot"] = { "order_by_type", nowait = false },
                },
                --]]
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

