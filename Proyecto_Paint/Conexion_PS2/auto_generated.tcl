# Script TCL generado automáticamente desde Makefile
# Fecha: Thu Dec  4 17:24:16 UTC 2025

# Configurar dispositivo
set_device -name GW5A-25A GW5A-LV25MG121NC1/I0

add_file sipeed_tang_primer_25k.cst
add_file sipeed_tang_primer_25k.sdc
# Agregar archivos fuente
add_file -type verilog ps2_paint_top.v
add_file -type verilog led_panel_4k_external.v
add_file -type verilog Arduino/ps2_mouse_receiver.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/Mouse_to_screen.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/mult.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/memory_V2.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/ctrl_lp4k.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/count.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/lsr_led.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/comp.v
add_file -type verilog PS2_to_screen/Mouse_to_screen/Led_panel_12bpp/mux_led.v

# Configurar opciones del proyecto
set_option -use_mspi_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -rw_check_on_ram 1
run all
