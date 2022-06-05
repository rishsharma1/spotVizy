local M = {}

M.dump = function(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. M.dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function easeOutQuart(t)
    t = t - 1
    return 1 - t * t * t * t
end

M.ease = function(t) 
    local progress = math.min(math.max(0, t), 1)
    return easeOutQuart(progress)
end

return M
 