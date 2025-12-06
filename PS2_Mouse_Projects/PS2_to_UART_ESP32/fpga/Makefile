# Makefile para PS2_to_UART_ESP32 - Parte FPGA
# Proyecto modular - Digital_P

#============================================================================
# CONFIGURACIÓN
#============================================================================

PROJECT = mouse_display_top
TOP_MODULE = mouse_display_top
DEVICE = GW5A-LV25MG121NC1/I0

# Directorios
SRC_DIR = src
SIM_DIR = sim
SYNTH_DIR = synthesis
CONST_DIR = constraints
COMMON_DIR = ../../common

# Archivos fuente (NUEVA ARQUITECTURA: ESP32 lee PS/2, FPGA recibe UART)
SOURCES = $(SRC_DIR)/uart_mouse_receiver.v \
          $(SRC_DIR)/mouse_display_top.v \
          $(SRC_DIR)/uart.v

# Testbench
TB = $(SIM_DIR)/uart_mouse_receiver_tb.v
TB_OUT = $(SIM_DIR)/uart_mouse_receiver_tb.vvp
VCD = $(SIM_DIR)/uart_mouse_receiver_tb.vcd

# Constraints y síntesis
CST_FILE = $(CONST_DIR)/$(PROJECT).cst
TCL_FILE = $(SYNTH_DIR)/build.tcl

# Herramientas
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
GOWIN = gw_sh

# Colores
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

#============================================================================
# TARGETS
#============================================================================

.PHONY: all clean sim wave synth program help info

# Target por defecto
all: sim

#----------------------------------------------------------------------------
# Simulación
#----------------------------------------------------------------------------

# Compilar testbench
compile: $(TB) $(SOURCES)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Compilando testbench...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@$(IVERILOG) -o $(TB_OUT) -s $(PROJECT)_tb $(TB) $(SOURCES)
	@echo "$(GREEN)✓ Compilación exitosa$(NC)"
	@echo ""

# Ejecutar simulación
sim: compile
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Ejecutando simulación...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@cd $(SIM_DIR) && $(VVP) $(PROJECT)_tb.vvp
	@echo ""
	@echo "$(GREEN)✓ Simulación completada$(NC)"
	@echo "$(YELLOW)  VCD generado: $(VCD)$(NC)"
	@echo ""

# Abrir GTKWave
wave: $(VCD)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Abriendo GTKWave...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@$(GTKWAVE) $(VCD) &
	@echo "$(GREEN)✓ GTKWave abierto$(NC)"
	@echo ""

#----------------------------------------------------------------------------
# Síntesis
#----------------------------------------------------------------------------

# Sintetizar con Gowin
synth: $(SOURCES) $(CST_FILE) $(TCL_FILE)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Sintetizando diseño con Gowin...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@cd $(SYNTH_DIR) && $(GOWIN) $(TCL_FILE)
	@echo "$(GREEN)✓ Síntesis completada$(NC)"
	@echo ""

# Programar FPGA
program:
	@echo "$(YELLOW)Programar FPGA desde Gowin IDE$(NC)"
	@echo "  Archivo: $(SYNTH_DIR)/impl/pnr/$(PROJECT).fs"
	@echo ""

#----------------------------------------------------------------------------
# Verificación
#----------------------------------------------------------------------------

# Verificar sintaxis
check: $(SOURCES)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Verificando sintaxis...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@$(IVERILOG) -t null $(SOURCES)
	@echo "$(GREEN)✓ Sintaxis correcta$(NC)"
	@echo ""

#----------------------------------------------------------------------------
# Utilidades
#----------------------------------------------------------------------------

# Limpiar archivos generados
clean:
	@echo "$(YELLOW)Limpiando archivos generados...$(NC)"
	@rm -f $(TB_OUT) $(VCD)
	@rm -rf $(SYNTH_DIR)/impl
	@rm -f $(SYNTH_DIR)/*.gprj $(SYNTH_DIR)/*.log
	@echo "$(GREEN)✓ Limpieza completa$(NC)"
	@echo ""

# Mostrar información
info:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Información del Proyecto$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  Proyecto:      $(PROJECT)"
	@echo "  Top Module:    $(TOP_MODULE)"
	@echo "  Dispositivo:   $(DEVICE)"
	@echo ""
	@echo "$(YELLOW)Archivos fuente:$(NC)"
	@for file in $(SOURCES); do echo "  - $$file"; done
	@echo ""
	@echo "$(YELLOW)Testbench:$(NC)"
	@echo "  - $(TB)"
	@echo ""

# Ayuda
help:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Makefile - PS2_to_UART_ESP32 (FPGA)$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo "$(GREEN)Targets disponibles:$(NC)"
	@echo "  $(YELLOW)make$(NC)          - Simular (default)"
	@echo "  $(YELLOW)make compile$(NC)  - Compilar testbench"
	@echo "  $(YELLOW)make sim$(NC)      - Compilar y simular"
	@echo "  $(YELLOW)make wave$(NC)     - Abrir GTKWave"
	@echo "  $(YELLOW)make check$(NC)    - Verificar sintaxis"
	@echo "  $(YELLOW)make synth$(NC)    - Sintetizar con Gowin"
	@echo "  $(YELLOW)make program$(NC)  - Instrucciones para programar"
	@echo "  $(YELLOW)make clean$(NC)    - Limpiar archivos generados"
	@echo "  $(YELLOW)make info$(NC)     - Información del proyecto"
	@echo "  $(YELLOW)make help$(NC)     - Esta ayuda"
	@echo ""
	@echo "$(GREEN)Ejemplos:$(NC)"
	@echo "  $(YELLOW)make sim && make wave$(NC)    # Simular y ver formas"
	@echo "  $(YELLOW)make check$(NC)               # Verificar sintaxis"
	@echo "  $(YELLOW)make synth$(NC)               # Sintetizar diseño"
	@echo ""
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
