local SoundManager = {}
SoundManager.__index = SoundManager

local SoundDuration = sound.GetDuration or function() return 1.5 end

local MODEL_PATTERNS = {
    {pattern = "female", folder = "Female/"},
    {pattern = "alyx", folder = "Female/"},
    {pattern = "mossman", folder = "Female/"},
    {pattern = "combine", folder = "Combine/"},
    {pattern = "police", folder = "Combine/"},
    {pattern = "metrocop", folder = "Combine/"},
    {pattern = "cp_", folder = "Combine/"},
}

function SoundManager:New(ragdoll)
    return setmetatable({
        ragdoll = ragdoll,
        sound = nil,
        state = "idle",
        loopParams = nil,
        lastPlayed = nil,
        timerID = "SM_" .. (IsValid(ragdoll) and ragdoll:EntIndex() or "invalid")
    }, SoundManager)
end

function SoundManager:GetGenderFolder()
    if not IsValid(self.ragdoll) then return "Male/" end
    
    local model = self.ragdoll:GetModel():lower()
    for _, data in ipairs(MODEL_PATTERNS) do
        if model:find(data.pattern) then
            return data.folder
        end
    end
    return "Male/"
end

function SoundManager:CanPlay()
    if not IsValid(self.ragdoll) then return false end
    if self.state == "fading" then return false end
    
    local health = self.ragdoll.AR_Health
    return not health or health > 35
end

function SoundManager:FindSounds(reactionType)
    local baseFolder = "SFX/"
    local genderFolder = self:GetGenderFolder()
    local fullPath = baseFolder .. genderFolder .. reactionType .. "/"
    
    local sounds = file.Find("sound/" .. fullPath .. "*.wav", "GAME")
    local mp3s = file.Find("sound/" .. fullPath .. "*.mp3", "GAME")
    
    if mp3s then
        for _, f in ipairs(mp3s) do
            table.insert(sounds, f)
        end
    end
    
    if #sounds == 0 and genderFolder ~= "Male/" then
        fullPath = baseFolder .. "Male/" .. reactionType .. "/"
        sounds = file.Find("sound/" .. fullPath .. "*.wav", "GAME")
        mp3s = file.Find("sound/" .. fullPath .. "*.mp3", "GAME")
        
        if mp3s then
            for _, f in ipairs(mp3s) do
                table.insert(sounds, f)
            end
        end
    end
    
    return #sounds > 0 and sounds or nil, fullPath
end

function SoundManager:StopSound()
    if self.sound then
        self.sound:Stop()
        self.sound = nil
    end
end

function SoundManager:ClearTimers()
    timer.Remove(self.timerID)
end

function SoundManager:PlaySound(path, level, pitch, volume)
    self:StopSound()
    
    self.sound = CreateSound(self.ragdoll, path)
    if not self.sound then return false end
    
    self.sound:SetSoundLevel(65)
    self.sound:PlayEx(2.5, pitch or 100)
    return true
end

function SoundManager:PlayOneShot(reactionType, level, pitch, volume)
    if not self:CanPlay() then return false end
    
    if self.state == "looping" then
        self:StopLoop()
    end
    
    local sounds, folder = self:FindSounds(reactionType)
    if not sounds then return false end
    
    local sound = table.Random(sounds)
    local success = self:PlaySound(folder .. sound, level, pitch, volume)
    
    if success then
        self.state = "playing"
        self.lastPlayed = sound
    end
    
    return success
end

function SoundManager:PlayLoop(reactionType, level, pitch, volume)
    if not self:CanPlay() then return false end
    
    local sounds, folder = self:FindSounds(reactionType)
    if not sounds then return false end
    
    self:ClearTimers()
    self:StopSound()
    
    self.state = "looping"
    self.loopParams = {
        sounds = sounds,
        folder = folder,
        level = level or 85,
        pitch = pitch or 100,
        volume = volume or 1.5
    }
    
    self:PlayNextLoop()
    return true
end

function SoundManager:PlayNextLoop()
    if not IsValid(self.ragdoll) or self.state ~= "looping" then return end
    if not self:CanPlay() then
        self:StopLoop()
        return
    end
    
    local params = self.loopParams
    if not params then return end
    
    local sound
    if #params.sounds > 1 then
        repeat
            sound = table.Random(params.sounds)
        until sound ~= self.lastPlayed
    else
        sound = params.sounds[1]
    end
    
    self.lastPlayed = sound
    local path = params.folder .. sound
    
    if not self:PlaySound(path, params.level, params.pitch, params.volume) then
        return
    end
    
    local duration = SoundDuration(path) or 1.5
    local cooldown = math.Rand(2, 4)
    
    timer.Create(self.timerID, duration + cooldown, 1, function()
        if IsValid(self.ragdoll) and self.state == "looping" then
            self:PlayNextLoop()
        end
    end)
end

function SoundManager:StopLoop(fadeDuration, callback)
    if self.state ~= "looping" then return end
    
    self:ClearTimers()
    self.loopParams = nil
    
    if fadeDuration and fadeDuration > 0 and self.sound then
        self:FadeOut(fadeDuration, callback)
    else
        self.state = "idle"
        self:StopSound()
        if callback then callback() end
    end
end

function SoundManager:FadeOut(duration, callback)
    if not self.sound or not IsValid(self.ragdoll) then
        if callback then callback() end
        return
    end
    
    self.state = "fading"
    self:ClearTimers()
    
    local sound = self.sound
    local startTime = CurTime()
    local fadeTimerID = self.timerID .. "_fade"
    
    timer.Create(fadeTimerID, 0.05, 0, function()
        if not IsValid(self.ragdoll) or not sound then
            timer.Remove(fadeTimerID)
            self:StopSound()
            self.state = "idle"
            if callback then callback() end
            return
        end
        
        local progress = math.Clamp((CurTime() - startTime) / duration, 0, 1)
        local volume = 4.5 * (1 - progress)
        
        sound:ChangeVolume(volume, 0.05)
        
        if progress >= 1 then
            timer.Remove(fadeTimerID)
            self:StopSound()
            self.state = "idle"
            if callback then callback() end
        end
    end)
end

function SoundManager:Stop(fadeDuration, callback)
    if self.state == "looping" then
        self:StopLoop(fadeDuration, callback)
    elseif self.state == "playing" or self.state == "fading" then
        if fadeDuration and fadeDuration > 0 and self.sound then
            self:FadeOut(fadeDuration, callback)
        else
            self:StopSound()
            self.state = "idle"
            if callback then callback() end
        end
    else
        if callback then callback() end
    end
end

function SoundManager:Cleanup()
    self:ClearTimers()
    self:StopSound()
    self.state = "idle"
    self.loopParams = nil
    self.ragdoll = nil
end

return SoundManager