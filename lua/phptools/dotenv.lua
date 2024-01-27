local Dotenv = {}

function Dotenv:new()
    local t = setmetatable({}, { __index = Dotenv })
    -- print('')
    return t
end

function Dotenv:run()
end
