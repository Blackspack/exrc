print("Startup installation")
write("Name for Label:")
os.setComputerLabel(read(nil))

shell.run("wget https://raw.githubusercontent.com/Blackspack/exrc/master/exrc/exrc.lua startup")

print("Installation finished")
sleep(5)
os.reboot()