Z_CORE = {}

-- JSON文字列エスケープ
function Z_CORE.escapeJson(str)
    str = tostring(str or "")
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\t", "\\t")
    str = str:gsub("\r\n", "\\n")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\n")
    return str
end

-- 軽量エラー指紋（Hash）の生成
local function toHexPrefix(str, maxBytes)
    str = tostring(str or "")
    maxBytes = maxBytes or 4
    local out = {}
    local n = math.min(#str, maxBytes)
    for i = 1, n do
        out[#out + 1] = string.format("%02X", str:byte(i))
    end
    return table.concat(out)
end

local function getErrorID(msg, info)
    local source = info.short_src or "unknown"
    local line = info.currentline or 0
    local fileName = source:match("([^/\\]+)$") or source
    local msgPart = tostring(msg or ""):gsub("%s+", ""):gsub("[^%w]", ""):sub(1, 5)
    if msgPart == "" then
        msgPart = toHexPrefix(msg, 4)
    end
    if msgPart == "" then
        msgPart = "X"
    end
    local infoTag = ((info.name or "") ~= "" and info.name or (info.namewhat or "NA"))
    infoTag = tostring(infoTag):gsub("[^%w]", ""):sub(1, 6)
    if infoTag == "" then
        infoTag = "NA"
    end
    return string.format("ERR_%s_%d_%s_%s", fileName, line, infoTag, msgPart)
end

-- エラーハンドラ / デバッグフック
function Z_CORE.Log(msg, ctx)
    local info = debug.getinfo(2, "Sl")
    local errID = getErrorID(msg, info)

    local logObj = {
        Z_LOG = true,
        id = errID,
        file = info.short_src,
        line = info.currentline,
        msg = msg,
        context = ctx or "none"
    }

    local safeID = Z_CORE.escapeJson(logObj.id)
    local safeFile = Z_CORE.escapeJson(logObj.file)
    local safeMsg = Z_CORE.escapeJson(logObj.msg)
    local safeCtx = Z_CORE.escapeJson(logObj.context)
    local jsonStr = string.format('{"Z_LOG":true,"id":"%s","file":"%s","line":%d,"msg":"%s","ctx":"%s"}',
        safeID, safeFile, logObj.line, safeMsg, safeCtx)
    print(jsonStr)
end

function Z_CORE.Err(msg, ctx)
    local info = debug.getinfo(2, "Sl")
    local errID = getErrorID(msg, info)
    local file = info.short_src or "unknown"
    local line = info.currentline or 0
    local safeID = Z_CORE.escapeJson(errID)
    local safeFile = Z_CORE.escapeJson(file)
    local safeMsg = Z_CORE.escapeJson(msg)
    local safeCtx = Z_CORE.escapeJson(ctx or "none")
    local jsonStr = string.format('{"Z_LOG":true,"id":"%s","file":"%s","line":%d,"msg":"%s","ctx":"%s"}',
        safeID, safeFile, line, safeMsg, safeCtx)
    print(jsonStr)
end
