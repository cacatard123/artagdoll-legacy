local headshotSfxCvar = GetConVar("ar_headshotSfx")

function RagdollSys.PlayHeadshotSound(pos)
    if not headshotSfxCvar then
        headshotSfxCvar = GetConVar("ar_headshotSfx")
        if not headshotSfxCvar then return end
    end
    
    if not headshotSfxCvar:GetBool() then return end
    if not pos or pos == Vector(0, 0, 0) then return end
    
    local chosenSound = RagdollSys.HeadshotSounds[math.random(1, #RagdollSys.HeadshotSounds)]
    if chosenSound then
        sound.Play(chosenSound, pos, 75, 100, 1)
    end
end

function RagdollSys.GetBoneTransform(ent, boneName)
    if not IsValid(ent) or not boneName then return nil end
    
    local boneID = ent:LookupBone(boneName)
    if not boneID then return nil end
    
    local bonePos, boneAng = ent:GetBonePosition(boneID)
    if not bonePos then return nil end
    
    return bonePos, boneAng
end

local headBoneCache = {}

function RagdollSys.IsHeadshot(ent, dmgpos, hitgroup)
    if hitgroup == HITGROUP_HEAD then return true end
    
    if not IsValid(ent) or not dmgpos or dmgpos == Vector(0, 0, 0) then 
        return false 
    end
    
    local boneID = headBoneCache[ent]
    if not boneID then
        boneID = ent:LookupBone("ValveBiped.Bip01_Head1")
        if not boneID then return false end
        headBoneCache[ent] = boneID
    end
    
    local headPos, headAng = ent:GetBonePosition(boneID)
    if not headPos or not headAng then 
        headBoneCache[ent] = nil
        return false 
    end
    
    local cfg = RagdollSys.Config
    local centerPos = headPos + (headAng:Forward() * cfg.HeadOffset.x) 
                              + (headAng:Right() * cfg.HeadOffset.y) 
                              + (headAng:Up() * cfg.HeadOffset.z)
    
    local distSqr = centerPos:DistToSqr(dmgpos)
    local radiusSqr = cfg.HeadRadius * cfg.HeadRadius
    
    return distSqr <= radiusSqr
end

hook.Add("EntityRemoved", "RagdollSys_ClearBoneCache", function(ent)
    headBoneCache[ent] = nil
end)