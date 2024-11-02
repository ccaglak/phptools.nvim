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

local function transform_if_ternary(text)
  -- Convert if to ternary
  if text:match("if%s*%(.-%)%s*{.-}%s*else%s*{.-}") then
    return text:gsub("if%s*(%b())%s*{%s*return%s*(.-)%s*;?%s*}%s*else%s*{%s*return%s*(.-)%s*;?%s*}",
      function(condition, true_val, false_val)
        return string.format("return %s ? %s : %s;", condition:sub(2, -2), true_val, false_val)
      end)
  end

  -- Convert ternary to if
  if text:match("return.-%.-%?.-:.-;") then
    return text:gsub("return%s*(.-)%s*%?%s*(.-)%s*:%s*(.-)%s*;", function(condition, true_val, false_val)
      return string.format("if (%s) {\n    return %s;\n} else {\n    return %s;\n}", condition, true_val, false_val)
    end)
  end
  return text
end

function M.toggle_if_ternary()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  local text = table.concat(lines, "\n")

  local new_text = transform_if_ternary(text)
  if new_text and new_text ~= text then
    local new_lines = vim.split(new_text, "\n")
    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, new_lines)
  end
end

local function transform_if_match(text)
  -- Convert if/elseif to match
  if text:match("if%s*%(.-%)%s*{.-}%s*elseif%s*%(.-%)%s*{.-}") then
    return text:gsub("if%s*%((.-)%s*==%s*(.-)%)%s*{%s*(.-)%s*}%s*elseif%s*%((.-)%s*==%s*(.-)%)%s*{%s*(.-)%s*}",
      function(var1, val1, body1, var2, val2, body2)
        return string.format("match (%s) {\n    %s => %s,\n    %s => %s,\n};",
          var1, val1, body1, val2, body2)
      end)
  end

  -- Convert match to if/elseif
  if text:match("match%s*%(.-%)%s*{.-}") then
    return text:gsub("match%s*%((.-)%)%s*{%s*(.-)%s*=>%s*(.-),%s*(.-)%s*=>%s*(.-),%s*}",
      function(var, val1, body1, val2, body2)
        return string.format("if (%s == %s) {\n    %s\n} elseif (%s == %s) {\n    %s\n}",
          var, val1, body1, var, val2, body2)
      end)
  end
  return text
end

function M.toggle_if_match()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  local text = table.concat(lines, "\n")

  local new_text = transform_if_match(text)
  if new_text and new_text ~= text then
    local new_lines = vim.split(new_text, "\n")
    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, new_lines)
  end
end

return M
