local function i()
    return 1,2
end

local function h()
    return 3,4, i()
end

local function g()
    return 5,6 , h()
end

print(g())