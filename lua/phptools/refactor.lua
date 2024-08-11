local tree = require("phptools.treesitter")

local Refactor = {}

function Refactor:new()
  local t = setmetatable({}, { __index = Refactor })
  --
  t.params = vim.lsp.util.make_position_params()
  t.current_file = t.params.textDocument.uri:gsub("file://", "")

  return t
end

--
--
--
function Refactor:run()
  local M = Refactor:new()
  --
  local methods = {}
  local mode = vim.api.nvim_get_mode()
  if mode.mode == "V" or mode.mode == "v" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
    table.insert(methods, { "funcInline", "funcToFile", "methodToFile", "methodInline" })
    vim.cmd([['<,'>delete z]])
  end
  if #methods == 0 then
    return
  end
  vim.ui.select(unpack(methods), { prompt = "Select Refactor:" }, function(choice)
    if choice == nil then
      return
    end
    if choice == "funcInline" or choice == "methodInline" then
      vim.ui.input({ prompt = "Function Name: ", relative = "editor" }, function(name)
        if choice == nil then
          return
        end
        if choice == "methodInline" then
          Refactor:funcInline(name, true)
          return
        end
        Refactor:funcInline(name)
      end)
    end
  end)
end

function Refactor:funcInline(text, visibility)
  local lines = {}
  local nr = 1
  table.insert(lines, "    function " .. text .. "()")
  local lastline = vim.api.nvim_buf_line_count(0)
  if visibility then
    lines = {}
    visibility = "protected "
    table.insert(lines, "    " .. visibility .. "function " .. text .. "()")
    lastline = lastline - 1
  end
  table.insert(lines, "    {")
  table.insert(lines, "         ")
  table.insert(lines, "    }")
  Refactor:add_to_buffer(lines, lastline)

  if visibility then
    nr = 2
  end

  vim.fn.cursor({ lastline - nr, 9 })

  vim.cmd([[put z]])

  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
end

function Refactor:add_to_buffer(lines, lastline, bufnr)
  bufnr = bufnr or vim.fn.bufnr(vim.api.nvim_buf_get_name(0))
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.fn.bufload(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, lastline, lastline, true, lines)

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
  vim.fn.cursor({ lastline + 1, 9 })
end

return Refactor
