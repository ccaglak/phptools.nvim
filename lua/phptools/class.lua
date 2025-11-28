local tree = require("phptools.treesitter")
local composer = require("phptools.composer")

local Class = {}

Class.templates = {
  class_interface_clause = "interface",
  base_clause = "class",
  object_creation_expression = "class",
  scoped_call_expression = "class",
  use_declaration = "trait",
  class_constant_access_expression = "enum",
  simple_parameter = "class",
}

local function make_position_params()
  return vim.lsp.util.make_position_params(nil, "utf-16")
end

function Class:new()
  return setmetatable({
    params = make_position_params(),
    constructor = false,
  }, { __index = self })
end

function Class:run()
  local instance = self:new()
  instance.parent = instance:get_parent()
  if not instance.parent then
    return
  end

  instance:process_parent()
  instance:get_class_name()
  instance:find_or_create_class()
end

function Class:process_parent()
  self.constructor = self.parent.type == "object_creation_expression" and self.parent.text:match("%((.-)%)") ~= ""
  self.parent.text = self.parent.text:gsub("%b()", "")
end

function Class:get_class_name()
  self.class_name = self.parent.type == "class_constant_access_expression"
      and {
        node = self.parent.node:child(),
        text = tree.get_text(self.parent.node:child()),
        range = { self.parent.node:child():range() },
      }
    or tree.children(self.parent.node, "name")
    or tree.children(self.parent.node, "named_type")
end

function Class:find_or_create_class()
  self.file_location = self:get_location(self:class_position(), "textDocument/definition")


  if self.file_location and self.file_location[1] then
    vim.lsp.util.show_document(self.file_location[1], "utf-8")
  else
    self:create_new_class()
  end
end

-- normalizes path for unix or windows, converts absolute to relative
local function normalize_path(path)
  -- Remove leading slashes to make path relative (prevent absolute paths)
  path = path:gsub("^[\\/]+", "")

  -- Remove trailing slashes
  path = path:gsub("[\\/]+$", "")

  if path ~= "" then
    path = path .. sep
  end
  path = path:gsub("[\\/]+", sep)
  return path
end

function Class:create_new_class()
  local pre_src = composer.get_prefix_and_src()
  if not pre_src then
    return
  end

  -- Build list of available directories from PSR-4 autoload
  local dirs = {}
  for _, entry in ipairs(pre_src) do
    table.insert(dirs, { path = entry.src, prefix = entry.prefix, is_custom = false })
  end

  -- If no PSR-4 paths found, fall back to current directory
  if #dirs == 0 then
    table.insert(dirs, { path = ".", prefix = "", is_custom = false })
  end

  -- Add option to create custom directory
  table.insert(dirs, { path = "[Create new directory]", prefix = "", is_custom = true })

  vim.ui.select(dirs, {
    prompt = "Select directory for " .. self.class_name.text .. ".php",
    format_item = function(item)
      if item.is_custom then
        return item.path
      end
      return item.path .. " (" .. item.prefix .. ")"
    end,
  }, function(selection)
    if not selection then
      return
    end

    local dir
    if selection.is_custom then
      -- Prompt user for custom directory
      vim.ui.input({
        prompt = "Enter directory path for " .. self.class_name.text .. ".php",
        completion = "dir",
        default = vim.fn.expand("%:h"),
      }, function(custom_dir)
        if not custom_dir then
          return
        end
        self:_create_class_in_directory(normalize_path(custom_dir))
      end)
    else
      self:_create_class_in_directory(normalize_path(selection.path))
    end
  end)
end

function Class:_create_class_in_directory(dir)
  -- Attempt to create directory and handle errors
  local mkdir_result = vim.fn.mkdir(dir, "p")
  if mkdir_result == -1 then
    vim.notify("Failed to create directory: " .. dir, vim.log.levels.ERROR)
    return
  end

  local file_path = dir .. self.class_name.text .. ".php"
  self.file_ns = composer.resolve_namespace(dir)
  local current_ns = composer.generate_use_statement(file_path)

  self:add_to_current_buffer({ current_ns })
  local bufnr = self:get_bufnr(file_path)
  self:add_template_to_buffer(self:template_builder(), bufnr)
  self:finalize_buffer(bufnr)
  _G._filepath_ = file_path
end

function Class:finalize_buffer(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! wall! | silent! edit")
  end)
  vim.fn.cursor({ self.constructor and 11 or 9, 9 })
end

function Class:class_position()
  return {
    textDocument = self.params.textDocument,
    position = { character = self.class_name.range[2] + 1, line = self.class_name.range[1] },
  }
end

function Class:get_bufnr(filename)
  return vim.fn.bufexists(filename) ~= 0 and vim.fn.bufnr(filename) or vim.fn.bufadd(filename)
end

function Class:add_template_to_buffer(lines, bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.bufload(bufnr)
    local flat_lines = {}
    for _, line in ipairs(lines) do
      for subline in line:gmatch("[^\r\n]+") do
        table.insert(flat_lines, subline)
      end
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, flat_lines)
  end
end

function Class:add_to_current_buffer(lines)
  vim.api.nvim_buf_set_lines(0, self:get_insertion_point(), self:get_insertion_point(), true, lines)
end

function Class:get_parent()
  for _, type in ipairs({
    "object_creation_expression",
    "base_clause",
    "class_interface_clause",
    "use_declaration",
    "class_constant_access_expression",
    "scoped_call_expression",
    "simple_parameter",
  }) do
    local parent = tree.parent(type)
    if parent and parent.type == type then
      return parent
    end
  end
end

function Class:template_builder()
  if self.parent.type == "class_constant_access_expression" and string.match(self.parent.text, "class") then
    self.parent.type = "" -- this will result template to default to class
  end

  local template = self.templates[self.parent.type] or "class"
  local tmpl = {
    "<?php",
    "",
    "declare(strict_types=1);",
    "",
    self.file_ns,
    "",
    template .. " " .. self.class_name.text,
    "{",
    self.constructor and "    public function __construct()\n    {\n        //\n    }" or "    //",
    "}",
  }
  return tmpl
end

function Class:get_location(params, method)
  local results = vim.lsp.buf_request_sync(0, method, params, 1000)
  return results and results[1] and results[1].result
end

function Class:get_insertion_point()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insertion_point = 2

  for i, line in ipairs(content) do
    if vim.fn.match(line, "^\\(declare\\)") >= 0 then
      insertion_point = i
    elseif vim.fn.match(line, "^\\(namespace\\)") >= 0 then
      return i, vim.fn.match(line, "^\\(namespace\\)")
    elseif vim.fn.match(line, "^\\(use\\|class\\|final\\|interface\\|abstract\\|trait\\|enum\\)") >= 0 then
      return insertion_point
    end
  end

  return insertion_point, nil
end

return Class
