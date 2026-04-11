--Body Parts List --> Foot_L, Foot_R, ForeArm_L, ForeArm_R, Groin, Hand_L, Hand_R, Head, LowerLeg_L, LowerLeg_R, MAX, Neck, Torso_Lower, Torso_Upper, UpperArm_L, UpperArm_R, UpperLeg_L, UpperLeg_R 
--Available Res Types list --> ScratchRes|DeepWoundRes|BurnRes|BulletRes|FractureRes|GlassRes|BiteRes

if(ItemValueTable == nil) then ItemValueTable = {}; end
ItemValueTable["Armor.StarShield"] = 10.00;
if(GlobalArmor == nil) then GlobalArmor = {} end

local WorkingArmor;
	
	
-- Shields
		
	WorkingArmor = "StarShield";
	GlobalArmor[WorkingArmor] = {};
		GlobalArmor[WorkingArmor]["ScratchRes"] = {Hand_L = 85, ForeArm_L = 85, UpperArm_L = 85, Torso_Upper = 85, Torso_Lower = 85, Groin = 85, UpperLeg_L = 85};
		GlobalArmor[WorkingArmor]["DeepWoundRes"] = {Hand_L = 85, ForeArm_L = 85, UpperArm_L = 85, Torso_Upper = 85, Torso_Lower = 85, Groin = 85, UpperLeg_L = 85};	
		GlobalArmor[WorkingArmor]["BiteRes"] = {Hand_L = 85, ForeArm_L = 85, UpperArm_L = 85, Torso_Upper = 85, Torso_Lower = 85, Groin = 85, UpperLeg_L = 85};			
		GlobalArmor[WorkingArmor]["BulletRes"] = {Hand_L = 95, ForeArm_L = 95, UpperArm_L = 95, Torso_Upper = 95, Torso_Lower = 95, Groin = 95, UpperLeg_L = 95};			
		GlobalArmor[WorkingArmor]["Durability"] = 40;
		GlobalArmor[WorkingArmor]["Location"] = "Shield";
		

