-- Enhanced Goto File (gf) - Universal Navigation Hub (Refactored)
-- Provides comprehensive file navigation for PHP, Laravel Blade, Routes, Components, and Logs
-- Dispatches to feature-specific modules for clean, maintainable architecture

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local trs = require("phptools.treesitter")

local np = gf_utils.normalize_path
local rp = gf_utils.relative_path

-- Feature modules
local blade = require("phptools.gf.gf_blade")
local livewire = require("phptools.gf.gf_livewire")
local routes = require("phptools.gf.gf_routes")
local logs = require("phptools.gf.gf_logs")
local migrations = require("phptools.gf.gf_migrations")
local assets = require("phptools.gf.gf_assets")
local functions = require("phptools.gf.gf_functions")
local components = require("phptools.gf.gf_components")
local locales = require("phptools.gf.gf_locales")
local middleware = require("phptools.gf.gf_middleware")
local twigs = require("phptools.gf.gf_twigs")
local symfony = require("phptools.gf.gf_symfony")
local inertia = require("phptools.gf.gf_inertia")
local gf_constant = require("phptools.gf.gf_constant")

-- ============================================================================
-- Blade Directive Parsing (from original gf.lua)
-- ============================================================================

local function parse_blade_directive()
  if not gf_utils.has_blade_parser() then
    return nil
  end

  local cursor_node = trs.cursor()
  if not cursor_node then
    return nil
  end

  local node = cursor_node.node

  local function extract_first_arg(param_text)
    if not param_text then
      return nil
    end
    param_text = param_text:gsub("^%s*[@%w]+%s*%(", ""):gsub("%)%s*$", "")
    local first_arg = param_text:match("^%s*['\"]([^'\"]+)['\"]")
    return first_arg
  end

  if trs.is_type(node, "parameter") then
    local directive_node = trs.find_prev_matching_sibling(node, "directive")
    if directive_node then
      local directive_text = trs.get_text_safe(directive_node)
      local param_text = trs.get_text_safe(node)
      if directive_text and param_text then
        local first_arg = extract_first_arg(param_text)
        return {
          directive = directive_text,
          parameter = first_arg or param_text,
        }
      end
    end
  end

  if trs.is_type(node, "directive") then
    local param_node = trs.find_next_matching_sibling(node, "parameter")
    if param_node then
      local directive_text = trs.get_text_safe(node)
      local param_text = trs.get_text_safe(param_node)
      if directive_text and param_text then
        local first_arg = extract_first_arg(param_text)
        return {
          directive = directive_text,
          parameter = first_arg or param_text,
        }
      end
    end
  end

  return nil
end

local function parse_blade_expression()
  local line = vim.api.nvim_get_current_line()
  if not line or not line:match("{{") then
    return nil
  end
  local func_name, arg = line:match("{{%s*([%w_]+)%s*%([ '\"]([^'\"]+)[ '\"]")
  if func_name and arg then
    return {
      function_name = func_name,
      argument = arg,
    }
  end
  return nil
end

local function find_blade_for_route(route_name)
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local parts = {}
  for part in route_name:gmatch("[^.]+") do
    table.insert(parts, part)
  end
  if #parts == 0 then
    return nil
  end
  local path = root .. "/resources/views"
  for i = 1, #parts - 1 do
    path = path .. "/" .. parts[i]
  end
  local blade_file = gf_utils.normalize_path(path .. "/" .. parts[#parts] .. ".blade.php")
  if vim.fn.filereadable(blade_file) == 1 then
    return blade_file
  end
  return nil
end

local function navigate_to_route(route_name)
  if not route_name or route_name == "" then
    return
  end

  local has_blade = find_blade_for_route(route_name) ~= nil
  local has_controller = false

  local route_list, _ = routes.get_routes()
  if route_list then
    for _, route in ipairs(route_list) do
      if route.name == route_name then
        local ctrl, _ = routes.parse_controller_action(route.action)
        if ctrl and routes.find_controller_file(ctrl) then
          has_controller = true
        end
        break
      end
    end
  end

  if has_blade and has_controller then
    vim.ui.select({ "Controller", "Blade View" }, { prompt = "Navigate to:" }, function(choice)
      if not choice then
        return
      end
      if choice == "Controller" then
        routes.goto_by_name(route_name)
      else
        blade._toBlade(route_name)
      end
    end)
  elseif has_blade then
    blade._toBlade(route_name)
  elseif has_controller then
    routes.goto_by_name(route_name)
  else
    gf_utils.notify_warn("No blade view or controller found for route: " .. route_name)
  end
end

local function navigate_to_config(config_key)
  if not config_key or config_key == "" then
    gf_utils.notify_warn("No config key provided")
    return
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local parts = {}
  for part in config_key:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return
  end

  local config_file = np(root .. "/config/" .. parts[1] .. ".php")
  if vim.fn.filereadable(config_file) == 1 then
    vim.cmd("edit " .. config_file)
    gf_utils.notify_info("Opened: " .. rp(config_file))
  else
    gf_utils.notify_warn("Config file not found: " .. rp(config_file))
  end
end

-- ============================================================================
-- Universal Navigation Dispatcher
-- ============================================================================

local function dispatch_navigation()
  local ft = vim.bo.filetype
  local line = vim.fn.getline(".")
  local current_file = vim.fn.expand("%:p")
  local is_laravel = gf_utils.is_laravel_project()

  -- Check if file type is supported for gf features
  if not gf_utils.is_supported_file_type(ft) then
    return false
  end

  -- BLADE FILES
  if ft == "blade" or current_file:match("%.blade%.php$") then
    -- Try PHP class name detection first (e.g., App\Controller\ProductController)
    local class_name = gf_utils.detect_php_class_name()
    if class_name then
      local class_file = gf_utils.find_php_class_file(class_name)
      if class_file then
        vim.cmd("edit " .. class_file)
        gf_utils.notify_info("Opened class: " .. class_name)
        return true
      end
    end

    -- Try tree-sitter-blade directives first
    if gf_utils.has_blade_parser() then
      local directive_info = parse_blade_directive()
      if directive_info and directive_info.parameter then
        if directive_info.directive:match("@livewire") then
          local component_file = livewire.resolve_component_path(directive_info.parameter)
          if component_file and vim.fn.filereadable(component_file) == 1 then
            vim.cmd("edit " .. component_file)
            gf_utils.notify_info("Opened Livewire component")
            return true
          end
        elseif directive_info.directive:match("@extends") or
               directive_info.directive:match("@include") or
               directive_info.directive:match("@component") then
          blade._toBlade(directive_info.parameter)
          return true
        elseif directive_info.directive:match("@section") then
          blade.to_section(directive_info.parameter)
          return true
        end
      end
    end

    -- @vite directive: @vite('path') or @vite(['path1', 'path2'])
    if line:match("@vite") then
      local paths = {}
      for path in line:gmatch("['\"]([^'\"]+)['\"]") do
        table.insert(paths, path)
      end
      if #paths == 1 then
        local root = gf_utils.get_project_root() or vim.fn.getcwd()
        gf_utils.resolve_and_open_file(root .. "/" .. paths[1])
        return true
      elseif #paths > 1 then
        vim.ui.select(paths, { prompt = "Open vite asset:" }, function(choice)
          if choice then
            local root = gf_utils.get_project_root() or vim.fn.getcwd()
            gf_utils.resolve_and_open_file(root .. "/" .. choice)
          end
        end)
        return true
      end
    end

    -- Try Blade expressions: {{ view() }}, {{ config() }}, {{ route() }}
    local expr_info = parse_blade_expression()
    if expr_info and expr_info.function_name and expr_info.argument then
      if expr_info.function_name == "config" then
        navigate_to_config(expr_info.argument)
        return true
      elseif expr_info.function_name == "view" then
        blade._toBlade(expr_info.argument)
        return true
      elseif expr_info.function_name == "route" then
        if expr_info.argument and expr_info.argument ~= "" then
          navigate_to_route(expr_info.argument)
          return true
        end
        routes.browse()
        return true
      end
    end

    -- Regex fallback for directives
    if not gf_utils.has_blade_parser() then
      local patterns = gf_utils.get_blade_patterns()
      local txt = line:match(patterns.include)
        or line:match(patterns.livewire)
        or line:match(patterns.component)
        or line:match(patterns.extends)
        or line:match(patterns.section)

      if txt then
        if line:match(patterns.livewire) then
          local component_file = livewire.resolve_component_path(txt)
          if component_file and vim.fn.filereadable(component_file) == 1 then
            vim.cmd("edit " .. component_file)
            return true
          end
        else
          blade._toBlade(txt)
          return true
        end
      end
    end

    -- HTML tag components
    if line:match("</x%-[%w%-%.]+") or line:match("<x%-[%w%-%.]+") or line:match("<livewire:") then
      blade.goto_component()
      return true
    end
  end

  -- PHP FILES
  if ft == "php" then
    -- Laravel-specific features (only if Laravel project)
    if is_laravel then
      -- Livewire file toggle
      if current_file:find(np("/app/Livewire/"), 1, true) then
        livewire.toggle_files()
        return true
      end

      -- view(), config() calls in PHP
      local view_arg = line:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
      if view_arg then
        blade._toBlade(view_arg)
        return true
      end

      local config_arg = line:match("config%s*%(%s*['\"]([^'\"]+)['\"]")
      if config_arg then
        navigate_to_config(config_arg)
        return true
      end

      -- Routes (Laravel only)
      if line:match("route%s*%(") or line:match("Route::") then
        local name_arg = line:match("name%s*%(%s*['\"]([^'\"]+)['\"]")
          or line:match("route%s*%(%s*['\"]([^'\"]+)['\"]")
        if name_arg then
          navigate_to_route(name_arg)
          return true
        end
        routes.browse()
        return true
      end

      -- Migration file navigation
      if line:match("Schema::create") or line:match("Schema::table") or line:match("Schema::drop") then
        if migrations.goto_migration() then
          return true
        end
      end

      -- Locale file navigation
      if line:match("__%(") or line:match("trans%(") or line:match("trans_choice%(") then
        if locales.goto_locale() then
          return true
        end
      end

      -- Middleware stack navigation
      if line:match("Route::middleware") or line:match("->middleware%(") or line:match("middleware%s*%(%s*%[") then
        if middleware.goto_middleware() then
          return true
        end
      end

      -- Inertia.js component navigation
      if line:match("inertia%(") or line:match("Inertia::") or line:match("Route::inertia") then
        if inertia.goto_inertia() then
          return true
        end
      end

      -- Symfony-specific navigation (services, entities, config, etc.)
      if symfony.goto_symfony_reference() then
        return true
      end
    end

    -- Asset file navigation (all PHP projects)
    if line:match("asset%(") or line:match("@assets%(") or
       line:match('src%s*=') or line:match('href%s*=') then
      if assets.goto_asset() then
        return true
      end
    end

    -- Function definition navigation (all PHP projects)
    if line:match("helper") or line:match("function_exists") then
      if functions.goto_function() then
        return true
      end
    end

    -- PHP includes with constants (works for all PHP projects)
    if line:match("require") or line:match("include") or
       line:match("CONST") or line:match("__DIR__") or
       line:match("getenv") or line:match("env%(") then
      gf_constant.resolve_php_include()
      return true
    end
  end

  -- Nested component navigation (Blade files)
  if ft == "blade" or current_file:match("%.blade%.php$") then
    if line:match("<x%-") or line:match("<livewire:") then
      if components.goto_nested_component() then
        return true
      end
    end

    -- Asset navigation in Blade files
    if line:match('src%s*=') or line:match('href%s*=') or line:match("asset%(") then
      if assets.goto_asset() then
        return true
      end
    end

    -- Function definition navigation in Blade files
    -- Only triggers when the word under cursor is followed by (
    local cursor_word = vim.fn.expand("<cword>")
    if cursor_word and cursor_word:match("^[a-z_][a-z0-9_]*$") and line:match(cursor_word .. "%s*%(") then
      if functions.goto_function() then
        return true
      end
    end
  end

  -- LIVEWIRE VIEWS (Laravel only)
  if is_laravel and current_file:find(np("/resources/views/livewire/"), 1, true) then
    livewire.toggle_files()
    return true
  end

  -- TWIG FILES
  if ft == "twig" then
    if twigs.goto_twig_template() then
      return true
    end

    -- Try to detect PHP class names in twig files (e.g., App\Controller\ProductController)
    local class_name = gf_utils.detect_php_class_name()
    if class_name then
      local class_file = gf_utils.find_php_class_file(class_name)
      if class_file then
        vim.cmd("edit " .. class_file)
        gf_utils.notify_info("Opened class: " .. class_name)
        return true
      end
    end
  end

  return false
end

-- ============================================================================
-- Setup
-- ============================================================================

local default_keymaps = {
  gf = "gf",
  browse_components = "<leader>gC",
  browse_livewire = "<leader>gw",
  toggle_livewire = "<leader>gW",
  browse_routes = "<leader>gr",
  browse_logs = "<leader>gl",
  tail_logs = "<leader>gL",
}

function M.setup(user_config)
  user_config = user_config or {}
  gf_utils.set_config(user_config)

  local keymaps = vim.tbl_extend("force", default_keymaps, user_config.keymaps or {})

  if keymaps.gf then
    vim.keymap.set("n", keymaps.gf, function()
      if dispatch_navigation() then
        return
      end
      local ft = vim.bo.filetype
      if ft == "php" or ft == "blade" then
        gf_constant.resolve_php_include()
      else
        vim.cmd.normal("gf")
      end
    end, { desc = "Smart goto file" })
  end

  if keymaps.browse_components then
    vim.keymap.set("n", keymaps.browse_components, M.browse_blade_components, { desc = "Browse Blade components" })
  end

  if keymaps.browse_livewire then
    vim.keymap.set("n", keymaps.browse_livewire, M.browse_livewire_components, { desc = "Browse Livewire components" })
  end

  if keymaps.toggle_livewire then
    vim.keymap.set("n", keymaps.toggle_livewire, M.toggle_livewire_files, { desc = "Toggle Livewire component/view" })
  end

  if keymaps.browse_routes then
    vim.keymap.set("n", keymaps.browse_routes, M.browse_routes, { desc = "Browse Laravel routes" })
  end

  if keymaps.browse_logs then
    vim.keymap.set("n", keymaps.browse_logs, M.browse_logs, { desc = "Browse log files" })
  end

  if keymaps.tail_logs then
    vim.keymap.set("n", keymaps.tail_logs, M.tail_logs, { desc = "Tail Laravel logs" })
  end
end

-- ============================================================================
-- Public Navigation API
-- ============================================================================

function M.goto_blade_component()
  return blade.goto_component()
end

function M.browse_blade_components()
  return blade.browse_components()
end

function M.browse_livewire_components()
  return livewire.browse_components()
end

function M.toggle_livewire_files()
  return livewire.toggle_files()
end

function M.browse_routes()
  return routes.browse()
end

function M.browse_logs()
  return logs.browse()
end

function M.tail_logs()
  return logs.tail()
end

function M.navigate_to_blade_template(template_path)
  return blade._toBlade(template_path)
end

function M.navigate_to_section(section_name)
  return blade.to_section(section_name)
end

function M.navigate_to_config(config_key)
  return navigate_to_config(config_key)
end

function M.navigate_to_livewire(component_name)
  local component_file = livewire.resolve_component_path(component_name)
  if component_file and vim.fn.filereadable(component_file) == 1 then
    vim.cmd("edit " .. component_file)
    gf_utils.notify_info("Opened Livewire component")
  else
    gf_utils.notify_warn("Livewire component not found: " .. component_name)
  end
end

function M.find_livewire_blade_usage(component_name)
  return livewire.search_blade_usage(component_name)
end

function M.get_config()
  return gf_utils.get_config()
end

function M.browse_symfony_services()
  return symfony.browse_services()
end

function M.browse_symfony_entities()
  return symfony.browse_entities()
end

return M
