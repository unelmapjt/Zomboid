signalisCharacter = {};

signalisCharacter.DoProfessions = function()
	-- FKLR
	local fklr = ProfessionFactory.addProfession("fklr", getText("UI_prof_Fklr_Replika"), "icon_FKLR_Replika", -4)
	fklr:addXPBoost(Perks.Spear, 2)
	fklr:addXPBoost(Perks.Fitness, 2)
	fklr:addXPBoost(Perks.Strength, 2)
	-- KLBR
	local klbr = ProfessionFactory.addProfession("klbr", getText("UI_prof_Klbr_Replika"), "icon_KLBR_Replika", 4)
	klbr:addXPBoost(Perks.Fitness, -1)
	klbr:addXPBoost(Perks.Strength, -1)
	klbr:addXPBoost(Perks.Lightfoot, 1)
	-- LSTR
	local lstr = ProfessionFactory.addProfession("lstr", getText("UI_prof_Lstr_Replika"), "icon_LSTR_Replika", -6)
    lstr:addXPBoost(Perks.Maintenance, 1)
    lstr:addXPBoost(Perks.Mechanics, 1)
	lstr:addXPBoost(Perks.Aiming,1)
	lstr:addXPBoost(Perks.Reloading,1)
	lstr:getFreeRecipes():add("Basic Mechanics");
    lstr:getFreeRecipes():add("Generator");
    lstr:addFreeTrait("Mechanics2");
	--ADLR
	local adlr = ProfessionFactory.addProfession("adlr", getText("UI_prof_Adlr_Replika"), "icon_ADLR_Replika", 2)
	adlr:addXPBoost(Perks.Maintenance, 1)
	adlr:addXPBoost(Perks.PlantScavenging, 1)
	--STCR
	local stcr = ProfessionFactory.addProfession("stcr", getText("UI_prof_Stcr_Replika"), "icon_STCR_Replika", -8)
	stcr:addFreeTrait("Desensitized")
	stcr:addXPBoost(Perks.SmallBlunt, 1)
	stcr:addXPBoost(Perks.Aiming, 2)
	stcr:addXPBoost(Perks.Reloading, 1)
	--STAR
	local star = ProfessionFactory.addProfession("star", getText("UI_prof_Star_Replika"), "icon_STAR_Replika", -6)
	star:addXPBoost(Perks.SmallBlunt, 1)
	star:addXPBoost(Perks.Aiming, 1)
	star:addXPBoost(Perks.Reloading, 1)
	-- EULR
    local eulr = ProfessionFactory.addProfession("eulr", getText("UI_prof_eulr_Replika"), "icon_EULR_Replika", -2)
    eulr:addXPBoost(Perks.Cooking, 2)
    eulr:addXPBoost(Perks.Doctor, 1)
    eulr:addXPBoost(Perks.SmallBlade, 1)
    eulr:addFreeTrait("Cook2");
	--MNHR
	local mnhr = ProfessionFactory.addProfession("mnhr", getText("UI_prof_Mnhr_Replika"), "icon_MNHR_Replika", -3)
	mnhr:addXPBoost(Perks.Strength, 2)
	mnhr:addXPBoost(Perks.Maintenance, 1)
	mnhr:addXPBoost(Perks.LongBlade, 1)
	--ARAR
	local arar = ProfessionFactory.addProfession("arar", getText("UI_prof_Arar_Replika"), "icon_ARAR_Replika", -10)
    arar:addXPBoost(Perks.Woodwork, 1)
	arar:addXPBoost(Perks.Electricity, 1)
	arar:addXPBoost(Perks.Mechanics, 1)
	arar:addXPBoost(Perks.MetalWelding, 1)
	arar:getFreeRecipes():add("Generator")
    arar:getFreeRecipes():add("Make Aerosol bomb")
    arar:getFreeRecipes():add("Make Flame bomb")
    arar:getFreeRecipes():add("Make Pipe bomb")
    arar:getFreeRecipes():add("Make Noise generator")
    arar:getFreeRecipes():add("Make Smoke Bomb")
	arar:getFreeRecipes():add("Basic Mechanics")
	arar:getFreeRecipes():add("Intermediate Mechanics")
	arar:getFreeRecipes():add("Make Metal Walls")
    arar:getFreeRecipes():add("Make Metal Fences")
    arar:getFreeRecipes():add("Make Metal Containers")
    arar:getFreeRecipes():add("Make Metal Sheet")
    arar:getFreeRecipes():add("Make Small Metal Sheet")
    arar:getFreeRecipes():add("Make Metal Roof")

	local profList = ProfessionFactory.getProfessions()
		for i = 1, profList:size() do
		local prof = profList:get(i - 1)
		BaseGameCharacterDetails.SetProfessionDescription(prof)
	end
end

Events.OnGameBoot.Add(signalisCharacter.DoProfessions);
Events.OnCreateLivingCharacter.Add(signalisCharacter.DoProfessions);
