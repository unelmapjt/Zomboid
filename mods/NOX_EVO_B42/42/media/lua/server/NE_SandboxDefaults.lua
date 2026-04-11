-- --------------------------------------------------------------------------
-- Path: media/lua/server/NE_SandboxDefaults.lua
-- Role: Enforces specific sandbox settings for NOX: EVOLVED.
-- Description: Overrides sandbox variables on world init to ensure difficulty.
-- --------------------------------------------------------------------------

local function NE_ForceSandboxOptions()
    print("[NOX] Enforcing sandbox defaults...")
    
    local sb = SandboxVars
    
    -- --- Zombies ---
    sb.ZombieConfig.Speed = 2               -- Fast Shambler
    sb.ZombieConfig.Strength = 1            -- Strong
    sb.ZombieConfig.Toughness = 1           -- Tough
    
    -- --- Population ---
    sb.Zombies = 2                          -- High Density (x1.5)
    sb.PopulationStartMultiplier = 1.0
    sb.PopulationPeakMultiplier = 1.5
    sb.PopulationPeakDay = 28
    
    -- --- Time & World ---
    sb.StartMonth = 10                      -- October
    sb.StartDay = 1
    
    -- --- Loot Rarity ---
    sb.FoodLoot = 2                         -- Extremely Rare
    sb.WeaponLoot = 2                       -- Extremely Rare
    sb.OtherLoot = 2                        -- Extremely Rare
    sb.MedicalLoot = 2                      -- Extremely Rare
    
    -- --- Nature & Erosion ---
    sb.ErosionSpeed = 2                     -- Normal
    sb.ErosionDays = 0                      -- Already progressed (start with some vines)
    sb.NatureAbundance = 3                  -- Rare
    
    -- --- Infrastructure ---
    sb.ElecShutModifier = 1                 -- 0-30 days
    sb.WaterShutModifier = 1                -- 0-30 days

    print("[NOX] Sandbox defaults applied.")
end

Events.OnInitWorld.Add(NE_ForceSandboxOptions)
