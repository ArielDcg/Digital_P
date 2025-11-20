# Makefile para proyecto PS/2 Mouse - Tang Primer 25K
# Requiere Gowin EDA instalado

PROJECT = ps2_mouse_project
TOP_MODULE = top_ps2_test
DEVICE = GW5A-LV25MG121NES

# Archivos fuente
SOURCES = ps2_mouse_init.v top_ps2_test.v
CONSTRAINTS = ps2_mouse_constraints.cst

# Herramientas
GOWIN_SH = gw_sh
PROGRAMMER = openFPGALoader

# Directorios
BUILD_DIR = impl/pnr

.PHONY: all synth program clean help

all: synth

# Síntesis completa
synth: $(SOURCES) $(CONSTRAINTS)
	@echo "🔨 Iniciando síntesis..."
	$(GOWIN_SH) build.tcl
	@echo "✅ Síntesis completada. Bitstream generado en $(BUILD_DIR)/"

# Programar FPGA via USB (SRAM)
program:
	@echo "📡 Programando FPGA (SRAM)..."
	$(PROGRAMMER) -b tangprimer25k $(BUILD_DIR)/$(PROJECT).fs
	@echo "✅ FPGA programada"

# Programar Flash (persistente)
program-flash:
	@echo "💾 Programando Flash..."
	$(PROGRAMMER) -b tangprimer25k -f $(BUILD_DIR)/$(PROJECT).fs
	@echo "✅ Flash programado"

# Limpiar archivos generados
clean:
	@echo "🧹 Limpiando archivos de build..."
	rm -rf impl/ .project_workspace/ *.log *.rpt
	@echo "✅ Limpieza completada"

# Mostrar ayuda
help:
	@echo "📚 Comandos disponibles:"
	@echo "  make synth         - Sintetizar diseño"
	@echo "  make program       - Programar FPGA (SRAM, volátil)"
	@echo "  make program-flash - Programar Flash (persistente)"
	@echo "  make clean         - Limpiar archivos generados"
	@echo ""
	@echo "⚙️  Requisitos:"
	@echo "  - Gowin EDA (gw_sh en PATH)"
	@echo "  - openFPGALoader (para programación)"
