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
    for i = 1, #str do
        if char == str:sub(i, i) then return true end
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














--- TRABALHOS POSTERIORES
--- PARTE PARSER

--- TABELAS
--- tabela de precedencia binaria
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

-- tablela de associatividade
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

-- tabela do que é operacao unaria
local parserUnaryOps = {
    ["NOT"] = true, ["-"] = true
}


local CMD_ENDERS = { "EOF", "END", "ELSE", "ELSEIF", "UNTIL" }


---
--- FUNCOES AUXILIARES
--- SYNTAX ERROR
--- PREC
--- ASSOC
local function syntaxError(tok, msg)
    error(string.format("syntax error '%s' %d:%d. :%s", tok.Tag, tok.StartLine, tok.StartCol, msg))
end

local function Prec(tag)
    return parserBinaryPrecedence[tag]
end


local function Assoc(tag)
    return parserBinaryAssociativity[tag]
end

local function cmd_enders(tag)
    return isInTable(tag, CMD_ENDERS)
end











-- PARSER OBJECT
local PS = { -- stands for Parser State
    -- nextToken = getToken(LS),
    tokens = { getToken(LS), getToken(LS) }
}

--- FUNCOES DO OBJETO PARSER
--- AVANCA PARSER
--- COME PARSER
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
        syntaxError(tk, string.format("Parser leu %s, esperava: %s", tk.Tag, tag))
    end
end










--- MAKE EXP CONSTRUTORES

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

local function makeExpEOF()
    return { Tag = "EXPEOF" }
end

local function makeExpString(str)
    return {
        Tag = "EXPSTR",
        Value = str
    }
end

local function makeExpTblConstructor(fields)
    return { Tag = "EXPTBLCONST", Fields = fields }
end

local function makeExpTblIndex(expTbl, expKey)
    return { Tag = "EXPTBLINDEX", Table = expTbl, Index = expKey }
end

local function makeExpLuaFunc(params, body)
    return { Tag = "EXPLUAFUNC", Params = params, CmdBody = body }
end


local function makeField(expKey, expVal)
    return { ExpKey = expKey, ExpVal = expVal }
end












--- FUNÇÕES DE PARSER
local parseExp
local parseBloco



--- FUNÇÕES AUXILIARES DE PARSER
--- PEGAR LISTA DE NAME, LISTA DE EXP ETC

local function isSuffix(tag)
    return tag == "." or tag == "(" or tag == "["
end

local function isFieldSep(tag)
    return tag == ',' or tag == ';'
end

-- retorna uma lista de expressoes que são os argumentos
local function parseGetExplist(ps)
    local args = {}

    args[#args + 1] = parseExp(ps)
    while ps.tokens[1].Tag == ',' do
        advanceParser(ps)
        args[#args + 1] = parseExp(ps)
    end
    return args
end

local function readNameList(ps)
    local params = {}
    if ps.tokens[1].Tag == "NAME" then
        params[#params + 1] = ps.tokens[1].Value
    end
    advanceParser(ps)

    while ps.tokens[1].Tag == "," do
        advanceParser(ps)
        if ps.tokens[1].Tag == "NAME" then
            params[#params + 1] = ps.tokens[1].Value
            advanceParser(ps)
        else
            syntaxError(ps.tokens[1], "unexpected token in name list")
        end
    end
    return params
end








--- FUNCAO DE PARSING DE NOS DE ARVORE DE EXPRESSAO

--- PARSE DE OBJETOS SIMPLES
---
--- PARSEPRIMARIA
--- PARSESUFIXADA
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

    syntaxError(tk, "Nao possivel parsear exp primaria")
end

local function parseSufixada(ps)
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
            e = makeExpTblIndex(e, key_arg)
        else
            advanceParser(ps)

            if ps.tokens[1].Tag == "NAME" then
                e = makeExpTblIndex(e, makeExpString(ps.tokens[1].Value))
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

local function parseTableConstructor(ps)
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
    return makeExpTblConstructor(fields)
end


local function parseLuaFunc(ps)
    comeParser(ps, "FUNCTION")
    comeParser(ps, "(")

    local params = {} -- inneficient but easier to implement
    if ps.tokens[1].Tag ~= ")" then
        params = readNameList(ps)
    end
    comeParser(ps, ")")

    local body = parseBloco(ps)
    comeParser(ps, "END")

    return makeExpLuaFunc(params, body)
end

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

    if ps.tokens[1].Tag == "STRING" then
        local str = ps.tokens[1].Value
        advanceParser(ps)
        return makeExpString(str)
    end

    if ps.tokens[1].Tag == "{" then
        return parseTableConstructor(ps)
    end

    if ps.tokens[1].Tag == "FUNCTION" then
        return parseLuaFunc(ps)
    end

    return parseSufixada(ps)
end









--- PARSE DE OPERADORES

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


--- FUNÇÃO PARSE EXP

function parseExp(ps)
    if ps.tokens[1].Tag == "EOF" then
        return makeExpEOF()
    end
    return parseBinopExp(ps, 0)
end

---





--- PARSING DE COMANDOS
--- AQUI TEMOS FUNCOES
--- PARSE IF
--- PARSE LOCAL
--- PARSE WHILE
--- PARSE FUNCTION
--- PARSE SET DE VARIAVEIS
--- PARSE BLOCO
--- PARSE CMD






--- MAKE CMD CONSTRUTORES

-- elses_block can be nil
local function makeIfCmd(exp_cond, block, elses_block)
    return { Tag = "CMDIF", ExpCond = exp_cond, Block = block, Elses = elses_block }
end

local function makeWhileCmd(exp_cond, while_block)
    return { Tag = "CMDWHILE", ExpCond = exp_cond, Block = while_block }
end


local function makeBlock(cmds)
    return { Tag = "CMDBLOCK", Cmds = cmds }
end

local function makeSetList(setlist, explist)
    return { Tag = "CMDSETLIST", ExpSetList = setlist, ExpValList = explist }
end


local function makeReturnCmd(explist)
    return { Tag = "CMDRETURN", ExpRetList = explist }
end

local function makeLocalSetList(names, exp_values, block)
    return { Tag = "CMDLOCALSET", Names = names, ExpValList = exp_values, Block = block }
end

local function makeCallCmd(expF, expArgList)
    return { Tag = "CMDCALL", F = expF, Args = expArgList }
end







--- FUNÇÕES AUXILIARES DE PARSING DE COMANDOS

local function parseSufList(ps)
    local suf = parseSufixada(ps)
    local sufs = { suf, HasCall = (suf.Tag == "EXPCALL") }
    while ps.tokens[1].Tag == ',' do
        advanceParser(ps)
        table.insert(sufs, parseSufixada(ps))
        sufs.HasCall = sufs.HasCall or (sufs[#sufs].Tag == "EXPCALL")
    end
    return sufs
end









---

local function parseIfCmd(ps)
    comeParser(ps, "IF")
    local exp_cond = parseExp(ps)
    comeParser(ps, "THEN")
    local main_b = parseBloco(ps)

    local ifstart = makeIfCmd(exp_cond, main_b, nil)
    local previous = ifstart

    while ps.tokens[1].Tag ~= "END" do
        if ps.tokens[1].Tag == "ELSEIF" then
            advanceParser(ps)
            local cond = parseExp(ps)
            comeParser(ps, "THEN")
            local curr = makeIfCmd(cond, parseBloco(ps), nil)
            previous.Elses = curr
            previous = curr
        elseif ps.tokens[1].Tag == "ELSE" then
            advanceParser(ps)
            previous.Elses = parseBloco(ps)
            break
        else
            syntaxError(ps.tokens[1].Tag, "didn't end conditional block")
        end
    end
    comeParser(ps, "END")

    return ifstart
end


local function parseWhileCmd(ps)
    comeParser(ps, "WHILE")
    local exp_cond = parseExp(ps)
    comeParser(ps, "DO")
    local b = parseBloco(ps)
    comeParser(ps, "END")
    return makeWhileCmd(exp_cond, b)
end



local function parseReturnCmd(ps)
    comeParser(ps, "RETURN")
    local explist
    if ps.tokens[1].Tag ~= "END" then
        explist = parseGetExplist(ps)
    end

    if ps.tokens[1].Tag == "END" or ps.tokens[1].Tag == "EOF" then
        return makeReturnCmd(explist)
    end

    syntaxError(ps.tokens[1], "expected end or eof after return")
end



local function parseFunctionDeclaration(ps)
    comeParser(ps, "FUNCTION")
    local name
    if ps.tokens[1].Tag == "NAME" then
        name = ps.tokens[1].Value
        advanceParser(ps)
    else
        syntaxError(ps.tokens[1].Tag, "name expected for function")
    end

    local params = {}
    comeParser(ps, "(")
    if ps.tokens[1].Tag ~= ")" then
        params = readNameList(ps)
    end
    comeParser(ps, ")")

    local body = parseBloco(ps)
    comeParser(ps, "END")

    return makeSetList({ makeExpName(name) }, { makeExpLuaFunc(params, body) })
end


-- pode retornar um bloco de atribuicoes locais
-- ou somente declaracoes (atribuicoes nil)
-- ou uma funcao local
local function parseLocalCmd(ps)
    comeParser(ps, "LOCAL")

    -- local function name ( params ) block end
    if ps.tokens[1].Tag == "FUNCTION" then
        local setlist = parseFunctionDeclaration(ps) --- ISSO AQUI É UMA SUJEIRA PARA FACILITAR, IDEALMENTE NÃO É ASSIM
        local fname = setlist.ExpSetList[1].Value
        local b = parseBloco(ps)

        return makeLocalSetList({fname}, setlist.ExpValList, b)
    end

    -- to read names is just to read paramaters :)
    local names = readNameList(ps)

    local explist = {}
    if ps.tokens[1].Tag == "=" then
        advanceParser(ps)
        explist = parseGetExplist(ps)
    end

    local b = parseBloco(ps)

    return makeLocalSetList(names, explist, b)
end


-- Same thing but maybe accepts suf lists
local function parseCmd(ps)
    if cmd_enders(ps.tokens[1].Tag) then return nil end

    if ps.tokens[1].Tag == "IF" then
        return parseIfCmd(ps)
    end

    if ps.tokens[1].Tag == "WHILE" then
        return parseWhileCmd(ps)
    end

    --trabalho 4
    if ps.tokens[1].Tag == "RETURN" then
        return parseReturnCmd(ps)
    end

    if ps.tokens[1].Tag == "FUNCTION" then
        return parseFunctionDeclaration(ps)
    end

    if ps.tokens[1].Tag == "LOCAL" then
        -- ou se trata de uma local function,
        -- ou uma atribuicao local
        return parseLocalCmd(ps)
    end

    -- exp sufixiada
    local sufs = parseSufList(ps)
    if ps.tokens[1].Tag == "=" and not sufs.HasCall then
        advanceParser(ps)
        local explist = parseGetExplist(ps)
        return makeSetList(sufs, explist)
    end

    if #sufs == 1 then
        local suf = sufs[1]
        if suf.Tag == "EXPCALL" then
            return makeCallCmd(suf.F, suf.Args)
        end
    end

    syntaxError(ps.tokens[1], "could not parse Cmd")
end


function parseBloco(ps)
    local cmds = {}
    local c = parseCmd(ps)
    while c do
        table.insert(cmds, c)
        c = parseCmd(ps)
    end
    if #cmds == 1 then return cmds[1] end
    return makeBlock(cmds)
end

















-- Evaluation
local function makeValNil()
    return { Tag = "VALNIL" }
end

local function makeValInt(n)
    return { Tag = "VALINT", Val = n }
end

local function makeValBool(b)
    return { Tag = "VALBOOL", Val = b }
end

local function makeValTbl(t)
    return { Tag = "VALTBL", Val = t }
end

local function makeValString(str)
    return { Tag = "VALSTR", Val = str }
end

local function makeValNotSet(name)
    return { Tag = "VALNOTSET", Name = name, --[[ Val = nil ]] }
end

-- Trabalho 4
local function makeValLuaFunc(env, params, body)
    return { Tag = "VALLUAFUNC", Params = params, Body = body, Env = env }
end

local function makeValLibFunc(func)
    return { Tag = "VALLIBFUNC", F = func }
end

local function makeValReturnList(valList)
    return { Tag = "VALLISTRET", Values = valList }
end


--- maybe fazer isso aq
local function makeValLibRet(anything)
    return {Tag = "LIBRET", Value = anything}
end
--









--- FUNCOES AUXILIARES DA AVALIACAO

local function isCondFalse(v)
    return v == nil or v == false
end

local function isCondTrue(v)
    return not isCondFalse(v)
end

local function evalError(msg)
    print(msg)
    error(msg)
end

--- SE O ELEMENTO DE RUTNIME FOR UMA LISTA, PEGA O PRIMEIRO
--- SE NÃO RETORNA O PROPRIO OBJETO
local function getSingle(runtime)
    if runtime.Tag == "VALLISTRET" then
        return runtime.Values[1]
    end

    return runtime
end





--- FUNCOES DE AMBIENTE

-- cria um nó de variavel para lista de ambientes
local function makeLocalEnvNode(varname, varvalue, up_env)
    return { Tag = "LOCALNODE", VarName = varname, VarValue = varvalue, UpEnv = up_env }
end

-- Recupera valor de nome de variavel na lista de ambientes
local function getVarValue(varname, env)
    if env.Tag == "BASENODE" then
        if env.Globals[varname] then
            return env.Globals[varname]
        end
        -- return makeValNotSet(varname)
        return makeValNil()
    end

    -- else is a local node
    if env.VarName == varname then
        return env.VarValue
    end

    -- else
    return getVarValue(varname, env.UpEnv)
end

local function updateVarValue(varname, newValue, env)
    if env.Tag == "BASENODE" then
        env.Globals[varname] = newValue
        return
    end

    -- else is a local node
    if env.VarName == varname then
        env.VarValue = newValue
        return
    end

    -- else
    updateVarValue(varname, newValue, env.UpEnv)
end




-- Cria ambiente base
local function makeBaseEnv()
    return {
        Tag = "BASENODE",
        Globals = {
            ["print"] = makeValLibFunc(print),
            -- for now only print
            -- to add modules do something like
            -- ["io"] = makeTable({["read"] =  makeValLibFunc(io.read)})
        }
    }
end








--- EVAL FUNCTIONS
local evalExp, evalCmdCall, evalCmd

local function evalFirst(exp, env)
    return getSingle(evalExp(exp, env))
end



local function evalTblConst(exptbl, env)
    local t = {}
    local unnumbered_field = 1
    for i = 1, #exptbl.Fields do
        local f = exptbl.Fields[i]
        if f.ExpKey then
            local key = evalFirst(f.ExpKey, env)
            if key.Val then
                t[key.Val] = evalFirst(f.ExpVal, env)
            else
                evalError("Trying to assign nil key to table")
            end
        else
            t[unnumbered_field] = evalFirst(f.ExpVal, env)
            unnumbered_field = unnumbered_field + 1
        end
    end

    return makeValTbl(t)
end

local function evalTblIndex(exptbl_ind, env)
    local t = evalExp(exptbl_ind.Table, env)
    if t.Tag == "VALTBL" then
        local index = evalFirst(exptbl_ind.Index, env)
        if t.Val[index.Val] then return t.Val[index.Val] end
        return makeValNil()
    end
    evalError(string.format("trying to index %s object", t.Tag))
end


local inspect = require("inspect")



function evalExp(exp, env)
    if exp.Tag == "EXPNAME" then
        return getVarValue(exp.Value, env)
    end
    if exp.Tag == "EXPNIL" then return makeValNil() end
    if exp.Tag == "EXPINT" then return makeValInt(exp.Value) end
    if exp.Tag == "EXPBOOL" then return makeValBool(exp.Value) end
    if exp.Tag == "EXPSTR" then return makeValString(exp.Value) end

    if exp.Tag == "EXPTBLCONST" then
        return evalTblConst(exp, env)
    end

    if exp.Tag == "EXPTBLINDEX" then
        return evalTblIndex(exp, env)
    end


    if exp.Tag == "EXPLUAFUNC" then
        return makeValLuaFunc(env, exp.Params, exp.CmdBody)
    end

    if exp.Tag == "EXPCALL" then
        local ret = evalCmdCall(makeCallCmd(exp.F, exp.Args), env)
        if ret then
            return ret
        else
            return makeValNil()
        end
    end

    if exp.Tag == "EXPUNOP" then
        local runtime = evalFirst(exp.Exp, env)
        if exp.Op == "NOT" then
            if isCondTrue(runtime.Val) then
                return makeValBool(true)
            else
                return makeValBool(false)
            end
        end

        if exp.Op == "-" then
            if runtime.Tag == "VALINT" then
                return makeValInt(-runtime.Val)
            else
                evalError(string.format("Tried to do - %s", runtime.Tag))
            end
        end
    end

    if exp.Tag == "EXPBINOP" then
        if exp.Op == "AND" then
            local lhs = evalFirst(exp.Exp1, env)
            if isCondFalse(lhs.Val) then return lhs end
            return evalFirst(exp.Exp2, env)
        end

        if exp.Op == "OR" then
            local lhs = evalFirst(exp.Exp1)
            if isCondTrue(lhs.Val) then return lhs end
            return evalFirst(exp.Exp2, env)
        end

        local lhs, rhs = evalFirst(exp.Exp1, env), evalFirst(exp.Exp2, env)

        if exp.Op == "<" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValBool(lhs.Val < rhs.Val)
            else
                evalError(string.format("Trying to compare %s < %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == ">" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValBool(lhs.Val > rhs.Val)
            else
                evalError(string.format("Trying to compare %s > %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "<=" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValBool(lhs.Val <= rhs.Val)
            else
                evalError(string.format("Trying to compare %s <= %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == ">=" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValBool(lhs.Val >= rhs.Val)
            else
                evalError(string.format("Trying to compare %s >= %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "==" then
            return makeValBool(lhs.Tag == rhs.Tag and lhs.Val == rhs.Val)
        end

        if exp.Op == "~=" then
            return makeValBool(lhs.Tag ~= rhs.Tag or lhs.Val ~= rhs.Val)
        end

        if exp.Op == "+" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val + rhs.Val)
            else
                evalError(string.format("Trying to sum %s + %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "-" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val - rhs.Val)
            else
                evalError(string.format("Trying to sub %s - %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "*" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val * rhs.Val)
            else
                evalError(string.format("Trying to mult %s * %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "/" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val / rhs.Val)
            else
                evalError(string.format("Trying to divide %s / %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "%" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val % rhs.Val)
            else
                evalError(string.format("Trying to mod %s %% %s", lhs.Tag, rhs.Tag))
            end
        end

        if exp.Op == "^" then
            if lhs.Tag == rhs.Tag and lhs.Tag == "VALINT" then
                return makeValInt(lhs.Val ^ rhs.Val)
            else
                evalError(string.format("Trying to exp %s ^ %s", lhs.Tag, rhs.Tag))
            end
        end
    end

    evalError("Could not evaluate exp", inspect(exp))
end

-- only used once, but denests code
-- will have to come back for when functions return multiple stuff

--- EVALSETLIST E A FUNCAO DE AVALIAR LISTAS
-- recebe uma lista de expressoes para avaliar, se a ultima for uma valretlist, preenche o final da lista
-- com os valores retornados
local function evalList(lista, env)
    local values = {}
    for i = 1, #lista do
        if i < #lista then
            values[#values+1] = evalFirst(lista[i], env)
        else -- o ultimo pode ser retorno multiplo de funcao
            local val = evalExp(lista[i], env)
            if val.Tag == "VALLISTRET" then
                for j = 1, #val.Values do
                    values[#values+1] = val.Values[j]
                end
            else
                values[#values+1] = val
            end
        end
    end
    return values
end



--- CONSERTAR ISSO DEPOIS
local function evalCmdSetList(setlistcmd, env)

    local values = evalList(setlistcmd.ExpValList, env)
 
    local indexList = {}
    local n_index = 1

    for i = 1, #setlistcmd.ExpSetList do
        local set = setlistcmd.ExpSetList[i]
        if set.Tag == "EXPTBLINDEX" then
            indexList[#indexList+1] = evalFirst(set.Index, env)
        end
    end


    for i = 1, #setlistcmd.ExpSetList do
        local set = setlistcmd.ExpSetList[i]
        local val = values[i] or makeValNil()
        if set.Tag == "EXPNAME" then
            updateVarValue(set.Value, val, env)
        elseif set.Tag == "EXPTBLINDEX" then
            local t = evalFirst(set.Table, env)
            if t.Tag == "VALTBL" then 
                local index = indexList[n_index]
                n_index = n_index + 1
                if index.Val ~= nil then
                    t.Val[index.Val] = values[i]
                else
                    evalError("table index is nil")
                end
            else
                evalError(string.format("attempting to index %s object", t.Tag))
            end
        end
    end
end


function evalCmdCall(cmd, env)
    local fval = evalExp(cmd.F, env)
    local args = evalList(cmd.Args, env)

    if fval.Tag == "VALLIBFUNC" then
        local newargs = {}
        for i = 1, #args do
            newargs[#newargs + 1] = args[i].Val
        end
        fval.F(table.unpack(newargs))
        return makeValNil() --- REVER DEPOIS
    end

    if fval.Tag == "VALLUAFUNC" then
        local newenv = fval.Env
        for i = 1, #fval.Params do
            local val = args[i] or makeValNil()

            newenv = makeLocalEnvNode(fval.Params[i], val, newenv)
        end

        return evalCmd(fval.Body, newenv)
    end

    evalError("Trying to call non function")
end

local function evalCmdReturn(cmd,env)
    local retlist = evalList(cmd.ExpRetList, env)

    if #retlist == 0 then
        return makeValNil()
    end

    if #retlist == 1 then
        return retlist[1]
    end

    return makeValReturnList(retlist)
end


local function evalLocalSet(cmd, env)
    local values = evalList(cmd.ExpValList, env)
    
    --- atribuicao em novos envs
    local newenv = env
    for i = 1, #cmd.Names do
        local val = values[i] or makeValNil()
        newenv = makeLocalEnvNode(cmd.Names[i], val, newenv)
    end

    return evalCmd(cmd.Block,newenv)
end


function evalCmd(cmd, env)
    if cmd.Tag == "CMDRETURN" then
        return evalCmdReturn(cmd,env)
    end

    if cmd.Tag == "CMDSETLIST" then
        evalCmdSetList(cmd, env)
        return
    end
    
    if cmd.Tag == "CMDCALL" then
        evalCmdCall(cmd, env)
        return
    end

    if cmd.Tag == "CMDLOCALSET" then
        return evalLocalSet(cmd,env)
    end

    if cmd.Tag == "CMDIF" then
        local cond = evalExp(cmd.ExpCond, env)
        if isCondTrue(cond.Val) then
            return evalCmd(cmd.Block, env)
        elseif cmd.Elses then
            return evalCmd(cmd.Elses, env)
        end
        return
    end

    if cmd.Tag == "CMDWHILE" then
        local cond = evalExp(cmd.ExpCond, env)
        while isCondTrue(cond.Val) do
            local ret = evalCmd(cmd.Block, env)
            if ret then return ret end

            cond = evalExp(cmd.ExpCond, env)
        end
        return
    end

    if cmd.Tag == "CMDBLOCK" then
        for i = 1, #cmd.Cmds do
            local ret = evalCmd(cmd.Cmds[i], env)
            if ret then return ret end
        end
        return
    end


    evalError(string.format("Couldn't evaluate command %s", cmd.Tag))
end

local b = parseBloco(PS)
print(inspect(b))

print("EVALUATION")
local env1 = makeBaseEnv()
-- print(inspect(env1))
evalCmd(b, env1)

-- print("ENDING ENVIRONMENT")
-- print(inspect(env1))
