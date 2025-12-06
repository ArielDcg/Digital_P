# Makefile para PS2_to_Screen
# Muestra cursor del mouse PS/2 en panel LED HUB75
# Proyecto modular - Digital_P

#============================================================================
# CONFIGURACIÓN
#============================================================================

PROJECT = mouse_to_screen
TOP_MODULE = Mouse_to_screen
DEVICE = GW5A-LV25MG121NC1/I0

# Directorios
SRC_DIR = src
SIM_DIR = sim
SYNTH_DIR = synthesis
CONST_DIR = constraints
COMMON_DIR = ../common

# Archivos fuente principales
MAIN_SOURCES = $(SRC_DIR)/Mouse_to_screen.v \
               $(SRC_DIR)/led_panel_4k.v \
               $(COMMON_DIR)/ps2_mouse_init.v

# Módulos auxiliares
AUX_SOURCES = $(SRC_DIR)/ctrl_lp4k.v \
              $(SRC_DIR)/memory_V2.v \
              $(SRC_DIR)/mult.v \
              $(SRC_DIR)/comp.v \
              $(SRC_DIR)/count.v \
              $(SRC_DIR)/lsr_led.v \
              $(SRC_DIR)/mux_led.v

SOURCES = $(MAIN_SOURCES) $(AUX_SOURCES)

# Testbench
TB = $(SIM_DIR)/led_panel_4k_TB.v
TB_OUT = $(SIM_DIR)/led_panel_4k_TB.vvp
VCD = $(SIM_DIR)/led_panel_4k_TB.vcd

# Constraints y síntesis
CST_FILE = $(CONST_DIR)/ps2_mouse_constraints.cst
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

compile: $(TB) $(SOURCES)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Compilando PS2_to_Screen testbench...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@$(IVERILOG) -o $(TB_OUT) $(TB) $(SOURCES)
	@echo "$(GREEN)✓ Compilación exitosa$(NC)"
	@echo ""

sim: compile
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Ejecutando simulación...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@cd $(SIM_DIR) && $(VVP) led_panel_4k_TB.vvp
	@echo ""
	@echo "$(GREEN)✓ Simulación completada$(NC)"
	@echo "$(YELLOW)  VCD: $(VCD)$(NC)"
	@echo ""

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

synth: $(SOURCES) $(CST_FILE) $(TCL_FILE)
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Sintetizando PS2_to_Screen...$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@cd $(SYNTH_DIR) && $(GOWIN) $(TCL_FILE)
	@echo "$(GREEN)✓ Síntesis completada$(NC)"
	@echo ""

program:
	@echo "$(YELLOW)Programar FPGA desde Gowin IDE$(NC)"
	@echo "  Archivo: $(SYNTH_DIR)/impl/pnr/$(PROJECT).fs"
	@echo ""

#----------------------------------------------------------------------------
# Verificación
#----------------------------------------------------------------------------

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

clean:
	@echo "$(YELLOW)Limpiando archivos generados...$(NC)"
	@rm -f $(TB_OUT) $(VCD)
	@rm -rf $(SYNTH_DIR)/impl
	@rm -f $(SYNTH_DIR)/*.gprj $(SYNTH_DIR)/*.log
	@echo "$(GREEN)✓ Limpieza completa$(NC)"
	@echo ""

info:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  PS2_to_Screen - Información$(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  Proyecto:      $(PROJECT)"
	@echo "  Top Module:    $(TOP_MODULE)"
	@echo "  Dispositivo:   $(DEVICE)"
	@echo "  Pantalla:      LED HUB75 64x64 (12 bpp)"
	@echo ""
	@echo "$(YELLOW)Archivos principales:$(NC)"
	@for file in $(MAIN_SOURCES); do echo "  - $$file"; done
	@echo ""

help:
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)  Makefile - PS2_to_Screen$(NC)"
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
	@echo "  $(YELLOW)make clean$(NC)    - Limpiar archivos"
	@echo "  $(YELLOW)make info$(NC)     - Información del proyecto"
	@echo "  $(YELLOW)make help$(NC)     - Esta ayuda"
	@echo ""
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
