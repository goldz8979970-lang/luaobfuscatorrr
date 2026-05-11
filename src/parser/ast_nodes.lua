-- ============================================
-- AST NODE DEFINITIONS
-- ============================================
-- All node types for the Abstract Syntax Tree

local ASTNode = {}
ASTNode.__index = ASTNode

function ASTNode.new(node_type, data)
    local self = setmetatable({}, ASTNode)
    self.type = node_type
    self.line = data and data.line or 0
    self.column = data and data.column or 0
    for k, v in pairs(data or {}) do
        if k ~= "line" and k ~= "column" then
            self[k] = v
        end
    end
    return self
end

-- ============ STATEMENTS ============

function ASTNode.block(statements, line, column)
    return ASTNode.new("Block", {
        statements = statements,
        line = line,
        column = column,
    })
end

function ASTNode.local_declaration(names, values, line, column)
    return ASTNode.new("LocalDeclaration", {
        names = names,
        values = values,
        line = line,
        column = column,
    })
end

function ASTNode.assignment(targets, values, line, column)
    return ASTNode.new("Assignment", {
        targets = targets,
        values = values,
        line = line,
        column = column,
    })
end

function ASTNode.function_declaration(name, params, body, is_local, line, column)
    return ASTNode.new("FunctionDeclaration", {
        name = name,
        params = params,
        body = body,
        is_local = is_local,
        line = line,
        column = column,
    })
end

function ASTNode.if_statement(condition, then_block, elseif_parts, else_block, line, column)
    return ASTNode.new("IfStatement", {
        condition = condition,
        then_block = then_block,
        elseif_parts = elseif_parts,
        else_block = else_block,
        line = line,
        column = column,
    })
end

function ASTNode.for_loop(var, start_val, end_val, step_val, body, line, column)
    return ASTNode.new("ForLoop", {
        var = var,
        start_val = start_val,
        end_val = end_val,
        step_val = step_val,
        body = body,
        line = line,
        column = column,
    })
end

function ASTNode.for_in_loop(vars, iterables, body, line, column)
    return ASTNode.new("ForInLoop", {
        vars = vars,
        iterables = iterables,
        body = body,
        line = line,
        column = column,
    })
end

function ASTNode.while_loop(condition, body, line, column)
    return ASTNode.new("WhileLoop", {
        condition = condition,
        body = body,
        line = line,
        column = column,
    })
end

function ASTNode.repeat_loop(body, condition, line, column)
    return ASTNode.new("RepeatLoop", {
        body = body,
        condition = condition,
        line = line,
        column = column,
    })
end

function ASTNode.break_statement(line, column)
    return ASTNode.new("BreakStatement", {
        line = line,
        column = column,
    })
end

function ASTNode.continue_statement(line, column)
    return ASTNode.new("ContinueStatement", {
        line = line,
        column = column,
    })
end

function ASTNode.return_statement(values, line, column)
    return ASTNode.new("ReturnStatement", {
        values = values,
        line = line,
        column = column,
    })
end

function ASTNode.expression_statement(expression, line, column)
    return ASTNode.new("ExpressionStatement", {
        expression = expression,
        line = line,
        column = column,
    })
end

-- ============ EXPRESSIONS ============

function ASTNode.identifier(name, line, column)
    return ASTNode.new("Identifier", {
        name = name,
        line = line,
        column = column,
    })
end

function ASTNode.number_literal(value, line, column)
    return ASTNode.new("NumberLiteral", {
        value = value,
        line = line,
        column = column,
    })
end

function ASTNode.string_literal(value, line, column)
    return ASTNode.new("StringLiteral", {
        value = value,
        line = line,
        column = column,
    })
end

function ASTNode.boolean_literal(value, line, column)
    return ASTNode.new("BooleanLiteral", {
        value = value,
        line = line,
        column = column,
    })
end

function ASTNode.nil_literal(line, column)
    return ASTNode.new("NilLiteral", {
        line = line,
        column = column,
    })
end

function ASTNode.varargs(line, column)
    return ASTNode.new("Varargs", {
        line = line,
        column = column,
    })
end

function ASTNode.table_constructor(fields, line, column)
    return ASTNode.new("TableConstructor", {
        fields = fields,
        line = line,
        column = column,
    })
end

function ASTNode.function_literal(params, body, is_variadic, line, column)
    return ASTNode.new("FunctionLiteral", {
        params = params,
        body = body,
        is_variadic = is_variadic,
        line = line,
        column = column,
    })
end

function ASTNode.binary_op(left, operator, right, line, column)
    return ASTNode.new("BinaryOp", {
        left = left,
        operator = operator,
        right = right,
        line = line,
        column = column,
    })
end

function ASTNode.unary_op(operator, operand, line, column)
    return ASTNode.new("UnaryOp", {
        operator = operator,
        operand = operand,
        line = line,
        column = column,
    })
end

function ASTNode.call_expression(callee, args, line, column)
    return ASTNode.new("CallExpression", {
        callee = callee,
        args = args,
        line = line,
        column = column,
    })
end

function ASTNode.method_call(object, method, args, line, column)
    return ASTNode.new("MethodCall", {
        object = object,
        method = method,
        args = args,
        line = line,
        column = column,
    })
end

function ASTNode.member_expression(object, property, is_computed, line, column)
    return ASTNode.new("MemberExpression", {
        object = object,
        property = property,
        is_computed = is_computed,
        line = line,
        column = column,
    })
end

function ASTNode.index_expression(object, index, line, column)
    return ASTNode.new("IndexExpression", {
        object = object,
        index = index,
        line = line,
        column = column,
    })
end

function ASTNode.type_assertion(expr, type_str, line, column)
    return ASTNode.new("TypeAssertion", {
        expr = expr,
        type_str = type_str,
        line = line,
        column = column,
    })
end

function ASTNode.conditional_expression(condition, true_expr, false_expr, line, column)
    return ASTNode.new("ConditionalExpression", {
        condition = condition,
        true_expr = true_expr,
        false_expr = false_expr,
        line = line,
        column = column,
    })
end

-- ============ TABLE FIELDS ============

function ASTNode.table_field_list(value, line, column)
    return ASTNode.new("TableFieldList", {
        value = value,
        line = line,
        column = column,
    })
end

function ASTNode.table_field_key_value(key, value, line, column)
    return ASTNode.new("TableFieldKeyValue", {
        key = key,
        value = value,
        line = line,
        column = column,
    })
end

function ASTNode.table_field_name(name, value, line, column)
    return ASTNode.new("TableFieldName", {
        name = name,
        value = value,
        line = line,
        column = column,
    })
end

return ASTNode