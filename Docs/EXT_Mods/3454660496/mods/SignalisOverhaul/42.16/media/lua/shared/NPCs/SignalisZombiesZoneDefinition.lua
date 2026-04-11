require 'NPCs/ZombiesZoneDefinition'

local signal_set = SandboxVars.SIGNAILS;


-- option SIGNAILS.RateSpawnList
-- {
--     type = enum,
--     default = 2,
--     numValues = 5,
--     page = SIGNAILS,
--     translation = SIGNAILS_RateSpawnList,
-- }
local RateSpawnList = signal_set.RateSpawnList;
local RateSpawn_EULRVeryCommon = signal_set.RateSpawn_EULRVeryCommon;
local RateSpawn_EULRCommon = signal_set.RateSpawn_EULRCommon;
local RateSpawn_EULRRare = signal_set.RateSpawn_EULRRare;
local RateSpawn_ARARVeryCommon = signal_set.RateSpawn_ARARVeryCommon;
local RateSpawn_ARARCommon = signal_set.RateSpawn_ARARCommon;
local RateSpawn_ARARRare = signal_set.RateSpawn_ARARRare;
local RateSpawn_ADLRVeryCommon = signal_set.RateSpawn_ADLRVeryCommon;
local RateSpawn_ADLRCommon = signal_set.RateSpawn_ADLRCommon;
local RateSpawn_KLBRCommon = signal_set.RateSpawn_KLBRCommon;
local RateSpawn_KLBRRare = signal_set.RateSpawn_KLBRRare;
local RateSpawn_STARVeryCommon = signal_set.RateSpawn_STARVeryCommon;
local RateSpawn_STARCommon = signal_set.RateSpawn_STARCommon;
local RateSpawn_STARRare = signal_set.RateSpawn_STARRare;
local RateSpawn_STCRCommon = signal_set.RateSpawn_STCRCommon;
local RateSpawn_STCRRare = signal_set.RateSpawn_STCRRare;
local RateSpawn_KNCRCommon = signal_set.RateSpawn_KNCRCommon;
local RateSpawn_GesBioVeryCommon = signal_set.RateSpawn_GesBioVeryCommon;
local RateSpawn_GestaltStudentLong = signal_set.RateSpawn_GestaltStudentLong;
local RateSpawn_GestaltStudentMid = signal_set.RateSpawn_GestaltStudentMid;
local RateSpawn_GestaltStudentMale = signal_set.RateSpawn_GestaltStudentMale;
local RateSpawn_FKLR = signal_set.RateSpawn_FKLR;
local RateSpawn_MNHR = signal_set.RateSpawn_MNHR;
local RateSpawn_PAVeteran = signal_set.RateSpawn_PAVeteran;
local RateSpawn_PAMedic = signal_set.RateSpawn_PAMedic;

-- if (RateSpawnList == 1) then
-- 	RateSpawn_EULRVeryCommon = 0;
-- 	RateSpawn_EULRCommon = 0;
-- 	RateSpawn_EULRRare = 0;
-- 	RateSpawn_ARARVeryCommon = 0;
-- 	RateSpawn_ARARCommon = 0;
-- 	RateSpawn_ARARRare = 0;
-- 	RateSpawn_ADLRVeryCommon = 0;
-- 	RateSpawn_ADLRCommon = 0;
-- 	RateSpawn_KLBRCommon = 0;
-- 	RateSpawn_KLBRRare = 0;
-- 	RateSpawn_STARVeryCommon = 0;
-- 	RateSpawn_STARCommon = 0;
-- 	RateSpawn_STARRare = 0;
-- 	RateSpawn_STCRCommon = 0;
-- 	RateSpawn_STCRRare = 0;
-- 	RateSpawn_KNCRCommon = 0;
-- 	RateSpawn_GesBioVeryCommon = 0;
-- 	RateSpawn_GestaltStudentLong = 0;
-- 	RateSpawn_GestaltStudentMid = 0;
-- 	RateSpawn_GestaltStudentMale = 0;
-- 	RateSpawn_FKLR = 0;
-- 	RateSpawn_MNHR = 0;
-- 	RateSpawn_PAVeteran = 0;
-- 	RateSpawn_PAMedic = 0;
-- end
-- if (RateSpawnList == 2) then
-- 	RateSpawn_EULRVeryCommon = 5;
-- 	RateSpawn_EULRCommon = 3;
-- 	RateSpawn_EULRRare = 2;
-- 	RateSpawn_ARARVeryCommon = 5;
-- 	RateSpawn_ARARCommon = 3;
-- 	RateSpawn_ARARRare = 2;
-- 	RateSpawn_ADLRVeryCommon = 5;
-- 	RateSpawn_ADLRCommon = 3;
-- 	RateSpawn_KLBRCommon = 3;
-- 	RateSpawn_KLBRRare = 2;
-- 	RateSpawn_STARVeryCommon = 5;
-- 	RateSpawn_STARCommon = 3;
-- 	RateSpawn_STARRare = 2;
-- 	RateSpawn_STCRCommon = 3;
-- 	RateSpawn_STCRRare = 2;
-- 	RateSpawn_KNCRCommon = 3;
-- 	RateSpawn_GesBioVeryCommon = 2;
-- 	RateSpawn_GestaltStudentLong = 2;
-- 	RateSpawn_GestaltStudentMid = 2;
-- 	RateSpawn_GestaltStudentMale = 2;
-- 	RateSpawn_FKLR = 0;
-- 	RateSpawn_MNHR = 3;
-- 	RateSpawn_PAVeteran = 2;
-- 	RateSpawn_PAMedic = 2;
-- end
-- if (RateSpawnList == 3) then
-- 	RateSpawn_EULRVeryCommon = 10;
-- 	RateSpawn_EULRCommon = 5;
-- 	RateSpawn_EULRRare = 4;
-- 	RateSpawn_ARARVeryCommon = 10;
-- 	RateSpawn_ARARCommon = 5;
-- 	RateSpawn_ARARRare = 4;
-- 	RateSpawn_ADLRVeryCommon = 10;
-- 	RateSpawn_ADLRCommon = 5;
-- 	RateSpawn_KLBRCommon = 5;
-- 	RateSpawn_KLBRRare = 5;
-- 	RateSpawn_STARVeryCommon = 10;
-- 	RateSpawn_STARCommon = 5;
-- 	RateSpawn_STARRare = 4;
-- 	RateSpawn_STCRCommon = 5;
-- 	RateSpawn_STCRRare = 4;
-- 	RateSpawn_KNCRCommon = 5;
-- 	RateSpawn_GesBioVeryCommon = 3;
-- 	RateSpawn_GestaltStudentLong = 3;
-- 	RateSpawn_GestaltStudentMid = 3;
-- 	RateSpawn_GestaltStudentMale = 3;
-- 	RateSpawn_FKLR = 0;
-- 	RateSpawn_MNHR = 5;
-- 	RateSpawn_PAVeteran = 2;
-- 	RateSpawn_PAMedic = 2;
-- end
-- if (RateSpawnList == 4) then
-- 	RateSpawn_EULRVeryCommon = 20;
-- 	RateSpawn_EULRCommon = 8;
-- 	RateSpawn_EULRRare = 6;
-- 	RateSpawn_ARARVeryCommon = 20;
-- 	RateSpawn_ARARCommon = 8;
-- 	RateSpawn_ARARRare = 6;
-- 	RateSpawn_ADLRVeryCommon = 20;
-- 	RateSpawn_ADLRCommon = 8;
-- 	RateSpawn_KLBRCommon = 8;
-- 	RateSpawn_KLBRRare = 8;
-- 	RateSpawn_STARVeryCommon = 20;
-- 	RateSpawn_STARCommon = 8;
-- 	RateSpawn_STARRare = 6;
-- 	RateSpawn_STCRCommon = 8;
-- 	RateSpawn_STCRRare = 6;
-- 	RateSpawn_KNCRCommon = 8;
-- 	RateSpawn_GesBioVeryCommon = 3;
-- 	RateSpawn_GestaltStudentLong = 3;
-- 	RateSpawn_GestaltStudentMid = 3;
-- 	RateSpawn_GestaltStudentMale = 3;
-- 	RateSpawn_FKLR = 1;
-- 	RateSpawn_MNHR = 8;
-- 	RateSpawn_PAVeteran = 3;
-- 	RateSpawn_PAMedic = 3;
-- end
-- if (RateSpawnList == 5) then
-- 	RateSpawn_EULRVeryCommon = 25;
-- 	RateSpawn_EULRCommon = 10;
-- 	RateSpawn_EULRRare = 7;
-- 	RateSpawn_ARARVeryCommon = 25;
-- 	RateSpawn_ARARCommon = 10;
-- 	RateSpawn_ARARRare = 7;
-- 	RateSpawn_ADLRVeryCommon = 20;
-- 	RateSpawn_ADLRCommon = 10;
-- 	RateSpawn_KLBRCommon = 10;
-- 	RateSpawn_KLBRRare = 10;
-- 	RateSpawn_STARVeryCommon = 20;
-- 	RateSpawn_STARCommon = 10;
-- 	RateSpawn_STARRare = 7;
-- 	RateSpawn_STCRCommon = 10;
-- 	RateSpawn_STCRRare = 7;
-- 	RateSpawn_KNCRCommon = 10;
-- 	RateSpawn_GesBioVeryCommon = 4;
-- 	RateSpawn_GestaltStudentLong = 4;
-- 	RateSpawn_GestaltStudentMid = 4;
-- 	RateSpawn_GestaltStudentMale = 4;
-- 	RateSpawn_FKLR = 2;
-- 	RateSpawn_MNHR = 10;
-- 	RateSpawn_PAVeteran = 4;
-- 	RateSpawn_PAMedic = 4;
-- end

Signalis_ZombiesZoneDefinition = ZombiesZoneDefinition or {};

local EULRVeryCommon = {
	name="EULR Replika",
	gender="female",
	chance=RateSpawn_EULRVeryCommon,
};
local EULRCommon = {
	name="EULR Replika",
	gender="female",			
	chance=RateSpawn_EULRCommon,
};
local EULRRare = {
	name="EULR Replika",
	gender="female",			
	chance=RateSpawn_EULRRare,
};
local ARARVeryCommon = {
		name="ARAR Replika",
		gender="female",			
		chance=RateSpawn_ARARVeryCommon,
	};
local ARARCommon = {
		name="ARAR Replika",
		gender="female",			
		chance=RateSpawn_ARARCommon,
	};
local ARARRare = {
		name="ARAR Replika",
		gender="female",			
		chance=RateSpawn_ARARRare,
	};
local ADLRVeryCommon = {
		name="ADLR Replika",
		gender="male",			
		chance=RateSpawn_ADLRVeryCommon,
	};
local ADLRCommon = {
		name="ADLR Replika",
		gender="male",			
		chance=RateSpawn_ADLRCommon,
	};
local KLBRCommon = {
		name="KLBR Replika",
		gender="female",			
		chance=RateSpawn_KLBRCommon,
	};
local KLBRRare = {
		name="KLBR Replika",
		gender="female",			
		chance=RateSpawn_KLBRRare,
	};
local STARVeryCommon = {
		name="STAR Replika",
		gender="female",			
		chance=RateSpawn_STARVeryCommon,
	};
local STARCommon = {
		name="STAR Replika",
		gender="female",			
		chance=RateSpawn_STARCommon,
	};
local STARRare = {
		name="STAR Replika",
		gender="female",			
		chance=RateSpawn_STARRare,
	};
local STCRCommon = {
		name="STCR Replika",
		gender="female",			
		chance=RateSpawn_STCRCommon,
	};
local STCRRare = {
		name="STCR Replika",
		gender="female",			
		chance=RateSpawn_STCRRare,
	};
local KNCRCommon = {
		name="KNCR Replika",
		gender="female",			
		chance=RateSpawn_KNCRCommon,
	};
local GesBioVeryCommon = {
		name="Gestalt Biologist",
		chance=RateSpawn_GesBioVeryCommon,
	};
local GestaltStudentLong = {
		name="Gestalt Student Long",
		chance=RateSpawn_GestaltStudentLong,
		gender="female",
	};
local GestaltStudentMid = {
		name="Gestalt Student Medium",
		chance=RateSpawn_GestaltStudentMid,
		gender="female",
	};
local GestaltStudentMale = {
		name="Gestalt Student Male",
		chance=RateSpawn_GestaltStudentMale,
		gender="male",
	};
local FKLR = {
		name="FKLR Replika",
		gender="female",			
		chance=RateSpawn_FKLR,
	};
local MNHR = {
		name="MNHR Replika",
		gender="female",			
		chance=RateSpawn_MNHR,
	};
local PAVeteran = {
		name="People Army Veteran",
		gender="female",			
		chance=RateSpawn_PAVeteran,
	};
local PAMedic = {
		name="People Army Medic",
		gender="female",			
		chance=RateSpawn_PAMedic,
	};
	
	
	
	
ZombiesZoneDefinition.Pharmacist[GesBioVeryCommon] = GesBioVeryCommon;
ZombiesZoneDefinition.Doctor[GesBioVeryCommon] = GesBioVeryCommon;
ZombiesZoneDefinition.Doctor[PAMedic] = PAMedic;
ZombiesZoneDefinition.Spiffo[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.Gigamart[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.PizzaWhirled[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.Dinner[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.PileOCrepe[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.Coffeeshop[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.SeaHorse[EULRVeryCommon] = EULRVeryCommon;
ZombiesZoneDefinition.Restaurant[EULRVeryCommon] = EULRVeryCommon;

ZombiesZoneDefinition.Survivalist[STARCommon] = STARCommon;
ZombiesZoneDefinition.Survivalist[STCRCommon] = STCRCommon;

ZombiesZoneDefinition.Rocker[GestaltStudentLong] = GestaltStudentLong;
ZombiesZoneDefinition.Rocker[GestaltStudentMid] = GestaltStudentMid;
ZombiesZoneDefinition.Rocker[GestaltStudentMale] = GestaltStudentMale;
ZombiesZoneDefinition.Rocker[EULRCommon] = EULRCommon;

ZombiesZoneDefinition.Shelter[GestaltStudentLong] = GestaltStudentLong;
ZombiesZoneDefinition.Shelter[GestaltStudentMid] = GestaltStudentMid;
ZombiesZoneDefinition.Shelter[GestaltStudentMale] = GestaltStudentMale;

ZombiesZoneDefinition.Rich[ADLRCommon] = ADLRCommon;
ZombiesZoneDefinition.Rich[FKLR] = FKLR;
ZombiesZoneDefinition.HotelRich[ADLRCommon] = ADLRCommon;
ZombiesZoneDefinition.HotelRich[FKLR] = FKLR;

ZombiesZoneDefinition.BaseballFan[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.BaseballFan[KNCRCommon] = KNCRCommon;

ZombiesZoneDefinition.VariousFoodMarket[EULRVeryCommon] = EULRVeryCommon;

ZombiesZoneDefinition.FarmingStore[EULRRare] = EULRRare;
ZombiesZoneDefinition.FarmingStore[ARARVeryCommon] = ARARVeryCommon;

ZombiesZoneDefinition.Athletic[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.StreetSports[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.Baseball[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.Baseball[KNCRCommon] = KNCRCommon;

ZombiesZoneDefinition.Farm[ARARRare] = ARARRare;
ZombiesZoneDefinition.CarRepair[ARARRare] = ARARRare;

ZombiesZoneDefinition.Fossoil[STCRCommon] = STCRCommon;

ZombiesZoneDefinition.Gas2Go[EULRRare] = EULRRare;
ZombiesZoneDefinition.ThunderGas[EULRRare] = EULRRare;
ZombiesZoneDefinition.McCoys[EULRRare] = EULRRare;

ZombiesZoneDefinition.Factory[ARARCommon] = ARARCommon;

ZombiesZoneDefinition.ConstructionSite[ARARRare] = ARARRare;

ZombiesZoneDefinition.Offices[EULRRare] = EULRRare;

ZombiesZoneDefinition.Bank[EULRVeryCommon] = EULRVeryCommon;

ZombiesZoneDefinition.SwimmingPool[STCRCommon] = STCRCommon;

ZombiesZoneDefinition.FancyHotel[ADLRCommon] = ADLRCommon;
ZombiesZoneDefinition.FancyHotel[FKLR] = FKLR;
ZombiesZoneDefinition.CountryClub[ADLRCommon] = ADLRCommon;
ZombiesZoneDefinition.CountryClub[FKLR] = FKLR;

ZombiesZoneDefinition.Spa[STCRCommon] = STCRCommon;

ZombiesZoneDefinition.Golf[ADLRVeryCommon] = ADLRVeryCommon;

ZombiesZoneDefinition.Police[STARVeryCommon] = STARVeryCommon;
ZombiesZoneDefinition.PoliceState[STARVeryCommon] = STARVeryCommon;

ZombiesZoneDefinition.Prison[STARVeryCommon] = STARVeryCommon;

ZombiesZoneDefinition.FireDept[KLBRCommon] = KLBRCommon;

ZombiesZoneDefinition.Army[KNCRCommon] = KNCRCommon;
ZombiesZoneDefinition.Army[STARCommon] = STARCommon;
ZombiesZoneDefinition.Army[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.Army[PAVeteran] = PAVeteran;
ZombiesZoneDefinition.Army[PAMedic] = PAMedic;

ZombiesZoneDefinition.SecretBase[KLBRRare] = KLBRRare;
ZombiesZoneDefinition.SecretBase[KNCRCommon] = KNCRCommon;
ZombiesZoneDefinition.SecretBase[STARCommon] = STARCommon;
ZombiesZoneDefinition.SecretBase[STCRCommon] = STCRCommon;
ZombiesZoneDefinition.SecretBase[FKLR] = FKLR;
ZombiesZoneDefinition.SecretBase[MNHR] = MNHR;
ZombiesZoneDefinition.SecretBase[PAVeteran] = PAVeteran;
ZombiesZoneDefinition.SecretBase[PAMedic] = PAMedic;

ZombiesZoneDefinition.Bar[STARRare] = STARRare;
ZombiesZoneDefinition.Bar[STCRRare] = STCRRare;
ZombiesZoneDefinition.Bar[KLBRRare] = KLBRRare;

ZombiesZoneDefinition.School[GestaltStudentLong] = GestaltStudentLong;

ZombiesZoneDefinition.Boxing[KNCRCommon] = KNCRCommon;
ZombiesZoneDefinition.Boxing[STCRCommon] = STCRCommon;

-- total chance can be over 100% we don't care as we'll roll on the totalChance and not a 100 (unlike the specific outfits on top of this)
Signalis_ZombiesZoneDefinition.Default = ZombiesZoneDefinition.Default or {};

table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", gender="female", chance=RateSpawn_EULRCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", gender="female", chance=RateSpawn_ARARCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", gender="female", chance=RateSpawn_KLBRCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=RateSpawn_GestaltStudentLong});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=RateSpawn_GestaltStudentMid});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=RateSpawn_GestaltStudentMale});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Officer", chance=RateSpawn_GesBioVeryCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=RateSpawn_GesBioVeryCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", gender="female", chance=RateSpawn_STARCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", gender="female", chance=RateSpawn_STCRCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", gender="female", chance=RateSpawn_KNCRCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", gender="male", chance=RateSpawn_ADLRCommon});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", gender="female", chance=RateSpawn_FKLR});
table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", gender="female", chance=RateSpawn_MNHR});
table.insert(ZombiesZoneDefinition.Default,{name = "PAVeteran", gender="female", chance=RateSpawn_PAVeteran});
table.insert(ZombiesZoneDefinition.Default,{name = "PAMedic", gender="female", chance=RateSpawn_PAMedic});

-- Specialized
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="bakery", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Officer", chance=RateSpawn_STARCommon, room="artstore"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="bakerykitchen", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="bandkitchen", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="bandlivingroom", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="bandmerch", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=RateSpawn_STCRCommon, room="bandmerch", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=RateSpawn_STARCommon, room="bandmerch", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="bar", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="bookstore", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=RateSpawn_KNCRCommon, room="butcher", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="cafe", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="carsupply", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="chineserestaurant", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="church", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="classroom", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=RateSpawn_GestaltStudentLong, room="classroom", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=RateSpawn_GestaltStudentMid, room="classroom", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=RateSpawn_GestaltStudentMale, room="classroom", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="classroom", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="clothingstore", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="construction", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=RateSpawn_GesBioVeryCommon, room="dentiststorage"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="factory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="factory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="factory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=RateSpawn_STCRCommon, room="gym", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=RateSpawn_KNCRCommon, room="gym", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=RateSpawn_KNCRCommon, room="hunting", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="knifefactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=RateSpawn_ADLRCommon, room="knifefactory", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="knifefactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="library", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="loggingfactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="loggingfactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", chance=RateSpawn_MNHR, room="loggingfactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=RateSpawn_GesBioVeryCommon, room="medical"});
table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=RateSpawn_GesBioVeryCommon, room="pharmacy"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=RateSpawn_ADLRCommon, room="prisoncells", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=RateSpawn_STARCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=RateSpawn_STCRCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=RateSpawn_KNCRCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", chance=RateSpawn_MNHR, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="prisoncells", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=RateSpawn_STARCommon, room="policestorage", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="radiofactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=RateSpawn_KLBRCommon, room="radiofactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=RateSpawn_ADLRCommon, room="radiofactory", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="radiofactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=RateSpawn_STARCommon, room="security", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=RateSpawn_KNCRCommon, room="stripclub", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="theatre", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=RateSpawn_ADLRCommon, room="theatre", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="toolstorage", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="toolstore", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=RateSpawn_GestaltStudentLong, room="toystore", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=RateSpawn_GestaltStudentMid, room="toystore", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=RateSpawn_GestaltStudentMale, room="toystore", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=RateSpawn_ARARCommon, room="warehouse", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=RateSpawn_EULRCommon, room="wirefactory", gender="female"});
table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=RateSpawn_ADLRCommon, room="wirefactory", gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=RateSpawn_FKLR, room="wirefactory", gender="female"});

-- SandboxVars.SignailsSetting.RateSpawn_EULRVeryCommon

-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", gender="female", chance=15});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", gender="female", chance=15});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", gender="female", chance=15});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=10});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=10});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=20});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Officer", chance=5});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=5});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", gender="female", chance=5});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", gender="female", chance=5});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", gender="female", chance=5});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", gender="male", chance=10});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", gender="female", chance=0});
-- table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", gender="female", chance=3});
-- table.insert(ZombiesZoneDefinition.Default,{name = "PAVeteran", gender="female", chance=2});
-- table.insert(ZombiesZoneDefinition.Default,{name = "PAMedic", gender="female", chance=2});

-- -- Specialized
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="bakery", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Officer", chance=20, room="artstore"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="bakerykitchen", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="bandkitchen", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="bandlivingroom", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="bandmerch", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=5, room="bandmerch", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=5, room="bandmerch", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=20, room="bar", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=70, room="bookstore", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=20, room="butcher", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="cafe", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=20, room="carsupply", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="chineserestaurant", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="church", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="classroom", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=10, room="classroom", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=10, room="classroom", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=20, room="classroom", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="classroom", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="clothingstore", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=20, room="construction", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=20, room="dentiststorage"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="factory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="factory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="factory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=10, room="gym", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=5, room="gym", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=5, room="hunting", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="knifefactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=10, room="knifefactory", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="knifefactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=70, room="library", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="loggingfactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="loggingfactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", chance=3, room="loggingfactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=20, room="medical"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "Gestalt Biologist", chance=20, room="pharmacy"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=10, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=10, room="prisoncells", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=10, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=5, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STCR Replika", chance=5, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=3, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "MNHR Replika", chance=3, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="prisoncells", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=10, room="policestorage", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="radiofactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KLBR Replika", chance=10, room="radiofactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=10, room="radiofactory", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="radiofactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "STAR Replika", chance=10, room="security", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "KNCR Replika", chance=5, room="stripclub", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="theatre", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=10, room="theatre", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=20, room="toolstorage", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=20, room="toolstore", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentLong", chance=10, room="toystore", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMid", chance=10, room="toystore", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "GestaltStudentMale", chance=20, room="toystore", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ARAR Replika", chance=20, room="warehouse", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "EULR Replika", chance=20, room="wirefactory", gender="female"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "ADLR Replika", chance=10, room="wirefactory", gender="male"});
-- table.insert(ZombiesZoneDefinition.Default,{name = "FKLR Replika", chance=0, room="wirefactory", gender="female"});