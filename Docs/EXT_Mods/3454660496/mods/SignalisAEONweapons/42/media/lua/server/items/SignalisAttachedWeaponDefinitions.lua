AttachedWeaponDefinitions = AttachedWeaponDefinitions or {};

AttachedWeaponDefinitions.handgunHolster = {
	id = "handgunHolster",
	chance = 50,
	outfit = { "Bandit", "Bandit_Early", "Bandit_Mid", "Bandit_Late", "BountyHunter", "PlonkiesGuy", "PrivateMilitia",  "Survivalist", "Survivalist02", "Survivalist03", "Survivalist04", "Survivalist05"},
	weaponLocation =  {"Holster Right"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	ensureItem = "Base.HolsterSimple",
	weapons = {
        "Base.Pistol1",
        "Base.Pistol2",
		"Base.Pistol3",
		"Base.Revolver",
		"Base.Revolver_Long",
		"Base.Revolver_Short",
        "Signalis_Weapons.Type-75",
		"Signalis_Weapons.EU-K508S",
	},
}

AttachedWeaponDefinitions.handgunHolsterShoulder = {
	id = "handgunHolster",
	chance = 50,
	outfit = { "Bandit", "Bandit_Early", "Bandit_Mid", "Bandit_Late", "BankRobber", "BankRobberSuit", "Biker", "BountyHunter", "Hunter", "PlonkiesGuy", "Survivalist", "Survivalist02", "Survivalist03", "Survivalist04", "Survivalist05"},
	weaponLocation =  {"Holster Shoulder"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	ensureItem = "Base.HolsterShoulder",
	weapons = {
		"Base.Pistol",
		"Base.Pistol2",
		"Base.Pistol3",
		"Base.Revolver",
		"Base.Revolver_Long",
		"Base.Revolver_Short",
        "Signalis_Weapons.Type-75",
		"Signalis_Weapons.EU-K508S",
	},
}

AttachedWeaponDefinitions.handgunHolsterDetective = {
	id = "handgunHolsterDetective",
	chance = 50,
	outfit = {"Agent", "Detective", "Mob", "MobCasual", "Police_SWAT"},
	weaponLocation =  {"Holster Shoulder"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	ensureItem = "Base.HolsterShoulder",
	weapons = {
		"Base.Pistol",
		"Base.Pistol2",
		"Base.Revolver",
		"Base.Revolver_Long",
		"Base.Revolver_Short",
        "Signalis_Weapons.Type-75",
		"Signalis_Weapons.EU-K508S",
	},
}

AttachedWeaponDefinitions.handgunHolsterSheriff = {
	id = "handgunHolster",
	chance = 50,
	outfit = { "Sheriff_Deputy", },
	weaponLocation =  {"Holster Right"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	ensureItem = "Base.HolsterSimple_Brown",
	weapons = {
		"Base.Pistol",
		"Base.Pistol2",
		"Base.Revolver",
		"Base.Revolver_Long",
        "Signalis_Weapons.Type-75",
		"Signalis_Weapons.EU-K508S",
	},
}