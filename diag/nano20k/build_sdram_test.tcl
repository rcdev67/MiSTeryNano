# Diagnose: SDRAM-Datenpfad mit dem Controller des Cores
set S ../../src/tang/nano20k
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
add_file $S/sdram.v
add_file $S/gowin_rpll/pll_160m.v
add_file $S/gowin_clkdiv/gowin_clkdiv.v
add_file sdram_test.v
add_file sdram_test.cst
set_option -verilog_std sysv2017
set_option -top_module sdram_test
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -output_base_name sdram_test
run all
