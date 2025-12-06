#==============================================================================
# Script TCL para síntesis con Gowin EDA
# Proyecto: PS2_to_UART_ESP32
# FPGA: Tang Primer 25K (GW5A-LV25MG121NC1/I0)
#==============================================================================

# Configuración del dispositivo
set_device GW5A-LV25MG121NC1/I0 -name GW5A-25

# Nombre del proyecto
set_option -output_base_name mouse_display_top

# Directorios
set SRC_DIR "../src"
set CONST_DIR "../constraints"

# Agregar archivos fuente (NUEVA ARQUITECTURA: ESP32→FPGA)
add_file -type verilog "$SRC_DIR/uart_mouse_receiver.v"
add_file -type verilog "$SRC_DIR/mouse_display_top.v"
add_file -type verilog "$SRC_DIR/uart.v"

# Agregar constraints
add_file -type cst "$CONST_DIR/mouse_uart_rx.cst"

# Configurar top module
set_option -top_module mouse_display_top

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

# Reporte
report_area -io_info -file "impl/pnr/ps2_mouse_to_uart_area.rpt"
report_timing -file "impl/pnr/ps2_mouse_to_uart_timing.rpt"
