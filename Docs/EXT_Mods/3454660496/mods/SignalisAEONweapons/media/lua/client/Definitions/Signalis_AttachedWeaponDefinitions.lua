-- define weapons to be attached to zombies when creating them
-- random knives inside their neck, spear in their stomach, meatcleaver in their back...
-- this is used in IsoZombie.addRandomAttachedWeapon()

AttachedWeaponDefinitions = AttachedWeaponDefinitions or {};
-- Global chance of having an attached weapon, if we pass this we gonna add randomly one from the list

-- star shield's LHand
AttachedWeaponDefinitions.StarShieldLelftHand = {
	chance = 40,
	outfit = {"STAR Replika"},
	weaponLocation =  {"Shield in Lhand"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	weapons = {
		"Base.StarShield",
	},
}