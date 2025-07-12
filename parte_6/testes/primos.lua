local primes = {}
local function is_prime(n)
    local is = true
    for i = 1, #primes do
        if primes[i] * primes[i] > n then
            break
        end
        if n % primes[i] == 0 then
            is = false
            break
        end
    end
    return is
end

for i = 2, 100 do
    if is_prime(i) then
        print(i)
        primes[#primes + 1] = i
    end
end
