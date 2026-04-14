include("Components/Utils/activeragdoll.lua")
include("Components/Utils/DeathFaces.lua")

cvars.AddChangeCallback("ar_PlayerCollideRagdoll", function(convar_name, old_value, new_value)
    local shouldCollide = tobool(new_value) or (tonumber(new_value) == 1)
    local newGroup = shouldCollide and COLLISION_GROUP_NONE or COLLISION_GROUP_WEAPON
    
    if AR_Manager and AR_Manager.ActiveRagdolls then
        for ent, _ in pairs(AR_Manager.ActiveRagdolls) do
            if IsValid(ent) then
                ent:SetCollisionGroup(newGroup)
            end
        end
    end
end, "AR_UpdateCollision")

hook.Add("OnEntityCreated", "ActiveRagdollPhysics", function(ent)
    local cvar = GetConVar("ar_enable")

    if not IsValid(ent) or (cvar and not cvar:GetBool()) then return end

    local class = ent:GetClass()
    if class ~= "prop_ragdoll" and class ~= "prop_ragdoll_attached" then return end
    
    ent:Fire("EnableDamage", "1")
    
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        
        local cvarDelayed = GetConVar("ar_enable")
        if cvarDelayed and not cvarDelayed:GetBool() then return end

        if AR_Manager and AR_Manager.ActiveRagdolls and AR_Manager.ActiveRagdolls[ent] then return end
        
        local model = ent:GetModel()
        if not model or model == "" then return end
        
        if RagdollSys.BlacklistedModels[string.lower(model)] then return end
        RagdollSys.SetupRagdoll(ent)

        if ent.AR_PreStoredData and AR_Manager.ActiveRagdolls[ent] then
            local controller = AR_Manager.ActiveRagdolls[ent]
            local data = ent.AR_PreStoredData
            
            if data.pos then controller.dmgpos = data.pos end
            if data.isHeadshot then 
                controller.isHeadshot = true 
                if controller.SetDead then controller:SetDead() end
            end
            
            ent.AR_PreStoredData = nil
        end
    end)
end)

hook.Add("ScaleNPCDamage", "AREHeadshotDetection", function(npc, hitgroup, dmginfo)
    if not IsValid(npc) or not dmginfo then return end
    
    local damageType = dmginfo:GetDamageType()
    if not damageType then return end
    
    local isBlast = bit.band(damageType, DMG_BLAST) == DMG_BLAST
    
    if isBlast then
        local willDie = (npc:Health() - dmginfo:GetDamage()) <= 0
        if willDie then
            npc.AR_BlastDeath = true
        end
    else
        npc.AR_BlastDeath = nil
    end
    
    if not isBlast then
        local dmgPos = dmginfo:GetDamagePosition()
        if dmgPos and dmgPos ~= Vector(0, 0, 0) then
            local isHeadshot = RagdollSys.IsHeadshot(npc, dmgPos, hitgroup)
            
            if isHeadshot then RagdollSys.PlayHeadshotSound(dmgPos) end
            RagdollSys.StoreDamageData(npc, isHeadshot and HITGROUP_HEAD or HITGROUP_GENERIC, dmgPos)
        end
    end
end)

hook.Add("ScalePlayerDamage", "AREPlayerHeadDetections", function(ply, hitgroup, dmginfo)
    if not IsValid(ply) or not dmginfo then return end
    
    local damageType = dmginfo:GetDamageType()
    if not damageType then return end
    
    local isBlast = bit.band(damageType, DMG_BLAST) == DMG_BLAST
    
    if isBlast then
        local willDie = (ply:Health() - dmginfo:GetDamage()) <= 0
        if willDie then
            ply.AR_BlastDeath = true
        end
    else
        ply.AR_BlastDeath = nil
    end
    
    if not isBlast then
        local dmgPos = dmginfo:GetDamagePosition()
        if dmgPos and dmgPos ~= Vector(0, 0, 0) then
            local isHeadshot = RagdollSys.IsHeadshot(ply, dmgPos, hitgroup)
            
            if isHeadshot then RagdollSys.PlayHeadshotSound(dmgPos) end

            RagdollSys.StoreDamageData(ply, isHeadshot and HITGROUP_HEAD or hitgroup, dmgPos)
        end
    end
end)

hook.Add("PlayerDeath", "AREPlayerDeathInfo", function(victim)
    if not IsValid(victim) then return end
    
    if not RagdollSys.EntityDamageData[victim] then
        RagdollSys.StoreDamageData(victim, HITGROUP_GENERIC, nil)
    end
end)

hook.Add("PostPlayerDeath", "AREPlayerRagdoll", function(ply)
    if not IsValid(ply) then return end
    
    local hadBlast = ply.AR_BlastDeath
    ply.AR_BlastDeath = nil
    
    local dmgData = RagdollSys.EntityDamageData[ply]

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local ragdoll = ply:GetRagdollEntity()
        if IsValid(ragdoll) and ragdoll:IsRagdoll() then
            RagdollSys.SetupRagdoll(ragdoll)
            
            if hadBlast then
                timer.Simple(0.1, function()
                    if IsValid(ragdoll) then
                        ragdoll:Ignite(8, 0)
                    end
                end)
            else
                if AR_Manager and AR_Manager.ActiveRagdolls and AR_Manager.ActiveRagdolls[ragdoll] then
                    local controller = AR_Manager.ActiveRagdolls[ragdoll]
                    
                    if dmgData then
                        local storedPos = dmgData.pos or dmgData.dmgPos
                        if storedPos then
                            controller.dmgpos = storedPos
                        end
                        
                        if dmgData.hitgroup == HITGROUP_HEAD then
                            controller.isHeadshot = true
                            if controller.SetDead then controller:SetDead() end
                        end
                    end
                end
            end
        end
    end)
end)

hook.Add("CreateEntityRagdoll", "ARETransferDamage", function(ent, ragdoll)
    if not IsValid(ent) or not IsValid(ragdoll) then return end
    
    local hadBlast = ent.AR_BlastDeath
    if hadBlast then
        ent.AR_BlastDeath = nil
        timer.Simple(0.1, function()
            if IsValid(ragdoll) then
                ragdoll:Ignite(8, 0)
            end
        end)
        return 
    end

    local dmgData = RagdollSys.EntityDamageData[ent]
    if dmgData then
        local storedPos = dmgData.pos or dmgData.dmgPos
        
        if ent.AR_BlastDeath then
            storedPos = nil
        end

        ragdoll.AR_PreStoredData = {
            pos = storedPos,
            isHeadshot = (dmgData.hitgroup == HITGROUP_HEAD)
        }
    end
end)

hook.Add("EntityTakeDamage", "AREDmg", function(ent, dmginfo)
    if not IsValid(ent) or not dmginfo then return end
    
    if ent.already_took_force == nil then 
        ent.already_took_force = false 
    end
    
    if ent.already_took_force then
        dmginfo:SetDamageForce(dmginfo:GetDamageForce() * 0.0001)
        return
    end
    
    ent.already_took_force = true
    timer.Simple(0, function()
        if IsValid(ent) then
            ent.already_took_force = false
        end
    end)

    local dmgforce = dmginfo:GetDamageForce()
    local length = dmgforce:Length()
    
    if dmginfo:GetAmmoType() == -1 then
        dmginfo:SetDamageForce(dmgforce)
    elseif length > 0 then
        dmginfo:SetDamageForce(dmgforce * (2200 / length))
    end

    local class = ent:GetClass()
    if class ~= "prop_ragdoll" and class ~= "prop_ragdoll_attached" then return end

    local damageType = dmginfo:GetDamageType()
    if not damageType then return end
    
    local isBullet = bit.band(damageType, DMG_BULLET) == DMG_BULLET
    local isCrush = bit.band(damageType, DMG_CRUSH) == DMG_CRUSH
    local isBlast = bit.band(damageType, DMG_BLAST) == DMG_BLAST

    if not AR_Manager or not AR_Manager.ActiveRagdolls then return end

    local controller = AR_Manager.ActiveRagdolls[ent]
    if not controller then return end

    local dmgPos = dmginfo:GetDamagePosition()
    if dmgPos == Vector(0, 0, 0) then
        dmgPos = ent:GetPos() + ent:OBBCenter()
    end

    if dmgPos and dmgPos ~= Vector(0, 0, 0) then
        if isBullet and not ent.AR_BlastDeath then
            controller.dmgpos = dmgPos
        end

        if ent.AR_BlastDeath then
            controller.dmgpos = nil
        end

        local isHeadshot = isBullet and RagdollSys.IsHeadshot(ent, dmgPos, HITGROUP_GENERIC)
        
        if isHeadshot then
            RagdollSys.PlayHeadshotSound(dmgPos)
            controller.isHeadshot = true
            if controller.SetDead then
                controller:SetDead()
            end
        elseif ent.AR_Health and ent.CanTakeDamage then
            if isCrush then
                local maxVelocity = 0
                local physCount = ent:GetPhysicsObjectCount()
                if physCount and physCount > 0 then
                    for i = 0, physCount - 1 do
                        local phys = ent:GetPhysicsObjectNum(i)
                        if IsValid(phys) then
                            local vel = phys:GetVelocity():Length()
                            if vel > maxVelocity then
                                maxVelocity = vel
                            end
                        end
                    end
                end
                
                if maxVelocity < 175 then
                    dmginfo:SetDamage(0)
                    return
                end
                
                dmginfo:SetDamage(dmginfo:GetDamage() * 0.3)
            end
            
            if isBullet then
                dmginfo:SetDamage(dmginfo:GetDamage() * 0.5)
            end
            
            ent.AR_Health = ent.AR_Health - dmginfo:GetDamage()
            
            if ent.AR_Health <= 0 then
                if isBlast then
                    ent.AR_BlastDeath = true
                    controller.dmgpos = nil 
                else
                    ent.AR_BlastDeath = nil
                end
                
                if controller.SetDead then
                    controller:SetDead()
                end
            end
        end
    end
end)

if timer.Exists("ARECleanupDamageData") then
    timer.Remove("ARECleanupDamageData")
end

timer.Create("ARECleanupDamageData", 3, 0, function()
    if not RagdollSys or not RagdollSys.EntityDamageData then return end
    
    local now = CurTime()
    local cutoff = now - 2
    for ent, data in pairs(RagdollSys.EntityDamageData) do
        if not IsValid(ent) or not data or data.time < cutoff then
            RagdollSys.EntityDamageData[ent] = nil
        end
    end
end)