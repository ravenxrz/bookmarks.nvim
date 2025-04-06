-- 定义模块
local M = {}

-- 插件配置
local config = {
  file_path = vim.fn.stdpath("data") .. "/bookmarks.json",
  highlight_group = "BookmarkLine",
  interval = 2
}

-- 书签数据
local bookmarks = {}
local namespace_id = vim.api.nvim_create_namespace("ravenxrz_bookmarks")
local attached_buffers = {}
local bookmarks_modified = false
local timer


-- 获取 buffer 名称
local function get_buf_name(bufnr)
  return vim.api.nvim_buf_get_name(bufnr)
end

-- 应用高亮
local function apply_highlight(bufnr, line_number)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)
  local line = lines[1]
  local line_length = string.len(line)
  vim.api.nvim_buf_set_extmark(
    bufnr,
    namespace_id,
    line_number - 1,
    0,
    {
      end_row = line_number - 1,
      end_col = line_length, -- 行尾
      hl_group = config.highlight_group,
    }
  )
end

-- 清除高亮
local function clear_highlight(bufnr, line_number)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, line_number - 1, line_number)
end

-- 保存书签
local function save_bookmarks()
  if not bookmarks_modified then
    return
  end
  -- 转换 bookmarks 为可编码的数据结构
  local encoded_bookmarks = {}
  for buf_name, bookmarked_lines in pairs(bookmarks) do
    local encoded_lines = {}
    for line_number, _ in pairs(bookmarked_lines) do
      table.insert(encoded_lines, line_number)
    end
    encoded_bookmarks[buf_name] = encoded_lines
  end

  local encoded = vim.json.encode(encoded_bookmarks)
  local file = io.open(config.file_path, "w")
  if not file then
    return
  end

  file:write(encoded)
  file:close()

  bookmarks_modified = false
end

-- 加载书签
local function load_bookmarks()
  local file = io.open(config.file_path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  if not content or content == "" then
    return
  end

  local decoded = vim.json.decode(content)
  if not decoded then
    return
  end

  -- 转换回 bookmarks 当前格式
  bookmarks = {}
  for buf_name, encoded_lines in pairs(decoded) do
    local bookmarked_lines = {}
    for _, line_number in ipairs(encoded_lines) do
      bookmarked_lines[line_number] = true
    end
    bookmarks[buf_name] = bookmarked_lines
  end

  -- 加载书签后应用高亮
  for buf_name, bookmarked_lines in pairs(bookmarks) do
    local bufnr = vim.fn.bufnr(buf_name)
    if bufnr > 0 then
      for line_number, _ in pairs(bookmarked_lines) do
        apply_highlight(bufnr, line_number)
      end
    end
  end
end

-- 切换书签
local function toggle_bookmark()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_name = get_buf_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_number = cursor[1]

  -- 获取当前行内容
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)
  local line = lines[1]
  local line_length = string.len(line)

  -- 如果是空行，则不添加书签
  if line_length == 0 then
    return
  end

  bookmarks[buf_name] = bookmarks[buf_name] or {}
  local bookmarked_lines = bookmarks[buf_name]

  if bookmarked_lines[line_number] then
    -- 移除书签
    bookmarked_lines[line_number] = nil
    clear_highlight(bufnr, line_number)
  else
    -- 添加书签
    bookmarked_lines[line_number] = true
    apply_highlight(bufnr, line_number)
  end

  -- 同步 bookmarks 数据
  bookmarks[buf_name] = bookmarked_lines

  bookmarks_modified = true
end

-- 来查找项目根目录
local function find_project_root(start_dir)
  local current_dir = start_dir
  while true do
    local git_dir = current_dir .. "/.git"
    local file = io.open(git_dir, "r")
    if file then
      file:close()
      return current_dir
    end
    local parent_dir = current_dir:match("^(.*)/[^/]+$")
    if not parent_dir or parent_dir == current_dir then
      break
    end
    current_dir = parent_dir
  end
  return nil
end

-- 获取相对于项目根目录的路径
local function get_relative_path(file_path)
  -- 获取当前文件所在目录
  local current_dir = vim.fn.expand("%:p:h")
  -- 查找项目根目录
  local project_root = find_project_root(current_dir)
  if project_root then
    -- 获取当前系统的路径分隔符
    local sep = package.config:sub(1, 1)
    -- 确保项目根目录以路径分隔符结尾
    if not project_root:match(sep .. "$") then
      project_root = project_root .. sep
    end
    -- 计算相对路径
    local pattern = "^" .. project_root:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local relative_path = file_path:gsub(pattern, "")
    return relative_path
  end
  return file_path
end

-- 列出书签 (Telescope)
local function list_bookmarks_telescope(all_buffers)
  local entries = {}

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_buf_name = get_buf_name(current_bufnr)

  for buf_name, bookmarked_lines in pairs(bookmarks) do
    if all_buffers or buf_name == current_buf_name then
      local bufnr = vim.fn.bufnr(buf_name)
      if bufnr > 0 then
        for line_number, _ in pairs(bookmarked_lines) do
          table.insert(entries, {
            value = buf_name .. ":" .. line_number,
            bufnr = bufnr,
            line = line_number,
            filename = buf_name,
            -- 只显示文件路径和行号
            display = string.format("%s:%s", get_relative_path(buf_name), line_number),
          })
        end
      end
    end
  end

  require("telescope.pickers").new({}, {
    prompt_title = "Bookmarks",
    finder = require("telescope.finders").new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          display = entry.display,
          ordinal = entry.value,
          -- 为预览提供必要信息
          filename = entry.filename,
          lnum = entry.line,
        }
      end,
    }),
    sorter = require("telescope.sorters").get_fuzzy_file(),
    previewer = require("telescope.previewers").vim_buffer_vimgrep.new({
      title = "Bookmark Preview",
      use_ft_detect = true,
      filesize_limit = 20, -- 预览文件大小限制（MB）
    }),
    attach_mappings = function(prompt_bufnr, map)
      map("n", "<CR>", function()
        local selection = require("telescope.actions.state").get_selected_entry()
        if selection then
          vim.api.nvim_win_focus(vim.api.nvim_get_current_win(), false)
          vim.api.nvim_buf_set_current(selection.bufnr)
          vim.api.nvim_win_set_cursor(0, { selection.line, 0 })
        end
        require("telescope").close(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

-- 设置高亮
local function setup_highlight()
  vim.api.nvim_set_hl(0, config.highlight_group, { bg = "#98FB98" }) -- 淡绿色
end

-- 更新书签行号
local function update_bookmark_lines(bufnr, start_line, delta)
  local buf_name = get_buf_name(bufnr)
  local bookmarked_lines = bookmarks[buf_name]
  if not bookmarked_lines then
    return
  end

  local new_bookmarked_lines = {}
  if delta < 0 then
    -- 处理删除行的情况
    for line_number, _ in pairs(bookmarked_lines) do
      if line_number >= start_line and line_number < start_line - delta then
        -- 删除的行包含书签，从 bookmarks 中移除
        bookmarked_lines[line_number] = nil
        bookmarks_modified = true
      elseif line_number >= start_line - delta then
        new_bookmarked_lines[line_number + delta] = true
        bookmarks_modified = true
      else
        new_bookmarked_lines[line_number] = true
      end
    end
  else
    -- 处理插入行的情况
    for line_number, _ in pairs(bookmarked_lines) do
      if line_number >= start_line then
        new_bookmarked_lines[line_number + delta] = true
        bookmarks_modified = true
      else
        new_bookmarked_lines[line_number] = true
      end
    end
  end

  bookmarks[buf_name] = new_bookmarked_lines
end


-- 附加缓冲区监听
local function attach_buffer(bufnr)
  if attached_buffers[bufnr] then
    return
  end

  local opts = {
    on_lines = function(_, _, _, first_line, last_line, new_last_line)
      local old_count = last_line - first_line
      local new_count = new_last_line - first_line
      local delta = new_count - old_count
      if delta == 0 then
        return
      end
      update_bookmark_lines(bufnr, first_line + 1, delta)
    end,
    on_bytes = function(...) end,       -- 可选：处理字节变化
    on_changedtick = function(...) end, -- 可选：处理 changedtick 变化
    on_detach = function(...) end,      -- 可选：处理分离
  }

  vim.api.nvim_buf_attach(bufnr, false, opts)
  attached_buffers[bufnr] = true
end


-- Setup 函数中添加
local function setup_timer()
  timer = vim.loop.new_timer()
  timer:start(
    config.interval * 1000,
    config.interval * 1000,
    vim.schedule_wrap(save_bookmarks)
  )
end

local function unload_timer()
  if timer then
    timer:stop()
    timer:close()
  end
end


-- 设置自动命令
local function setup_autocommands()
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(event)
      local bufnr = event.buf
      local buf_name = get_buf_name(bufnr)
      if bookmarks[buf_name] then
        for line_number, _ in pairs(bookmarks[buf_name]) do
          apply_highlight(bufnr, line_number)
        end
      end
      attach_buffer(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("BookmarkPluginCleanup", { clear = true }),
    callback = function()
      save_bookmarks()
      unload_timer()
    end,
  })
end

-- Setup 函数
local function setup()
  setup_highlight()
  setup_autocommands()
  load_bookmarks()
  setup_timer()
end

-- 清除当前 buffer 书签的函数
local function clear_current_buffer_bookmarks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buf_name = get_buf_name(bufnr)

  if bookmarks[buf_name] then
    -- 清除高亮
    for line_number, _ in pairs(bookmarks[buf_name]) do
      clear_highlight(bufnr, line_number)
    end

    -- 清除书签数据
    bookmarks[buf_name] = {}
    save_bookmarks()
  end
end

-- 清除所有 buffer 书签的函数
local function clear_all_bookmarks()
  for buf_name, bookmarked_lines in pairs(bookmarks) do
    local bufnr = vim.fn.bufnr(buf_name)
    if bufnr ~= -1 then
      -- 清除高亮
      for line_number, _ in pairs(bookmarked_lines) do
        clear_highlight(bufnr, line_number)
      end
    end
  end

  -- 清除书签数据
  bookmarks = {}
  save_bookmarks()
end

local function list_current_buffer_bookmarks()
  list_bookmarks_telescope(false)
end

local function list_all_bookmarks()
  list_bookmarks_telescope(true)
end

-- 跳转到下一个书签
local function goto_next_bookmark()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_name = get_buf_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  local bookmarked_lines = bookmarks[buf_name]
  if not bookmarked_lines then
    return
  end

  local next_line = math.huge
  for line_number, _ in pairs(bookmarked_lines) do
    if line_number > current_line and line_number < next_line then
      next_line = line_number
    end
  end

  if next_line ~= math.huge then
    vim.api.nvim_win_set_cursor(0, { next_line, 0 })
  end
end

-- 跳转到上一个书签
local function goto_prev_bookmark()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_name = get_buf_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  local bookmarked_lines = bookmarks[buf_name]
  if not bookmarked_lines then
    return
  end

  local prev_line = -math.huge
  for line_number, _ in pairs(bookmarked_lines) do
    if line_number < current_line and line_number > prev_line then
      prev_line = line_number
    end
  end

  if prev_line ~= -math.huge then
    vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
  end
end

M.toggle_bookmark = toggle_bookmark
M.list_current_buffer_bookmarks = list_current_buffer_bookmarks
M.list_all_buffer_bookmarks = list_all_bookmarks
M.clear_current_buffer_bookmarks = clear_current_buffer_bookmarks
M.clear_all_bookmarks = clear_all_bookmarks
M.goto_next_bookmark = goto_next_bookmark
M.goto_prev_bookmark = goto_prev_bookmark
M.setup = setup

return M
