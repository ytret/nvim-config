local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;"
    .. cwd .. "/plugins/yt-window-picker/lua/?.lua;"
    .. cwd .. "/plugins/yt-window-picker/lua/?/init.lua;"
    .. package.path
