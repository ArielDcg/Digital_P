#==============================================================================
# Script TCL para síntesis con Gowin EDA
# Proyecto: PS2_to_Screen
# FPGA: Tang Primer 25K (GW5A-LV25MG121NC1/I0)
#==============================================================================

# Configuración del dispositivo
set_device GW5A-LV25MG121NC1/I0 -name GW5A-25

# Nombre del proyecto
set_option -output_base_name mouse_to_screen

# Directorios
set SRC_DIR "../src"
set COMMON_DIR "../../common"
set CONST_DIR "../constraints"

# Agregar archivos fuente principales
add_file -type verilog "$SRC_DIR/Mouse_to_screen.v"
add_file -type verilog "$SRC_DIR/led_panel_4k.v"
add_file -type verilog "$COMMON_DIR/ps2_mouse_init.v"

# Agregar módulos auxiliares
add_file -type verilog "$SRC_DIR/ctrl_lp4k.v"
add_file -type verilog "$SRC_DIR/memory_V2.v"
add_file -type verilog "$SRC_DIR/mult.v"
add_file -type verilog "$SRC_DIR/comp.v"
add_file -type verilog "$SRC_DIR/count.v"
add_file -type verilog "$SRC_DIR/lsr_led.v"
add_file -type verilog "$SRC_DIR/mux_led.v"

# Agregar constraints
add_file -type cst "$CONST_DIR/ps2_mouse_constraints.cst"

# Configurar top module
set_option -top_module Mouse_to_screen

# Opciones de síntesis
set_option -verilog_std v2001
set_option -print_all_synthesis_warning 1

# Opciones de place & route
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

# Frecuencia del reloj
create_clock -name clk -period 37.037 [get_ports {clk}]

# Ejecutar síntesis
run all

# Reportes
report_area -io_info -file "impl/pnr/mouse_to_screen_area.rpt"
report_timing -file "impl/pnr/mouse_to_screen_timing.rpt"
