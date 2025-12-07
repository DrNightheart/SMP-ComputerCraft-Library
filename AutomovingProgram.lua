local CONFIG_FILE = "auto_filter_config.json" 

-- FLUID & ITEM UPDATE! Did some optimizations, I hope you all enjoyyy!
--I also added extra comments inorder to help newbies.
-- Made by DrNightheart. Distribute however you please.

local function split(input, delimiter)
    local parts = {}
    for part in string.gmatch(input, "([^" .. delimiter .. "]+)") do
        local trimmed = part:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(parts, trimmed)
        end
    end
    return parts
end

-- ITEM SCANNING...
local function getInventorySlotsContaining(p, exactName)
    local lowerName = string.lower(exactName)
    local foundSlots = {}

    local success, inventory = pcall(p.list)
    if not success or type(inventory) ~= "table" then
        return foundSlots
    end

    for slot, item in pairs(inventory) do
        if item and item.name then
            local itemName = string.lower(item.name)
            if itemName == lowerName then
                table.insert(foundSlots, {
                    slot = slot,
                    name = item.name, 
                    count = item.count
                })
            end
        end
    end
    return foundSlots
end

-- FLUID SCANNING (New! I added this in THIS version, it is experimental.)
local function getFluidTanksContaining(p, exactName)
    local lowerName = string.lower(exactName)
    local foundTanks = {}

    -- Peripheral must support tanks(). Now, normally all modded fluid tanks have this, however, you never know.
    if not p.tanks then return foundTanks end

    local success, tanks = pcall(p.tanks)
    if not success or type(tanks) ~= "table" then
        return foundTanks
    end

    for i, tank in pairs(tanks) do
        if tank and tank.name then
            local fluidName = string.lower(tank.name)
            if fluidName == lowerName and tank.amount > 0 then
                table.insert(foundTanks, {
                    slot = nil, -- Fluids don't strictly use slots for pushing usually, but this is more for making sure
                    name = tank.name,
                    count = tank.amount
                })
            end
        end
    end
    return foundTanks
end

-- CORE LOGIC! If you wanna learn something, look here!
local function sendAllThingsFromNetwork(targetNames, destNames, sourceNames, mode)
    
    local isFluidMode = (mode == "fluid")

    -- 1. Validate The Destinations
    local destinations = {}
    local destIDs = {}
    for _, name in ipairs(destNames) do
        local p = peripheral.wrap(name)
        if p then
            if (isFluidMode and p.tanks) or (not isFluidMode and p.pushItems) then
                local id = peripheral.getName(p)
                table.insert(destinations, {
                    peripheral = p,
                    id = id,
                    name = name
                })
                destIDs[id] = true
            end
        end
    end

    -- 2. Validate The Sources
    local validSources = {}
    for _, name in ipairs(sourceNames) do
        local p = peripheral.wrap(name)
        if p then
             if (isFluidMode and p.pushFluid) or (not isFluidMode and p.list) then
                table.insert(validSources, {
                    peripheral = p,
                    id = peripheral.getName(p),
                    name = name
                })
            end
        end
    end

    -- 3. Safety Checks (Not new)
    if #destinations == 0 then
        print("Error: No valid destinations found for mode: " .. mode)
        return 0
    end
    if #validSources == 0 then
        print("Error: No valid sources found for mode: " .. mode)
        return 0
    end

-- Yeah, sooo, if you get this error, it means you messed up.
    local sourcesToScan = {}
    for _, source in ipairs(validSources) do
        if not destIDs[source.id] then
            table.insert(sourcesToScan, source)
        end
    end

    if #sourcesToScan == 0 then
        print("ERROR: All valid sources are also destinations.")
    end

    -- 5. Main Loop! Look here to learn MORE things!
    local typeLabel = isFluidMode and "Fluid" or "Item"
    print(string.format("Moving %s(s) from %d source(s) to %d destination(s).", typeLabel, #sourcesToScan, #destinations))
    print("Monitoring continuously...")

    local totalMovedOverall = 0
    local lastReportTime = os.clock()

    while true do
        local movedThisCycle = 0
        
        for _, targetName in ipairs(targetNames) do
            for _, sourceData in ipairs(sourcesToScan) do
                local p = sourceData.peripheral
                
                if peripheral.isPresent(sourceData.name) then
                    
                    local contentSlots = {}
                    if isFluidMode then
                        contentSlots = getFluidTanksContaining(p, targetName)
                    else
                        contentSlots = getInventorySlotsContaining(p, targetName)
                    end

                    if #contentSlots > 0 then
                        
                        for _, sourceDetail in ipairs(contentSlots) do
                            local sourceSlot = sourceDetail.slot -- nil for fluids usually
                            local remainingInSource = sourceDetail.count
                            local fullName = sourceDetail.name 

                            for _, dest in ipairs(destinations) do
                                if remainingInSource <= 0 then break end

                                if peripheral.isPresent(dest.name) then
                                    local limit = remainingInSource
                                    local success, movedCount

                                    if isFluidMode then
                                        success, movedCount = pcall(p.pushFluid, dest.id, limit, fullName)
                                    else
                                        success, movedCount = pcall(p.pushItems, dest.id, sourceSlot, limit, nil, fullName)
                                    end

                                    if not success or type(movedCount) ~= "number" then
                                        -- Suppress error printing slightly to avoid spam, or print once
                                    elseif movedCount > 0 then
                                        movedThisCycle = movedThisCycle + movedCount
                                        totalMovedOverall = totalMovedOverall + movedCount
                                        remainingInSource = remainingInSource - movedCount
                                    end
                                end
                            end
                        end
                    end
                end 
            end 
        end

        -- Reporting logic
        if movedThisCycle > 0 then
            local unit = isFluidMode and "mB" or "items"
            print(string.format("Moved %d %s. Total: %d", movedThisCycle, unit, totalMovedOverall))
            lastReportTime = os.clock()
        else
            if os.clock() - lastReportTime >= 20 then
                print(string.format("... Still monitoring (%s). Total moved: %d", typeLabel, totalMovedOverall))
                lastReportTime = os.clock()
            end
        end

        sleep(1) -- Adjust for speed
    end
end

-- CONFIG LOGIC. This is for the first startup stuff ya get asked.

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then return nil end
    local file = fs.open(CONFIG_FILE, "r")
    if file then
        local content = file.readAll()
        file.close()
        local success, config = pcall(textutils.unserialize, content)
        if success and type(config) == "table" and config.targets then
            return config
        end
    end
    return nil
end

local function saveConfig(mode, targets, destinations, sources)
    local config = {
        mode = mode,
        targets = targets,
        destinations = destinations,
        sources = sources
    }
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(textutils.serialize(config))
        file.close()
        print(string.format("Configuration saved to '%s'.", CONFIG_FILE))
    end
end

local function promptForConfig()
    print("To reset, delete '" .. CONFIG_FILE .. "'") -- I made it use the CONFIG_FILE so if ya change that, this changes too!

    -- 1. Ask for Mode Stuff uwu
    print("\nSelect Mode:")
    print("1. Items")
    print("2. Fluids")
    io.write("> ")
    local modeInput = read()
    local mode = "item"
    if modeInput == "2" or string.lower(modeInput) == "fluid" or string.lower(modeInput) == "fluids" then
        mode = "fluid"
    end
    print("Mode selected: " .. string.upper(mode))

    if mode == "fluid" then
        print("\nFluids to move (e.g. 'minecraft:water,minecraft:lava'):")
    else
        print("\nItems to move (e.g. 'minecraft:cobblestone,minecraft:stone'):")
    end
    io.write("> ")
    local targetInput = read()
    local targets = split(targetInput, ",")

    -- 3. Destinations
    print("\nDestinations (Name/ID, comma-separated):")
    io.write("> ")
    local destInput = read()
    local destinations = split(destInput, ",")
    
    -- 4. Sources
    print("\nSources (Name/ID, comma-separated):")
    io.write("> ")
    local sourceInput = read()
    local sources = split(sourceInput, ",")

    if #targets == 0 or #destinations == 0 or #sources == 0 then
        print("Error: All fields must be provided. Aborting setup.")
        return nil
    end

    saveConfig(mode, targets, destinations, sources)
    return { mode = mode, targets = targets, destinations = destinations, sources = sources }
end
--main

local function main()
    local config = loadConfig()

    if not config then
        print("First run detected.")
        config = promptForConfig()
    end

    if config and config.targets then
        -- Default to item mode if old config exists without mode, this is so people can update their systems without havin to reconfigure
        local mode = config.mode or "item" 
        sendAllThingsFromNetwork(config.targets, config.destinations, config.sources, mode)
    else
        print("Error: Invalid config. Please delete '" .. CONFIG_FILE .. "' and restart.")
    end
end

main()
