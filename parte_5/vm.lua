-- PREVIOUS STUFF
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

local function makeValLibFunc(func)
    return { Tag = "VALLIBFUNC", F = func }
end

local function isCondFalse(runtime)
    return runtime.Tag == "VALNIL" or (runtime.Tag == "VALBOOL" and runtime.Val == false)
end

local function isCondTrue(v)
    return not isCondFalse(v)
end

-- doesn't really work
local string_rep_table = {
    ["\\n"] = "\n",
    ["\\t"] = "\t",
    ["\\\\"] = "\\",

}
-- decode strings
local function prepare_string(str)
    local s = string.gsub(str, '\\[\\nt]', string_rep_table)
    return s
end


-- funcoes que tratam erros
local function unbox(runtimeval, tipo)
    if runtimeval.Tag ~= tipo then
        error(string.format("funcao esperava : %s recebeu : %s", tipo, runtimeval.Tag))
    end

    return runtimeval.Val
end

local function argsize(args, atleast, fname)
    if #args >= atleast then
        return true
    end

    error(string.format("function %s expected %d arguments", fname, atleast))
end


--Separei global env aqui para facilitar modifica-lo
local GlobalEnv = {
    ["print"] = makeValLibFunc(
        function(args)
            for i = 1, #args do
                io.write(tostring(args[i].Val))
                if i < #args then
                    io.write(" ")
                end
            end
            io.write("\n")
            return makeValNil()
        end
    ),

    ["tostring"] = makeValLibFunc( -- isso é levemente ineficiente pois pode dar tostring("em uma string")
        function(args)
            argsize(args, 1, "tostring")
            if args[1].Tag == "VALTBL" then
                return makeValString(tostring(args[1]))
            elseif args[1].Tag == "VALLUAFUNC" or args[1].Tag == "VALLIBFUNC" then
                return makeValString("function in " .. tostring(args[1]))
            end

            return makeValString(tostring(args[1].Val))
        end
    ),

    ["error"] = makeValLibFunc(
        function(args)
            if #args >= 1 then
                error(tostring(args[1].Val))
            end
            error()
            return makeValNil()
        end
    ),

    ["io"] = makeValTbl({ -- tabela IO
        ["write"] = makeValLibFunc(
            function(args)
                if #args > 0 then
                    io.write(tostring(args[1].Val))
                end
                return makeValNil() -- geralmente retorna o ponteiro para a file, nao aqui
            end
        ),

        ["read"] = makeValLibFunc(
            function(nchars)
                local c
                local n = 1
                if #nchars > 1 then
                    n = unbox(nchars[1], "VALINT")
                end
                c = io.read(n)
                if c == nil then
                    return makeValNil()
                end
                return makeValString(c)
            end
        )
    }),

    ["math"] = makeValTbl({
        ["sqrt"] = makeValLibFunc(
            function(args)
                argsize(args, 1, "math.sqrt")
                local n = unbox(args[1], "VALINT")
                return makeValInt(math.sqrt(n))
            end
        )
    }),


    ["string"] = makeValTbl(
        {
            ["len"] = makeValLibFunc(
                function(args)
                    argsize(args, 1, "string.len")
                    local s = unbox(args[1], "VALSTR")
                    return makeValInt(string.len(s))
                end
            ),

            ["sub"] = makeValLibFunc(
                function(args)
                    argsize(args, 3, "string.sub")
                    local str  = unbox(args[1], "VALSTR")
                    local i, j = unbox(args[2], "VALINT"), unbox(args[3], "VALINT")
                    return makeValInt(string.sub(str, i, j))
                end
            ),

            ["char"] = makeValLibFunc(
                function(args)
                    argsize(args, 1, "string.char")
                    local n = unbox(args[1], "VALINT")
                    return makeValString(string.char(n))
                end
            ),

            ["byte"] = makeValLibFunc(
                function(args)
                    argsize(args, 1, "string.byte")
                    local s = unbox(args[1], "VALSTR")
                    return makeValString(string.byte(s))
                end
            ),

        }
    )
}


-- READING AND EXECUTING COMPILED CODE

-- INSTRUCTION/LABEL READING
local function makeInst(instruction, args)
    return { instruction, args }
end

-- returns instruction or label str if label
local function read_line(line)
    -- eh push string?
    local first_tok, second_tok, third_tok
    local is_push_str = string.find(line, "PUSH_STRING")

    if is_push_str then
        local first_quotes = string.find(line, '"')
        if not first_quotes then error("didn't find beginning of string") end
        local last_quotes = string.find(string.reverse(line), '"')
        second_tok = string.sub(line, first_quotes + 1, string.len(line) - last_quotes)
        return makeInst("PUSH_STRING", { second_tok })
    end

    local pattern = "^%s*(%S+)%s*(%S*)%s*(%S*)%s*$"
    first_tok, second_tok, third_tok = string.match(line, pattern)

    if string.sub(first_tok, -1, -1) == ":" then
        return nil, string.sub(first_tok, 1, -2)
    end


    local args = { second_tok, third_tok }
    return makeInst(first_tok, args)
end

-- RETURNS PROGRAM LIST WITH LABELS ALREADY TRANSFORMED INTO NUMBERS
local function read_program()
    local instructions = {}
    local label_set = {}


    local line = io.read("l")
    while line do
        local inst, label = read_line(line)
        if label then
            label_set[label] = #instructions + 1
        else -- its an instruction
            instructions[#instructions + 1] = inst
        end
        line = io.read("l")
    end
    return { Insts = instructions, LabelSet = label_set }
end

local function is_exit(inst)
    return inst[1] == "EXIT"
end

local function vm_top(vm)
    return vm.Stack[#vm.Stack]
end

local function vm_pop(vm)
    if #vm.Stack == 0 then
        error("stack empty!")
    end
    local popped = vm.Stack[#vm.Stack]
    table.remove(vm.Stack, #vm.Stack)
    return popped
end

local function vm_push(vm, val)
    table.insert(vm.Stack, val)
end

local function call(vm, f, args)
    if f.Tag == "VALLIBFUNC" then
        local ret = f.F(args)
        if ret.Tag ~= "VALNIL" then
            vm_push(vm, ret)
        end
    else
        error("nao implementado ainda")
    end
end

-- fazer um switch-case pode ser mais rápido que o usual!
local table_instructions = {
    -- PUSHS
    ["PUSH_NIL"] = function(vm)
        vm_push(vm, makeValNil())
        vm.PC = vm.PC + 1
    end,

    ["PUSH_TRUE"] = function(vm)
        vm_push(vm, makeValBool(true))
        vm.PC = vm.PC + 1
    end,

    ["PUSH_FALSE"] = function(vm)
        vm_push(vm, makeValBool(false))
        vm.PC = vm.PC + 1
    end,

    ["PUSH_NUMBER"] = function(vm, args)
        vm_push(vm, makeValInt(tonumber(args[1])))
        vm.PC = vm.PC + 1
    end,

    ["PUSH_STRING"] = function(vm, args)
        -- still need to parse string correctly
        vm_push(vm, makeValString(prepare_string(args[1])))
        vm.PC = vm.PC + 1
    end,


    -- TABLES
    ["NEW_TABLE"] = function(vm)
        vm_push(vm, makeValTbl({}))
        vm.PC = vm.PC + 1
    end,

    ["GET_TABLE"] = function(vm)
        local key = vm_pop(vm)
        local tbl = vm_pop(vm)
        vm_push(vm, tbl.Val[key.Val])
        vm.PC = vm.PC + 1
    end,

    ["SET_TABLE"] = function(vm)
        local val = vm_pop(vm)
        local key = vm_pop(vm)
        local tbl = vm_pop(vm)
        tbl.Val[key.Val] = val
        vm.PC = vm.PC + 1
    end,

    -- GLOBAIS
    ["GET_GLOBAL"] = function(vm, args)
        vm_push(vm, vm.Globals[args[1]] or makeValNil())
        vm.PC = vm.PC + 1
    end,

    ["SET_GLOBAL"] = function(vm, args)
        local val = vm_pop(vm)
        vm.Globals[args[1]] = val
        vm.PC = vm.PC + 1
    end,

    -- OPERADORES UNARIOS
    ["NEG"] = function(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" then
            vm_push(vm, makeValInt(-a.Val))
        else
            error("trying to neg non integer")
        end
        vm.PC = vm.PC + 1
    end,


    ["LEN"] = function(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALTBL" then
            vm_push(vm, makeValInt(#a.Val))
        else
            error("trying to len non table")
        end
        vm.PC = vm.PC + 1
    end,

    ["NOT"] = function(vm)
        local a = vm_pop(vm)
        vm_push(vm, makeValBool(not isCondTrue(a)))
        vm.PC = vm.PC + 1
    end,


    -- Binarias
    -- a op b
    -- generally b will be on top
    ["ADD"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValInt(a.Val + b.Val))
        else
            error("trying to + stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["SUB"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValInt(a.Val - b.Val))
        else
            error("trying to - stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["MUL"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValInt(a.Val * b.Val))
        else
            error("trying to * stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["DIV"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValInt(a.Val / b.Val))
        else
            error("trying to / stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["MOD"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValInt(a.Val % b.Val))
        else
            error("trying to % stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["CONCAT"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALSTR" and b.Tag == "VALSTR" then
            vm_push(vm, makeValInt(a.Val + b.Val))
        else
            error("trying to .. stuff that isn't string")
        end
        vm.PC = vm.PC + 1
    end,

    ["EQ"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        vm_push(makeValBool(a.Val == b.Val))
        vm.PC = vm.PC + 1
    end,

    ["NEQ"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        vm_push(makeValBool(a.Val ~= b.Val))
        vm.PC = vm.PC + 1
    end,

    ["LT"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValBool(a.Val < b.Val))
        else
            error("trying to < stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["LEQ"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValBool(a.Val <= b.Val))
        else
            error("trying to <= stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["GT"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValBool(a.Val > b.Val))
        else
            error("trying to > stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    ["GEQ"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        if a.Tag == "VALINT" and b.Tag == "VALINT" then
            vm_push(vm, makeValBool(a.Val >= b.Val))
        else
            error("trying to >= stuff that isn't number")
        end
        vm.PC = vm.PC + 1
    end,

    -- DESVIOS
    ["JUMP"] = function(vm, args)
        vm.PC = vm.Prog.LabelSet[args[1]]
    end,

    ["JUMP_TRUE"] = function(vm, args)
        local b = vm_pop(vm)
        if isCondTrue(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE"] = function(vm, args)
        local b = vm_pop(vm)
        if isCondFalse(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_TRUE_OR_POP"] = function(vm, args)
        local b = vm_top(vm)
        if isCondTrue(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE_OR_POP"] = function(vm, args)
        local b = vm_top(vm)
        if isCondFalse(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["CALL"] = function(vm, args)
        local n_args = tonumber(args[1])
        local f_args = {}
        for pos = n_args, 1, -1 do  -- temos colocar de trás para frente
            f_args[pos] = vm_pop(vm)
        end
        local f = vm_pop(vm)

        call(vm, f, f_args)
        vm.PC = vm.PC + 1
    end,

    ["POP"] = function(vm, args)
        for _ = 1, tonumber(args[1]) do
            vm_pop(vm)
        end
        vm.PC = vm.PC + 1
    end,

    ["EXIT"] = function()
        print("EXITING PROGRAM EXEC")
        os.exit(1)
    end,

    -- EXTRAS
    ["DUP"] = function(vm, args)
        local n = tonumber(args[1])
        for i = 1, n do
            vm_push(vm, vm_top(vm))
        end
        vm.PC = vm.PC + 1
    end

}



local function run_inst(vm, inst)
    -- this is equivalent to a switch case, i don't know if it's faster than a bazillion ifs
    local inst_function = table_instructions[inst[1]]
    local args = inst[2]
    inst_function(vm, args)
end


local function run_vm(vm)
    while true do
        local inst = vm.Prog.Insts[vm.PC]
        if is_exit(inst) then
            break
        end
        run_inst(vm, inst)
    end
end

VM = {
    Stack = {},
    PC = 1,
    Prog = read_program(),
    Globals = GlobalEnv
}

run_vm(VM)
