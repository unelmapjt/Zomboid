HTT = HTT or {}

if HTT._clientToxicOverlayLoaded then
    return
end
HTT._clientToxicOverlayLoaded = true

if not HTT._toxicOverlayRemovedLogged and HTT.log then
    HTT._toxicOverlayRemovedLogged = true
    HTT.log("Toxic overlay renderer disabled (climate-fog only mode).")
end
