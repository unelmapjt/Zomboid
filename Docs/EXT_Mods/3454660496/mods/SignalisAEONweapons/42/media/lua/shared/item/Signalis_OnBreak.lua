OnBreak = OnBreak or {}

function OnBreak.DisposableStunProd_Used(item, player)
	OnBreak.GroundHandler(item, player, "Signalis_Weapons.DisposableStunProd_Used")
	OnBreak.HandleHandler(item, player, "Signalis_Weapons.DisposableStunProd_Used", false)
end