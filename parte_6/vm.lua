-- READING AND ASSEMBLING
-- INSTRUCTION/LABEL READING

local file_bytecode = assert(io.open(arg[1],"r"), "could not open file " .. arg[1])
io.input(file_bytecode)

local inspect = require("inspect")

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

local function makeInst(instruction, args)
    if #args > 0 then
        return { instruction, args } -- não fiz tagged para ser um pouquinho mais rápido
    else
        return { instruction }
    end
end

local function makeFn(instructions, n_args)
    return { instructions, n_args }
end

-- returns instruction or label or func declaration
local function read_line(line)
    -- returns a tag of what the line represents (tag, something, something)
    -- eh push string?
    local first_tok, second_tok, third_tok
    local is_push_str = string.find(line, "PUSH_STRING")
    local is_error = string.find(line,"ERROR")

    if is_push_str or is_error then
        local first_quotes = string.find(line, '"')
        if not first_quotes then error("didn't find beginning of string") end
        local last_quotes = string.find(string.reverse(line), '"')
        second_tok = string.sub(line, first_quotes + 1, string.len(line) - last_quotes)
        local tag = (is_push_str and "PUSH_STRING") or (is_error and "ERROR") 

        return { Tag = "INSTRUCTION", Inst = makeInst(tag, { prepare_string(second_tok) }) }
    end

    local pattern = "^%s*(%S+)%s*(%S*)%s*(%S*)%s*$"
    first_tok, second_tok, third_tok = string.match(line, pattern)

    if string.sub(first_tok, -1, -1) == ":" then
        return { Tag = "LABEL", Label = string.sub(first_tok, 1, -2) }
    end

    if first_tok == "FUNCTION" then
        return { Tag = "FUNCTION", Label = second_tok, N_Args = third_tok } -- everything is a string
    end

    -- else is an instruction
    local args = {}
    if second_tok ~= "" then
        args[1] = second_tok
    end
    if third_tok ~= "" then
        args[2] = third_tok
    end
    return { Tag = "INSTRUCTION", Inst = makeInst(first_tok, args) }
end

local function separate_functions(tagged_lines)
    local separated_funcs = {}
    local curr_func = {}

    for i = 1, #tagged_lines do
        table.insert(curr_func, tagged_lines[i])
        if i < #tagged_lines then
            if tagged_lines[i + 1].Tag == "FUNCTION" then
                table.insert(separated_funcs, curr_func)
                curr_func = {}
            end
        end
    end
    table.insert(separated_funcs, curr_func)
    return separated_funcs
end

local function read_program()
    local line = io.read("l")
    local tagged_lines = {}
    while line do
        if string.len(line) > 0 then
            tagged_lines[#tagged_lines + 1] = read_line(line)
        end
        line = io.read("l")
    end

    local sep_fn = separate_functions(tagged_lines)
    local funcs = {}
    local label_funcs = {}

    for i = 1, #sep_fn do
        local lines = sep_fn[i]

        local fn_label, fn_args = lines[1].Label, lines[1].N_Args -- a primeira é sempre FUNCTION L N
        local labels = {}
        local fn_insts = {}

        for j = 2, #lines do
            if lines[j].Tag == "LABEL" then
                labels[lines[j].Label] = #fn_insts + 1
            elseif lines[j].Tag == "INSTRUCTION" then
                fn_insts[#fn_insts + 1] = lines[j].Inst
            end
        end

        funcs[#funcs + 1] = { FnInstructions = fn_insts, Labels = labels, N_Args = fn_args } -- still everythign is a string
        label_funcs[fn_label] = #funcs
    end
    return { funcs, label_funcs }
end

local function is_jmp(inst_tag)
    return inst_tag == "JUMP" or inst_tag == "JUMP_TRUE" or inst_tag == "JUMP_FALSE"
        or inst_tag == "JUMP_TRUE_OR_POP" or inst_tag == "JUMP_FALSE_OR_POP"
end

local function uses_string(inst_tag)
    return inst_tag == "PUSH_STRING" or inst_tag == "SET_GLOBAL" or
        inst_tag == "GET_GLOBAL" or inst_tag == "ENCAP_GLOBAL" or
        inst_tag == "ERROR"
end

-- assemble program retorna o programa como instruções de maquina.
-- não há mais valores representados em string a não ser strings e nomes globais
-- todas as labels e argumentos já são números
local function assemble_program(compiled)
    Prog = {}
    for i = 1, #compiled[1] do
        local F = compiled[1][i]
        for j = 1, #F.FnInstructions do
            local inst = F.FnInstructions[j]
            local inst_tag = inst[1]

            -- se não tem arg joga fora
            if is_jmp(inst_tag) then
                inst[2][1] = F.Labels[inst[2][1]]
            elseif inst_tag == "CLOSURE" then
                inst[2][1] = compiled[2][inst[2][1]]
            elseif not uses_string(inst_tag) then -- os argumentos sao numeros
                if inst[2] then
                    if inst[2][1] then inst[2][1] = tonumber(inst[2][1]) end
                    if inst[2][2] then inst[2][2] = tonumber(inst[2][2]) end
                end
            end
        end
        table.insert(Prog, makeFn(F.FnInstructions, tonumber(F.N_Args)))
    end
    return Prog
end


-- VM vals
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

local function makeValLuaFunc(env, fn_number)
    return { Tag = "VALLUAFUNC", Env = env, FnNumber = fn_number }
end

local function makeValReturnList(valList)
    if #valList == 1 then return valList[1] end
    return { Tag = "VALLISTRET", Values = valList }
end

local function make_LVal_Tbl(tbl, key)
    return { Tag = "LVALTBL", Tbl = tbl, Index = key}
end

local function make_LVal_Local(n_jumps, n_var)
    return { Tag = "LVALLOCAL", N_Jumps = n_jumps, N_Var = n_var}
end

local function make_LVal_Global(global_name)
    return { Tag = "LVALGLOBAL", GlobalName = global_name}
end

--conditionals

local function isCondFalse(runtime)
    return runtime.Tag == "VALNIL" or (runtime.Tag == "VALBOOL" and runtime.Val == false)
end

local function isCondTrue(v)
    return not isCondFalse(v)
end



-- VM


-- VM ENVIRONMENT
-- depois de muita dor de cabeça, acho que entendi minha confusão.
-- environments são LISTAS (hash tables) em cada nivel de função.

--[[
    ENV = {UP_ENV, [0|1|2|3|4|5 ... ]}
    Na main, UP_ENV = nil
    em todas as outras, usamos o UP_ENV da criação da função.
]]

local function makeEnv(upEnv)
    return { Up = upEnv, Locals = {} }
end

local function getLocal(env, n_jumps, n_var)
    for _ = 1, n_jumps do
        env = env.Up
    end
    return env.Locals[n_var]
end

local function setLocal(env, n_jumps, n_var, val)
    for _ = 1, n_jumps do
        env = env.Up
    end
    env.Locals[n_var] = val
end


-- vm helpers
-- essa é a função de unpack
-- ela serve somente quando não sabemos quantas variaveis estamos retornando
-- isso é, quando chamamos uma função f(1,2,g()) - g tendo retorno multiplo
-- ou quando uma função retorna sem saber o número exato
-- return 1, 2, g()
local function treat_list(args)
    if #args > 0 and args[#args].Tag == "VALLISTRET" then
        local last = args[#args]

        args[#args] = nil -- might be empty
        for i = 1, #last.Values do
            args[#args + 1] = last.Values[i]
        end
    end
    return args
end

local function vm_top(vm)
    return vm.MemStack[#vm.MemStack]
end

local function vm_pop(vm)
    if #vm.MemStack == 0 then
        error("stack empty!")
    end
    local popped = vm.MemStack[#vm.MemStack]
    table.remove(vm.MemStack, #vm.MemStack)
    return popped
end

local function vm_push(vm, val)
    table.insert(vm.MemStack, val)
end


local function vm_saveframe(vm)
    vm.CallStack[#vm.CallStack + 1] = { vm.CurrentF, vm.PC, vm.Env, vm.ExpectedRet }
end

-- WARNING, PODE RETORNAR NIL SE CALLSTACK VAZIO! (util para main)
local function vm_popframe(vm)
    local popped = vm.CallStack[#vm.CallStack]
    vm.CallStack[#vm.CallStack] = nil
    return popped
end

local function vm_newframe(vm, f_number, pc, env, expected_ret)
    vm.CurrentF = f_number
    vm.PC = pc
    vm.Env = env
    vm.ExpectedRet = expected_ret
end

local function call(vm, f, f_args, n_ret)
    if f.Tag == "VALLIBFUNC" then
        local ret = f.F(f_args)
        if ret.Tag ~= "VALNIL" then
            vm_push(vm, ret)
        end
        vm.PC = vm.PC + 1
        return
    end

    -- valluafunc
    vm.PC = vm.PC + 1 -- save return pointer!
    vm_saveframe(vm) -- save old frame in callstack
    
    local f_number = f.FnNumber
    local num_param = vm.Fns[f_number][2]
    local new_env = makeEnv(f.Env)

    
    for i = 1, num_param do
        if i <= #f_args then
            setLocal(new_env, 0, i, f_args[i])
        end
    end
    
    vm_newframe(vm, f_number, 1, new_env, n_ret)
end

local function ret(vm, f_rets)
    if vm.ExpectedRet == -1 then
        vm_push(vm, makeValReturnList(f_rets))
    else
        for i = vm.ExpectedRet, 1, -1 do
            if f_rets[i] then
                vm_push(vm, f_rets[i])
            else
                vm_push(vm, makeValNil())
            end
        end
    end

    local old_frame = vm_popframe(vm)

    if old_frame == nil then
        -- pilha vazia, estamos na main e retornamos
        os.exit(0)
    end

    --volta para função chamadoras
    vm_newframe(vm, old_frame[1], old_frame[2], old_frame[3], old_frame[4])
end


local function setlist(vm, sets, values)
    local n = #sets
    for i = 1, n do
        local lval = sets[i]
        if lval.Tag == "LVALLOCAL" then
            setLocal(vm.Env, lval.N_Jumps, lval.N_Var, values[i])
        elseif lval.Tag == "LVALGLOBAL" then
            vm.Globals[lval.GlobalName] = values[i]
        else -- lval.Tag == "LVALTBL"
            lval.Tbl.Val[lval.Index.Val] = values[i]
        end
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
        vm_push(vm, makeValString(args[1]))
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
        local v = tbl.Val[key.Val]
        if v then
            vm_push(vm, v)
        else 
            vm_push(vm, makeValNil())
        end
        vm.PC = vm.PC + 1
    end,

    ["SET_TABLE"] = function(vm)
        local val = vm_pop(vm)
        local key = vm_pop(vm)
        local tbl = vm_pop(vm)
        tbl.Val[key.Val] = val
        vm.PC = vm.PC + 1
    end,

    -- LOCAIS
    ["GET_LOCAL"] = function(vm, args)
        vm_push(vm, getLocal(vm.Env, args[1], args[2]))
        vm.PC = vm.PC + 1
    end,

    ["SET_LOCAL"] = function(vm, args)
        local val = vm_pop(vm)
        setLocal(vm.Env, args[1], args[2], val)
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

    -- FUNÇÕES
    ["CLOSURE"] = function(vm, args)
        vm_push(vm, makeValLuaFunc(vm.Env, args[1]))
        vm.PC = vm.PC + 1
    end,

    ["CALL"] = function(vm, args)
        local n_args = args[1]
        local f_args = {}
        for pos = 1, n_args do
            f_args[pos] = vm_pop(vm)
        end

        f_args = treat_list(f_args)
        local f = vm_pop(vm)

        local n_ret = args[2]
        call(vm, f, f_args, n_ret)
    end,

    ["RETURN"] = function(vm, args)
        local n_ret = args[1]
        local f_rets = {}
        for pos = 1, n_ret do
            f_rets[pos] = vm_pop(vm)
        end
        f_rets = treat_list(f_rets)
        
        ret(vm, f_rets)
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
        vm_push(vm, makeValBool(a.Val == b.Val))
        vm.PC = vm.PC + 1
    end,

    ["NEQ"] = function(vm)
        local b = vm_pop(vm)
        local a = vm_pop(vm)
        vm_push(vm, makeValBool(a.Val ~= b.Val))
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
        vm.PC = args[1]
    end,

    ["JUMP_TRUE"] = function(vm, args)
        local b = vm_pop(vm)
        if isCondTrue(b) then
            vm.PC = args[1]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE"] = function(vm, args)
        local b = vm_pop(vm)
        if isCondFalse(b) then
            vm.PC = args[1]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_TRUE_OR_POP"] = function(vm, args)
        local b = vm_top(vm)
        if isCondTrue(b) then
            vm.PC = args[1]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE_OR_POP"] = function(vm, args)
        local b = vm_top(vm)
        if isCondFalse(b) then
            vm.PC = args[1]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["POP"] = function(vm, args)
        for _ = 1, tonumber(args[1]) do
            vm_pop(vm)
        end
        vm.PC = vm.PC + 1
    end,

    ["EXIT"] = function()
        os.exit(1)
    end,

    -- EXTRAS
    ["DUP"] = function(vm, args)
        local n = args[1]
        for _ = 1, n do
            vm_push(vm, vm_top(vm))
        end
        vm.PC = vm.PC + 1
    end,

    ["ENCAP_LOCAL"] = function (vm, args)
        vm_push(vm, make_LVal_Local(args[1],args[2]))
        vm.PC = vm.PC + 1
    end,

    ["ENCAP_GLOBAL"] = function (vm, args)
        vm_push(vm, make_LVal_Global(args[1]))
        vm.PC = vm.PC + 1
    end,

    ["ENCAP_TBLSET"] = function (vm)
        local index = vm_pop(vm)
        local tbl = vm_pop(vm)
        vm_push(vm, make_LVal_Tbl(tbl,index))
        vm.PC = vm.PC + 1
    end,

    ["SETLIST"] = function (vm, args)
        local n = args[1]
        local sets = {}
        local values = {}
        for i = 1, n do
            sets[i] = vm_pop(vm)
        end

        for i = 1, n do
            values[i] = vm_pop(vm)
        end

        setlist(vm, sets, values)
        vm.PC = vm.PC + 1
    end,

    ["ERROR"] = function (vm, args)
        print(string.format("error: %s",args[1]))
        os.exit(1)
    end
}


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
                    return makeValString(string.sub(str, i, j))
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
                    return makeValInt(string.byte(s))
                end
            ),

        }
    )
}


local function run_inst(vm, inst)
    local inst_function = table_instructions[inst[1]]
    local args = inst[2]
    inst_function(vm, args)
end

local function run_vm(vm)
    while true do
        if vm.PC > #vm.Fns[vm.CurrentF][1] then -- function withou return
            ret(vm, 0)
        end
        local inst = vm.Fns[vm.CurrentF][1][vm.PC]
        -- print(vm.CurrentF, vm.PC, inspect(inst))
        run_inst(vm, inst)
    end
end

Compiled_Prog = read_program()
Assembled_Prog = assemble_program(Compiled_Prog)

-- print(inspect(Assembled_Prog))

local mainEnv = makeEnv(nil)
-- VM STARTS RUNNING MAIN
VM = {
    CurrentF = 1,
    PC = 1,
    Env = mainEnv,
    ExpectedRet = 0,
    MemStack = {},
    CallStack = {}, -- has func, pc, env, expected_ret
    Fns = Assembled_Prog,
    Globals = GlobalEnv
}


run_vm(VM)
