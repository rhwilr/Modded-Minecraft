API = require("buttonAPI")
local event = require("event")
local computer = require("computer")
local term = require("term")
local component = require("component")
local gpu = component.gpu
 
local rs = component.redstone
local colors = require("colors")
local side = require("sides")
 
function API.fillTable()
  API.setTable("Flash", test1, 10,20,3,5)  
  API.setTable("Toggle", test2, 22,32,3,5)
  API.setTable("Free Ram", test3, 10,20,8,10)
  API.setTable("Reboot", test4, 22,32,8,10)
  API.screen()
end
 
function getClick()
  local _, _, x, y = event.pull(1,touch)
  if x == nil or y == nil then
    local h, w = gpu.getResolution()
    gpu.set(h, w, ".")
    gpu.set(h, w, " ")
  else
    API.checkxy(x,y)
  end
end
 
function test1()
  API.flash("Flash",0.01)
end
 
function test2()
  API.toggleButton("Toggle")
  if buttonStatus == true then
    -- # If the button is on (green) do something.
  else
    -- # If the button is off (red) do this instead.
  end
end
 
function test3()
  term.setCursor(1,25)
  term.write("Free Memory: "..computer.freeMemory().." bytes")
end
 
function test4()
  computer.shutdown(true)
end
 
term.setCursorBlink(false)
gpu.setResolution(80, 25)
API.clear()
API.fillTable()
API.heading("Button API Demo! Created in CC by DW20, ported to OC by MoparDan!")
API.label(1,24,"A sample Label.")
 
while true do
  getClick()
end