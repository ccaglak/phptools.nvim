local tree = require("phptools.treesitter")
local composer = require("phptools.composer")
local utils = require("phptools.utils")

local Class = {}
Class.__index = Class

Class.templates = {
  class_interface_clause = "interface",
  base_clause = "class",
  object_creation_expression = "class",
  scoped_call_expression = "class",
  use_declaration = "trait",
  class_constant_access_expression = "enum",
  simple_parameter = "class",
  property_promotion_parameter = "class",
}

function Class:new()
  local instance = setmetatable({
    params = utils.make_position_params(),
    constructor = false,
  }, { __index = self })
  return instance
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
  if self.parent and self.parent.text then
    self.constructor = self.parent.type == "object_creation_expression" and self.parent.text:match("%((.-)%)") ~= ""
    self.parent.text = self.parent.text:gsub("%b()", "")
  end
end

function Class:get_class_name()
  if self.parent.type == "class_constant_access_expression" and self.parent.node then
    local child = self.parent.node:child()
    if child then
      self.class_name = {
        node = child,
        text = tree.get_text(child),
        range = { child:range() },
      }
      return
    end
  end

  if self.parent.node then
    self.class_name = tree.children(self.parent.node, "name") or tree.children(self.parent.node, "named_type")
  end
end

function Class:find_or_create_class()
  local class_pos = self:class_position()
  if not class_pos then
    self:create_new_class()
    return
  end

  self.file_location = self:get_location(class_pos, "textDocument/definition")

  if self.file_location and self.file_location[1] then
    vim.lsp.util.show_document(self.file_location[1], "utf-8")
  else
    self:create_new_class()
  end
end

-- normalizes path for unix or windows, converts absolute to relative

function Class:create_new_class()
  if not self.class_name or not self.class_name.text then
    vim.notify("Unable to determine class name", vim.log.levels.ERROR)
    return
  end

  local pre_src = composer.get_prefix_and_src()
  self.has_psr4 = pre_src and #pre_src > 0

  -- Build list of available directories from PSR-4 autoload for reference
  if self.has_psr4 then
    local available_paths = {}
    for _, entry in ipairs(pre_src) do
      table.insert(available_paths, entry.src .. " (" .. entry.prefix .. ")")
    end
    vim.notify("Available paths:\n" .. table.concat(available_paths, "\n"), vim.log.levels.INFO)
  else
    vim.notify("No PSR-4 autoload configuration found. Creating class without namespace.", vim.log.levels.WARN)
  end

  local default_dir = vim.fn.expand("%:h")
  local root = _G.get_php_root() or vim.fn.getcwd()
  if root and default_dir:find(root, 1, true) == 1 then
    default_dir = default_dir:sub(#root + 1):gsub("^[/\\]", "")
  end
  if default_dir == "" or default_dir == "." then
    default_dir = (self.has_psr4 and pre_src[1]) and pre_src[1].src or ""
  end

  vim.ui.input({
    prompt = "Enter directory for " .. self.class_name.text .. ".php: ",
    completion = "dir",
    default = default_dir,
  }, function(dir)
    if not dir then
      return
    end
    -- Remove leading slashes to make path relative (prevent absolute paths)
    dir = dir:gsub("^[\\/]+", "")
    self:_create_class_in_directory(utils.normalize_path(dir) .. _G.sep)
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

  -- Only generate namespace and use statement if PSR-4 autoload exists
  if self.has_psr4 then
    self.file_ns = composer.resolve_namespace(dir)
    local current_ns = composer.generate_use_statement(file_path)
    self:add_to_current_buffer({ current_ns })
  else
    -- Generate require_once statement when no PSR-4 autoload
    local require_statement = self:generate_require_once(file_path)
    if require_statement then
      self:add_to_current_buffer({ require_statement })
    end
  end

  local bufnr = utils.get_or_create_buffer(file_path)
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
  if not self.class_name or not self.class_name.range then
    return nil
  end
  return {
    textDocument = self.params.textDocument,
    position = { character = self.class_name.range[2] + 1, line = self.class_name.range[1] },
  }
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
  local insertion_point = utils.get_insertion_point()
  vim.api.nvim_buf_set_lines(0, insertion_point, insertion_point, true, lines)
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
    "property_promotion_parameter",
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
  }

  -- Only include namespace if PSR-4 autoload was found
  if self.file_ns then
    table.insert(tmpl, "")
    table.insert(tmpl, self.file_ns)
  end

  table.insert(tmpl, "")
  table.insert(tmpl, template .. " " .. self.class_name.text)
  table.insert(tmpl, "{")
  table.insert(tmpl, self.constructor and "    public function __construct()\n    {\n        //\n    }" or "    //")
  table.insert(tmpl, "}")

  return tmpl
end

function Class:generate_require_once(file_path)
  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  relative_path = relative_path:gsub("\\", "/")

  return string.format("require_once __DIR__ . '/%s';", relative_path)
end

function Class:get_location(params, method)
  return utils.query(params, method, 1000)
end

return Class
