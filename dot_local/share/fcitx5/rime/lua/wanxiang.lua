---@diagnostic disable: undefined-global

-- 万象的一些共用工具函数
local wanxiang = {}

-- x-release-please-start-version

wanxiang.version = "v12.6.4"

-- x-release-please-end

-- 全局内容
---@alias PROCESS_RESULT ProcessResult
wanxiang.RIME_PROCESS_RESULTS = {
    kRejected = 0, -- 表示处理器明确拒绝了这个按键，停止处理链但不返回 true
    kAccepted = 1, -- 表示处理器成功处理了这个按键，停止处理链并返回 true
    kNoop = 2,     -- 表示处理器没有处理这个按键，继续传递给下一个处理器
}

-- 整个生命周期内不变，缓存判断结果
local is_mobile_device = nil
-- 判断是否为手机设备
---@author amzxyz
---@return boolean
function wanxiang.is_mobile_device()
    local function _is_mobile_device()
        local dist = rime_api.get_distribution_code_name() or ""
        local user_data_dir = rime_api.get_user_data_dir() or ""
        local sys_dir = rime_api.get_shared_data_dir() or ""
        -- 转换为小写以便比较
        local lower_dist = dist:lower()
        local lower_path = user_data_dir:lower()
        local sys_lower_path = sys_dir:lower()
        -- 主判断：常见移动端输入法
        if lower_dist == "trime" or
            lower_dist == "hamster" or
            lower_dist == "squirrel" then
            return true
        end

        -- 补充判断：路径中包含移动设备特征，很可以mac的运行逻辑和手机一球样
        if lower_path:find("/android/") or
            lower_path:find("/mobile/") or
            lower_path:find("/sdcard/") or
            lower_path:find("/data/storage/") or
            lower_path:find("/storage/emulated/") or
            lower_path:find("applications") or
            lower_path:find("library") then
            return true
        end
        -- 补充判断：路径中包含移动设备特征，很可以mac的运行逻辑和手机一球样
        if sys_lower_path:find("applications") or
            sys_lower_path:find("library") then
            return true
        end
        -- 特定平台判断（Android/Linux）
        if jit and jit.os then
            local os_name = jit.os:lower()
            if os_name:find("android") then
                return true
            end
        end

        -- 所有检查未通过则默认为桌面设备
        return false
    end

    if is_mobile_device == nil then
        is_mobile_device = _is_mobile_device()
    end
    return is_mobile_device
end

--- 检测是否为万象专业版
---@param env Env
---@return boolean
function wanxiang.is_pro_scheme(env)
    -- local schema_name = env.engine.schema.schema_name
    -- return schema_name:gsub("PRO$", "") ~= schema_name
    return env.engine.schema.schema_id == "wanxiang_pro"
end

-- 以 `tag` 方式检测是否处于反查模式
function wanxiang.is_in_radical_mode(env)
    local seg = env.engine.context.composition:back()
    return seg and (
        seg:has_tag("wanxiang_reverse")
    ) or false
end

---判断是否在命令模式
---@param context Context | nil
---@return boolean
function wanxiang.is_function_mode_active(context)
    if not context or not context.composition or context.composition:empty() then
        return false
    end

    local seg = context.composition:back()
    if not seg then return false end

    return seg:has_tag("number") or  -- number_translator.lua 数字金额转换 R+数字
        seg:has_tag("unicode") or    -- unicode.lua 输出 Unicode 字符 U+小写字母或数字
        --seg:has_tag("punct") or      -- 标点符号 全角半角提示
        seg:has_tag("calculator") or -- super_calculator.lua V键计算器
        seg:has_tag("shijian") or    -- shijian.lua /rq /sr 等与时间日期相关功能
        seg:has_tag("Ndate")         -- shijian.lua N日期功能
end

---判断文件是否存在
function wanxiang.file_exists(filename)
    local f = io.open(filename, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

---按照优先顺序获取文件：用户目录 > 系统目录
---@param filename string 相对路径
---@retur string | nil
function wanxiang.get_filename_with_fallback(filename)
    local _path = filename:gsub("^/+", "") -- 去掉开头的斜杠

    local user_path = rime_api.get_user_data_dir() .. '/' .. _path
    if wanxiang.file_exists(user_path) then
        return user_path
    end

    local shared_path = rime_api.get_shared_data_dir() .. '/' .. _path
    if wanxiang.file_exists(shared_path) then
        return shared_path
    end

    return nil
end

-- 按照优先顺序加载文件：用户目录 > 系统目录
---@param filename string 相对路径
---@retur file* | nil, function
function wanxiang.load_file_with_fallback(filename, mode)
    mode = mode or "r" -- 默认读取模式

    local _filename = wanxiang.get_filename_with_fallback(filename)

    local file, err
    local function close()
        if not file then return end
        file:close()
        file = nil
    end

    if _filename then
        file, err = io.open(_filename, mode)
    end

    return file, close, err
end

local USER_ID_DEFAULT = "unknown"
---作为「小狼毫」和「仓」 `rime_api.get_user_id()` 的一个 workaround
---详见：
---1. https://github.com/rime/weasel/pull/1649
---2. https://github.com/rime/librime/issues/1038
---@return string
function wanxiang.get_user_id()
    local user_id = rime_api.get_user_id()
    if user_id ~= USER_ID_DEFAULT then return user_id end

    local user_data_dir = rime_api.get_user_data_dir()
    local installation_path = user_data_dir .. "/installation.yaml"
    local installation_file, _ = io.open(installation_path, "r")
    if not installation_file then return user_id end

    for line in installation_file:lines() do
        local key, value = line:match('^([^#:]+):%s+"?([^"]%S+[^"])"?')
        if key == "installation_id" then
            user_id = value
            break
        end
    end

    installation_file:close()
    return user_id
end

wanxiang.INPUT_METHOD_MARKERS = {
    ["Ⅰ"] = "pinyin", --全拼
    ["Ⅱ"] = "zrm", --自然码双拼
    ["Ⅲ"] = "flypy", --小鹤双拼
    ["Ⅳ"] = "mspy", --微软双拼
    ["Ⅴ"] = "sogou", --搜狗双拼
    ["Ⅵ"] = "abc", --智能abc双拼
    ["Ⅶ"] = "ziguang", --紫光双拼
    ["Ⅷ"] = "pyjj", --拼音加加
    ["Ⅸ"] = "gbpy", --国标双拼
    ["Ⅹ"] = "lxsq", --乱序17
    ["Ⅺ"] = "zrlong", --自然龙
    ["Ⅻ"] = "hxlong", --汉心龙
    ["ⅲ"] = "ⅲ", -- 间接辅助标记：命中则额外返回 md="ⅲ"
}

local __input_type_cache = {}      -- 缓存首个命中的 id（兼容旧用法）
local __input_md_cache   = {}      -- 新增：是否命中“ⅲ”（若命中则为 "ⅲ"，否则为 nil）

--- 根据 speller/algebra 中的特殊符号返回输入类型：
--- - 若未命中“ⅲ”，只返回 id（保持旧行为）
--- - 若命中“ⅲ”，返回两个值：id, "ⅲ"
---@param env Env
---@return string                -- id
---@return string|nil            -- md（仅在命中“ⅲ”时返回 "ⅲ"）
function wanxiang.get_input_method_type(env)
    local schema_id = env.engine.schema.schema_id or "unknown"

    -- 命中缓存则按是否有 md 决定返回 1 个或 2 个值
    local cached_id = __input_type_cache[schema_id]
    if cached_id then
        local cached_md = __input_md_cache[schema_id]
        if cached_md then
            return cached_id, cached_md   -- 返回两个值：id, "ⅲ"
        else
            return cached_id              -- 只返回 id
        end
    end

    local cfg = env.engine.schema.config
    local result_id = "unknown"
    local md        = nil                 -- 只有命中“ⅲ”时设为 "ⅲ"

    local n = cfg:get_list_size("speller/algebra")
    for i = 0, n - 1 do
        local s = cfg:get_string(("speller/algebra/@%d"):format(i))
        if s then
            -- 不提前返回：需要把整段都扫描完，才能知道是否命中“ⅲ”
            for symbol, id in pairs(wanxiang.INPUT_METHOD_MARKERS) do
                if s:find(symbol, 1, true) then
                    if symbol == "ⅲ" or id == "ⅲ" then
                        md = "ⅲ"                  -- 记录辅助标记
                    else
                        if result_id == "unknown" then
                            result_id = id        -- 只记录第一个“正常映射”的 id
                        end
                    end
                end
            end
        end
    end

    -- 写缓存
    __input_type_cache[schema_id] = result_id
    __input_md_cache[schema_id]   = md   -- 命中则为 "ⅲ"，否则为 nil

    -- 返回：命中“ⅲ”→两个值；否则一个值
    if md then
        return result_id, md
    else
        return result_id
    end
end

return wanxiang
