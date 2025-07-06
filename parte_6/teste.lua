
A = 1
B = 2


local function f()
    local function g(a,b)
        return a + b, 3
    end
    A = 100
    return true, g(), false
end
