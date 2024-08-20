Scaleforms = exports["meta_libs"]:Scaleforms()

Drilling = {}

Drilling.DisabledControls = {
  30,  -- Move Left/Right
  31,  -- Move Up/Down
  44,  -- Cover
  --1,   -- Look Left/Right
  --2,   -- Look Up/Down
  199, -- Pause Menu
  35, --v
  24, -- attack
  140, -- attack
}
 

DrillPropHandle = nil
cameraInitialized = false
local fadeDuration = 500 
local soundId = nil
local soundPlaying = false
particle = nil

local function requestModel(modelName)
  local modelHash = GetHashKey(modelName)
  RequestModel(modelHash)
  while not HasModelLoaded(modelHash) do
      Citizen.Wait(0)
  end
  return modelHash
end

local function createAndAttachDrill()
  local modelHash = requestModel("hei_prop_heist_drill")
  local playerPed = PlayerPedId()
  local boneIndex = GetPedBoneIndex(playerPed, 57005)  -- Right hand bone index


  -- Create and attach the drill prop
  local prop = CreateObject(modelHash, 1.0, 1.0, 1.0, true, true, false)
  SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)

  local boneIndex = GetPedBoneIndex(playerPed, 28422)
  AttachEntityToEntity(prop, playerPed, boneIndex, 0.0, 0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
  SetEntityAsMissionEntity(prop, true, true)


  return prop
end

Drilling.Start = function(callback)
  if not Drilling.Active then
    Drilling.Active = true
    Drilling.Init()

    -- Load and play the animation
    Drilling.LoadAnimations()
    TaskPlayAnim(PlayerPedId(), "anim@heists@fleeca_bank@drilling", "drill_straight_idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Initialize and play the sound
    

    Drilling.Update(callback)
  end
end

function loadDrillSound()
 
	RequestAmbientAudioBank("DLC_HEIST_FLEECA_SOUNDSET", 0)
	RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL", 0)
	RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL_2", 0)
end

Drilling.Init = function()
  local prop = createAndAttachDrill()
  DrillPropHandle = prop

  FreezeEntityPosition(PlayerPedId(),true)

  if Drilling.Scaleform then
    Scaleforms.UnloadMovie(Drilling.Scaleform)
  end

  Drilling.Scaleform = Scaleforms.LoadMovie("DRILLING")

  -- Initialize drill variables
  Drilling.DrillSpeed = 0.0
  Drilling.DrillPos = 0.0
  Drilling.DrillTemp = 0.0
  Drilling.HoleDepth = 0.1
  
  -- Set initial scaleform values
  Scaleforms.PopFloat(Drilling.Scaleform, "SET_SPEED", 0.0)
  Scaleforms.PopFloat(Drilling.Scaleform, "SET_DRILL_POSITION", 0.0)
  Scaleforms.PopFloat(Drilling.Scaleform, "SET_TEMPERATURE", 0.0)
  Scaleforms.PopFloat(Drilling.Scaleform, "SET_HOLE_DEPTH", 0.0)
end

Drilling.LoadAnimations = function()
  RequestAnimDict("anim@heists@fleeca_bank@drilling")
  while not HasAnimDictLoaded("anim@heists@fleeca_bank@drilling") do
    Wait(100)
  end
end


Drilling.ClearDrillProp = function()
  if DrillPropHandle and DoesEntityExist(DrillPropHandle) then
      print("found")
      -- Detach the prop first (just to be safe)
      DetachEntity(DrillPropHandle, true, true)

      -- Delete the prop
      DeleteObject(DrillPropHandle)
      
      -- Double-check if it still exists
      if DoesEntityExist(DrillPropHandle) then
          SetEntityAsMissionEntity(DrillPropHandle, true, true)
          DeleteEntity(DrillPropHandle)
      end

      -- Set the handle to nil
      DrillPropHandle = nil
  end

  -- Clear the player's animation
  ClearPedTasks(PlayerPedId())
end




Drilling.Update = function(callback)
  local playerLocation = GetEntityCoords(PlayerPedId())
  local heading = GetEntityHeading(PlayerPedId())

  while Drilling.Active do
    Drilling.Draw()
    Drilling.DisableControls()
    Drilling.HandleControls()

    -- Check for the ESC key to stop the drilling process
    if IsControlJustPressed(0, 200) then
      -- Stop the drilling process
      Drilling.Active = false
      StopSound(soundId)
      FreezeEntityPosition(PlayerPedId(),false)
      
      -- Cleanup the drilling (clear animation and remove prop)
      Drilling.ClearDrillProp()
      ClearPedTasks(PlayerPedId()) -- Clear the animation
      StopSound(soundId)
      ReleaseSoundId(soundId) -- Release the sound ID
      StopGameplayCamShaking(true)

    end
    Citizen.Wait(0)
  end

  -- Cleanup when drilling is finished
  Drilling.ClearDrillProp()
  ClearPedTasksImmediately(PlayerPedId())
  StopSound(soundId)
  Drilling.Active = false
  ReleaseSoundId(soundId) -- Release the sound ID
  StopSound(soundId)
  StopGameplayCamShaking(true)
  FreezeEntityPosition(PlayerPedId(),false)
  StopParticleFxLooped(particle, false)
  callback(Drilling.Result)

end

Drilling.Draw = function()
  DrawScaleformMovieFullscreen(Drilling.Scaleform, 255, 255, 255, 255, 255)
end



Drilling.HandleControls = function()
  local last_pos = Drilling.DrillPos
  local last_speed = Drilling.DrillSpeed
  local last_temp = Drilling.DrillTemp


  -- Handle Drill Position with W and S keys
  if IsControlJustPressed(0, 32) then -- W key
    Drilling.DrillPos = math.min(1.0, Drilling.DrillPos + 0.005)
   
    
  elseif IsControlPressed(0, 32) then -- W key
    Drilling.DrillPos = math.min(1.0, Drilling.DrillPos + (0.06 * GetFrameTime() / (math.max(0.1, Drilling.DrillTemp) * 10)))
    
  end

  if IsControlJustPressed(0, 33) then -- S key
    Drilling.DrillPos = math.max(0.0, Drilling.DrillPos - 0.01)
  elseif IsControlPressed(0, 33) then -- S key
    Drilling.DrillPos = math.max(0.0, Drilling.DrillPos - (0.1 * GetFrameTime()))
  end

  -- Handle Drill Speed with Q and E keys
  if IsControlJustPressed(0, 46) then -- Q key
    Drilling.DrillSpeed = math.min(1.0, Drilling.DrillSpeed + 0.05)
  elseif IsControlPressed(0, 46) then -- Q key
    Drilling.DrillSpeed = math.min(1.0, Drilling.DrillSpeed + (0.5 * GetFrameTime()))
  end

  if Drilling.DrillSpeed > 0 and Drilling.Active then
      if not soundPlaying then
        -- Load the sound resources and play the sound
        loadDrillSound()
        soundId = GetSoundId()
        PlaySoundFromEntity(soundId, "Drill", DrillPropHandle, "DLC_HEIST_FLEECA_SOUNDSET", 1, 0)
        ShakeGameplayCam("SKY_DIVING_SHAKE", 0.6)

        particle = StartParticleFxLoopedOnEntity(
    "scr_drill_debris", -- Particle effect name
    drillPropHandle, -- Entity handle (in your case, the drill prop)
    0.0, -- X offset
    -0.55, -- Y offset
    0.01, -- Z offset
    90.0, -- X rotation
    90.0, -- Y rotation
    90.0, -- Z rotation
    0.8, -- Scale of the effect
    false, -- X-axis rotation relative to the entity
    false, -- Y-axis rotation relative to the entity
    false -- Z-axis rotation relative to the entity
)

        soundPlaying = true
      end
    else
      if soundPlaying then
        -- Stop and release the sound
        StopSound(soundId)
        ReleaseSoundId(soundId)
        StopGameplayCamShaking(true)
        soundPlaying = false
      end
    end

  if IsControlJustPressed(0, 44) then -- E key
    Drilling.DrillSpeed = math.max(0.0, Drilling.DrillSpeed - 0.05)
  elseif IsControlPressed(0, 44) then -- E key
    Drilling.DrillSpeed = math.max(0.0, Drilling.DrillSpeed - (0.5 * GetFrameTime()))
  end

  -- Update Scaleform values if changed
  if Drilling.DrillPos ~= last_pos then
    Scaleforms.PopFloat(Drilling.Scaleform, "SET_DRILL_POSITION", Drilling.DrillPos)
  end

  if Drilling.DrillSpeed ~= last_speed then
    Scaleforms.PopFloat(Drilling.Scaleform, "SET_SPEED", Drilling.DrillSpeed)
  end

  Scaleforms.PopFloat(Drilling.Scaleform, "SET_TEMPERATURE", Drilling.DrillTemp)

  if Drilling.DrillPos >= 0.29 and Drilling.DrillPos <= 0.305 or Drilling.DrillPos >= 0.50 and Drilling.DrillPos <= 0.51 or Drilling.DrillPos >= 0.62 and Drilling.DrillPos <= 0.63 or Drilling.DrillPos >= 0.78 and Drilling.DrillPos <= 0.79 then
    PlaySoundFrontend(-1, "Drill_Pin_Break", "DLC_HEIST_FLEECA_SOUNDSET", 1);
    print("broken!")
  end

  -- Update temperature and hole depth based on current position and speed
  if Drilling.DrillPos > Drilling.HoleDepth then
    if Drilling.DrillSpeed > 0.1 then
      Drilling.DrillTemp = math.min(1.0, Drilling.DrillTemp + ((1.0 * GetFrameTime()) * Drilling.DrillSpeed))
      Drilling.HoleDepth = Drilling.DrillPos
    else
      Drilling.DrillPos = Drilling.HoleDepth
    end
  else
    Drilling.DrillTemp = math.max(0.0, Drilling.DrillTemp - (1.0 * GetFrameTime()))
  end

  -- End the drilling if conditions are met
  if Drilling.DrillTemp >= 1.0 then
    Drilling.Result = false
    Drilling.Active = false
  elseif Drilling.DrillPos >= 1.0 then
    Drilling.Result = true
    Drilling.Active = false
  end
end

Drilling.DisableControls = function()
  for _,control in ipairs(Drilling.DisabledControls) do
    DisableControlAction(0, control, true)
  end
end

Drilling.EnableControls = function()
  for _,control in ipairs(Drilling.DisabledControls) do
    DisableControlAction(0, control, false)
  end
end

AddEventHandler("Drilling:Start", Drilling.Start)
