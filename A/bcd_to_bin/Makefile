# --------------------------
# Makefile para peripheral_bcd_to_bin
# --------------------------

TARGET = bcd_to_bin
TOP    = bcd_to_bin

# Archivos fuente del módulo principal
OBJS     = bcd_to_bin_16.v comp_digit.v sub_digit.v rsr.v counter.v control_bcd_to_bin.v
PER_OBJS = peripheral_bcd_to_bin.v $(OBJS)

# Marcar targets que no corresponden a archivos
.PHONY: all sim sim_per clean

# Target por defecto
all: sim

# --------------------------
# Simulación funcional normal (testbench bcd_to_bin_16_TB.v)
# --------------------------
sim:
	rm -f a.out *.vcd
	iverilog -DBENCH bcd_to_bin_16_TB.v $(OBJS)
	vvp a.out
	gtkwave bcd_to_bin_16_TB.vcd &

# --------------------------
# Simulación del periférico (testbench peripheral_bcd_to_bin_TB.v)
# --------------------------
sim_per:
	rm -f a.out *.vcd
	iverilog -DBENCH peripheral_bcd_to_bin_TB.v $(PER_OBJS)
	vvp a.out
	gtkwave peripheral_bcd_to_bin_TB.vcd &

# --------------------------
# Limpieza de archivos generados
# --------------------------
clean:
	rm -f a.out *.vcd *.vpp *.json *.rpt $(TOP)_synth.v
