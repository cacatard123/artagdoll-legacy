RagdollSys.EntityDamageData = RagdollSys.EntityDamageData or {}
RagdollSys.Dolls = RagdollSys.Dolls or {}

function RagdollSys.StoreDamageData(entity, hitgroup, damagePos)
    if not IsValid(entity) then return end
    
    RagdollSys.EntityDamageData[entity] = {
        hitgroup = hitgroup or HITGROUP_GENERIC,
        pos = damagePos,
        time = CurTime()
    }
end

function RagdollSys.GetAndClearDamageData(sourceEnt, ragdoll)
    local data = nil
    
    if IsValid(sourceEnt) and RagdollSys.EntityDamageData[sourceEnt] then
        data = RagdollSys.EntityDamageData[sourceEnt]
        RagdollSys.EntityDamageData[sourceEnt] = nil
    end
    
    if IsValid(ragdoll) and RagdollSys.EntityDamageData[ragdoll] then
        data = data or RagdollSys.EntityDamageData[ragdoll]
        RagdollSys.EntityDamageData[ragdoll] = nil
    end
    
    return data
end

function RagdollSys.CreateRagdoll(player)
    if not IsValid(player) then return end
    
    if IsValid(RagdollSys.Dolls[player]) then
        SafeRemoveEntity(RagdollSys.Dolls[player])
    end

    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then return end

    local model = player:GetModel()
    if not model or model == "" then
        SafeRemoveEntity(ragdoll)
        return
    end
    
    ragdoll:SetModel(model)
    ragdoll:SetPos(player:GetPos())
    ragdoll:SetAngles(player:GetAngles())
    ragdoll:Spawn()
    ragdoll:SetOwner(player)
    ragdoll:SetSkin(player:GetSkin())
    ragdoll:SetColor(player:GetColor())
    ragdoll:SetMaterial(player:GetMaterial())

    local bodyGroupCount = player:GetNumBodyGroups()
    if bodyGroupCount and bodyGroupCount > 0 then
        for i = 0, bodyGroupCount - 1 do
            ragdoll:SetBodygroup(i, player:GetBodygroup(i))
        end
    end

    local selfVel = player:GetVelocity()
    local physCount = ragdoll:GetPhysicsObjectCount()

    if physCount and physCount > 0 then
        for i = 0, physCount - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                local bone = ragdoll:TranslatePhysBoneToBone(i)
                if bone then
                    local matrix = player:GetBoneMatrix(bone)
                    if matrix then
                        phys:SetPos(matrix:GetTranslation())
                        phys:SetAngles(matrix:GetAngles())
                        phys:SetVelocity(selfVel)
                    end
                end
            end
        end
    end

    ragdoll.IsPlayerRagdoll = true
    ragdoll.OwnerPlayer = player

    if player.SpectateEntity and player.Spectate then
        player:SpectateEntity(ragdoll)
        player:Spectate(OBS_MODE_CHASE)
    end

    RagdollSys.Dolls[player] = ragdoll
    return ragdoll
end

function RagdollSys.SetupRagdoll(ragdoll)
    if not IsValid(ragdoll) then return end
    if not AR_Manager or AR_Manager.ActiveRagdolls[ragdoll] then return end

    local cvar = GetConVar("ar_PlayerCollideRagdoll")
    local shouldCollide = cvar and cvar:GetBool() or false
    
    if shouldCollide then
        ragdoll:SetCollisionGroup(COLLISION_GROUP_NONE)
    else
        ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    end

    if DeathFaces and DeathFaces.Activate then
        DeathFaces:Activate(ragdoll, 1.3, math.Rand(0.5, 1.5))
    end

    if not ActiveRagdoll then return end
    
    if not RagdollSys.Config or not RagdollSys.Config.AnimatorModel or not RagdollSys.BoneList then 
        return 
    end
    
    local animator = ActiveRagdoll:CreateAnimator(ragdoll, RagdollSys.Config.AnimatorModel, RagdollSys.BoneList)
    if not animator then return end
    
    local sourceEnt = ragdoll:GetOwner()
    if IsValid(sourceEnt) and sourceEnt:IsOnFire() then
        ragdoll:Ignite(10, 100)
    end
    
    local damageData = IsValid(sourceEnt) and RagdollSys.EntityDamageData[sourceEnt] or nil
    local wasHeadshot = damageData and damageData.hitgroup == HITGROUP_HEAD
    local initialBehavior = ragdoll:IsOnFire() and "Burning" or "Stagger"

    if not AR_Manager.RegisterRagdoll then return end
    
    local controller = AR_Manager:RegisterRagdoll(ragdoll, initialBehavior)
    if not controller then return end
    
    if damageData and damageData.pos then
        controller.dmgpos = damageData.pos
        controller.hitgroup = damageData.hitgroup or HITGROUP_GENERIC
        controller.isHeadshot = wasHeadshot
        if IsValid(sourceEnt) then
            RagdollSys.EntityDamageData[sourceEnt] = nil
        end
    else
        controller.dmgpos = nil
        controller.hitgroup = HITGROUP_GENERIC
        controller.isHeadshot = false
    end
    
    if controller.isHeadshot and controller.SetDead then
        controller:SetDead()
    end
    
    local controllerID = "EuphoriaFSM_" .. (controller.EntIndex or ragdoll:EntIndex())
    
    if ragdoll.AddCallback then
        ragdoll:AddCallback("PhysicsCollide", function(ent, data, phys)
            if controller and controller.OnPhysicsCollide then
                controller:OnPhysicsCollide(data, phys)
            end
        end)
    end
    
    if ragdoll.CallOnRemove then
        ragdoll:CallOnRemove(controllerID, function()
            if controller and controller.OnRemove then
                controller:OnRemove()
            end
        end)
    end
end

local PLAYER = FindMetaTable("Player")
if PLAYER then
    PLAYER.CreateRagdoll = RagdollSys.CreateRagdoll
    PLAYER.GetRagdollEntity = function(self) 
        if not IsValid(self) then return NULL end
        return RagdollSys.Dolls[self] or NULL 
    end
end