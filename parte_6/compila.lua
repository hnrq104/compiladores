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
        if char == string.sub(str,i, i) then return true end
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

    [".."] = 20
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
    ["NOT"] = true, ["-"] = true, ["#"] = true
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

local function makeBreakCmd()
    return {Tag = "CMDBREAK"}
end

-- novo
local function makeForCmd(exp_start, index_name, exp_end, exp_step, block)
    -- posso fazer assim, ou posso lembrar que for é um açucar para while NÃO É EM LUA
    
    return {
        Tag = "CMDFOR",
        IndexName = index_name,
        ExpStart = exp_start,
        ExpEnd = exp_end,
        ExpStep = exp_step,
        Block = block
    }
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
    local explist = {}
    if ps.tokens[1].Tag ~= "END" then
        explist = parseGetExplist(ps)
    end

    if cmd_enders(ps.tokens[1].Tag) then
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
        local fname = setlist.ExpSetList[1]
        local b = parseBloco(ps)


        -- açucar sintatico para
        -- local fname
        -- fname = function ...
        -- bloco
        
        -- isso é
        local cmd = makeLocalSetList(
            { fname.Value },
            {},
            makeBlock({
                -- fname = func
                makeSetList(
                        { fname },
                        setlist.ExpValList
                ),
                -- prox bloco
                b
            })
        )
        return cmd
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


local function parseForCmd(ps)
    comeParser(ps, "FOR")

    local name
    if ps.tokens[1].Tag == "NAME" then
        name = ps.tokens[1].Value
        advanceParser(ps)
    else
        syntaxError(ps.tokens[1].Tag, "name expected in for")
    end

    comeParser(ps, "=")

    local exp_start = parseExp(ps)
    comeParser(ps, ',')
    local exp_end = parseExp(ps)
    local exp_step = nil
    if ps.tokens[1].Tag == "," then
        advanceParser(ps)
        exp_step = parseExp(ps)
    end
    if exp_step == nil then
        exp_step = makeExpInt(1)
    end

    comeParser(ps, "DO")
    local bloco = parseBloco(ps)
    comeParser(ps, "END")

    return makeForCmd(exp_start, name, exp_end, exp_step, bloco)
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

    -- trab 6
    if ps.tokens[1].Tag == "FOR" then
        return parseForCmd(ps)
    end

    if ps.tokens[1].Tag == "BREAK" then
        comeParser(ps,"BREAK")
        return makeBreakCmd()
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

-- CODE GENERATION









-- Tava bonitinho funcional,
-- mas agora para separar as funções seria terrível
-- mudar literalmetne todas as funções dessa parte e colocar um argumento a mais
-- vamos só nos preocupar com isso durante a criação de funções, estamos sujando o código mas tudo bem

-- CONTADOR DE LABEL
local LBL_NUMBER = 1
local function newLabel()
    local lbl = "L" .. tostring(LBL_NUMBER)
    LBL_NUMBER = LBL_NUMBER + 1
    return lbl
end

-- CONTADOR DE FUNÇÕES
-- code object
-- isso aqui é uma maquininha de estados para lidar com funções 
-- e breaks!
local CODE = {
    Fns = { { N_Args = 0 } }, -- F1
    Stack = { 1 },
    BreakStack = {}
}

local function pushNewFunction(n_args)
    local stack_size = #CODE.Stack
    local fn_size = #CODE.Fns
    CODE.Fns[fn_size + 1] = { N_Args = n_args }
    CODE.Stack[stack_size + 1] = fn_size + 1
    return fn_size + 1 -- function number
end

local function FnLabel(n)
    return "F" .. tostring(n)
end

local function popFuncStack()
    CODE.Stack[#CODE.Stack] = nil
end

local function writeInstruction(instruction)
    local stack_top = CODE.Stack[#CODE.Stack]
    local fn = CODE.Fns[stack_top]
    fn[#fn + 1] = instruction
end

local function pushBreak(lbl)
    CODE.BreakStack[#CODE.BreakStack+1] = lbl
end

local function topBreak()
    if #CODE.BreakStack == 0 then
        print("compilation error: break found outside loop")
        os.exit(1)
    end
    return CODE.BreakStack[#CODE.BreakStack]
end

local function popBreak()
    local popped = CODE.BreakStack[#CODE.BreakStack]
    CODE.BreakStack[#CODE.BreakStack] = nil
    return popped
end

-- FUNÇÕES DE AMBIENTE
-- A ideia é que se você não achar, você deve chamar global pelo nome, então
-- mantemos somente os ambientes locais

-- vou ter que consertar
-- basenode de escopo de funcao
-- nodes normais

--[[
    Um desenho representando o que vou fazer (dá para ser mais econômico com ponteiros)
     ____
    |size|
    | BN |  --- ...
    |____|

       ^
       |          2º Nó         1º Nó  (ordem cronológica)
     ____          ____          ____
    |size|  --->  | N2 |  --->  | N1 |
    | BN |        | VN |        | VN |
    |____|  <---  |____|        |____|
       ^                           |
       | _  _  _  _  _  _  _  _  _ |
]]

--- Cada function env é representado por um BASENODE (BN) que sempre guarda seu tamanho.
--- Quando acrescentamos uma variável, adicionamos no início da lista.
--- Um env, durante a compilação, será um Node, ou um BN ou um VN (VarNode). Quando busca-
--- mos uma variável, seguimos a ordem cronológica (direita e cima).
--- Todo VN aponta para o BN que pertence, isso serve para acelerar a inserção de novas variaveis.



local function AddBaseNode(up_env)
    return { Tag = "BASENODE", UpEnv = up_env, Size = 0, NextVN = nil }
end

local function AddVarNode(varname, basenode)
    basenode.Size = basenode.Size + 1
    local newnode = {
        Tag = "VARNODE",
        BN = basenode,
        Varname = varname,
        NextVN = basenode.NextVN,
        Num = basenode.Size
    }
    basenode.NextVN = newnode
    return basenode.Size, newnode
end


local function search_name_right(varname, varnode)
    while varnode ~= nil do
        if varnode.Varname == varname then
            return varnode.Num
        end
        varnode = varnode.NextVN
    end
    return nil
end

-- para consertar isso, buscamos de trás para frente numa lista, não em uma hash table
local function getVarNumber(varname, node)
    local n_jump = 0
    local n_var
    local basenode
    if node.Tag == "VARNODE" then
        basenode = node.BN
        n_var = search_name_right(varname, node)
        if n_var then
            return n_jump, n_var
        end
    else
        basenode = node
    end

    -- search above
    while basenode.UpEnv ~= nil do
        n_jump = n_jump + 1
        basenode = basenode.UpEnv
        if basenode.NextVN then
            n_var = search_name_right(varname, basenode.NextVN)
            if n_var then
                return n_jump, n_var
            end
        end
    end

    return nil
end

local function addVar(varname, env)
    if env.Tag == "BASENODE" then
        return AddVarNode(varname, env)
    else -- env.Tag == "LOCALNODE"
        return AddVarNode(varname, env.BN)
    end
end

local function newFunctionEnv(up_env_node)
    if up_env_node.Tag == "VARNODE" then
        return AddBaseNode(up_env_node.BN)
    else -- up_env_node == "BASENODE"
        return AddBaseNode(up_env_node)
    end
end

--- FUNCOES AUXILIARES DA AVALIACAO
local function genError(msg)
    error(msg)
end



-- INSTRUCOES
-- literais simples
local function PUSH_NIL()
    writeInstruction('\tPUSH_NIL\n')
end

local function PUSH_BOOL(b)
    if b == true then
        writeInstruction('\tPUSH_TRUE\n')
    end
    if b == false then
        writeInstruction('\tPUSH_FALSE\n')
    end
end

local function PUSH_NUMBER(n)
    local n_str = tostring(n)
    writeInstruction('\tPUSH_NUMBER ' .. n_str .. '\n')
end


-- this doesn't really work right
local string_rep_table = {
    ["\n"] = "\\n",
    ["\t"] = "\\t",
    ["\\"] = "\\\\",

}

local function escape_str_especifico(str)
    local new_str = ""
    local size = string.len(str)

    local char
    for i = 1, size do
        char = string.sub(str,i,i)
        if char == "\n" then
            char = "\\n"
        elseif char == "\t" then
            char = "\\t"
        elseif  char == "\\" then
            char = "\\\\"
        end
        new_str = new_str..char
    end
    return new_str
end

local function PUSH_STRING(str)
    -- POR ENQUANTO TÁ ASSIM TENHO QUE DESESCAPAR OS CARACTERES
    -- VOU RESOLVER SUJAMENTE AGORA USANDO G:SUB PQ É MAIS FÁCILS
    -- str = string.gsub(str, '[\\\n\t]', string_rep_table)
    writeInstruction('\tPUSH_STRING "' .. escape_str_especifico(str) .. '"\n')
end


local function CLOSURE(flabel)
    writeInstruction('\tCLOSURE ' .. flabel .. '\n')
end

-- operacoes com tabela
local function NEW_TABLE()
    writeInstruction('\tNEW_TABLE\n')
end

local function GET_TABLE()
    writeInstruction('\tGET_TABLE\n')
end

local function SET_TABLE()
    writeInstruction('\tSET_TABLE\n')
end

-- variaveis globais
local function GET_GLOBAL(name)
    writeInstruction('\tGET_GLOBAL ' .. name .. '\n')
end

local function SET_GLOBAL(name)
    writeInstruction('\tSET_GLOBAL ' .. name .. '\n')
end

local function GET_LOCAL(jumps, nvar)
    writeInstruction('\tGET_LOCAL ' .. tostring(jumps) .. ' ' .. tostring(nvar) .. '\n')
end

local function SET_LOCAL(jumps, nvar)
    writeInstruction('\tSET_LOCAL ' .. tostring(jumps) .. ' ' .. tostring(nvar) .. '\n')
end


-- operadores unarios
local function NEG()
    writeInstruction('\tNEG\n')
end

local function LEN()
    writeInstruction('\tLEN\n')
end

local function NOT()
    writeInstruction('\tNOT\n')
end

-- operadores binarios

local function ADD()
    writeInstruction('\tADD\n')
end

local function SUB()
    writeInstruction('\tSUB\n')
end

local function MUL()
    writeInstruction('\tMUL\n')
end

local function DIV()
    writeInstruction('\tDIV\n')
end

local function MOD()
    writeInstruction('\tMOD\n')
end

local function CONCAT()
    writeInstruction('\tCONCAT\n')
end

local function EQ()
    writeInstruction('\tEQ\n')
end

local function NEQ()
    writeInstruction('\tNEQ\n')
end

local function LT()
    writeInstruction('\tLT\n')
end

local function LEQ()
    writeInstruction('\tLEQ\n')
end

local function GT()
    writeInstruction('\tGT\n')
end

local function GEQ()
    writeInstruction('\tGEQ\n')
end

local function POW()
    writeInstruction('\tPOW\n')
end

-- desvios
local function JUMP(label)
    writeInstruction('\tJUMP ' .. label .. '\n')
end

local function JUMP_TRUE(label)
    writeInstruction('\tJUMP_TRUE ' .. label .. '\n')
end

local function JUMP_FALSE(label)
    writeInstruction('\tJUMP_FALSE ' .. label .. '\n')
end

-- pula sem comer condicional
local function JUMP_TRUE_OR_POP(label)
    writeInstruction('\tJUMP_TRUE_OR_POP ' .. label .. '\n')
end

local function JUMP_FALSE_OR_POP(label)
    writeInstruction('\tJUMP_FALSE_OR_POP ' .. label .. '\n')
end

-- chamadas de funcao
local function CALL(n_args, n_ret) -- n ret talvez?
    local n_args_str = tostring(n_args)
    local n_ret_str = tostring(n_ret)
    writeInstruction('\tCALL ' .. n_args_str .. ' ' .. n_ret_str .. '\n')
end

local function RETURN(n_returned)
    writeInstruction('\tRETURN '..tostring(n_returned)..'\n')
end

-- outros
local function POP(n)
    local n_str = tostring(n)
    writeInstruction('\tPOP ' .. n_str .. '\n')
end

-- ENCAP é encapsulate
local function ENCAP_LOCAL(n_jump, n_var)
    writeInstruction('\tENCAP_LOCAL ' .. tostring(n_jump) .. ' ' .. tostring(n_var) .. '\n')
end

local function ENCAP_TBLSET()
    writeInstruction('\tENCAP_TBLSET\n')
end

local function ENCAP_GLOBAL(globalname)
    writeInstruction('\tENCAP_GLOBAL ' .. globalname .. '\n')
end


local function SETLIST(n)
    local n_str = tostring(n)
    writeInstruction('\tSETLIST ' .. n_str .. '\n')
end

local function EXIT()
    writeInstruction('\tEXIT\n')
end

local function DUP(n)
    local n_str = tostring(n)
    writeInstruction('\tDUP ' .. n_str .. '\n')
end

local function ERROR(msg)
    writeInstruction('\tERROR "' .. escape_str_especifico(msg) .. '"\n')
end


--- GEN BYTE CODE FUNCTIONS
local genCodeExp, genCodeCmd
local genOr, genAnd 
local genClosure, genReturn



local function genTblConst(exptbl, env)
    NEW_TABLE()
    local unnumbered_field = 1
    if #exptbl.Fields > 0 then
        DUP(#exptbl.Fields)
    end
    for i = 1, #exptbl.Fields do
        local f = exptbl.Fields[i]
        if f.ExpKey then
            genCodeExp(f.ExpKey, env)
        else
            PUSH_NUMBER(unnumbered_field)
            unnumbered_field = unnumbered_field + 1
        end
        genCodeExp(f.ExpVal, env)
        SET_TABLE()
    end
end

local function genTblIndex(exptbl_ind, env)
    genCodeExp(exptbl_ind.Table, env)
    genCodeExp(exptbl_ind.Index, env)
    GET_TABLE()
end

local function genCall(expcall, env, expected_ret)
    genCodeExp(expcall.F, env)
    for i = #expcall.Args, 1, -1 do
        local exp_arg = expcall.Args[i]
        if i == #expcall.Args and exp_arg.Tag == "EXPCALL" then
            genCall(exp_arg, env, -1)
        else
            genCodeExp(exp_arg, env)
        end
    end
    CALL(#expcall.Args, expected_ret)
end


local inspect = require("inspect")

local function genCompleteNil(n_nils)
    for _ = 1, n_nils do
        PUSH_NIL()
    end
end


-- SHOULD DO A SWITCH
-- Se expected_ret for -1, a o número a retornar é arbitrário
function genCodeExp(exp, env, lbl_t, lbl_f, expected_ret)
    expected_ret = expected_ret or 1

    if exp.Tag == "EXPCALL" then
        genCall(exp, env, expected_ret)
        return
    end

    if expected_ret > 1 then -- ISSO AQUI PARECE UMA SUJEIRA, E É.
        genCompleteNil(expected_ret - 1)
    end

    if exp.Tag == "EXPLUAFUNC" then
        genClosure(exp, env)
        return
    end

    if exp.Tag == "EXPNAME" then
        local n_jumps, n_var = getVarNumber(exp.Value, env)
        if n_jumps then
            GET_LOCAL(n_jumps, n_var)
        else
            GET_GLOBAL(exp.Value)
        end
        return
    end

    if exp.Tag == "EXPNIL" then
        PUSH_NIL()
        return
    end

    if exp.Tag == "EXPINT" then
        PUSH_NUMBER(exp.Value)
        return
    end

    if exp.Tag == "EXPBOOL" then
        PUSH_BOOL(exp.Value)
        return
    end
    if exp.Tag == "EXPSTR" then
        PUSH_STRING(exp.Value)
        return
    end

    if exp.Tag == "EXPTBLCONST" then
        genTblConst(exp, env)
        return
    end

    if exp.Tag == "EXPTBLINDEX" then
        genTblIndex(exp, env)
        return
    end


    if exp.Tag == "EXPUNOP" then
        genCodeExp(exp.Exp, env, lbl_t, lbl_f) -- GET FIRST (SOMEHOW)

        -- local runtime = evalFirst(exp.Exp, env)
        if exp.Op == "NOT" then
            NOT()
            return
        end

        if exp.Op == "-" then
            NEG()
            return
        end

        if exp.Op == "#" then
            LEN()
            return
        end
    end

    if exp.Tag == "EXPBINOP" then
        if exp.Op == "AND" then
            return genAnd(exp, env, lbl_t, lbl_f)
            -- genError("ainda não está implementado")
        end

        if exp.Op == "OR" then
            return genOr(exp, env, lbl_t, lbl_f)
            -- genError("ainda não está implementado")
        end

        genCodeExp(exp.Exp1, env) -- lhs
        genCodeExp(exp.Exp2, env) -- rhs

        -- local lhs, rhs = evalFirst(exp.Exp1, env), evalFirst(exp.Exp2, env)

        if exp.Op == "<" then
            LT()
            return
        end

        if exp.Op == ">" then
            GT()
            return
        end

        if exp.Op == "<=" then
            LEQ()
            return
        end

        if exp.Op == ">=" then
            GEQ()
            return
        end

        if exp.Op == "==" then
            EQ()
            return
        end

        if exp.Op == "~=" then
            NEQ()
            return
        end

        if exp.Op == "+" then
            ADD()
            return
        end

        if exp.Op == "-" then
            SUB()
            return
        end

        if exp.Op == "*" then
            MUL()
            return
        end

        if exp.Op == "/" then
            DIV()
            return
        end

        if exp.Op == "%" then
            MOD()
            return
        end

        if exp.Op == "^" then
            POW()
            return
        end

        if exp.Op == ".." then
            CONCAT()
            return
        end
    end

    genError(string.format("Could not gen exp %s", tostring(inspect(exp))))
end

local function isBinopOp(exp, op)
    return exp.Tag == "EXPBINOP" and exp.Op == op
end

local function writeLabel(lbl)
    writeInstruction(lbl .. ':\n')
end

function genOr(exp, env, lbl_t, lbl_f)
    local newlbl = lbl_t or newLabel()
    genCodeExp(exp.Exp1, env, newlbl, nil)
    JUMP_TRUE_OR_POP(newlbl)
    if isBinopOp(exp.Exp2, "AND") then
        genCodeExp(exp.Exp2, env, lbl_f, newlbl)
    else
        genCodeExp(exp.Exp2, env, newlbl, lbl_f)
    end
    if not lbl_t then writeLabel(newlbl) end
end

function genAnd(exp, env, lbl_t, lbl_f)
    local newlbl = lbl_f or newLabel()
    genCodeExp(exp.Exp1, env, nil, newlbl)
    JUMP_FALSE_OR_POP(newlbl)
    if isBinopOp(exp.Exp2, "OR") then
        genCodeExp(exp.Exp2, env, newlbl, lbl_t)
    else
        genCodeExp(exp.Exp2, env, lbl_t, newlbl)
    end

    if not lbl_f then writeLabel(newlbl) end
end

-- Ruim por enquanto, depois devo consertar para não fazer o jump (acho que ja sei como)
local function genJmp(exp, env, lbl_t, lbl_f)
    if exp.Tag == "EXPUNOP" and exp.Op == "NOT" then
        genJmp(exp.Exp, env, lbl_f, lbl_t)
        return
    end
    genCodeExp(exp, env)
    if lbl_t then
        JUMP_TRUE(lbl_t)
    else
        JUMP_FALSE(lbl_f)
    end
end

local function genIf(cmdif, env)
    local lbl_f = newLabel()
    genJmp(cmdif.ExpCond, env, nil, lbl_f)
    genCodeCmd(cmdif.Block, env)
    writeLabel(lbl_f)
    if cmdif.Elses then
        genCodeCmd(cmdif.Elses, env)
    end
end

local function genWhile(cmdwhile, env)
    local lblock = newLabel()
    local lcond = newLabel()
    
    local lend = newLabel()
    pushBreak(lend)

    JUMP(lcond)
    writeLabel(lblock)
    genCodeCmd(cmdwhile.Block, env)
    writeLabel(lcond)
    genJmp(cmdwhile.ExpCond, env, lblock, nil)
    
    writeLabel(lend)
    popBreak()
end

local function genFor(cmd, env)
    local l_jump_error = newLabel()
    
    local lblock, lcond = newLabel(), newLabel()
    
    local lend = newLabel()
    pushBreak(lend)
    
    local new_env, pos_iter, pos_step, pos_end

    pos_iter, new_env = addVar(cmd.IndexName, env)
    pos_step, new_env = addVar("1_step", new_env)
    pos_end, new_env  = addVar("2_stop", new_env)

    genCodeExp(cmd.ExpStep, env)
    DUP(1)
    SET_LOCAL(0, pos_step)
    -- vê se é 0
    PUSH_NUMBER(0)
    EQ()
    JUMP_FALSE(l_jump_error)
    ERROR("step in for loop equal to 0")
    writeLabel(l_jump_error)

    -- preenche iterador e end
    genCodeExp(cmd.ExpStart, env)
    genCodeExp(cmd.ExpEnd, env)
    SET_LOCAL(0, pos_end)
    SET_LOCAL(0, pos_iter)

    JUMP(lcond)
    writeLabel(lblock)
    genCodeCmd(cmd.Block, new_env)

    -- iter = iter + step
    PUSH_NUMBER(1)
    GET_LOCAL(0, pos_iter)
    ADD()
    SET_LOCAL(0, pos_iter)

    -- agora a parte chata do condicional
    writeLabel(lcond) -- poderia adicionar uma expressão imensa e gerar cond
    -- algo como (step>0 and iter <= end) or (step < 0 and iter >= end) jump_true lblock
    local bigexp = makeBinop("OR",
        makeBinop("AND",
            makeBinop(">", makeExpName("1_step"), makeExpInt(0)),
            makeBinop("<=", makeExpName(cmd.IndexName), makeExpName("2_stop"))),
        makeBinop("AND",
            makeBinop("<", makeExpName("1_step"), makeExpInt(0)),
            makeBinop(">=", makeExpName(cmd.IndexName), makeExpName("2_stop")))
    )
    genJmp(bigexp, new_env, lblock, nil)

    writeLabel(lend)
    popBreak()
    -- acho que é isso aqui.
end


-- vou ter que trocar, mas já sei de uma forma melhor, encapsular

local function genSet(cmd, env)
    local needed_variables = #cmd.ExpSetList
    local val_size = #cmd.ExpValList

    local last = 0
    if val_size < needed_variables then
        genCodeExp(cmd.ExpValList[val_size], env, nil, nil, needed_variables - val_size + 1)
        last = 1 -- we already computed the last value
    end

    for i = val_size - last, 1, -1 do
        genCodeExp(cmd.ExpValList[i], env)
    end

    -- check if we need a set list or not
    local hasTblIndex = false
    for i = 1, needed_variables do
        if cmd.ExpSetList[i].Tag == "EXPTBLINDEX" then
            hasTblIndex = true
            break
        end
    end

    if hasTblIndex then
        for i = needed_variables, 1, -1 do
            local set = cmd.ExpSetList[i]
            if set.Tag == "EXPTBLINDEX" then
                genCodeExp(set.Table, env)
                genCodeExp(set.Index, env)
                ENCAP_TBLSET()
            else -- expname
                local n_jump, n_var = getVarNumber(set.Value, env)
                if n_jump then
                    ENCAP_LOCAL(n_jump, n_var)
                else
                    ENCAP_GLOBAL(set.Value)
                end
            end
        end
        SETLIST(needed_variables)
    else
        -- everything is a name
        for i = 1, needed_variables do
            local set = cmd.ExpSetList[i]

            local n_jump, n_var = getVarNumber(set.Value, env)
            
            if n_jump then
                SET_LOCAL(n_jump, n_var)
            else
                SET_GLOBAL(set.Value)
            end
        end
    end

    -- pop valores desnecessarios
    if needed_variables < val_size then
        POP(val_size - needed_variables)
    end
end


local function genLocalSet(cmd, env)
    local needed_variables = #cmd.Names
    local val_size = #cmd.ExpValList

    if val_size > 0 then
        local last = 0
        if val_size < needed_variables then
            genCodeExp(cmd.ExpValList[val_size], env, nil, nil, needed_variables - val_size + 1)
            last = 1 -- we already computed the last value
        end
        
        for i = val_size - last, 1, -1 do
            genCodeExp(cmd.ExpValList[i], env)
        end
    else
        for _ = 1, needed_variables do
            PUSH_NIL()
        end
    end

    local new_env = env
    for i = 1, needed_variables do
        local pos
        pos, new_env = addVar(cmd.Names[i], new_env)
        SET_LOCAL(0, pos)
    end

    -- pop valores desnecessarios
    if needed_variables < val_size then
        POP(val_size - needed_variables)
    end

    genCodeCmd(cmd.Block, new_env)
end


function genCodeCmd(cmd, env)
    if cmd.Tag == "CMDRETURN" then
        genReturn(cmd, env)
        return
    end

    if cmd.Tag == "CMDSETLIST" then
        genSet(cmd, env)
        return
    end

    if cmd.Tag == "CMDCALL" then
        genCall(cmd, env, 0)
        return
    end

    if cmd.Tag == "CMDLOCALSET" then
        genLocalSet(cmd, env)
        return
    end

    if cmd.Tag == "CMDIF" then
        genIf(cmd, env)
        return
        -- genError("ainda nao implementado")
    end

    if cmd.Tag == "CMDWHILE" then
        genWhile(cmd, env)
        return
    end

    if cmd.Tag == "CMDBLOCK" then
        for i = 1, #cmd.Cmds do
            local ret = genCodeCmd(cmd.Cmds[i], env)
            if ret then return ret end
        end
        return
    end
    
    if cmd.Tag == "CMDFOR" then
        genFor(cmd, env)
        return
    end
    
    if cmd.Tag == "CMDBREAK" then
        JUMP(topBreak())
        return
    end

    genError(string.format("Couldn't evaluate command %s", cmd.Tag))
end


function genClosure(exp, env)
    -- make new env for function
    local newenv = newFunctionEnv(env)
    for i = 1, #exp.Params do
        _, newenv = addVar(exp.Params[i], newenv)
    end

    -- push new function to stack
    local fn = pushNewFunction(#exp.Params)
    genCodeCmd(exp.CmdBody, newenv)
    popFuncStack()

    CLOSURE(FnLabel(fn))
end

-- o a única coisa que posso fazer é dizer "estou retornando pelo menos x coisas"
-- pois poderia ter return 1,2, g()
-- onde g() pode retornar uma quantidade variada de objetos dependendo da execução do código


-- SOLUÇÃO
-- Toda função retorna um objeto RETLIST, que podemos dar UNPACK
-- A função return diz o tamanho do RETLIST
-- se uma função nao tiver return, então o RETLIST tem tamanho 0 (mas ele existe!)
-- se uma função for chamada com expected ret = 0, ai sim, não empilhamos o retlist
function genReturn(cmd, env)
    local n_returned = #cmd.ExpRetList
    if n_returned == 0 then
        RETURN(0)
    else
        genCodeExp(cmd.ExpRetList[n_returned],env, nil, nil, -1) -- -1 here stands for any amount of return 
        for i = n_returned - 1, 1, -1 do
            genCodeExp(cmd.ExpRetList[i], env)
        end
        RETURN(n_returned)
    end
end

-- EXECUCAO
local f0_env = AddBaseNode(nil)
local b = parseBloco(PS)
genCodeCmd(b, f0_env)
EXIT()


local function slow_concat(tbl)
    local str = ""
    for i = 1, #tbl do
        str = str .. tbl[i]
    end
    return str
end

local function FN_DECLARATION(fn_number)
    print("FUNCTION "..FnLabel(fn_number).." "..tostring(CODE.Fns[fn_number].N_Args))
    -- my slow concat
    print(slow_concat(CODE.Fns[fn_number]))
end

for fns = 1, #CODE.Fns do
    FN_DECLARATION(fns)
end
