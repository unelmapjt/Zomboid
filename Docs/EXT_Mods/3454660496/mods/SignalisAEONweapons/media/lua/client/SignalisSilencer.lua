local Signalis_SilenceEffect = {
  signalisBullets9mm = {0.4;'SilencedReplikaSmallArms';0.5};
  signalisBullets45 = {0.4;'SilencedReplikaSmallArms';0.5};
  signalisBullets44 = {0.4;'SilencedReplikaSmallArms';0.5};
  signalisBullets38 = {0.4;'SilencedReplikaSmallArms';0.5};
  signalis223Bullets = {0.45;'SilencedReplikaMediumArms';0.55};
  signalis308Bullets = {0.45;'SilencedReplikaMediumArms';0.55};
  signalis556Bullets = {0.5;'SilencedReplikaMediumArms';0.55};
  signalisShotgunShells = {0.5;'SilencedReplikaLoudArms';0.6};
}

local function Signalis_silencer(wielder, weapon)

	if weapon == nil then return end
	if not weapon:IsWeapon() or not weapon:isRanged() then return; end
	
    local scriptItem = weapon:getScriptItem()

    local soundRadius = scriptItem:getSoundRadius()
    local swingSound = scriptItem:getSwingSound()
	local soundVolume = scriptItem:getSoundVolume()

    local canon = weapon:getCanon()
    if canon then
      if getDebug() then print(canon:getType()) end
      if string.find(canon:getType(), "SignalisSuppressor") then
	  
        local weaponAmmo, replaced = string.gsub(weapon:getAmmoType(), "Base.", "")
        local ammo = "signalis" .. weaponAmmo
		
        if getDebug() then
          print("Ammo: " .. ammo)
          print("Silenced sfx: " .. Signalis_SilenceEffect[ammo][2])
        end
		
    	soundRadius = soundRadius * Signalis_SilenceEffect[ammo][1]
        swingSound = Signalis_SilenceEffect[ammo][2]
		soundVolume = soundVolume *  Signalis_SilenceEffect[ammo][3]
		
	  else return end
    end

    weapon:setSoundRadius(soundRadius)
    weapon:setSwingSound(swingSound)
	weapon:setSoundVolume(soundVolume)
	
	if getDebug() then
    print("Gun radius: " .. weapon:getSoundRadius())
    print("Gun sfx: " .. weapon:getSwingSound())
	print("Gun volume: " .. weapon:getSoundVolume())
	end
end

Events.OnEquipPrimary.Add(Signalis_silencer);

Events.OnGameStart.Add(function() -- player setup on game start
	local player = getPlayer()
	Signalis_silencer(player, player:getPrimaryHandItem())
end)