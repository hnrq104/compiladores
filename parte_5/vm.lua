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

local function isCondFalse(runtime)
    return runtime.Tag == "VALNIL" or (runtime.Tag == "VALBOOL" and runtime.Val == false)
end

local function isCondTrue(v)
    return not isCondFalse(v)
end



-- READING AND EXECUTING COMPILED CODE

-- INSTRUCTION/LABEL READING
local function makeInst(instruction, args)
    return { instruction, args }
end

-- returns instruction or label str if label
local function read_line(line)
    local pattern = "^%s*(%S+)%s*(%S*)%s*(%S*)%s*$"
    local first_tok, second_tok, third_tok = string.match(line, pattern)
    if string.sub(first_tok, -1, -1) == ":" then
        return nil, string.sub(first_tok, 1, -2)
    end

    if first_tok == "PUSH_STRING" then
        local first_quotes = string.find(line, '"')
        if not first_quotes then error("didn't find beginning of string") end
        local last_quotes = string.find(string.reverse(line), '"')
        second_tok = string.sub(line, first_quotes + 1, string.len(line) - last_quotes)
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


VM = {
    Stack = {},
    PC = 1,
    Prog = read_program(),
    Globals = {}
}

local inspect = require("inspect")

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

local function call(f, args)
    error("nao implementado ainda")
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
        vm_push(tbl.Val[key.Val])
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
        local a = vm_pop(vm)
        local b = vm_pop(vm)
        if a.Tag == "VALSTR" and b.Tag == "VALSTR" then
            vm_push(vm, makeValInt(a.Val + b.Val))
        else
            error("trying to .. stuff that isn't string")
        end
        vm.PC = vm.PC + 1

    end,

    ["EQ"] = function(vm)
        local a = vm_pop(vm)
        local b = vm_pop(vm)
        vm_push(makeValBool(a.Val == b.Val))
        vm.PC = vm.PC + 1

    end,

    ["NEQ"] = function(vm)
        local top = vm_pop(vm)
        local bot = vm_pop(vm)
        vm_push(makeValBool(bot.Val ~= top.Val))
        vm.PC = vm.PC + 1

    end,
    
    ["LT"] = function(vm)
        local top = vm_pop(vm)
        local bot = vm_pop(vm)
        if bot.Tag == "VALINT" and top.Tag == "VALINT" then
            vm_push(vm, makeValBool(bot.Val < top.Val))
        else
            error("trying to < stuff that isn't number")
        end
        vm.PC = vm.PC + 1

    end,

    ["LEQ"] = function(vm)
        local top = vm_pop(vm)
        local bot = vm_pop(vm)
        if bot.Tag == "VALINT" and top.Tag == "VALINT" then
            vm_push(vm, makeValBool(bot.Val <= top.Val))
        else
            error("trying to <= stuff that isn't number")
        end
        vm.PC = vm.PC + 1

    end,

    ["GT"] = function(vm)
        local a = vm_pop(vm)
        local b = vm_pop(vm)
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
    ["JUMP"] = function (vm, args)
        vm.PC = vm.Prog.LabelSet[args[1]]
    end,

    ["JUMP_TRUE"] = function (vm, args)
        local b = vm_pop(vm)
        if isCondTrue(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE"] = function (vm, args)
        local b = vm_pop(vm)
        if isCondFalse(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_TRUE_OR_POP"] = function (vm, args)
        local b = vm_top(vm)
        if isCondTrue(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["JUMP_FALSE_OR_POP"] = function (vm, args)
        local b = vm_top(vm)
        if isCondFalse(b) then
            vm.PC = vm.Prog.LabelSet[args[1]]
        else
            vm_pop(vm)
            vm.PC = vm.PC + 1
        end
    end,

    ["CALL"] = function (vm, args)
        local n_args = tonumber(args[1])
        local f_args = {}
        for _ = 1, n_args do
            table.insert(f_args,vm_pop(vm))
        end
        local f = vm_pop(vm)

        call(f,f_args)
    end,

    ["POP"] = function (vm, args)
        for _ = 1, tonumber(args[1]) do
            vm_pop(vm)
        end
        vm.PC = vm.PC + 1

    end,

    ["EXIT"] = function (vm)
        print("EXITING PROGRAM EXEC")
        os.exit(1)
    end

}



local function run_inst(vm, inst)
    -- this is equivalent to a switch case, i don't know if it's faster than a bazillion ifs
    local inst_function = table_instructions[inst[1]]
    local args = inst[2]
    inst_function(vm,args)
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

run_vm(VM)
print(inspect(VM))
