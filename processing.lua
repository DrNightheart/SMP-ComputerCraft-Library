--hoi, this was made for Tinman, pretty easy to use.
local configFile = "transfer_config.txt"

local function getInput(prompt)
    io.write(prompt)
    return io.read()
end

local function split(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        local trimmed = match:match("^%s*(.-)%s*$") 
        if trimmed ~= "" then
            table.insert(result, trimmed)
        end
    end
    return result
end

local function saveConfig(config)
    local file = fs.open(configFile, "w")
    file.writeLine(config.itemFilter or "")
    file.writeLine(config.source)
    file.writeLine(config.destAInput)
    file.writeLine(config.destB)
    file.close()
    print("Config saved to " .. configFile)
end

local function loadConfig()
    if not fs.exists(configFile) then
        return nil
    end
    local file = fs.open(configFile, "r")
    local config = {}
    config.itemFilter = file.readLine()
    if config.itemFilter == "" then config.itemFilter = nil end
    config.source = file.readLine()
    config.destAInput = file.readLine()
    config.destB = file.readLine()
    file.close()
    return config
end

-- Get config
print("=== Item Transfer Configuration ===")
local savedConfig = loadConfig()
if savedConfig then
    print("Using saved configuration...")
    itemFilter = savedConfig.itemFilter
    source = savedConfig.source
    destAInput = savedConfig.destAInput
    destB = savedConfig.destB
else
    itemFilter = getInput("Item (leave blank for no filter): ")
    if itemFilter == "" then itemFilter = nil end
    source = getInput("Source: ")
    destAInput = getInput("Destination A (comma-separated for multiple): ")
    destB = getInput("Destination B: ")
    saveConfig({itemFilter=itemFilter, source=source, destAInput=destAInput, destB=destB})
end

local destAList = split(destAInput, ",")

-- Wrap peripherals
local srcPeripheral = peripheral.wrap(source)
local destAPeripherals = {}
for _, destA in ipairs(destAList) do
    local p = peripheral.wrap(destA)
    if not p then
        error("Failed to connect to: " .. destA)
    end
    table.insert(destAPeripherals, {name = destA, peripheral = p})
end
local destBPeripheral = peripheral.wrap(destB)

if not srcPeripheral or not destBPeripheral then
    error("Failed to connect to source or destination B!")
end

print("Filter: " .. (itemFilter or "None"))
print("Source: " .. source)
print("Destination A (" .. #destAPeripherals .. " depots):")
for _, depot in ipairs(destAPeripherals) do
    print("  - " .. depot.name)
end
print("Destination B: " .. destB)
print("\nPress Ctrl+T to stop\n")

-- Track what items r sent to A
local sentToA = {}
local currentDepotIndex = 1

while true do
    -- Step 1: Move items from Source to A (round-robin style :sunglasses:
    local sourceItems = srcPeripheral.list()
    if sourceItems then
        for slot, item in pairs(sourceItems) do
            if not itemFilter or item.name == itemFilter then
                local depot = destAPeripherals[currentDepotIndex]
                local moved = srcPeripheral.pushItems(depot.name, slot)
                if moved > 0 then
                    sentToA[item.name] = true
                    print("Moved " .. moved .. "x " .. item.name .. " to " .. depot.name)
                    
                    -- Round-robin to next depot
                    currentDepotIndex = currentDepotIndex + 1
                    if currentDepotIndex > #destAPeripherals then
                        currentDepotIndex = 1
                    end
                end
            end
        end
    end
    
-- check depots for processed items
    for _, depot in ipairs(destAPeripherals) do
        local depotItems = depot.peripheral.list()
        if depotItems then
            for slot, item in pairs(depotItems) do
                -- If this item is NOT one we originally sent to A, it's been processed
                if not sentToA[item.name] then
                    local moved = depot.peripheral.pushItems(destB, slot)
                    if moved > 0 then
                        print("Processed! Moved " .. moved .. "x " .. item.name .. " from " .. depot.name .. " to B")
                    end
                end
            end
        end
    end
    
    sleep(0.4)
end
