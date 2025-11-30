################################################################################
# Makefile para simulación de MIT PS/2 Mouse con Icarus Verilog
# Target: Tang Primer 25K (Gowin GW5A-25, 27MHz clock)
################################################################################

# Compilador y simulador
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Archivos fuente
DUT_FILES = mit_ps2_mouse_interface.v
TB_FILE = tb_mit_ps2_mouse_27mhz.v

# Archivos de salida
VVP_OUT = simulation.vvp
VCD_OUT = tb_mit_ps2_mouse_27mhz.vcd

# Flags de compilación
IVERILOG_FLAGS = -g2012 -Wall -Winfloop
VVP_FLAGS =

# Regla por defecto
.PHONY: all
all: compile simulate

# Compilar el diseño
.PHONY: compile
compile: $(VVP_OUT)

$(VVP_OUT): $(DUT_FILES) $(TB_FILE)
	@echo "==================================================="
	@echo "  Compilando con Icarus Verilog..."
	@echo "==================================================="
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(VVP_OUT) $(DUT_FILES) $(TB_FILE)
	@echo "Compilación exitosa: $(VVP_OUT)"
	@echo ""

# Ejecutar la simulación
.PHONY: simulate
simulate: $(VVP_OUT)
	@echo "==================================================="
	@echo "  Ejecutando simulación..."
	@echo "==================================================="
	$(VVP) $(VVP_FLAGS) $(VVP_OUT)
	@echo ""
	@echo "Simulación completada. VCD generado: $(VCD_OUT)"
	@echo ""

# Ver formas de onda con GTKWave
.PHONY: wave
wave: $(VCD_OUT)
	@echo "Abriendo GTKWave..."
	$(GTKWAVE) $(VCD_OUT) &

# Limpiar archivos generados
.PHONY: clean
clean:
	@echo "Limpiando archivos generados..."
	rm -f $(VVP_OUT) $(VCD_OUT)
	@echo "Limpieza completada."

# Ejecutar todo el flujo (compilar, simular y ver ondas)
.PHONY: run
run: clean all
	@echo ""
	@echo "==================================================="
	@echo "  Flujo completo ejecutado"
	@echo "==================================================="
	@echo "Para ver las formas de onda ejecuta: make wave"

# Ayuda
.PHONY: help
help:
	@echo "Makefile para simulación de MIT PS/2 Mouse @ 27MHz"
	@echo ""
	@echo "Objetivos disponibles:"
	@echo "  make all       - Compilar y simular (por defecto)"
	@echo "  make compile   - Solo compilar el diseño"
	@echo "  make simulate  - Solo ejecutar la simulación"
	@echo "  make wave      - Abrir GTKWave con el VCD generado"
	@echo "  make run       - Limpiar, compilar y simular"
	@echo "  make clean     - Eliminar archivos generados"
	@echo "  make help      - Mostrar esta ayuda"
	@echo ""
	@echo "Archivos:"
	@echo "  DUT: $(DUT_FILES)"
	@echo "  TB:  $(TB_FILE)"
	@echo "  VCD: $(VCD_OUT)"
