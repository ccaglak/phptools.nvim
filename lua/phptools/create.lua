local composer = require("phptools.composer")

local Create = {}
function Create:new()
  local t = setmetatable({}, { __index = Create })
  return t
end

function Create:run()
  local M = Create:new()
  local filename = vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")

  local file_ns = composer.resolve_namespace()

  vim.ui.select({ "class", "enum", "interface", "trait", "abstract", "ps", "psa" }, {
    prompt = "Create",
  }, function(selection)
    if not selection then
      return
    end
    local tmpl = M:template_builder(filename, selection, file_ns)
    M:add_to_current_buffer(tmpl)
  end)
end

function Create:add_to_current_buffer(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
end

function Create:template_builder(filename, template, file_ns)
  local tmpl = {
    "<?php",
    "",
    "declare(strict_types=1);",
    "",
  }
  if template == "ps" then
    return tmpl
  end
  if template == "psa" then
    table.insert(tmpl, "require __DIR__.'/vendor/autoload.php';")
    return tmpl
  end

  table.insert(tmpl, file_ns)
  table.insert(tmpl, "")
  if template == "abstract" then
    template = "abstract class"
  end
  table.insert(tmpl, template .. " " .. filename)
  table.insert(tmpl, "{")
  table.insert(tmpl, "        //")
  table.insert(tmpl, "}")
  return tmpl
end

return Create
