##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 1.2;
set RST_NAME "reset";
set AXIS_TDATA "AXIS_TDATA";
set AXIS_TUSER "AXIS_TUSER";
set COMPUTE_FINISHED "compute_finished";
set A_READ_ADDR "A_read_addr";
set B_READ_ADDR "B_read_addr";

set AXIS_TREADY_NAME "AXIS_TREADY";
set TOP_MOD_NAME "input_mems";
set SRC_FILE [list "input_mems.sv" "input_mems_datapath.sv" "input_mems_fsm.sv"]
# If you have multiple source files, change the line above to list them all like this:
# set SRC_FILE [list "file1.sv" "file2.sv"];
###############################################

# setup
source setupdc.tcl
file mkdir work_synth
date
pid
pwd
getenv USER
getenv HOSTNAME


# optimize FSMs
set fsm_auto_inferring "true"; 
set fsm_enable_state_minimization "true";

define_design_lib WORK -path work_synth
analyze $SRC_FILE -format sverilog
elaborate -work WORK $TOP_MOD_NAME

###### CLOCKS AND PORTS #######
set CLK_PORT [get_ports $CLK_NAME]
set TMP1 [remove_from_collection [all_inputs] $CLK_PORT]
set INPUTS [remove_from_collection $TMP1 $RST_NAME]
create_clock -period $CLK_PERIOD $CLK_PORT
set_input_delay 0.08 -max -clock $CLK_NAME $INPUTS
set_output_delay 0.08 -max -clock $CLK_NAME [all_outputs]


###### OPTIMIZATION #######
set_max_area 0 

###### RUN #####
compile_ultra
report_area
report_power
report_timing
report_timing -loops
date
# write -f verilog $TOP_MOD_NAME -output gates.v -hierarchy

quit

