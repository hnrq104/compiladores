-- Disciplina: Compiladores
-- Professor: Hugo Musso
-- Aluno: Henrique (122078397)


-- TRABALHO PARTE LEXER
-- SOMENTE COISAS DO LEXER

-- tables
local reserved_words = {
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "goto", "if", "in",
    "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while",
}

local operators = {
    "+", "-", "*", "/", "%", "^", "#",
    "&", "~", "|", "<<", ">>", "//",
    "==", "~=", "<=", ">=", "<", ">", "=",
    "(", ")", "{", "}", "[", "]", "::",
    ";", ":", ",", ".", "..", "..."
}

local spaces = { " ", "\t", "\n", "\r" }

--- AUXILIARY FUNCTIONS
--- IS CHAR IN STR
--- IS IN TABLE
--- IS LETTER
--- IS NUMBER
--- IS ALPHANUMERIC
local function isCharInStr(char, str)
    for i = 1, string.len(str) do
        if char == string.sub(str, i, i) then return true end
    end
    return false
end

local function isInTable(str, table)
    for i = 1, #table do
        if str == table[i] then return true end
    end
    return false
end

-- same thing as (and) or (and), i find it cleaner with if's
local function isLetter(char)
    if char == nil then return false end

    local byte = string.byte(char)
    if string.byte("a") <= byte and byte <= string.byte("z") then return true end
    if string.byte("A") <= byte and byte <= string.byte("Z") then return true end
    return false
end

local function isNumber(char)
    if char == nil then return false end
    local byte = string.byte(char)
    return string.byte("0") <= byte and byte <= string.byte("9")
end

local function isAlphaNumeric(char)
    return isLetter(char) or isNumber(char)
end


-- LEXER FUNCTIONS

-- LEXER OBJECT
local LS = { -- Stands for Lexer State
    chars = { io.read(1), io.read(1), io.read(1) },
    currentLine = 0,
    currentColumn = 0,
}

--reads one more character, swapping positions
local function updateLexerState(ls, iterations)
    local n_iter = iterations or 1

    for _ = 1, n_iter do
        if ls.chars[1] == "\n" then
            ls.currentLine = ls.currentLine + 1
            ls.currentColumn = 0
        else
            ls.currentColumn = ls.currentColumn + 1
        end

        ls.chars[1], ls.chars[2], ls.chars[3] = ls.chars[2], ls.chars[3], io.read(1)
    end
end



local function makeTok(tok_tag, semantic_value, start_line, start_col, end_line, end_col)
    local tab = { Tag = tok_tag, StartLine = start_line, StartCol = start_col, EndLine = end_line, EndCol = end_col }
    if semantic_value ~= nil then tab.Value = semantic_value end
    return tab
end

-- READ FUNCTIONS
local function readName(ls)
    local name = ""
    local start_l = ls.currentLine
    local start_c = ls.currentColumn

    while ls.chars[1] == "_" or isAlphaNumeric(ls.chars[1]) do
        name = name .. ls.chars[1]
        updateLexerState(ls)
    end


    if isInTable(name, reserved_words) then
        return makeTok(string.upper(name), nil, start_l, start_c, ls.currentLine, ls.currentColumn)
    end

    return makeTok("NAME", name, start_l, start_c, ls.currentLine, ls.currentColumn)
end

local function readHexaNumber(ls)
    local n = "0x"
    local start_l, start_c = ls.currentLine, ls.currentColumn
    updateLexerState(ls, 2)

    local first_dot = true
    local is_hexa_complete = false
    while isNumber(ls.chars[1]) or isCharInStr(ls.chars[1], "aAbBcCdDeEfF")
        or (first_dot and ls.chars[1] == '.') do
        n = n .. ls.chars[1]
        if ls.chars[1] == '.' then
            first_dot = false
        else
            is_hexa_complete = true
        end -- could optimize but really why
        updateLexerState(ls)
    end
    if not is_hexa_complete then
        error("Malformed hexadecimal number!")
    end
    return makeTok("NUMBER", tonumber(n), start_l, start_c, ls.currentLine, ls.currentColumn)
end

local function readNumber(ls)
    if ls.chars[1] == "0" and isCharInStr(ls.chars[2], "xX") then
        return readHexaNumber(ls)
    end
    local start_l, start_c = ls.currentLine, ls.currentColumn
    local n = ""
    local first_dot = true
    while isNumber(ls.chars[1]) or (first_dot and ls.chars[1] == ".") do
        n = n .. ls.chars[1]
        if ls.chars[1] == '.' then
            first_dot = false
        end
        updateLexerState(ls)
    end
    return makeTok("NUMBER", tonumber(n), start_l, start_c, ls.currentLine, ls.currentColumn)
end

local function readOperator(ls)
    -- operators are at most 3 long so we can do this gambiarra
    for i = 3, 1, -1 do
        local op = ""
        if ls.chars[i] ~= nil then
            for j = 1, i do
                op = op .. ls.chars[j]
            end
            if isInTable(op, operators) then
                local tok = makeTok(op, nil, ls.currentLine, ls.currentColumn, ls.currentLine, ls.currentColumn + i)
                updateLexerState(ls, i)
                return tok
            end
        end
    end
    return nil
end

-- read brackets returns 0 if no brackets, 1 if [[ and #eq_sign + 1 if [==...[
local function readOpenBrackets(ls)
    local comment_depth = 0
    if ls.chars[1] == '[' then
        local num_eq = 0
        updateLexerState(ls)

        while ls.chars[1] == '=' do
            num_eq = num_eq + 1
            updateLexerState(ls)
        end

        if ls.chars[1] == '[' then
            comment_depth = num_eq + 1
            updateLexerState(ls)
        end
    end
    return comment_depth
end




local escaped_table = {
    ["\\\\"] = "\\",
    ["\\\""] = "\"",
    ["\\\'"] = "\'",
    ["\\n"] = "\n",
    ["\\r"] = "\r",
    ["\\t"] = "\t"
}

local function readCharInString(ls)
    if ls.chars[2] ~= nil then
        local es = ls.chars[1] .. ls.chars[2]
        if escaped_table[es] then
            updateLexerState(ls, 2)
            return escaped_table[es]
        end
    end

    local c = ls.chars[1]
    updateLexerState(ls)
    return c
end

local function readShortString(ls)
    local start_l = ls.currentLine
    local start_c = ls.currentColumn

    local apostrophe = ls.chars[1] -- the crux of the biscuit is the apostrophe

    updateLexerState(ls)
    local str = ""
    while not isCharInStr(ls.chars[1], apostrophe .. "\n") and ls.chars[1] ~= nil do
        str = str .. readCharInString(ls)
    end

    if ls.chars[1] == "\n" or ls.chars[1] == nil then
        error("Unclosed string")
    end

    updateLexerState(ls)
    return makeTok("STRING", str, start_l, start_c, ls.currentLine, ls.currentColumn)
end

local function readBigString(ls, string_depth, start_l, start_c)
    local str = ""
    while true do
        if ls.chars[1] == ']' then
            local possible_str = "]" -- we must buffer this part, maybe what we are reading is part of the string

            local finished_string = true
            for _ = 1, string_depth - 1 do
                updateLexerState(ls)
                if ls.chars[1] ~= '=' then
                    finished_string = false
                    break
                else
                    possible_str = possible_str .. '='
                end
            end

            if finished_string and ls.chars[2] == ']' then
                updateLexerState(ls, 2)
                return makeTok("STRING", str, start_l, start_c, ls.currentLine, ls.currentColumn)
            else -- we didnt't finish, everything we read was a string
                str = str .. possible_str
            end
        elseif ls.chars[1] == nil then
            error("Unclosed string or comment at line " ..
                tostring(ls.currentLine) .. " column " .. tostring(ls.currentColumn))
        end

        str = str .. readCharInString(ls)
    end
end

local function readComment(ls)
    -- skip (--)
    updateLexerState(ls, 2)

    local comment_depth = readOpenBrackets(ls)
    -- small comment
    if comment_depth == 0 then
        while ls.chars[1] ~= '\n' and ls.chars[1] ~= nil do
            updateLexerState(ls)
        end
        updateLexerState(ls)
    else -- big comment
        -- print("GOT HERE", comment_depth)
        readBigString(ls, comment_depth)
    end
end

-- the end
local function getToken(ls)
    -- EOF
    if ls.chars[1] == nil then
        return makeTok("EOF", nil, ls.currentLine, ls.currentColumn, ls.currentLine, ls.currentColumn)
    end

    -- SPACES
    if isInTable(ls.chars[1], spaces) then
        while isInTable(ls.chars[1], spaces) do
            updateLexerState(ls)
        end
        return getToken(ls)
    end

    --COMMENTS
    if ls.chars[2] and ls.chars[1] .. ls.chars[2] == "--" then
        readComment(ls)
        return getToken(ls)
    end

    -- NAMES
    if isLetter(ls.chars[1]) or (ls.chars[1] == "_" --[[ and isAlphanumeric(ls.chars[2]) ]]) then
        return readName(ls)
    end

    -- NUMBERS
    if isNumber(ls.chars[1]) or (ls.chars[1] == '.' and isNumber(ls.chars[2])) then
        return readNumber(ls)
    end

    -- STRINGS
    if ls.chars[1] == [["]] or ls.chars[1] == [[']] then
        return readShortString(ls)
    end

    if ls.chars[1] == "[" and isCharInStr(ls.chars[2], "=[") then
        local n = readOpenBrackets(ls)
        if n == 0 then
            error("Big string opened improperly")
        end
        return readBigString(ls, n, ls.currentLine, ls.currentColumn)
    end

    -- OPERATORS
    local tok = readOperator(ls)
    -- print("GOT HERE")
    if tok ~= nil then
        return tok
    end

    error("Couldn't lex token: line " .. tostring(ls.currentLine) .. " col " .. tostring(ls.currentColumn))
end

-- LEXER RESUMO:
--[[

A variável "global" LS funciona como Lexer State, lendo sobre o io e tokenizando o arquivo.
Para conseguir um novo token do arquivo, basta chamar:
- getToken(LS)

Mesmo que o arquivo tenha finalizado, getToken retornará um token do tipo EOF.

tokens são tables com os campos: (em parentese são os possíveis valores)
Tag :  (EOF) (NAME),           (STRING), (NUMBER),         (OPERATOR - aqui a tag é o próprio operador)
Value : nil, (string do nome), (string), (valor numerico),  nil

StartCol, EndCol : (coluna que o token começa e termina)
StartLine, EndLine : (linha que o token começa e termina)
]]

local tok = getToken(LS)
print(tok.Tag, tok.Value)

while tok.Tag ~= "EOF" do
    tok = getToken(LS)
    print(tok.Tag, tok.Value)
end
