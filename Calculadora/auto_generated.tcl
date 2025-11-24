# Script TCL generado automáticamente desde Makefile
# Fecha: Mon Nov 24 09:22:52 AM -05 2025

# Configurar dispositivo
set_device -name GW5A-25A GW5A-LV25MG121NC1/I0

add_file sipeed_tang_primer_25k.cst
add_file sipeed_tang_primer_25k.sdc
# Agregar archivos fuente
add_file -type verilog cores/cpu/femtorv32_quark_V2.v
add_file -type verilog cores/uart/perip_uart.v
add_file -type verilog cores/uart/uart.v
add_file -type verilog cores/mult_ASM/perip_mult.v
add_file -type verilog cores/mult_ASM/mult_32.v
add_file -type verilog cores/mult_ASM/acc.v
add_file -type verilog cores/mult_ASM/comp.v
add_file -type verilog cores/mult_ASM/lsr_mult.v
add_file -type verilog cores/mult_ASM/control_mult.v
add_file -type verilog cores/mult_ASM/rsr.v
add_file -type verilog cores/div/perip_div.v
add_file -type verilog cores/div/div.v
add_file -type verilog cores/sqrt_ASM/addc2.v
add_file -type verilog cores/sqrt_ASM/count.v
add_file -type verilog cores/sqrt_ASM/lsr.v
add_file -type verilog cores/sqrt_ASM/perip_sqrt.v
add_file -type verilog cores/sqrt_ASM/sqrt.v
add_file -type verilog cores/sqrt_ASM/lsr2.v
add_file -type verilog cores/sqrt_ASM/control.v
add_file -type verilog cores/bin2bcd/add_sub_c2.v
add_file -type verilog cores/bin2bcd/bin2bcd.v
add_file -type verilog cores/bin2bcd/mux2.v
add_file -type verilog cores/bin2bcd/count.v
add_file -type verilog cores/bin2bcd/ctrl_b2b.v
add_file -type verilog cores/bin2bcd/perip_bin2bcd.v
add_file -type verilog cores/bin2bcd/lsr4.v
add_file -type verilog cores/bin2bcd/reg_msb.v
add_file -type verilog cores/bcd2bin/bcd2bin.v
add_file -type verilog cores/bcd2bin/perip_bcd2bin.v
add_file -type verilog cores/bcd2bin/rsr4.v
add_file -type verilog cores/bram/bram.v
add_file -type verilog SOC.v

# Configurar opciones del proyecto
set_option -use_mspi_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -rw_check_on_ram 1
run all
