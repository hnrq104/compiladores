
i = 0
a = 400
x = 13151
y = (x + a/x)/2

while (x - y > 0.005 or y - x > 0.005) do
    i = i + 1
    x = y
    y = (x + a/x)/2
end
print(x,y,i)

if i < 15 then
    print("Achamos uma aproximação para sqrt de 400 em ...\n\tMENOS DE 15...\n\tp\nassos! \\:)") -- uma carinha com topete
end

print(y - math.sqrt(a))