-- all Assignment ------------------------------

Names = peripheral.getNames()
reactor = {}	--names stored
numreactor = 0	--number of reactor
turbine = {}	--names stored
numturbine = 0	--number of turbine
energystorage = {} --names stored
energyneed = 0 -- LVL of energy need
highRPM = 1800 -- eff. highRPM
highRPMcalibration = {}
lowRPM = 900 -- eff. lowRPM
lowRPMcalibration = {}
ERROR = 0 -- all error expect turbine
reactormodes = {} -- turbine error 
maxenergyin = 0 -- Max energy input in storage
energygenerated = 0
activmodereactor = 0
fluidneed = 0
cog = 0
cogalready = {}

------------------------------------------------

function search() -- Search all peripheral
	print("Start Initialization")
	reactor = {}
	turbine = {}
	energystorage = {}
	reactormodes = {}
--find reactor
	for r in pairs(Names) do
		if string.find(Names[r],"BiggerReactors_Reactor_") then
			table.insert(reactor, Names[r])
			numreactor = numreactor + 1
		end
	end
	if reactor[1] == nil then printError("no reactor connected") ERROR = 1 end
--reactor passiv or activ table create
	for r in pairs(reactor) do 
		if  peripheral.call(reactor[r],"coolantTank") == nil then
			if  peripheral.call(reactor[r],"battery") == nil then 
				printError("reactor "..r.." need a battery or fluidport ")
				ERROR = 1
			end
		end
		if peripheral.call(reactor[r],"coolantTank") == nil then
			table.insert(reactormodes,r, 1) -- passiv mode
		else 
			table.insert(reactormodes,r, 0) -- activ mode
			activmodereactor = activmodereactor + 1
		end
	end	
--find turbine
	for r in pairs(Names) do
		if string.find(Names[r],"BiggerReactors_Turbine_") then
			table.insert(turbine, Names[r])
			numturbine = numturbine + 1
		end
	end
	if turbine[1] == nil then printError("no turbine connected") end

--find energystorage
	for r in pairs(Names) do 
		if string.find(Names[r],"inductionPort_") then
			table.insert(energystorage, Names[r])
		end
	end
	if energystorage[1] == nil then printError("no energystorage(Mekanism) connected") ERROR = 1 end
end
search() --first search start (will be move to main later)

--on start up set reactor rods 100 and turbine 0mb/s 
for r in pairs(reactor) do
	peripheral.call(reactor[r],"setAllControlRodLevels", 100)
end
for r in pairs(turbine) do 
	peripheral.call(turbine[r],"setCoilEngaged", false)
	peripheral.call(turbine[r],"setActive", false)
	peripheral.call(turbine[r],"fluidTank").setNominalFlowRate(0)
end
print("finished start up")


function settingsload() ---start Load settings
	if cog == 0 then
		settings.clear()
		settings.load("/brc/config")
	else 
		print("calibration ongoing")
	end
end
settingsload() -- first start load

function errorhandler() -- restart search and identify energy   (future)
end

function energyupdate()
	energystatus = peripheral.call(energystorage[1], "getEnergyFilledPercentage")
	maxenergyin = 0.4 * peripheral.call(energystorage[1], "getTransferCap")
	energyout = peripheral.call(energystorage[1], "getLastOutput")
	energygenerated = 0
	-- future set powertaget --
	poweroff = 0.9
	poweron = 0.5
	


	-------------------------------
	for m in pairs(reactormodes) do
		local reactormode = reactormodes[m]	
		if reactormode == 0 then -- activ reactor mode
			for r in pairs(turbine) do --turbine energy output read
				local gen = peripheral.call(turbine[r], "battery").producedLastTick()
				energygenerated = energygenerated + gen
			end
		else --passiv reactor mode
			local gen = peripheral.call(reactor[m], "battery").producedLastTick()
			energygenerated = energygenerated + gen	
		end
	end
	if maxenergyin*0.9 <= energygenerated then printError("Limit in battery input") end	
end
energyupdate()




function reactorcontrol()
	fluidneed = 0 
	rod = 0
	for r in pairs(turbine) do ---turbine flow rate
		if peripheral.call(turbine[r], "active") == true then
			fluidneed = fluidneed + peripheral.call(turbine[r], "fluidTank").nominalFlowRate()
		end
	end
    
	for m in pairs(reactor) do --- start function  
		peripheral.call(reactor[m], "setActive", true)
		local rod = peripheral.call(reactor[m], "getControlRod",0).level() -- rod lvl
		
		if reactormodes[m] == 0 then --activ reactor
			local capacity = peripheral.call(reactor[m], "coolantTank").capacity()
			local hotfluid = peripheral.call(reactor[m], "coolantTank").hotFluidAmount()
			local transfluid = peripheral.call(reactor[m], "coolantTank").maxTransitionedLastTick()
			local pufferfluid = hotfluid - capacity / 2 
			
			if fluidneed*3 <= transfluid then --controller
				rod = rod + 4
			elseif  fluidneed*2 <= transfluid then 
				rod = rod + 2
			elseif  hotfluid == capacity then 
				rod = rod + 1
			elseif	fluidneed >= transfluid or pufferfluid <= 1 then
				rod = rod - 1
			elseif  fluidneed*1.1 <= transfluid or 1 <= pufferfluid then 
				rod = rod + 1
			end
			
			if rod >= 100 then --safety rod controll
				rod = 100 
			elseif rod <= 0 then 
				rod = 0 
			end
			if rod ~= peripheral.call(reactor[m], "getControlRod",0).level() then --rod set
				peripheral.call(reactor[m], "setAllControlRodLevels", rod)
				print(rod)
			end	
			
		elseif reactormodes[m] == 1 then  --passiv reactor (inprocess)
			
		end
	end 
end

function tubinecontrol() --v0.1
	local setRPM = 1
	local status = 0
	if energystatus >= poweroff then --on off
		status = 0
	else
		status = 1
	end	
	if energystatus <= poweron then	--RPM set (fluid)
		for t in pairs(turbine) do
			peripheral.call(turbine[t],"fluidTank").setNominalFlowRate(settings.get(turbine[t] .."HR"))
			setRPM = 1
		end
	elseif energystatus <= 0.7 then
		for t in pairs(turbine) do
			peripheral.call(turbine[t],"fluidTank").setNominalFlowRate(settings.get(turbine[t] .."LR"))
			setRPM = 0
		end
	end
	for t in pairs(turbine) do
		if status == 0 then
			peripheral.call(turbine[t],"setCoilEngaged", false)
		end
		if setRPM == 1 and highRPM <= peripheral.call(turbine[t], "rotor").RPM() and status == 1 then
			peripheral.call(turbine[t],"setCoilEngaged", true)
		elseif setRPM == 1 and highRPM-50 >= peripheral.call(turbine[t], "rotor").RPM() and status == 1 then
			peripheral.call(turbine[t],"setCoilEngaged", false)
		elseif setRPM == 0 and lowRPM <= peripheral.call(turbine[t], "rotor").RPM() and status == 1 then
			peripheral.call(turbine[t],"setCoilEngaged", true)
		elseif setRPM == 0 and lowRPM-50 >= peripheral.call(turbine[t], "rotor").RPM() and status == 1 then
			peripheral.call(turbine[t],"setCoilEngaged", false)
		end
		if status == 1 then
			peripheral.call(turbine[t],"setActive", true)
		elseif status == 0 then
			peripheral.call(turbine[t],"setActive", false) 
		end
		 
	end	

end



function startcalibration(num) -- calibration start for turbine  
	local id = multishell.launch({},"/brc/calibration.lua",turbine[num]) --maybe change to run later
	multishell.setTitle(id, turbine[num])
	cog = 1
end


--rod = peripheral.call(reactor[1], "getControlRod",1).level()

--print(rod)



function calibrationchecker()
	while true do
        if multishell.getCount() == 1 then 
			cog = 0
		end		
		settingsload()
		
		for r in pairs(turbine) do
			if settings.get(turbine[r] .. "HR") == nil or settings.get(turbine[r] .. "LR") == nil then
				if cogalready[r] == nil then
					startcalibration(r)
					table.insert(cogalready,r,1)
				elseif cogalready[r] == 0 then
					startcalibration(r)
					cogalready[r] = 1
				end
			end
		end
			
			
		os.sleep(60)
    end
end


function Main()
    while true do
        energyupdate()
		reactorcontrol()
		tubinecontrol()
        os.sleep(1)
    end
end

---getControlRod

--tables = peripheral.call(reactor[1],"controlRodCount")
--print("")
--for r in pairs(reactor) do print(reactor[r]) print(reactormodes[r]) end


parallel.waitForAll(Main,calibrationchecker)