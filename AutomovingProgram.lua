--Hello! This is an example code. It functions fully, but is quite barebones. Made by DrNightheart.
local CONFIG_FILE = "auto_filter_config.json" --you can change this if you want! Its important to change this if you have a lot of CC Programs, because some may accidentally use the same config and screw things up.
-------------------------------------------------- hoi. THIS VERSION IS THE FIXED VERSION! DO NOT USE ANY PROGRAMS BEFORE THIS ONE. I APOLOGIZE FOR ADDING THE INCORRECT FILE EARLIER!!

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

local function sendAllItemsFromNetwork(itemNames, destNames, sourceNames)
    
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
        print("ERROR: All valid sources are also destinations. No items will be moved. I.. why?")
    end

    -- 5. Start the main loop!!
    local itemSummary = destNames[1]
    if #destNames > 1 then itemSummary = destNames[1] .. " and " .. (#destNames - 1) .. " others" end

    local itemListSummary = itemNames[1]
    if #itemNames > 1 then itemListSummary = itemNames[1] .. " and " .. (#itemNames - 1) .. " others" end

    print(string.format("Moving '%s' from %d source(s) to %s.", itemListSummary, #sourcesToScan, itemSummary))
    print("Monitoring continuously...") --This helps prevent server strain!

    local totalMovedOverall = 0
    local lastReportTime = os.clock()

    while true do
        local movedThisCycle = 0
        
        for _, itemName in ipairs(itemNames) do
            for _, sourceData in ipairs(sourcesToScan) do
                local p = sourceData.peripheral
                
                if peripheral.isPresent(sourceData.name) then
                    -- Pass the exact item name to the function instead of ALL of that thing
                    local itemSlots = getInventorySlotsContaining(p, itemName)

                    if #itemSlots > 0 then
                        
                        for _, sourceDetail in ipairs(itemSlots) do
                            local sourceSlot = sourceDetail.slot
                            local remainingInSlot = sourceDetail.count
                            
                            
                            local fullItemName = sourceDetail.name 

                            for _, dest in ipairs(destinations) do
                                if remainingInSlot <= 0 then break end

                                if peripheral.isPresent(dest.name) then
                                    local limit = remainingInSlot
                                
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
        end

        --this is here to just kinda remove strain on the server, helps slow it down while lookin good. CC may be optimized but a million of these could screw it up.
        if movedThisCycle > 0 then
            print(string.format("Moved %d item(s). Total: %d", movedThisCycle, totalMovedOverall))
            lastReportTime = os.clock()
        else
            -- Only print status update every 20 seconds if nothing moved
            if os.clock() - lastReportTime >= 20 then
                print(string.format("... Still monitoring. Total moved: %d", totalMovedOverall))
                lastReportTime = os.clock()
            end
        end

        sleep(1)--Change this for faster program
    end
end

-- Config logic thingies

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return nil
    end

    local file = fs.open(CONFIG_FILE, "r")
    if file then
        local content = file.readAll()
        file.close()
        local success, config = pcall(textutils.unserialize, content)
        if success and type(config) == "table" and config.items and config.destinations and config.sources then
            return config
        end
    end
    return nil
end

local function saveConfig(items, destinations, sources)
    local config = {
        items = items,
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
    print("If you change your mind, delete '" .. CONFIG_FILE .. "'")

  
    io.write("Items, use the format 'minecraft:clay,minecraft:stone' for multiple.")
    local itemInput = read()
    local items = split(itemInput, ",")

    io.write("Destinations (Name/ID, comma-separated, priority order): ")
    local destInput = read()
    local destinations = split(destInput, ",")
    
    io.write("Sources (Name/ID, comma-separated,sources get pulled from.): ")
    local sourceInput = read()
    local sources = split(sourceInput, ",")

    if #items == 0 or #destinations == 0 or #sources == 0 then
        print("Error: Items, Destinations, and Sources must all be provided. Aborting setup.")
        print("Try again ):.")
        return nil
    end

    saveConfig(items, destinations, sources)
    return { items = items, destinations = destinations, sources = sources }
end

-- main

local function main()
    local config = loadConfig()

    if not config then
        print("First run detected.")
        config = promptForConfig()
    end

    if config and config.items and #config.items > 0 and config.destinations and #config.destinations > 0 and config.sources and #config.sources > 0 then
        sendAllItemsFromNetwork(config.items, config.destinations, config.sources)
    else
        print("Error: Invalid config. Please delete '" .. CONFIG_FILE .. "' and restart this.")
    end
end

main()
