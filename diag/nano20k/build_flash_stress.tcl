# Diagnose: Flash-Lesepfad unter Dauerlast (komplettes TOS, Pruefsumme, Endlosschleife)
set S ../../src/tang/nano20k
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
add_file $S/flash_dspi.v
add_file $S/gowin_rpll/flash_pll.v
add_file flash_stress.v
add_file flash_stress.cst
set_option -verilog_std sysv2017
set_option -top_module flash_stress
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -output_base_name flash_stress
run all
