
--Hello! This is an example code. It functions fully, but is quite barebones. Made by DrNightheart.
local CONFIG_FILE = "auto_filter_config.json" --you can change this if you want! Its important to change this if you have a lot of CC Programs, because some may accidentally use the same config and screw things up.
-------------------------------------------------- hoi
local function tokenize(input)
    local parts = {}
    for part in string.gmatch(input, "%S+") do
        table.insert(parts, part)
    end
    return parts
end

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
            
      --EXACT match of items. I used to use string.find 
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

-- this is the core logic! 

local function sendAllItemsFromNetwork(itemName, destNames, sourceNames)
    
    -- 1. Validate the destinations to make sure it works right
    local destinations = {}
    local destIDs = {}
    for _, name in ipairs(destNames) do
        local p = peripheral.wrap(name)
        if p and p.pushItems then
            local id = peripheral.getName(p)
            table.insert(destinations, {
                peripheral = p,
                id = id,
                name = name
            })
            destIDs[id] = true
        end
    end

    -- 2. Validate sources to make sure it works right
    local validSources = {}
    for _, name in ipairs(sourceNames) do
        local p = peripheral.wrap(name)
        if p and p.list then
            table.insert(validSources, {
                peripheral = p,
                id = peripheral.getName(p),
                name = name
            })
        end
    end

    -- 3. Check for valid setup, if it ISNT valid, then.. how?
    if #destinations == 0 then
        print("Error: No valid destinations found. Stopping.")
        return 0
    end
    if #validSources == 0 then
        print("Error: No valid source peripherals found. Stopping.")
        return 0
    end

    -- 4. 
    local sourcesToScan = {}
    for _, source in ipairs(validSources) do
        if not destIDs[source.id] then
            table.insert(sourcesToScan, source)
        end
    end

    if #sourcesToScan == 0 then
        print("Warning: All valid sources are also destinations. No items will be moved. I.. why?")
    end

    -- 5. Start the main loop!!
    local itemSummary = destNames[1]
    if #destNames > 1 then itemSummary = destNames[1] .. " and " .. (#destNames - 1) .. " others" end


    print(string.format("Moving  '%s' from %d source(s) to %s.", itemName, #sourcesToScan, itemSummary))

    local totalMovedOverall = 0
    local cycleCount = 0

    while true do
        local movedThisCycle = 0
        
        for _, sourceData in ipairs(sourcesToScan) do
            local p = sourceData.peripheral
            
            if peripheral.isPresent(sourceData.name) then
                -- Pass the exact item name to the function
                local itemSlots = getInventorySlotsContaining(p, itemName)

                if #itemSlots > 0 then
                    
                    for _, sourceDetail in ipairs(itemSlots) do
                        local sourceSlot = sourceDetail.slot
                        local remainingInSlot = sourceDetail.count
                        
                        -- Get the correctly-cased item name *from the slot detail*
                        local fullItemName = sourceDetail.name 

                        for _, dest in ipairs(destinations) do
                            if remainingInSlot <= 0 then break end

                            if peripheral.isPresent(dest.name) then
                                local limit = remainingInSlot
                                
                                -- Use the correct fullItemName as the filter
                                local success, movedCount = pcall(p.pushItems, dest.id, sourceSlot, limit, nil, fullItemName)

                                if not success or type(movedCount) ~= "number" then
                                    print(string.format("Warning: Peripheral '%s' error during transfer. Error: %s", dest.name, tostring(movedCount)))
                                
                                elseif movedCount > 0 then
                                    movedThisCycle = movedThisCycle + movedCount
                                    totalMovedOverall = totalMovedOverall + movedCount
                                    remainingInSlot = remainingInSlot - movedCount
                                end
                            end
                        end
                    end
                end
            end -- end!!
        end -- holy ends.. some sort of broken end.

        cycleCount = cycleCount + 1
--this is here to just kinda remove strain on the server, helps slow it down while lookin good.  CC may be optimized but a million of these could screw it up.
        if movedThisCycle > 0 then
            print(string.format("[Cycle %d] Moved %d item(s). Total Overall: %d.", cycleCount, movedThisCycle, totalMovedOverall))
        elseif cycleCount % 20 == 0 then
             print(string.format("... Monitoring sources (Cycle %d). No items moved.", cycleCount))
        end

        sleep(1)
    end
end

-- Config logic

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return nil
    end

    local file = fs.open(CONFIG_FILE, "r")
    if file then
        local content = file.readAll()
        file.close()
        local success, config = pcall(textutils.unserialize, content)
        if success and type(config) == "table" and config.item and config.destinations and config.sources then
            return config
        end
    end
    return nil
end

local function saveConfig(item, destinations, sources)
    local config = {
        item = item,
        destinations = destinations,
        sources = sources
    }
    local content = textutils.serialize(config)
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(content)
        file.close()
        print(string.format("Configuration saved to '%s'.", CONFIG_FILE))
    end
end

local function promptForConfig()
    print("--- Initial Filtered Setup ---")
    print("If you change your mind, delete the file '" .. CONFIG_FILE .. "'")

  
    io.write("Item (exact ID, e.g., 'minecraft:clay'): ")
    local item = read()

    io.write("Destinations (Name/ID, comma-separated, priority order): ")
    local destInput = read()
    local destinations = tokenize(destInput)
    
    io.write("Sources (Name/ID, comma-separated, ONLY PULL FROM THESE): ")
    local sourceInput = read()
    local sources = tokenize(sourceInput)

    if #destinations == 0 or #sources == 0 then
        print("Error: Destinations and Sources must be provided. Aborting setup.")
        return nil
    end

    saveConfig(item, destinations, sources)
    return { item = item, destinations = destinations, sources = sources }
end

-- main

local function main()
    local config = loadConfig()

    if not config then
        print("First run detected.")
        config = promptForConfig()
    end

    if config and config.item and config.destinations and #config.destinations > 0 and config.sources and #config.sources > 0 then
        sendAllItemsFromNetwork(config.item, config.destinations, config.sources)
    else
        print("Error: Invalid config. Please delete '" .. CONFIG_FILE .. "' and restart this.")
    end
end

main()
