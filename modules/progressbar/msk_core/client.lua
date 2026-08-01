---@diagnostic disable: duplicate-set-field
local resourceName = "msk_core"
local configValue = BridgeClientConfig.ProgressBarSystem
if (configValue == "auto" and GetResourceState(resourceName) ~= "started") or (configValue ~= "auto" and configValue ~= resourceName) then return end

ProgressBar = ProgressBar or {}

---Converts bridge/ox-style progress options into the msk_core Progress.Start format.
---@param options table
---@return table
local function convertToMsk(options)
    options = options or {}

    -- QB exposes animation under .animation.animDict/.anim and disables under .controlDisables
    local anim = options.anim or options.animation
    local animation
    if anim then
        animation = {
            dict = anim.dict or anim.animDict,
            anim = anim.clip or anim.anim,
            flag = anim.flag or anim.flags or 49,
        }
    end

    -- ox uses options.disable.{move,car,combat,mouse}, QB uses options.controlDisables.*
    local d = options.disable or options.controlDisables or {}
    local disable = {
        move    = d.move or d.disableMovement,
        vehicle = d.car or d.disableCarMovement,
        combat  = d.combat or d.disableCombat,
        mouse   = d.mouse or d.disableMouse,
    }

    return {
        duration = options.duration,
        text = options.label or options.text or '',
        disable = disable,
        animation = animation,
        forceOverride = options.forceOverride,
    }
end

---This will open a progress bar (blocking until it completes).
---@param options table
---@param cb any optional callback receiving the success boolean
---@param isQBInput boolean optional
---@return boolean success true if the progress completed without being cancelled
function ProgressBar.Open(options, cb, isQBInput)
    local data = convertToMsk(options)

    -- msk_core Progress.Start blocks for the full duration; if it is interrupted
    -- it stops early. We treat a fully elapsed bar as success.
    exports.msk_core:Progressbar(data)

    local active = exports.msk_core:ProgressActive()
    local success = not active

    if cb then cb(success) end
    return success
end

ProgressBar.GetResourceName = function()
    return resourceName
end

return ProgressBar
