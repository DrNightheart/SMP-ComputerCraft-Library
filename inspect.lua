--THIS IS ONLY GOOD FOR ONE PERIPHERAL BECAUSE IT OUTPUTS A LOTTA STUFF.  SKIPPING MODEMS JUST CAUSE WE HAVE SO MANY IN A NETWORK
print("Peripheral names and types:")
local names = peripheral.getNames()
for _,n in ipairs(names) do
  local t = peripheral.getType(n) or "<unknown>"
  print("-", n, "type=", t)
end
 
print("\methods for non-modem peripherals (skip modems):")
local modemTypes = { modem=true, wireless_modem=true, ender_modem=true, "modem", "wireless_modem", "ender_modem" }
for _,n in ipairs(names) do
  local t = peripheral.getType(n) or ""
  if not (t == "modem" or t == "wireless_modem" or t == "ender_modem") then
    print("\n== Methods for:", n, "type=", t, "==")
    local ok, methods = pcall(peripheral.getMethods, n)
    if not ok then
      print("  error listing methods:", methods)
    else
      for i,m in ipairs(methods) do
        print("   ", i, m)
      end
    end
  else
  end
end
