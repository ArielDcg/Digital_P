# Makefile Principal - PS2 Mouse Projects
# Gestión de proyectos modulares
# Digital_P

#============================================================================
# CONFIGURACIÓN
#============================================================================

# Directorios de proyectos
SCREEN_DIR = PS2_to_Screen
UART_DIR = PS2_to_UART_ESP32/fpga

# Colores
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
CYAN = \033[0;36m
NC = \033[0m

#============================================================================
# TARGETS PRINCIPALES
#============================================================================

.PHONY: all clean help screen uart screen-sim uart-sim screen-synth uart-synth info

# Target por defecto
all: help

#----------------------------------------------------------------------------
# Compilación de todos los proyectos
#----------------------------------------------------------------------------

# Compilar todo
compile-all:
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     COMPILANDO TODOS LOS PROYECTOS PS/2 MOUSE          ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@$(MAKE) -C $(SCREEN_DIR) compile
	@$(MAKE) -C $(UART_DIR) compile
	@echo ""
	@echo "$(GREEN)✓ Todos los proyectos compilados$(NC)"
	@echo ""

# Simular todo
sim-all:
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     SIMULANDO TODOS LOS PROYECTOS PS/2 MOUSE           ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@$(MAKE) -C $(SCREEN_DIR) sim
	@$(MAKE) -C $(UART_DIR) sim
	@echo ""
	@echo "$(GREEN)✓ Todas las simulaciones completadas$(NC)"
	@echo ""

#----------------------------------------------------------------------------
# Proyectos individuales
#----------------------------------------------------------------------------

# PS2_to_Screen
screen:
	@echo "$(CYAN)→ Trabajando en PS2_to_Screen...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) all

screen-sim:
	@echo "$(CYAN)→ Simulando PS2_to_Screen...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) sim

screen-wave:
	@echo "$(CYAN)→ Abriendo GTKWave para PS2_to_Screen...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) wave

screen-synth:
	@echo "$(CYAN)→ Sintetizando PS2_to_Screen...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) synth

screen-clean:
	@echo "$(CYAN)→ Limpiando PS2_to_Screen...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) clean

# PS2_to_UART_ESP32
uart:
	@echo "$(CYAN)→ Trabajando en PS2_to_UART_ESP32...$(NC)"
	@$(MAKE) -C $(UART_DIR) all

uart-sim:
	@echo "$(CYAN)→ Simulando PS2_to_UART_ESP32...$(NC)"
	@$(MAKE) -C $(UART_DIR) sim

uart-wave:
	@echo "$(CYAN)→ Abriendo GTKWave para PS2_to_UART_ESP32...$(NC)"
	@$(MAKE) -C $(UART_DIR) wave

uart-synth:
	@echo "$(CYAN)→ Sintetizando PS2_to_UART_ESP32...$(NC)"
	@$(MAKE) -C $(UART_DIR) synth

uart-clean:
	@echo "$(CYAN)→ Limpiando PS2_to_UART_ESP32...$(NC)"
	@$(MAKE) -C $(UART_DIR) clean

#----------------------------------------------------------------------------
# Utilidades
#----------------------------------------------------------------------------

# Limpiar todo
clean:
	@echo "$(YELLOW)Limpiando todos los proyectos...$(NC)"
	@$(MAKE) -C $(SCREEN_DIR) clean
	@$(MAKE) -C $(UART_DIR) clean
	@echo "$(GREEN)✓ Limpieza completa de todos los proyectos$(NC)"
	@echo ""

# Información
info:
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║          PROYECTOS PS/2 MOUSE - INFORMACIÓN             ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Proyectos disponibles:$(NC)"
	@echo ""
	@echo "  $(YELLOW)1. PS2_to_Screen$(NC)"
	@echo "     Muestra cursor del mouse en panel LED HUB75 64x64"
	@echo "     Directorio: $(SCREEN_DIR)"
	@echo ""
	@echo "  $(YELLOW)2. PS2_to_UART_ESP32$(NC)"
	@echo "     Envía datos del mouse por UART a ESP32"
	@echo "     Directorio: $(UART_DIR)"
	@echo ""
	@echo "$(GREEN)Módulos comunes:$(NC)"
	@echo "  - common/ps2_mouse_init.v (Controlador PS/2)"
	@echo ""
	@echo "$(GREEN)Hardware:$(NC)"
	@echo "  - FPGA: Tang Primer 25K (GW5A-LV25MG121NC1/I0)"
	@echo "  - Mouse: PS/2 estándar"
	@echo ""

# Ayuda
help:
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     MAKEFILE PRINCIPAL - PROYECTOS PS/2 MOUSE           ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)═══ COMPILACIÓN GLOBAL ═══$(NC)"
	@echo "  $(YELLOW)make compile-all$(NC)     - Compilar todos los proyectos"
	@echo "  $(YELLOW)make sim-all$(NC)         - Simular todos los proyectos"
	@echo "  $(YELLOW)make clean$(NC)           - Limpiar todos los proyectos"
	@echo ""
	@echo "$(GREEN)═══ PS2_to_Screen ═══$(NC)"
	@echo "  $(YELLOW)make screen$(NC)          - Simular (default)"
	@echo "  $(YELLOW)make screen-sim$(NC)      - Simular"
	@echo "  $(YELLOW)make screen-wave$(NC)     - Ver formas de onda"
	@echo "  $(YELLOW)make screen-synth$(NC)    - Sintetizar"
	@echo "  $(YELLOW)make screen-clean$(NC)    - Limpiar"
	@echo ""
	@echo "$(GREEN)═══ PS2_to_UART_ESP32 ═══$(NC)"
	@echo "  $(YELLOW)make uart$(NC)            - Simular (default)"
	@echo "  $(YELLOW)make uart-sim$(NC)        - Simular"
	@echo "  $(YELLOW)make uart-wave$(NC)       - Ver formas de onda"
	@echo "  $(YELLOW)make uart-synth$(NC)      - Sintetizar"
	@echo "  $(YELLOW)make uart-clean$(NC)      - Limpiar"
	@echo ""
	@echo "$(GREEN)═══ INFORMACIÓN ═══$(NC)"
	@echo "  $(YELLOW)make info$(NC)            - Información de proyectos"
	@echo "  $(YELLOW)make help$(NC)            - Esta ayuda"
	@echo ""
	@echo "$(GREEN)═══ EJEMPLOS ═══$(NC)"
	@echo "  $(CYAN)make screen-sim && make screen-wave$(NC)"
	@echo "     Simular PS2_to_Screen y ver formas"
	@echo ""
	@echo "  $(CYAN)make uart-synth$(NC)"
	@echo "     Sintetizar PS2_to_UART_ESP32"
	@echo ""
	@echo "  $(CYAN)make sim-all$(NC)"
	@echo "     Simular ambos proyectos"
	@echo ""
	@echo "$(GREEN)═══ MAKEFILES INDIVIDUALES ═══$(NC)"
	@echo "  Para opciones avanzadas, usar Makefiles individuales:"
	@echo "  $(CYAN)cd PS2_to_Screen && make help$(NC)"
	@echo "  $(CYAN)cd PS2_to_UART_ESP32/fpga && make help$(NC)"
	@echo ""
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
