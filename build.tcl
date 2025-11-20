#!/usr/bin/env gw_sh
# Script TCL para síntesis de proyecto PS/2 Mouse
# Tang Primer 25K (GW5A-LV25MG121NES)

# Crear nuevo proyecto
set_device GW5A-LV25MG121NES -name ps2_mouse_project

# Agregar archivos fuente
add_file ps2_mouse_init.v
add_file top_ps2_test.v

# Agregar archivo de constraints
add_file ps2_mouse_constraints.cst

# Configurar top module
set_option -top_module top_ps2_test

# Configurar opciones de síntesis
set_option -verilog_std v2001
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

# Ejecutar síntesis
run all

# Fin del script
