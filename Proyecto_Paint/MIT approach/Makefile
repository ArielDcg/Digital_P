# Makefile para simulación MIT PS/2 Mouse @ 27MHz
# Estructura basada en Conexion_PS2/Makefile

OBJS = mit_ps2_mouse_interface.v

all: sim

sim:
	rm -f a.out *.vcd
	iverilog -DBENCH tb_mit_ps2_mouse_27mhz.v $(OBJS)
	vvp a.out
	gtkwave bench.vcd

clean:
	rm -f a.out *.vcd
