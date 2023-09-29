local EMPTY_TABLE = {}
local function MakeDecorItem(name, bank, build, data)
    data = data or EMPTY_TABLE

    local assets =
    {
        Asset("ANIM", "anim/"..bank..".zip"),
    }
    if build then
        if bank ~= build then
            table.insert(assets, Asset("ANIM", "anim/"..build..".zip"))
        end
    else
        build = bank
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddFollower()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("furnituredecor") -- From "furnituredecor", for optimization

        if data.common_postinit then
            data.common_postinit(inst)
        end

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        --
        local furnituredecor = inst:AddComponent("furnituredecor")
        furnituredecor.onputonfurniture = data.put_on_furniture

        --
        inst:AddComponent("inspectable")

        --
        inst:AddComponent("inventoryitem")

        --
        MakeHauntable(inst)

        --
        local burnable = MakeSmallBurnable(inst)
        if data.onburnt then
            burnable:SetOnBurntFn(data.onburnt)
        end

        MakeSmallPropagator(inst)

        --
        inst.OnSave = data.onsave
        inst.OnLoad = data.onload

        --
        if data.master_postinit then
            data.master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, assets)
end

local decor_items = {}
table.insert(decor_items, MakeDecorItem("decor_centerpiece", "decor_centerpiece"))
table.insert(decor_items, MakeDecorItem("decor_portraitframe", "decor_portraitframe"))

--
return unpack(decor_items)