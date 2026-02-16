local utils = require("phptools.utils")

local M = {}

-- Reference to consolidated templates (kept for backward compatibility in tests)
M.templates = vim.tbl_extend("force", {}, utils.templates.control_structures, utils.templates.definitions)

function M.get_visual_selection()
  vim.cmd('noau normal! "vy"')
  local text = vim.fn.getreg("v")
  vim.fn.setreg("v", {})
  return text or ""
end

function M.smart_indent(code)
  if not code or #code == 0 then
    return ""
  end

  -- Get the proper indent character and size from buffer settings
  local indent_char = vim.bo.expandtab and "  " or "\t"
  local indent_size = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or 2
  local indent = string.rep(indent_char, indent_size)

  local buffer = {}
  for _, line in ipairs(vim.split(code, "\n", true)) do
    -- Skip empty lines
    if line:match("%S") then
      -- Remove leading whitespace and add new indent
      local trimmed = line:gsub("^%s+", "")
      table.insert(buffer, indent .. trimmed)
    else
      table.insert(buffer, "")
    end
  end
  return table.concat(buffer, "\n")
end

function M.surround_code(structure, code)
  if not structure or not M.templates[structure] then
    vim.notify("Invalid structure: " .. tostring(structure), vim.log.levels.ERROR)
    return nil
  end

  if not code or #code == 0 then
    vim.notify("No code selected", vim.log.levels.WARN)
    return nil
  end

  local indented_code = M.smart_indent(code)
  local result

  -- Helper to get and validate user input
  local function get_required_input(prompt)
    local value = vim.fn.input(prompt)
    if not value or #value == 0 then
      vim.notify("Cancelled: " .. prompt, vim.log.levels.WARN)
      return nil
    end
    return value
  end

  if structure == "function" or structure == "method" then
    local func_name = get_required_input("Enter " .. structure .. " name: ")
    if not func_name then return nil end
    local params = vim.fn.input("Enter " .. structure .. " parameters (optional): ")
    result = string.format(M.templates[structure], func_name, params or "", indented_code)
  elseif structure == "foreach" then
    local items_name = get_required_input("Enter items array name: ")
    if not items_name then return nil end
    local item_name = get_required_input("Enter item variable name: ")
    if not item_name then return nil end
    result = string.format(M.templates[structure], items_name, item_name, indented_code)
  elseif structure == "for" then
    local init = get_required_input("Enter initialization: ")
    if not init then return nil end
    local condition = get_required_input("Enter condition: ")
    if not condition then return nil end
    local increment = get_required_input("Enter increment: ")
    if not increment then return nil end
    result = string.format(M.templates[structure], init, condition, increment, indented_code)
  elseif structure == "do_while" then
    local condition = get_required_input("Enter condition: ")
    if not condition then return nil end
    result = string.format(M.templates[structure], indented_code, condition)
  elseif structure == "try_catch" then
    local catch_code = vim.fn.input("Enter catch block code (or leave empty): ")
    result = string.format(M.templates[structure], indented_code, catch_code or "// TODO: Handle exception")
  else
    local condition = get_required_input("Enter condition: ")
    if not condition then return nil end
    result = string.format(M.templates[structure], condition, indented_code)
  end

  return result
end

function M.refactor()
  -- Validate buffer is modifiable
  if vim.bo.modifiable == false then
    vim.notify("Buffer is not modifiable", vim.log.levels.ERROR)
    return
  end

  local structures = vim.tbl_keys(M.templates)
  if not structures or #structures == 0 then
    vim.notify("No structures available", vim.log.levels.ERROR)
    return
  end

  -- Get visual selection and marks BEFORE the async call
  local code = M.get_visual_selection()
  local start_line = vim.fn.line("'<") - 1
  local start_col = vim.fn.col("'<") - 1
  local end_line = vim.fn.line("'>") - 1
  local end_col = vim.fn.col("'>")

  if not code or #code == 0 then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    vim.ui.select(structures, {
      prompt = "Select structure to surround with:",
    }, function(choice)
      if not choice then
        return
      end

      local surrounded_code = M.surround_code(choice, code)
      if not surrounded_code then
        return
      end

      local lines = vim.split(surrounded_code, "\n", true)

      if choice == "function" or choice == "method" then
        -- Delete selected lines
        vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, {})

        -- Insert at end of buffer
        local last_line = vim.api.nvim_buf_line_count(0)
        if choice == "method" then
          last_line = math.max(0, last_line - 1)
        end

        vim.api.nvim_buf_set_lines(0, last_line, last_line, false, lines)

        -- Move cursor to the created function
        vim.api.nvim_win_set_cursor(0, { last_line + 1, 0 })
        vim.api.nvim_buf_call(0, function()
          vim.cmd("silent! write! | edit")
        end)
      else
        -- Replace selected text inline
        local line_content = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, true)[1] or ""
        local safe_end_col = math.min(end_col, #line_content)

        vim.api.nvim_buf_set_text(
          0,
          start_line,
          start_col,
          end_line,
          safe_end_col,
          lines
        )

        vim.api.nvim_buf_call(0, function()
          vim.cmd("silent! write! | edit")
        end)
      end
    end)
  end)
end

return M
