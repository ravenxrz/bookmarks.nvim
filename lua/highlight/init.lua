-- 定义模块
local M = {}

-- 插件配置
local config = {
  file_path = vim.fn.stdpath("data") .. "/bookmarks.json",
  highlight_group = "BookmarkLine",
}

-- 书签数据
local bookmarks = {}
local namespace_id = nil

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
      end_line = line_number - 1,
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
  local encoded = vim.json.encode(bookmarks)
  local file = io.open(config.file_path, "w")
  if not file then
    return
  end

  file:write(encoded)
  file:close()
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

  bookmarks = decoded

  -- 加载书签后应用高亮
  for buf_name, bookmarked_lines in pairs(bookmarks) do
    local bufnr = vim.fn.bufnr(buf_name)
    if bufnr > 0 then
      for _, line in ipairs(bookmarked_lines) do
        apply_highlight(bufnr, line)
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

  local index = nil
  for i, line in ipairs(bookmarked_lines) do
    if line == line_number then
      index = i
      break
    end
  end

  if index then
    -- 移除书签
    table.remove(bookmarked_lines, index)
    clear_highlight(bufnr, line_number)
  else
    -- 添加书签
    table.insert(bookmarked_lines, line_number)
    apply_highlight(bufnr, line_number)
  end

  -- 同步 bookmarks 数据
  bookmarks[buf_name] = bookmarked_lines

  save_bookmarks()
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
        for _, line in ipairs(bookmarked_lines) do
          local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
          table.insert(entries, {
            value = buf_name .. ":" .. line .. ": " .. line_content,
            bufnr = bufnr,
            line = line,
            filename = buf_name,
            display = string.format("%s:%s: %s", buf_name, line, line_content),
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
        }
      end,
    }),
    sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
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

local function create_ns()
  namespace_id = vim.api.nvim_create_namespace("ravenxrz_bookmarks")
end

-- 设置高亮
local function setup_highlight()
  vim.api.nvim_set_hl(0, config.highlight_group, { bg = "#458588" })
end

-- 设置自动命令
local function setup_autocommands()
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(event)
      local bufnr = event.buf
      local buf_name = get_buf_name(bufnr)
      if bookmarks[buf_name] then
        for _, line in ipairs(bookmarks[buf_name]) do
          apply_highlight(bufnr, line)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      save_bookmarks()
    end,
  })
end

-- Setup 函数
local function setup()
  create_ns()
  setup_highlight()
  setup_autocommands()
  load_bookmarks()
end

-- 清除当前 buffer 书签的函数
local function clear_current_buffer_bookmarks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buf_name = get_buf_name(bufnr)

  if bookmarks[buf_name] then
    -- 清除高亮
    for _, line_number in ipairs(bookmarks[buf_name]) do
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
      for _, line_number in ipairs(bookmarked_lines) do
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


M.toggle_bookmark = toggle_bookmark
M.list_current_buffer_bookmarks = list_current_buffer_bookmarks
M.list_all_buffer_bookmarks = list_all_bookmarks
M.clear_current_buffer_bookmarks = clear_current_buffer_bookmarks
M.clear_all_bookmarks = clear_all_bookmarks
M.setup = setup

return M
