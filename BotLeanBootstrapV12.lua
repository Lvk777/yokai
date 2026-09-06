-- Lean bootstrap for the bot-practice profile.
-- Intentionally avoids the old multi-layer CuratedBootstrap stack, which had
-- delayed callbacks/replacements that could restore the legacy menu after the
-- final bot controls were already created.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local BASE = "https://raw.githubusercontent.com/Lvk777/yokai/refs/heads/custom/curated-yokai-final/"

local function run(name)
    local ok,err=pcall(function()
        local src=game:HttpGet(BASE..name,true)
        local fn,compileErr=loadstring(src)
        if not fn then error(compileErr or ("compile failed: "..name)) end
        fn()
    end)
    if not ok then warn("[Yokai bot bootstrap] "..name.." failed: "..tostring(err)) end
    return ok
end

-- Keep only the small set of foundations the final bot profile actually needs.
-- In particular, do NOT load AttachedVisualsPreview/VisualsPreviewControlsFix and
-- the long chain of local visual patches from CuratedBootstrap.
run("CuratedPrePatch.lua")
run("CuratedModules.lua")
pcall(function()
    if shared.YokaiCuratedRestoreGuiHooks then shared.YokaiCuratedRestoreGuiHooks() end
end)

run("VisualsV4.lua")
-- NoMenuFog lives in Utility here; ViewmodelAudioFixes then becomes the only
-- local owner of GunChams/SelfChams.
run("UILayoutArmFixes.lua")
run("ViewmodelAudioFixes.lua")
run("RuntimeHarmonyFix.lua")
run("VisualsIndependentWindowFix.lua")

shared.YokaiBotLeanBootstrapLoaded=true
