local M = {}

local templates = {
  ["if"] = "if (%s) {\n%s\n}",
  ["foreach"] = "foreach (%s as %s) {\n%s\n}",
  ["for"] = "for (%s; %s; %s) {\n%s\n}",
  ["while"] = "while (%s) {\n%s\n}",
  ["do_while"] = "do {\n%s\n} while (%s);",
  ["try_catch"] = "try {\n%s\n} catch (Exception $e) {\n%s\n}",
  ["function"] = "function %s(%s)\n{\n%s\n}",
  ["method"] = "public function %s(%s)\n{\n%s\n}",
}

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = end_pos[2], end_pos[3]

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then
    return ""
  end

  lines[1] = string.sub(lines[1], start_col)
  if #lines > 1 then
    lines[#lines] = string.sub(lines[#lines], 1, end_col - 1)
  else
    lines[1] = string.sub(lines[1], 1, end_col - start_col + 1)
  end

  return table.concat(lines, "\n")
end

local function get_indentation(line)
  local space_count = line:match("^( *)")
  local tab_count = line:match("^(\t*)")
  if #space_count > 0 then
    return space_count, string.rep(" ", #space_count)
  elseif #tab_count > 0 then
    return tab_count, "\t"
  else
    return "", "    " -- Default to 4 spaces if no indentation detected
  end
end

local function smart_indent(code)
  local first_line = vim.split(code, "\n", true)[1]
  local indent, indent_char = get_indentation(first_line)
  local indent_size = #indent_char == 1 and vim.bo.shiftwidth or #indent_char

  local buffer = {}
  for _, line in ipairs(vim.split(code, "\n", true)) do
    local line_indent = get_indentation(line)
    local new_indent = string.rep(indent_char, math.floor(#line_indent / indent_size))
    table.insert(buffer, indent .. new_indent .. line:gsub("^%s+", ""))
  end
  return table.concat(buffer, "\n")
end

local function surround_code(structure, code)
  local indented_code = smart_indent(code)
  local result

  if structure == "function" or structure == "method" then
    local func_name = vim.fn.input("Enter " .. structure .. " name: ")
    local params = vim.fn.input("Enter " .. structure .. " parameters: ")
    result = string.format(templates[structure], func_name, params, indented_code)
  elseif structure == "foreach" then
    local item_name = vim.fn.input("Enter item variable name: ")
    local items_name = vim.fn.input("Enter items array name: ")
    result = string.format(templates[structure], items_name, item_name, indented_code)
  elseif structure == "for" then
    local init = vim.fn.input("Enter initialization: ")
    local condition = vim.fn.input("Enter condition: ")
    local increment = vim.fn.input("Enter increment: ")
    result = string.format(templates[structure], init, condition, increment, indented_code)
  elseif structure == "do_while" then
    local condition = vim.fn.input("Enter condition: ")
    result = string.format(templates[structure], indented_code, condition)
  else
    local condition = vim.fn.input("Enter condition: ")
    result = string.format(templates[structure], condition, indented_code)
  end

  return result
end

function M.refactor()
  local structures = vim.tbl_keys(templates)

  vim.schedule(function()
    vim.ui.select(structures, {
      prompt = "Select structure to surround with:",
    }, function(choice)
      if choice then
        local code = get_visual_selection()
        if code ~= "" then
          local surrounded_code = surround_code(choice, code)

          if choice == "function" or choice == "method" then
            -- Add function to the end of the file
            vim.cmd([['<,'>delete]])
            local lines = vim.split(surrounded_code, "\n", true)
            local last_line = vim.api.nvim_buf_line_count(0)
            if choice == "method" then
              last_line = last_line - 1
            end
            vim.api.nvim_buf_set_lines(0, last_line, last_line, false, lines)

            -- Move cursor to the created function
            vim.api.nvim_win_set_cursor(0, { last_line + 1, 0 })
            vim.api.nvim_buf_call(0, function()
              vim.cmd("silent! write! | edit")
            end)
          else
            -- Existing logic for other structures
            local end_line = vim.fn.line("'>") - 1
            local end_col = math.min(vim.fn.col("'>"), #vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, true)[1])
            vim.api.nvim_buf_set_text(
              0,
              vim.fn.line("'<") - 1,
              vim.fn.col("'<") - 1,
              end_line,
              end_col,
              vim.split(surrounded_code, "\n", true)
            )
            vim.api.nvim_buf_call(0, function()
              vim.cmd("silent! write! | edit")
            end)
          end
        else
          vim.api.nvim_err_writeln("No text selected")
        end
      end
    end)
  end)
end

return M
