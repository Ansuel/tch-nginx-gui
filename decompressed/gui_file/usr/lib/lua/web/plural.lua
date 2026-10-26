-- This module implements the translation of gettext plural expressions
-- to a Lua function that when called will return the correct plural index value.
-- To achieve this it implements a lexer/parser that compiles the C like gettext
-- expression to a string containing the equivalent Lua code.
-- Then the string is compiledas a Lua function
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local concat = table.concat
local string = string
local find = string.find
local format = string.format
local setmetatable = setmetatable
local loadstring = loadstring

local remove = table.remove

--- Utility class to iterate over a sequence with look-ahead possibility
-- To simplify the lexer and parser
local Reader = {}
Reader.__index = Reader

--- Read the next item from the list
-- This consumes the item, it cannot be read again.
-- If already at the end it returns the default value for this reader
function Reader:read()
    local idx, len = self._idx, self._len
    if idx<len then
        idx = idx+1
        self._idx = idx
        return self._get(idx)
    else
        return self._default
    end
end

--- Return the item that the next read will return.
-- This will not consume the item
function Reader:peek()
    local idx, len = self._idx, self._len
    if idx<len then
        idx = idx + 1
        return self._get(idx)
    else
        return self._default
    end
end

--- return the current position 
-- This is informational only, handy for error messages
function Reader:pos()
    return self._idx
end

--- Check if we moved beyond the end of the sequence
function Reader:atend()
    return self._idx >= self._len
end

--- Create a Reader
-- @param data the sequence to iterate over (must support #)
-- @param get function(d, i) to retrieve item i from d (d will be data)
-- @param default the value to return when the sequence is exhausted
--                (this defaults to nil)
local function reader(data, get, default)
    local rdr = {
       _idx = 0;
       _len = #data;
       _default = default;
       _get = function(idx) return get(data, idx) end;
    }
    return setmetatable(rdr, Reader)
end

-- helper for stringreader
local function string_get(s, idx)
    return s:sub(idx, idx)
end

--- stringreader:expect
-- Check if the next char is what we expect and then consume it
-- @param c the expected char
-- @return true if next char was c (then it is read)
-- @return false if the next char was not c (it was not read)
local function string_expect(self, c)
    if self:peek()==c then
        self:read()
        return true
    else
        return false
    end
end

--- Create a reader for a string
-- @param s the string to iterate over
-- @retruns the reader
-- The default value is set to the empty string
-- An expect method is added to the reader
local function stringreader(s)
    local rdr = reader(s, string_get, '')
    rdr.expect = string_expect
    return rdr 
end

--- helper for table reader
local function table_get(t, idx)
    return t[idx]
end

--- Create a reader for an array table
local function tablereader(t)
    return reader(t, table_get)
end

--- Generate code for a math operator
-- ( * / % + - )
-- @param op the operator object
-- @param left the left operand
-- @param right the right operand
-- @returns an expression object
local function math_op(op, left, right)
    return {type='expr', token=format('(%s %s %s)', left.token, op.luatext, right.token)}
end

-- special handling for the division
-- it must do integer arithmatic so 1/2 must be 0, not 0.5
local function div_op(_, left, right)
    return {type='expr', token=format('math.floor(%s / %s)', left.token, right.token)}
end

--- Generate code for a comparison operator
-- ( == != < <= >= > )
-- @param op the operator object
-- @param left the left operand
-- @param right the right operand
-- @returns an expression object
local function cmp_op(op, left, right)
    return {type='expr', token=format('((%s %s %s) and 1 or 0)', left.token, op.luatext, right.token)}
end

--- Generate code for a boolean operator
-- ( && || )
-- @param op the operator object
-- @param left the left operand
-- @param right the right operand
-- @returns an expression object
local function bool_op(op, left, right)
    return {type='expr', token=format('(((%s~=0) %s (%s~=0)) and 1 or 0)', left.token, op.luatext, right.token)}
end

--- Generate the code for the ? part of the ?: operator
-- @param op the operator object
-- @param left the left operand
-- @param right the right operand
-- @returns an expression object
local function select_op(_, left, right)
    -- set the type to 'select' to enable error checking 
    return {type='select', token=format("%s or %s", left.token, right.token)} 
end

--- Generate the code for the : part of the ?: operator
-- @param op the operator object
-- @param left the left operand
-- @param right the right operand
-- @returns an expression object
local function cond_op(_, left, right)
    -- the right hand operand must be from a : expression
    if right.type ~= 'select' then
        return nil, "syntax error, ? missing :"
    end
    return {type='expr', token=format("((%s~=0) and %s)", left.token, right.token)}
end

--- Genrate code for the ! operator
-- @param op the operator object
-- @param right the right operand
-- @returns an expression object
local function not_op(_, right)
    return {type='expr', token=format('(((%s)==0) and 1 or 0)', right.token)}
end

--- The lexer, breaks up the expression string into an array of tokens
-- @param expr the string with the gettext expression
-- @returns the array of tokens
-- @returns nil, err in case of error
local function tokenize(expr)
    local tokens = {}
    local pos
    
    local function token(tokenstr, tokentype, priority, method, luatext, assoc)
        tokens[#tokens+1] = {
           type=tokentype, --the type of the token, one of
                           -- unop, unary operator (!)
                           -- binop, binary operator ( * / % + - && || ? : < <= >= > == !=)
                           -- var, the variable n
                           -- number, a number
                           -- ( 
                           -- )
                           -- expr, the result of an expression evaluation.
                           --       Not set by tokenize
                           -- select, the result of the : operator
                           --         Not set by tokenize
           token=tokenstr, -- the actual text
           priority=priority, --the priorty (lower number == higher priority)
           method = method, -- the function to call for an operator
           luatext = luatext or tokenstr, -- the Lua version of the operator eg for != this is ~=
           assoc = assoc or 'left' -- associativity, left or right
           
           --only type and token are mandatory 
        }
    end
    expr = stringreader(expr)
    while not expr:atend() do
        local c = expr:read()
        -- skip spaces
        while c and c:match('%s') do
            c = expr:read()
        end
        if c=='' then break end
        pos = expr:pos()
        if c:match('%d') then --number
            local n = {c}
            while expr:peek():match('%d') do
                n[#n+1] = expr:read()
            end
            token(concat(n, ''), 'number' )
        elseif c=='=' then
            if expr:peek()=='=' then
                expr:read()
                token('==', 'binop', 5, cmp_op)
            else
                return nil, format('syntax error (pos=%d), lone =', pos)
            end
        elseif c=='!' then
            if expr:expect('=') then
                token('!=', 'binop', 5, cmp_op, '~=')
            else
                token('!', 'unop', 1, not_op, nil, 'right')
            end
        elseif c=='&' then
            if expr:expect('&') then
                token('&&', 'binop', 6, bool_op, 'and')
            else
                return nil, format('syntax error (pos=%d), lone &', expr:pos())
            end
        elseif c=='|' then
            if expr:expect('|') then
                token('||', 'binop', 7, bool_op, 'or')
            else
                return nil, format('sysntax error (pos=%d), lone |', expr:pos())
            end
        elseif c=='<' then
            if expr:expect('=') then
                token('<=', 'binop', 4, cmp_op)
            else
                token('<', 'binop', 4, cmp_op)
            end
        elseif c=='>' then
            if expr:expect('=') then
                token('>=', 'binop', 4, cmp_op)
            else
                token('>', 'binop', 4, cmp_op)
            end
        elseif c=='n' then
            token(c, 'var')
        elseif (c=='*') or (c=='%') then
            token(c, 'binop', 2, math_op)
        elseif c=='/' then
            -- division is special, to ensure integer math.
            token(c, 'binop', 2, div_op)
        elseif (c=='+') or (c=='-') then
            token(c, 'binop', 3, math_op)
        elseif c=='?' then
            token(c, 'binop', 8, cond_op, nil, 'right')
        elseif c==':' then
            token(c, 'binop', 8, select_op, nil, 'right')
        elseif find('()', c, 1, true) then
            token(c, c)
        else
            return nil, format('syntax error (pos %d), unexpected %s', expr:pos(), c)
        end
    end
    return tokens
end

--- Reduce an array of operands and operators to a single expression
-- the must be syntactically correct (ensured by the parser)
-- @param binop the expression array
-- @return the resulting single expression object
--         or nil, err
local function binop_reduce(binop)
    while true do
        -- find the highest priority operator
        local prio = 100 --lower than low
        local idx = 0 --none found
        local assoc = 'none'
        for i, op in ipairs(binop) do
            if (op.type=='binop') or (op.type=='unop') then
                if op.priority<prio then
                    -- higher priority so associativity is ignored
                    idx = i
                    prio = op.priority
                    assoc = op.assoc
                elseif (assoc=='right') and (op.priority==prio) then
                    -- right associative, so we are looking for the rightmost one
                    idx = i
                end
            end
        end
        if idx==0 then
            -- no more operators left
            -- the list is fully reduced (only ternary still possible)
            break
        end
        local op = binop[idx]
        if op.type=='unop' then
            -- execute the unary operator
            -- this assumes only right associative unops, but we only have !
            -- so this is ok.
            local right = binop[idx+1]
            local ex, err = op.method(op, right)
            if not ex then
                return nil, err
            end
            -- replace operator with result
            binop[idx] = ex 
            -- reomve operand
            remove(binop, idx+1)
        else
            -- binary operator
            local left = binop[idx-1]
            local right = binop[idx+1]
            local ex, err = op.method(op, left, right)
            if not ex then
                return nil, err
            end
            -- replace operator with result
            binop[idx] = ex
            -- remove operands, use order right, left.
            remove(binop, idx+1) -- op/result still on index idx
            remove(binop, idx-1) -- so this is ok
        end 
    end
    while #binop>1 do
        -- still ?: ops left
        --find rightmost ?
        local idx = 0
        for i, op in ipairs(binop) do
            if op.type=='tcond' then
                idx = i
            end
        end
        if idx>1 then
            local cond = binop[idx-1]
            local iftrue = binop[idx+1]
            local opselect = binop[idx+2]
            local iffalse = binop[idx+3]
            if not(cond and iftrue and opselect and iffalse) then
                return nil, "syntax error on ?"
            end
            if opselect.type~='tselect' then
                return nil, "syntax error, missing :"
            end
            binop[idx] = {type='expr', token=format("((%s~=0) and %s or %s)", cond.token, iftrue.token, iffalse.token)}
            remove(binop, idx+3)
            remove(binop, idx+2)
            remove(binop, idx+1)
            remove(binop, idx-1)
        else
            return nil, "syntax error, does not reduce"
        end
    end
    return binop[1]
end

--- Parse and translate an expression
-- @param tokens a list of tokens, received from the lexer
-- @returns the expresion object (type='expr' token=actual text)
--          or nil, err
-- Grammar:
--
-- expr ::= [!] base-expr [ binop [!] base-expr ]*
-- base-expr ::= n
--             | number
--             | ( expr )   
local function expression(tokens)
    local binops = {}
    while true do
        local token = tokens:peek()
        if token.type=='unop' then
            tokens:read()
            binops[#binops+1] = token
            token = tokens:peek()
        end
        if token.type=='var' then
            binops[#binops+1] = token
        elseif token.type=='number' then
            binops[#binops+1] = token
        elseif token.type=='(' then
            tokens:read()
            local ex = expression(tokens)
            token = tokens:peek()
            if token.type ~= ')' then
                return nil, format('syntax error: ) expected, got %s', tostring(token.type))
            end
            binops[#binops+1] = {type='expr', token=format('(%s)', ex.token)}
        else
            return nil, "syntax error"
        end
        tokens:read()
        token = tokens:peek()
        if token and token.type=='binop' then
            tokens:read()
            -- ? and : are not really binary ops, so change then
            -- binop_reduce will then handle the ternary reduction correctly
            if token.token=='?' then
                token.type = 'tcond'
            elseif token.token == ':' then
                token.type = 'tselect'
            end
            binops[#binops+1] = token
        else
            break
        end
    end
    return binop_reduce(binops) 
end

--- parse the tokens into an expression
-- @param tokens the array of tokens
-- @return a Lua expression string 
--         or nil, err
local function parse(tokens)
    local ex, err = expression( tablereader(tokens) )
    if ex then
        return ex.token
       else
           return nil, err
    end
end

--- split the gettext expr assignments
-- @param expr the raw gettext expression
-- @return a table key=var, value=expression
-- The expr is like 'nplurals=2;plural=n!=1;'
local function split(expr)
    local expressions = {}
    for var, ex in expr:gmatch('%s*(%a+)%s*=%s*([^;]*);') do
        expressions[var] = ex
    end
    return expressions
end

local Plural = {}
Plural.__index = Plural
Plural.__call = function(self, n)
    n = self.plural(n)
    if (n<0) then
        n=0
    elseif n>=self.nplurals then
        n = self.nplurals-1
    end
    
    return n
end

--- Compile a gettext plural expression into a Lua callable
-- @param expr the raw gettext expression
-- @returns a table callable as a function
--          or nil, err
-- When called, the result is exactly like the C expression but limited to the
-- range [0..nplurals-1]
local function compile_plural(expr)
    local result = {}
    local expressions = split(expr)
    local nplurals = expressions.nplurals
    if not nplurals then
        return nil, 'invalid expression, nplurals missing'
    end
    local n = tonumber(nplurals)
    if not n then
        return nil, 'invalid expression, nplurals not a number'
    end
    if math.floor(n) ~= n then
        return nil, 'invalid expression, nplurals not an int'
    end
    result.nplurals = n
    
    local plural = expressions.plural
    if not plural then
        return nil, 'invalid expression, plural missing'
    end
    
    local tokens, err = tokenize(plural)
    if not tokens then
        return nil, err
    end
    
    plural, err = parse(tokens)
    if not plural then
        return nil, err
    end
    --result.expr = plural --for debugging
    plural, err = loadstring('n=...;return '..plural)
    if not plural then
        return nil, err
    end
    
    result.plural = plural
    
    setmetatable(result, Plural)
    
    return result
end

local M = {
    compile = compile_plural
}

return M
