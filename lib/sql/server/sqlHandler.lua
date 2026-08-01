--[[
    DEPRECATED: the SQL helper module is deprecated in its entirety and will be
    REMOVED on 2026-08-22. Migrate to oxmysql directly — MySQL.query.await(query,
    params) with ? placeholders — which is safer and more flexible than these
    wrappers ever were.
]]

SQL = {}

Require("lib/MySQL.lua", "oxmysql")

local warnedResources = {}

local function warnDeprecated()
    local caller = GetInvokingResource() or GetCurrentResourceName()
    if warnedResources[caller] then return end
    warnedResources[caller] = true
    print(("^3[community_bridge] SQL helpers are deprecated and will be REMOVED on 2026-08-22. '%s' should migrate to oxmysql directly (MySQL.query.await with ? placeholders).^0"):format(caller))
end

-- Identifiers (table/column names) cannot be parameterized, so they are
-- validated against a strict pattern and backtick-quoted instead. Values are
-- never concatenated into queries - they always go through ? placeholders.
local function quoteIdentifier(name)
    assert(type(name) == "string" and name:match("^[%a_][%w_]*$"),
        ("SQL: unsafe identifier '%s' - table/column names may only contain letters, digits and underscores"):format(tostring(name)))
    return "`" .. name .. "`"
end

--- Builds a parameterized WHERE clause from a table of column = value pairs.
-- Raw WHERE strings are intentionally rejected: they made SQL injection
-- unavoidable whenever a player-influenced value reached these helpers.
local function buildWhere(where)
    assert(type(where) == "table" and next(where) ~= nil,
        "SQL: where must be a non-empty table of column = value pairs (raw WHERE strings are no longer accepted)")

    local conditions = {}
    local params = {}

    for column, value in pairs(where) do
        table.insert(conditions, quoteIdentifier(column) .. " = ?")
        table.insert(params, value)
    end

    return table.concat(conditions, " AND "), params
end

--- Creates a table in the database if it does not exist.
-- @param tableName The name of the table to create. Example: {{ name = "identifier", type = "VARCHAR(50)", primary = true }}
-- @param columns A table containing column definitions, where each column is a table with 'name' and 'type'.
---@return nil

---@deprecated Removed on 2026-08-22 — use oxmysql directly.
function SQL.Create(tableName, columns)
    warnDeprecated()
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local columnsList = {}
    for i, column in pairs(columns) do
        assert(type(column.type) == "string", "SQL: column type must be a string")
        table.insert(columnsList, string.format("%s %s", quoteIdentifier(column.name), column.type))
    end

    local query = string.format("CREATE TABLE IF NOT EXISTS %s (%s);",
        quoteIdentifier(tableName),
        table.concat(columnsList, ", ")
    )

    MySQL.query.await(query)
end

--  insert if not exist otherwise update
---@deprecated Removed on 2026-08-22 — use oxmysql directly.
function SQL.InsertOrUpdate(tableName, data)
    warnDeprecated()
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local columns = {}
    local placeholders = {}
    local updates = {}
    local params = {}

    for column, value in pairs(data) do
        local quoted = quoteIdentifier(column)
        table.insert(columns, quoted)
        table.insert(placeholders, "?")
        table.insert(updates, quoted .. " = VALUES(" .. quoted .. ")") -- Use VALUES() for update
        table.insert(params, value)
    end

    local query = string.format(
        "INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s;",
        quoteIdentifier(tableName),
        table.concat(columns, ", "),
        table.concat(placeholders, ", "),
        table.concat(updates, ", ")
    )

    MySQL.query.await(query, params)
end

--- Selects rows matching the given filters.
-- @param tableName The table to query.
-- @param where Table of column = value pairs, joined with AND. Example: { citizenid = cid }
---@deprecated Removed on 2026-08-22 — use oxmysql directly.
function SQL.Get(tableName, where)
    warnDeprecated()
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local conditions, params = buildWhere(where)
    local query = string.format("SELECT * FROM %s WHERE %s;", quoteIdentifier(tableName), conditions)
    local result = MySQL.query.await(query, params)
    return result
end

---@deprecated Removed on 2026-08-22 — use oxmysql directly.
function SQL.GetAll(tableName)
    warnDeprecated()
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local query = string.format("SELECT * FROM %s;", quoteIdentifier(tableName))
    local result = MySQL.query.await(query)
    return result
end

--- Deletes rows matching the given filters.
-- @param tableName The table to delete from.
-- @param where Table of column = value pairs, joined with AND. Example: { citizenid = cid }
---@deprecated Removed on 2026-08-22 — use oxmysql directly.
function SQL.Delete(tableName, where)
    warnDeprecated()
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local conditions, params = buildWhere(where)
    local query = string.format("DELETE FROM %s WHERE %s;", quoteIdentifier(tableName), conditions)
    MySQL.query.await(query, params)
end

exports('SQL', function()
    warnDeprecated()
    return SQL
end)

return SQL
