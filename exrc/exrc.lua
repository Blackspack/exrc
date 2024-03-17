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
res=0--- pid output
oldres=0
fulldown=0
tspeed = {}
------------------------------------------------

function search() -- Search all peripheral
	print("Start Initialization")
	reactor = {}
	turbine = {}
	energystorage = {}
	reactormodes = {}
--find reactor
	for r in pairs(Names) do
	    print(Names[r])
		if string.find(Names[r],"Reactor_") then
			table.insert(reactor, Names[r])
			numreactor = numreactor + 1
		end
	end
	if reactor[1] == nil then printError("no reactor connected") ERROR = 1 end
--find turbine
	for r in pairs(Names) do
		if string.find(Names[r],"Turbine_") then
			table.insert(turbine, Names[r])
			numturbine = numturbine + 1
			table.insert(tspeed,0)
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
search() --first search start 

function startup()
	--on start up set reactor rods 100 and turbine 0mb/s 
	for r in pairs(reactor) do
		peripheral.call(reactor[r],"setAllControlRodLevels", 100)
	end
	for r in pairs(turbine) do 
		peripheral.call(turbine[r],"setInductorEngaged", false)
		peripheral.call(turbine[r],"setActive", false)
		peripheral.call(turbine[r],"setFluidFlowRateMax", 0)
		peripheral.call(turbine[r],"setVentOverflow", true)
	end
	print("finished start up")
end
startup()
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
		if peripheral.call(turbine[r], "getActive") == true then
			fluidneed = fluidneed + peripheral.call(turbine[r], "getFluidFlowRateMax")
		end
	end
    
	for m in pairs(reactor) do --- start function  
		peripheral.call(reactor[m], "setActive", true)
		local rod = peripheral.call(reactor[m], "getControlRodLevel",0) -- rod lvl
		
		local capacity = peripheral.call(reactor[m], "getHotFluidAmountMax")
		local hotfluid = peripheral.call(reactor[m], "getHotFluidAmount")
		local transfluid = peripheral.call(reactor[m], "getHotFluidProducedLastTick")
		local pufferfluid = hotfluid - capacity / 2 
		--controller
		if capacity/2 <= hotfluid then
			if  hotfluid == capacity-1000 then 
				rod = rod + 10
			elseif fluidneed*3 <= transfluid then 
				rod = rod + 4
			elseif  fluidneed*2 <= transfluid then 
				rod = rod + 2
			elseif  fluidneed*1.1 <= transfluid or 1 <= pufferfluid then 
				rod = rod + 1
			end
		end
		if capacity/2 >= hotfluid then
            if capacity/8 >= hotfluid then
				rod = rod - 2
			elseif	fluidneed >= transfluid or pufferfluid <= 1 then
				rod = rod - 1
			end
		end
	
		if rod >= 100 then --safety rod controll
			rod = 100 
		elseif rod <= 0 then 
			rod = 0 
		end

		if rod ~= peripheral.call(reactor[m], "getControlRodLevel", 0) then --rod set
			peripheral.call(reactor[m], "setAllControlRodLevels", rod)
			print(rod)
		end	
	end 
end

function tubinecontrol() --v1.0
	local setRPM = 1
	local status = 0
	if energystatus >= poweroff then --on off
		status = 0
	else
		status = 1
	end	
	if energystatus <= poweron and fulldown==0 then	--RPM set (fluid)
		for t in pairs(turbine) do
			turbinePID(turbine[t])

			if res >= 3 then
				tspeed[t] = tspeed[t]+(res-oldres)
            elseif res <= -3 then 
				tspeed[t] = tspeed[t]+(res+oldres)
			end
			peripheral.call(turbine[t],"setFluidFlowRateMax",tspeed[t])
			setRPM = 1
		end
	elseif energystatus <= 0.7 or fulldown==1 then
		for t in pairs(turbine) do
			turbinePIDeff(turbine[t])
			if res >= 3 then
				tspeed[t] = tspeed[t]+(res-oldres)
            elseif res <= -3 then 
				tspeed[t] = tspeed[t]+(res+oldres)
			end
			peripheral.call(turbine[t],"setFluidFlowRateMax",tspeed[t])
			setRPM = 0
			fulldown=1
			if energystatus >= 0.35 then
                fulldown=0
            end
		end
	end
	for t in pairs(turbine) do
		if status == 0 then
			peripheral.call(turbine[t],"setInductorEngaged", false)
		end
		if setRPM == 1 and highRPM-50 <= peripheral.call(turbine[t], "getRotorSpeed") and status == 1 then
			peripheral.call(turbine[t],"setInductorEngaged", true)
		elseif setRPM == 1 and highRPM-100 >= peripheral.call(turbine[t], "getRotorSpeed") and status == 1 then
			peripheral.call(turbine[t],"setInductorEngaged", false)
		elseif setRPM == 0 and lowRPM-50 <= peripheral.call(turbine[t], "getRotorSpeed") and status == 1 then
			peripheral.call(turbine[t],"setInductorEngaged", true)
		elseif setRPM == 0 and lowRPM-100 >= peripheral.call(turbine[t], "getRotorSpeed") and status == 1 then
			peripheral.call(turbine[t],"setInductorEngaged", false)
		end
		if status == 1 then
			peripheral.call(turbine[t],"setActive", true)
		elseif status == 0 then
			peripheral.call(turbine[t],"setActive", false) 
		end
		 
	end	
	



end
function pid(p,i,d) --pid from steampage
    return{p=p,i=i,d=d,E=0,D=0,I=0,
		run=function(s,sp,pv)
			local E,D,A
			E = sp-pv
			D = E-s.E
			A = math.abs(D-s.D)
			s.E = E
			s.D = D
			s.I = A<E and s.I +E*s.i or s.I*0.5
			return E*s.p +(A<E and s.I or 0) +D*s.d
		end
	}
end


pid1 = pid(0.1,0.01, 0.005) -- PID settings
pid2 = pid(0.25,0.005, 0.005)
function turbinePID(turbineC)
	oldres = res
	res=0
	setpoint = 1800
	pv1 = peripheral.call(turbineC, "getRotorSpeed")
	print("------")
	if pv1 <= 1400 then
	res = pid2:run(setpoint,pv1)
	else
	res = pid1:run(setpoint,pv1)
	end
	print(oldres)
	print(res)
	print("------")
end
function turbinePIDeff(turbineC)
    oldres = res
	res=0
	setpoint = 900
	pv1 = peripheral.call(turbineC, "getRotorSpeed")
	print("------")
	res = pid1:run(setpoint,pv1)
	print(res .. "eff")
	print("------")
end

function Main()
    while true do
        energyupdate()
		reactorcontrol()
		tubinecontrol()
        os.sleep(1)
    end
end

parallel.waitForAll(Main)