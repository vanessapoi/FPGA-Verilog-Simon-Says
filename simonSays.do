# set the working dir, where all compiled verilog goes
vlib work

# compile all verilog modules in mux.v to working dir
# could also have multiple verilog files
vlog main - Copy.v
vlog hexdecoder.v
vlog alu.v
vlog random.v
#vlog PS2_Controller.v
#vlog Hexadecimal_To_Seven_Segment.v
#vlog Altera_UP_PS2_Data_In.v
#vlog Altera_UP_PS2_Command_Out.v
#vlog Altera_UP_Audio_Bit_Counter.v
#vlog Altera_UP_Audio_In_Deserializer.v
#vlog Altera_UP_Audio_Out_Serializer.v
#vlog Altera_UP_Clock_Edge.v
#vlog Altera_UP_SYNC_FIFO.v
#vlog audio.v
#vlog Audio_Clock.v
#vlog Audio_Controller.v
#vlog avconf.v
#vlog HexToDecimalDisplayD1.v
#vlog HexToDecimalDisplayD2.v
#vlog I2C_Controller.v
#vlog rom.v
#vlog rom_bb.v
#vlog sound.v

#load simulation using mux as the top level simulation module
vsim main

#log all signals and add some signals to waveform window
log {/*}
# add wave {/*} would add all items in top level simulation module
add wave {/*}

#clock
force {CLOCK_50} 1 0ns, 0 {10ns} -r 20ns

# Init, run for a bit
force {KEY[0]} 1
force {KEY[1]} 0
force {KEY[2]} 0
force {KEY[3]} 0
force {SW[0]} 0
force {SW[1]} 0
force {SW[2]} 0
force {SW[3]} 0
run 20 ns

# State 1
force {KEY[0]} 0
force {KEY[3]} 1
run 40ns

# State 2-6
force {KEY[3]} 0
run 220ns

# playerInHigh
force {SW[1]} 1
run 120ns

# playerInLow
force {SW[1]} 0
run 360ns

# playerInHigh
force {SW[1]} 1
run 40ns

# playerInLow
force {SW[1]} 0
run 40ns

# playerInHigh
force {SW[2]} 1
run 40ns

# playerInLow
force {SW[2]} 0
run 160ns

#keyboard enter
force {keyData} 01011010
run 160 ns

