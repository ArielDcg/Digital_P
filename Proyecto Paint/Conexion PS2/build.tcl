#!/usr/bin/env gw_sh
# Script TCL para síntesis de proyecto PS/2 Mouse
# Tang Primer 25K (GW5A-LV25MG121NES)

# Abrir proyecto
open_project ps2_mouse.gprj

# Configurar top module
set_option -top_module top_ps2_test

# Configurar opciones de síntesis
set_option -verilog_std v2001
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

# Ejecutar síntesis completa
run all

# Fin del script
