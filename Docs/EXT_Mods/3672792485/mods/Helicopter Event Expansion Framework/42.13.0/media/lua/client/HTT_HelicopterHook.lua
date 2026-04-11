require "HTT_Main"

-- Legacy file retained for compatibility.
-- Vanilla helicopter hook moved to server-side script `HTT_VanillaHook.lua`.
if not HTT._legacyClientHookNotice then
    HTT._legacyClientHookNotice = true
    HTT.log("Client vanilla hook disabled. Event authority is now server-side.")
end
