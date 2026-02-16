local composer = require("phptools.composer")

local Create = {}
Create.__index = Create

-- Detect if this is a Laravel project
local function is_laravel_project()
  return vim.fn.filereadable(_G.get_php_root() .. "/artisan") == 1
end

local function detect_laravel_entity()
  local filepath = vim.fn.expand("%:p")
  local filename = vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")

  if
    filename:find("Controller")
    or filepath:find("/Http/Controllers/", 1, true)
    or filepath:find("\\Http\\Controllers\\", 1, true)
  then
    return "controller"
  end

  if filename:find("Model") or filepath:find("/Models/", 1, true) or filepath:find("\\Models\\", 1, true) then
    return "model"
  end

  if
    filename:find("Request")
    or filepath:find("/Http/Requests/", 1, true)
    or filepath:find("\\Http\\Requests\\", 1, true)
  then
    return "request"
  end

  -- Jobs
  if filename:find("Job") or filepath:find("/Jobs/", 1, true) or filepath:find("\\Jobs\\", 1, true) then
    return "job"
  end

  -- Events
  if filename:find("Event") or filepath:find("/Events/", 1, true) or filepath:find("\\Events\\", 1, true) then
    return "event"
  end

  -- Listeners
  if filename:find("Listener") or filepath:find("/Listeners/", 1, true) or filepath:find("\\Listeners\\", 1, true) then
    return "listener"
  end

  return nil
end

local function get_template_options()
  local options = { "class", "enum", "interface", "trait", "abstract" }

  if is_laravel_project() then
    local entity_type = detect_laravel_entity()
    if entity_type then
      table.insert(options, 1, entity_type)
    end
  end

  return options
end

local function get_base_template()
  return {
    "<?php",
    "",
    "declare(strict_types=1);",
    "",
  }
end

function Create:new()
  return setmetatable({}, { __index = self })
end

function Create:run()
  local M = Create:new()
  local filename = vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")

  local file_ns = composer.resolve_namespace()
  local template_options = get_template_options()

  vim.ui.select(template_options, {
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
  local tmpl = get_base_template()

  if not file_ns then
    vim.notify("Unable to determine namespace", vim.log.levels.WARN)
    return tmpl
  end

  table.insert(tmpl, file_ns)
  table.insert(tmpl, "")

  if template == "controller" then
    table.insert(tmpl, "use Illuminate\\Http\\Request;")
    table.insert(tmpl, "use Illuminate\\Routing\\Controller as BaseController;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " extends BaseController")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    public function index()")
    table.insert(tmpl, "    {")
    table.insert(tmpl, "        //")
    table.insert(tmpl, "    }")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Handle Laravel model
  if template == "model" then
    table.insert(tmpl, "use Illuminate\\Database\\Eloquent\\Model;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " extends Model")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    protected $fillable = [];")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Handle Laravel form request
  if template == "request" then
    table.insert(tmpl, "use Illuminate\\Foundation\\Http\\FormRequest;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " extends FormRequest")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    public function authorize(): bool")
    table.insert(tmpl, "    {")
    table.insert(tmpl, "        return true;")
    table.insert(tmpl, "    }")
    table.insert(tmpl, "")
    table.insert(tmpl, "    public function rules(): array")
    table.insert(tmpl, "    {")
    table.insert(tmpl, "        return [];")
    table.insert(tmpl, "    }")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Handle Laravel job
  if template == "job" then
    table.insert(tmpl, "use Illuminate\\Bus\\Queueable;")
    table.insert(tmpl, "use Illuminate\\Contracts\\Queue\\ShouldQueue;")
    table.insert(tmpl, "use Illuminate\\Foundation\\Bus\\Dispatchable;")
    table.insert(tmpl, "use Illuminate\\Queue\\InteractsWithQueue;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " implements ShouldQueue")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    use Dispatchable, InteractsWithQueue, Queueable;")
    table.insert(tmpl, "")
    table.insert(tmpl, "    public function handle(): void")
    table.insert(tmpl, "    {")
    table.insert(tmpl, "        //")
    table.insert(tmpl, "    }")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Handle Laravel event
  if template == "event" then
    table.insert(tmpl, "use Illuminate\\Broadcasting\\Channel;")
    table.insert(tmpl, "use Illuminate\\Broadcasting\\InteractsWithSockets;")
    table.insert(tmpl, "use Illuminate\\Broadcasting\\PresenceChannel;")
    table.insert(tmpl, "use Illuminate\\Broadcasting\\PrivateChannel;")
    table.insert(tmpl, "use Illuminate\\Contracts\\Broadcasting\\ShouldBroadcast;")
    table.insert(tmpl, "use Illuminate\\Foundation\\Events\\Dispatchable;")
    table.insert(tmpl, "use Illuminate\\Queue\\SerializesModels;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " implements ShouldBroadcast")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    use Dispatchable, InteractsWithSockets, SerializesModels;")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Handle Laravel listener
  if template == "listener" then
    table.insert(tmpl, "use Illuminate\\Contracts\\Queue\\ShouldQueue;")
    table.insert(tmpl, "use Illuminate\\Queue\\InteractsWithQueue;")
    table.insert(tmpl, "")
    table.insert(tmpl, "class " .. filename .. " implements ShouldQueue")
    table.insert(tmpl, "{")
    table.insert(tmpl, "    use InteractsWithQueue;")
    table.insert(tmpl, "")
    table.insert(tmpl, "    public function handle($event): void")
    table.insert(tmpl, "    {")
    table.insert(tmpl, "        //")
    table.insert(tmpl, "    }")
    table.insert(tmpl, "}")
    return tmpl
  end

  -- Convert abstract to "abstract class"
  local entity_type = (template == "abstract") and "abstract class" or template

  table.insert(tmpl, entity_type .. " " .. filename)
  table.insert(tmpl, "{")
  table.insert(tmpl, "        //")
  table.insert(tmpl, "}")

  return tmpl
end

return Create
