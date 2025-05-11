-- Disciplina: Compiladores
-- Professor: Hugo Musso
-- Aluno: Henrique (122078397)

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

local function isInTable(str, table)
    for i = 1, #table do
        if str == table[i] then return true end
    end
    return false
end

-- LEXER FUNCTIONS
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


-- AUXILIARY FUNCTIONS
local function isCharInStr(char, str)
    for i = 1, #str do
        if char == str:sub(i, i) then return true end
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

local function readCharInString(ls)
    local escaped_table = {
        ["\\\\"] = "\\",
        ["\\\""] = "\"",
        ["\\\'"] = "\'",
        ["\\n"] = "\n",
        ["\\r"] = "\r",
        ["\\t"] = "\t"
    }

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
            for j = 1, i do op = op .. ls.chars[j] end
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
            error(string.format("Unclosed string or comment at line %d column %d!", ls.currentLine, ls.currentColumn))
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
    if isNumber(ls.chars[1]) then
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
    if tok ~= nil then
        return tok
    end

    error(string.format("Couldn't lex token: line %d col %d", ls.currentLine, ls.currentColumn))
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

-- PARSER
local function syntaxError(tok)
    error(string.format("syntax error '%s' %d:%d.", tok.Tag, tok.StartLine, tok.StartCol))
end


local PS = { -- stands for Parser State
    -- nextToken = getToken(LS),
    tokens = { getToken(LS), getToken(LS) }
}


local function advanceParser(ps, n_iterations)
    n_iterations = n_iterations or 1
    for _ = 1, n_iterations do
        ps.tokens[1], ps.tokens[2] = ps.tokens[2], getToken(LS)
    end
    -- ps.nextToken = getToken(LS)
end

local function comeParser(ps, tag)
    local tk = ps.tokens[1]
    if tk.Tag == tag then
        advanceParser(ps)
    else
        syntaxError(tk)
    end
end


local parserBinaryPrecedence = {
    ["AND"] = 5,
    ["OR"] = 6,

    ["<"] = 10,
    [">"] = 10,
    ["<="] = 10,
    [">="] = 10,
    ["=="] = 10,
    ["~="] = 10,

    ["+"] = 20,
    ["-"] = 20,

    ["*"] = 30,
    ["/"] = 30,
    ["%"] = 30,

    -- ["^"] = 40
}

local function Prec(tag)
    return parserBinaryPrecedence[tag]
end


-- 1 for left associativity, 0 for right associativity
local parserBinaryAssociativity = {
    ["AND"] = 1,
    ["OR"] = 1,


    ["<"] = 1,
    [">"] = 1,
    ["<="] = 1,
    [">="] = 1,
    ["=="] = 1,
    ["~="] = 1,

    ["+"] = 1,
    ["-"] = 1,

    ["*"] = 1,
    ["/"] = 1,
    ["%"] = 1,

    -- ["^"] = 0,
    [".."] = 0
}

local function Assoc(tag)
    return parserBinaryAssociativity[tag]
end


local parserUnaryOps = {
    ["NOT"] = true, ["-"] = true
}

local function makeExpNil()
    return {
        Tag = "EXPNIL",
        Value = nil
    }
end

local function makeExpBool(value)
    return {
        Tag = "EXPBOOL",
        Value = value
    }
end

local function makeExpInt(value)
    return {
        Tag = "EXPINT",
        Value = value
    }
end

local function makeExpName(value)
    return {
        Tag = "EXPNAME",
        Value = value
    }
end

local function makeUnop(op, exp)
    return {
        Tag = "EXPUNOP",
        Op = op,
        Exp = exp
    }
end

local function makeBinop(op, exp1, exp2)
    return {
        Tag = "EXPBINOP",
        Op = op,
        Exp1 = exp1,
        Exp2 = exp2
    }
end

local function makeExpCall(expf, args)
    return {
        Tag = "EXPCALL",
        F = expf,
        Args = args
    }
end


local parseExp

local function parsePrimaria(ps)
    local tk = ps.tokens[1]
    if tk.Tag == "NAME" then
        local exp = makeExpName(tk.Value)
        advanceParser(ps)
        return exp
    end

    if tk.Tag == "(" then
        advanceParser(ps)
        local exp = parseExp(ps)
        comeParser(ps, ")")
        return exp
    end

    syntaxError(tk)
end

-- retorna uma lista de expressoes que são os argumentos
-- testar depois talvez
local function parseGetExplist(ps)
    local args = {}

    args[#args + 1] = parseExp(ps)
    while ps.tokens[1].Tag == ',' do
        advanceParser(ps)
        args[#args + 1] = parseExp(ps)
    end
    return args
end


-- isso é de certa forma associatiov a esquerda com ()

local parseSufixada -- refiz abaixo para o trab 3

local parseTableConstructor

local function parseSimples(ps)
    if ps.tokens[1].Tag == "NIL" then
        advanceParser(ps)
        return makeExpNil()
    end

    if ps.tokens[1].Tag == "TRUE" then
        advanceParser(ps)
        return makeExpBool(true)
    end

    if ps.tokens[1].Tag == "FALSE" then
        advanceParser(ps)
        return makeExpBool(false)
    end

    if ps.tokens[1].Tag == "NUMBER" then
        local num = ps.tokens[1].Value
        advanceParser(ps)
        return makeExpInt(num)
    end

    if ps.tokens[1].Tag == "{" then
        return parseTableConstructor(ps)
    end

    return parseSufixada(ps)
end

local parseUnopExp

local function parseExponentExp(ps)
    local s = parseSimples(ps)
    if ps.tokens[1].Tag == '^' then
        advanceParser(ps)
        return makeBinop("^", s, parseUnopExp(ps))
    end
    return s
end

function parseUnopExp(ps)
    local tag = ps.tokens[1].Tag
    if parserUnaryOps[tag] then
        advanceParser(ps)
        return makeUnop(tag, parseUnopExp(ps))
    end
    return parseExponentExp(ps)
end

local function parseBinopExp(ps, min_prec)
    local e = parseUnopExp(ps)

    while Prec(ps.tokens[1].Tag) and Prec(ps.tokens[1].Tag) >= min_prec do
        local op = ps.tokens[1].Tag
        advanceParser(ps)
        local rhs = parseBinopExp(ps, Prec(op) + Assoc(op))

        e = makeBinop(op, e, rhs)
    end

    return e
end


function parseExp(ps)
    if ps.tokens[1].Tag == "EOF" then
        return nil
    end
    return parseBinopExp(ps, 0)
end

--Trabalho 3
-- consertos dos trabalhos anteriores:
-- consertei precedência do '^'
-- consertei erro de eof no lexer
-- consertei erro de leitura de numeros hexa e float
-- o que falta:
-- table constructor/ tbl index
-- while, if
-- var assignment
-- consertar parse sufixo

local function makeField(expKey, expVal)
    return { Tag = "TBLFIELD", ExpKey = expKey, ExpVal = expVal }
end

local function makeTblConstructor(fields)
    return { Tag = "TBLCONST", Fields = fields }
end

local function makeTblIndex(expTbl, expKey)
    return { Tag = "TBLINDEX", Table = expTbl, Index = expKey }
end


local function isSuffix(tag)
    return tag == "." or tag == "(" or tag == "["
end

---
function parseSufixada(ps)
    local e = parsePrimaria(ps)

    while isSuffix(ps.tokens[1].Tag) do
        if ps.tokens[1].Tag == "(" then
            advanceParser(ps)

            local args = {}
            if ps.tokens[1].Tag ~= ")" then
                args = parseGetExplist(ps)
            end
            comeParser(ps, ")")
            e = makeExpCall(e, args)
        elseif ps.tokens[1].Tag == "[" then
            advanceParser(ps)

            local key_arg = parseExp(ps)
            comeParser(ps, "]")
            e = makeTblIndex(e, key_arg)
        else -- tok.tag = .
            advanceParser(ps)

            if ps.tokens[1].Tag == "NAME" then
                e = makeTblIndex(e, makeExpName(ps.tokens[1].Value))
            end
            comeParser(ps, "NAME")
        end
    end
    return e
end

local function parseField(ps)
    local expkey = nil

    if ps.tokens[1].Tag == '[' then
        advanceParser(ps)
        expkey = parseExp(ps)
        comeParser(ps, ']')
        comeParser(ps, '=')
        return makeField(expkey, parseExp(ps))
    end

    if ps.tokens[1].Tag == "NAME" and ps.tokens[2].Tag == '=' then
        expkey = makeExpName(ps.tokens[1].Value)
        advanceParser(ps, 2)
    end

    return makeField(expkey, parseExp(ps))
end

local function isFieldSep(tag)
    return tag == ',' or tag == ';'
end

function parseTableConstructor(ps)
    comeParser(ps, "{")
    local fields = {}

    if ps.tokens[1].Tag ~= '}' then
        fields[#fields + 1] = parseField(ps)
        while isFieldSep(ps.tokens[1].Tag) do
            advanceParser(ps)
            if ps.tokens[1].Tag ~= "}" then
                fields[#fields + 1] = parseField(ps)
            end
        end
    end
    comeParser(ps, '}')
    return makeTblConstructor(fields)
end

local inspect = require("inspect")

local e = parseExp(PS)
while e do
    print(inspect(e))
    e = parseExp(PS)
end
