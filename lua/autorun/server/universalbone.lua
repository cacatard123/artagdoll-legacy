-- custom model support thingy

if SERVER then AddCSLuaFile() end

UniversalBone = UniversalBone or {}

local function GetPhysBoneData(target, physID)
    local phys = target:GetPhysicsObjectNum(physID)
    if not IsValid(phys) then return nil end

    local boneID = target:TranslatePhysBoneToBone(physID)
    local boneName = target:GetBoneName(boneID)
    
    if not boneName then return nil end
    
    return {
        Phys = phys,
        Name = boneName,
        BoneID = boneID,
        PhysID = physID
    }
end

function UniversalBone.FindBone(target, boneInput)
    if not IsValid(target) then return nil end
    if not isstring(boneInput) then return nil end

    local count = target:GetPhysicsObjectCount()

    for i = 0, count - 1 do
        local data = GetPhysBoneData(target, i)

        if data and data.Name == boneInput then
            return data.Phys, data.PhysID
        end
    end

    return nil, nil
end

function UniversalBone.BuildCache(target)
    if not IsValid(target) then return {} end
    
    local cache = {}
    local count = target:GetPhysicsObjectCount()
    
    for i = 0, count - 1 do
        local data = GetPhysBoneData(target, i)
        if data then
            cache[data.Name] = data.Phys
        end
    end
    
    return cache
end