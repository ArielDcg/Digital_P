# PS2_to_Screen

Muestra cursor del mouse PS/2 en un panel LED HUB75.

## 📋 Descripción

Este proyecto lee datos de un mouse PS/2 en la FPGA y muestra un cursor en movimiento en un panel LED HUB75 de 64x64 píxeles con color de 12 bits.

## 🗂️ Estructura

```
PS2_to_Screen/
├── src/                    # Código fuente Verilog
│   ├── Mouse_to_screen.v   # Top module
│   ├── led_panel_4k.v      # Controlador LED panel
│   ├── ctrl_lp4k.v         # Control del panel
│   ├── memory_V2.v         # Memoria de framebuffer
│   └── ...                 # Módulos auxiliares
├── sim/                    # Testbenches
├── constraints/            # Archivos .cst
├── synthesis/              # Scripts .tcl
├── Makefile                # Compilación
└── README.md               # Esta documentación
```

## 🔌 Conexión

```
┌──────────┐    PS/2    ┌─────────┐    HUB75    ┌──────────┐
│  Mouse   │ ─────────► │  FPGA   │ ──────────► │ LED Panel │
│   PS/2   │            │  Tang   │             │  64x64    │
└──────────┘            └─────────┘             └──────────┘
```

### Panel LED HUB75:
- **Resolución:** 64x64 píxeles
- **Profundidad de color:** 12 bits (4096 colores)
- **Interfaz:** HUB75 estándar
- **Pines:** R1,G1,B1,R2,G2,B2, A,B,C,D,E, CLK, LAT, OE

## 🚀 Uso Rápido

```bash
# Simular
make sim

# Ver formas de onda
make wave

# Verificar sintaxis
make check

# Sintetizar
make synth

# Limpiar
make clean

# Ayuda
make help
```

## ✨ Características

- ✅ Cursor en movimiento suave
- ✅ Detección de posición X, Y
- ✅ Indicación visual de botones
- ✅ Framebuffer de 12 bpp
- ✅ Actualización en tiempo real

## 📊 Especificaciones Técnicas

### Resolución:
- Panel: 64x64 píxeles
- Framebuffer: 4096 palabras × 12 bits
- Frecuencia de refresco: ~60 Hz

### Movimiento del Cursor:
- Entrada: 9 bits con signo (-256 a +255)
- Rango en pantalla: 0-63 (X, Y)
- Límites implementados por hardware

### Colores:
- R: 4 bits
- G: 4 bits
- B: 4 bits
- Total: 4096 colores posibles

## 🎨 Personalización

### Cambiar color del cursor:
Editar en `Mouse_to_screen.v`:
```verilog
// Color del cursor (12 bits RGB)
localparam CURSOR_COLOR = 12'hFFF;  // Blanco
// localparam CURSOR_COLOR = 12'hF00;  // Rojo
// localparam CURSOR_COLOR = 12'h0F0;  // Verde
// localparam CURSOR_COLOR = 12'h00F;  // Azul
```

### Cambiar tamaño del cursor:
```verilog
// Tamaño del cursor en píxeles
localparam CURSOR_SIZE = 3;  // 3x3 píxeles
```

## 🛠️ Requisitos

### Hardware:
- Mouse PS/2
- FPGA Tang Primer 25K
- Panel LED HUB75 64x64
- Fuente de alimentación 5V para panel
- Cables de conexión

### Software:
- Gowin IDE (síntesis)
- Icarus Verilog (simulación)
- GTKWave (visualización)
- Make

## 🐛 Solución de Problemas

### Panel LED no enciende:
1. Verificar alimentación del panel (5V)
2. Verificar conexión de pines HUB75
3. Revisar constraints (.cst)

### Cursor no se mueve:
1. Verificar mouse PS/2 conectado
2. Ver señales de debug con GTKWave
3. Verificar inicialización PS/2

### Colores incorrectos:
1. Verificar orden de pines R,G,B
2. Ajustar mapeo en constraints
3. Verificar polaridad de OE

## 📚 Referencias

- **Módulo PS/2:** `../common/README.md`
- **Protocolo HUB75:** [Especificación estándar](https://github.com/hzeller/rpi-rgb-led-matrix)

## 📝 Licencia

Código abierto para uso educativo y comercial.

---

**Proyecto:** Digital_P - PS2 Mouse Projects
**Versión:** 2.0 (Modular)
