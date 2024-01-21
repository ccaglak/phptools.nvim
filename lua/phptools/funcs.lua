local uv = vim.uv or vim.loop

function string.starts(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

function string.ends(String, End)
  return End == "" or string.sub(String, -string.len(End)) == End
end

---- got to find home for these funcs
local get_sep = function()
  local win = uv.os_uname().sysname == "Darwin" or "Linux"
  return win and "/" or "\\"
end

_G.sep = get_sep()
local get_root = function()
  local root = vim.fs.find(
    { ".git", "composer.json", "vendor", "package.json" },
    { path = vim.api.nvim_buf_get_name(0), upward = true }
  )[1]
  root = root and vim.fs.dirname(root) or uv.cwd()
  if not string.ends(root, sep) then
    root = root .. sep
  end
  return root
end
_G.root = get_root()
--

function string.pascalcase(str, deli)
  deli = deli or "\\"
  local pascalCase = ""
  for match in str:gmatch("[a-zA-Z0-9]+") do
    pascalCase = pascalCase .. match:gsub("^.", string.upper) .. deli
  end
  return pascalCase:sub(1, -2)
end

function string.ltrim(input)
  return string.gsub(input, "^[ \t\n\r]+", "")
end

function string.rtrim(input)
  return string.gsub(input, "[ \t\n\r]+$", "")
end

function string.ucfirst(str)
  return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

function string.trim(input)
  input = string.gsub(input, "^[ \t\n\r]+", "")
  return string.gsub(input, "[ \t\n\r]+$", "")
end

function io.pathinfo(path)
  local pos = string.len(path)
  local extpos = pos + 1
  while pos > 0 do
    local b = string.byte(path, pos)
    if b == 46 then -- 46 = char "."
      extpos = pos
    elseif b == 47 then -- 47 = char "/"
      break
    end
    pos = pos - 1
  end

  local dirname = string.sub(path, 1, pos)
  local filename = string.sub(path, pos + 1)
  extpos = extpos - pos
  local basename = string.sub(filename, 1, extpos - 1)
  local extname = string.sub(filename, extpos)
  return {
    dirname = dirname,
    filename = filename,
    basename = basename,
    extname = extname,
  }
end
