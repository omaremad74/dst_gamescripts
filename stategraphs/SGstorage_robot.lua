require("stategraphs/commonstates")

local events =
{
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnSink(),
}

local actionhandlers =
{
    ActionHandler( ACTIONS.PICKUP,    "pickup" ),
    ActionHandler( ACTIONS.CHECKTRAP, "pickup" ),
    ActionHandler( ACTIONS.STORE,     "store"  ),
}

local WALK_SOUNDNAME = "walk_loop"
local ACTIVE_SOUNDNAME = "active_loop"
local NEUTRAL_VOICE_SOUNDNAME = "neutral_voice"

local NEUTRAL_VOCALIZATION_INTERVAL = 20
local NEUTRAL_VOCALIZATION_CHANCE   = 0.1

local PICKUP_VOCALIZATION_CHANCE = 0.2

local function _ReturnToIdle(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState("idle")
    end
end

local idle_on_animover = { EventHandler("animover", _ReturnToIdle) }

local function MakeImmovable(inst)
    inst.Physics:SetTempMass0(true)
end

local function RestoreMobility(inst)
    inst.Physics:SetTempMass0(false)
end

local function PlayVocalizationSound(inst)
    if inst.SoundEmitter:PlayingSound(NEUTRAL_VOICE_SOUNDNAME) or inst.components.inventoryitem:IsHeld() then
        return
    end

    if math.random() < NEUTRAL_VOCALIZATION_CHANCE and (
        inst.sg.mem.last_vocalization_time == nil or (GetTime() - inst.sg.mem.last_vocalization_time > NEUTRAL_VOCALIZATION_INTERVAL)
    ) then
        inst.sg.mem.last_vocalization_time = GetTime()

        inst.SoundEmitter:PlaySound("qol1/collector_robot/neutral_voice", NEUTRAL_VOICE_SOUNDNAME)
    end
end

local states =
{
    State {
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            -- Safeguard.
            if inst.components.fueled:IsEmpty() then
                inst.sg:GoToState("idle_broken")

                return
            end

            inst.components.locomotor:Stop()

            PlayVocalizationSound(inst)

            inst.AnimState:PlayAnimation("idle", true)
        end,

        events = idle_on_animover,
    },

    State{
        name = "pickup",
        tags = { "busy" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("pickup")

            inst.SoundEmitter:KillSound(WALK_SOUNDNAME)
            inst.SoundEmitter:PlaySound("qol1/collector_robot/idle", ACTIVE_SOUNDNAME)

            inst.SoundEmitter:PlaySound("qol1/collector_robot/pickup")

            MakeImmovable(inst)
        end,

        timeline =
        {
            FrameEvent(27, function(inst)
                ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .02, .12, inst, 30)

                inst:PerformBufferedAction()
            end),

            FrameEvent(37, function(inst)
                if math.random() < PICKUP_VOCALIZATION_CHANCE then
                    inst.sg.mem.last_vocalization_time = GetTime()
                    inst.SoundEmitter:PlaySound("qol1/collector_robot/pickup_voice")
                end
            end),
        },

        events = idle_on_animover,
        onexit = RestoreMobility,
    },

    State{
        name = "store",
        tags = { "busy" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("dropoff")

            inst.SoundEmitter:KillSound(WALK_SOUNDNAME)
            inst.SoundEmitter:PlaySound("qol1/collector_robot/idle", ACTIVE_SOUNDNAME)

            inst.SoundEmitter:PlaySound("qol1/collector_robot/dropoff")

            MakeImmovable(inst)
        end,

        timeline =
        {
            FrameEvent(6, function(inst)
                inst:PerformBufferedAction()
            end),

            FrameEvent(50, function(inst)
                inst.sg.mem.last_vocalization_time = GetTime()
                inst.SoundEmitter:PlaySound("qol1/collector_robot/dropoff_voice")
            end),
        },

        events = idle_on_animover,

        onexit = function(inst)
            inst.components.inventory:CloseAllChestContainers()

            RestoreMobility(inst)
        end,
    },

    State {
        name = "repairing_pre",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("repair_pre", false)

            --inst.SoundEmitter:PlaySound("qol1/collector_robot/repair_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("repairing")
            end),
        },

        onexit = function(inst)
            inst.AnimState:SetBuild("storage_robot")
        end,
    },

    State {
        name = "repairing",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("repair", false)

            inst.SoundEmitter:PlaySound("qol1/collector_robot/repair")
        end,

        events = idle_on_animover,
    },

    State {
        name = "breaking",
        tags = { "busy", "broken" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.components.inventory:DropEverything()

            inst.AnimState:PlayAnimation("breaking")

            inst.SoundEmitter:KillAllSounds()
            inst.SoundEmitter:PlaySound("qol1/collector_robot/breakdown")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle_broken")
            end),
        },
    },

    State {
        name = "idle_broken",
        tags = { "busy", "broken" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_broken", false)

            inst.SoundEmitter:KillAllSounds()
        end,
    },
}

CommonStates.AddSinkAndWashAshoreStates(states, {washashore = "idle_broken"})

CommonStates.AddWalkStates(
    states,
    nil,
    nil,
    true,
    nil,
    {
        startonenter = function(inst)
            inst.components.fueled:StartConsuming()

            inst.SoundEmitter:KillSound(ACTIVE_SOUNDNAME)

            if not inst.SoundEmitter:PlayingSound(WALK_SOUNDNAME) then
                inst.SoundEmitter:PlaySound("qol1/collector_robot/walk", WALK_SOUNDNAME)
            end
        end,

        endonexit = function(inst)
            inst.components.fueled:StopConsuming()

            inst.SoundEmitter:KillSound(WALK_SOUNDNAME)
        end,

        walktimeline =
        {
            FrameEvent(5, PlayVocalizationSound),
        },
    }
)

return StateGraph("storage_robot", states, events, "idle", actionhandlers)
