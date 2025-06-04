
local copy = {}

function copy.CopyShallow(orig)
    local result = {}
    for k, v in pairs(orig) do
        result[k] = v
    end
    return result
end

function copy.CopyDeep(orig)
    local result = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            result[k] = copy.CopyDeep(v) -- recursively copy tables
        else
            result[k] = v -- copy value
        end
    end
    return result
end


return copy