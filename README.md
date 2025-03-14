# 特性

> 初衷是想做一个用来高亮某些关键日志行，并且方便快速定位，但做着做着发现和书签很像，区别在于这个插件用高亮来标识一个书签而已。

bookmark插件，支持功能：

- 开关bookmark
- 持久化bookmark
- 跳转到上/下一个bookmark
- 支持查看buffer级别、全局别bookmark
- 清除buffer级别、全局别bookmark
- 支持telescope预览

提供接口(lua):

- `toggle_bookmark`
- `list_current_buffer_bookmarks`
- `list_all_buffer_bookmarks`
- `clear_current_buffer_bookmarks`
- `clear_all_bookmarks`
- `goto_next_bookmark`
- `goto_prev_bookmark`

# 高亮

高亮组：`BookmarkLine`，默认值为:

```lua
vim.api.nvim_set_hl(0, config.highlight_group, { bg = "#98FB98" }) -- 淡绿色
```

# 截图

<img src="https://ravenxrz-blog.oss-cn-chengdu.aliyuncs.com/img/oss_imgimage-20250314174003216.png" alt="image-20250314174003216" style="zoom:50%;" />



![image-20250314174049699](https://ravenxrz-blog.oss-cn-chengdu.aliyuncs.com/img/oss_imgimage-20250314174049699.png)

# 安装

lazy.nvim:

```lua
{
    "ravenxrz/bookmarks.nvim",
    config = true,
}
```

# keymap定制

```lua
local keymap = vim.keymap.set
keymap("n", "<leader>bb", function() require("bookmarks").toggle_bookmark() end, opts)
keymap("n", "<leader>bc", function() require("bookmarks").clear_current_buffer_bookmarks() end, opts)
keymap("n", "<leader>bC", function() require("bookmarks").clear_all_bookmarks() end, opts)
keymap("n", "<leader>bs", function() require("bookmarks").list_current_buffer_bookmarks() end, opts)
keymap("n", "<leader>bS", function() require("bookmarks").list_all_buffer_bookmarks() end, opts)
keymap("n", "]m", "<Nop>", opts)
keymap("n", "[m", "<Nop>", opts)
keymap("n", "]m", function() require("bookmarks").goto_next_bookmark() end, opts)
keymap("n", "[m", function() require("bookmarks").goto_prev_bookmark() end, opts)

```
