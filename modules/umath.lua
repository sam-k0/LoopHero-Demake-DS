--= Math Functions ==========--

local umath = {}

local SEED = 123456789 -- Seed for random number generator

function umath.Random()
    -- Constants from Numerical Recipes LCG
    SEED = (1103515245 * SEED + 12345) % 2147483648
    return (SEED % 10000) / 10000  -- returns a float between 0.0 and 1.0
end

function umath.Floor(x)
    return x - (x % 1)
end

function umath.RandomRange(min, max)
    if max == nil then
        return min
    end
    return umath.Floor(umath.Random() * (max - min + 1) + min)
end

function umath.RandomChoice(t)
    if #t == 1 then 
        return t[1]
    end
    if #t == 0 then 
        return nil 
    end
    return t[umath.RandomRange(1, #t)]
end

function umath.RandomInt(a, b)
    return a + umath.Floor(umath.Random() * (b - a + 1))
end

function umath.Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function umath.Round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

return umath
