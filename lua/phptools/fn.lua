local M = {}

local api = vim.api
local ts = vim.treesitter

local function get_node_at_cursor()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  return ts.get_node({
    bufnr = 0,
    pos = { row - 1, col },
  })
end

local function find_parent_function_node(node)
  while node do
    local type = node:type()
    if type == "arrow_function" or type == "anonymous_function" then
      return node
    end
    node = node:parent()
  end
end

local function replace_buffer_region(bufnr, start_row, end_row, new_text)
  local new_lines = vim.split(new_text, "\n")
  api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, new_lines)
end

local function transform_function(text, is_arrow)
  if is_arrow then
    return text:gsub("fn%s*(%b())%s*=>%s*(.+)", function(params, body)
      return string.format("function%s {\n    return %s;\n};", params, body:gsub(";*$", ""))
    end)
  end
  return text:gsub("function%s*(%b())%s*{%s*return%s*(.+);%s*}%s*;", "fn%1 => %2;")
end

local function transform_if_ternary(text)
  local if_pattern = "if%s*(%b())%s*{%s*return%s*(.-)%s*;?%s*}%s*else%s*{%s*return%s*(.-)%s*;?%s*}"
  local ternary_pattern = "return%s*(.-)%s*%?%s*(.-)%s*:%s*(.-)%s*;"

  if text:match(if_pattern) then
    return text:gsub(if_pattern, function(condition, true_val, false_val)
      return string.format("return %s ? %s : %s;", condition:sub(2, -2), true_val, false_val)
    end)
  end

  if text:match(ternary_pattern) then
    return text:gsub(ternary_pattern, function(condition, true_val, false_val)
      return string.format("if (%s) {\n    return %s;\n} else {\n    return %s;\n}", condition, true_val, false_val)
    end)
  end
  return text
end

local function transform_if_match(text)
  local if_pattern =
    "if%s*%((.-)%s*==%s*(.-)%)%s*{%s*return%s*(.-)%s*;%s*}%s*elseif%s*%((.-)%s*==%s*(.-)%)%s*{%s*return%s*(.-)%s*;%s*}"
  local match_pattern = "match%s*%((.-)%)%s*{%s*(.-)%s*=>%s*(.-),%s*(.-)%s*=>%s*(.-)%s*}"

  if text:match(if_pattern) then
    return text:gsub(if_pattern, function(var1, val1, body1, var2, val2, body2)
      return string.format(
        "match (%s) {\n    %s => %s,\n    %s => %s\n};",
        var1,
        val1,
        body1:gsub('"', "'"),
        val2,
        body2:gsub('"', "'")
      )
    end)
  end

  if text:match(match_pattern) then
    return text:gsub(match_pattern, function(var, val1, body1, val2, body2)
      return string.format(
        "if (%s == %s) {\n    return %s;\n} elseif (%s == %s) {\n    return %s;\n}",
        var,
        val1,
        body1,
        var,
        val2,
        body2
      )
    end)
  end
  return text
end

function M.toggle_function()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local function_node = find_parent_function_node(node)
  if not function_node then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local start_row, _, end_row, _ = function_node:range()
  local text = table.concat(api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false), "\n")

  local new_text = transform_function(text, function_node:type() == "arrow_function")
  if new_text ~= text then
    replace_buffer_region(bufnr, start_row, end_row, new_text)
  end
end

function M.toggle_if_ternary()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local start_row, _, end_row, _ = node:range()
  local text = table.concat(api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false), "\n")

  local new_text = transform_if_ternary(text)
  if new_text ~= text then
    replace_buffer_region(bufnr, start_row, end_row, new_text)
  end
end

function M.toggle_if_match()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local start_row, _, end_row, _ = node:range()
  local text = table.concat(api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false), "\n")

  local new_text = transform_if_match(text)
  if new_text ~= text then
    replace_buffer_region(bufnr, start_row, end_row, new_text)
  end
end

function M.toggle_quotes()
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  local start_pos = col
  while start_pos > 0 do
    local char = line:sub(start_pos, start_pos)
    if char == '"' or char == "'" then
      break
    end
    start_pos = start_pos - 1
  end

  local end_pos = col + 1
  while end_pos <= #line do
    local char = line:sub(end_pos, end_pos)
    if char == '"' or char == "'" then
      break
    end
    end_pos = end_pos + 1
  end

  local quote_start = line:sub(start_pos, start_pos)
  local quote_end = line:sub(end_pos, end_pos)

  -- Only toggle if quotes match
  if quote_start == quote_end then
    local new_quote = quote_start == '"' and "'" or '"'
    local new_line = line:sub(1, start_pos - 1)
      .. new_quote
      .. line:sub(start_pos + 1, end_pos - 1)
      .. new_quote
      .. line:sub(end_pos + 1)

    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { row, col })
  end
end

return M
