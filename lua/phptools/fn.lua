local M = {}

local function get_node_at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return vim.treesitter.get_node({
    bufnr = 0,
    pos = { row - 1, col },
  })
end

local function find_parent_node(node)
  local function_types = {
    arrow_function = true,
    anonymous_function = true,
  }

  while node do
    if function_types[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

local function transform_function(text, is_arrow)
  if is_arrow then
    return text:gsub("fn%s*(%b())%s*=>%s*(.+)", "function%1 {\n    return %2;\n}")
  end
  return text:gsub("function%s*(%b())%s*{%s*return%s*(.+);%s*}", function(params, body)
    return string.format("fn%s => %s", params, body:gsub(";%s*$", ""))
  end)
end

function M.toggle_function()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local function_node = find_parent_node(node)
  if not function_node then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = function_node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  local text = table.concat(lines, "\n")

  local is_arrow = function_node:type() == "arrow_function"
  local new_text = transform_function(text, is_arrow)

  if new_text and new_text ~= text then
    local new_lines = vim.split(new_text, "\n")
    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, new_lines)
  end
end

return M
