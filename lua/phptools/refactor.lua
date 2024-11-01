local ui = require("phptools").config.ui.enable

if ui then
  vim.ui.select = require("phptools.ui").select
end
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

local get_visual_selection = function()
  vim.cmd('noau normal! "vy"')
  local text = vim.fn.getreg("v")
  vim.fn.setreg("v", {})
  -- text = string.gsub(tostring(text), "\n", "") -- removes newlines
  if #text > 0 then
    return text
  else
    return ""
  end
end

local function smart_indent(code)
  local indent, indent_char = "    ", "\t"
  local indent_size = #indent_char == 1 and vim.bo.shiftwidth or #indent_char

  local buffer = {}
  for _, line in ipairs(vim.split(code, "\n", true)) do
    local line_indent = "    "
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
  local code = get_visual_selection()
  vim.schedule(function()
    vim.ui.select(structures, {
      prompt = "Select structure to surround with:",
    }, function(choice)
      if choice then
        if code ~= "" then
          local surrounded_code = surround_code(choice, code)

          if choice == "function" or choice == "method" then
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
