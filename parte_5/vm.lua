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

-- Trabalho 4
local function makeValLuaFunc(env, params, body)
    return { Tag = "VALLUAFUNC", Params = params, Body = body, Env = env }
end

local function makeValLibFunc(func)
    return { Tag = "VALLIBFUNC", F = func }
end

local function makeValReturnList(valList)
    if #valList == 0 then return makeValNil() end
    if #valList == 1 then return valList[1] end
    return { Tag = "VALLISTRET", Values = valList }
end

local function isCondFalse(runtime)
    return runtime.Tag == "VALNIL" or (runtime.Tag == "VALBOOL" and runtime.Val == false)
end

local function isCondTrue(v)
    return not isCondFalse(v)
end


--- FUNCOES DE AMBIENTE

-- Cria ambiente base
local function makeBaseEnv(globals)
    return {
        Tag = "BASENODE",
        Globals = globals
    }
end

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

-- AMBIENTE BASE
-- Cria ambiente base com minha versão de funcoes da lib padrao

-- funcoes que tratam erros
local function unbox(runtimeval, tipo)
    if runtimeval.Tag ~= tipo then
        error("funcao esperava :" .. tipo .. " recebeu :" .. runtimeval.Tag)
    end

    return runtimeval.Val
end

local function argsize(args, atleast, fname)
    if #args >= atleast then
        return true
    end

    error("function " .. fname .. " expected " .. tostring(atleast) .. " arguments")
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


    ["table"] = makeValTbl(
        {
            ["unpack"] = makeValLibFunc(
                function(list_tbl)
                    if #list_tbl < 1 or list_tbl[1].Tag ~= "VALTBL" then
                        genError("unpack precisa de um argumento tabela")
                    end
                    local unpk = {}
                    for i = 1, #list_tbl[1].Val do
                        unpk[#unpk + 1] = list_tbl[1].Val[i]
                    end
                    return makeValReturnList(unpk)
                end
            )
        }
    ),

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
