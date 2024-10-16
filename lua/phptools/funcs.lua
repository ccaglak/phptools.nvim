function string.starts(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

function string.ends(String, End)
  return End == "" or string.sub(String, -string.len(End)) == End
end

_G.sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"

_G.root = vim.fs.root(0, { "composer.json", ".git" }) or vim.uv.cwd()

function string.pascalcase(str, deli)
  deli = deli or "\\"
  local pascalCase = ""
  for match in str:gmatch("[a-zA-Z0-9_-]+") do
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

function string.lcfirst(str)
  return string.lower(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- delete first char
function string.dltfirst(str)
  return str:sub(2)
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
