# Proyectos Mouse PS/2

Colección modular de proyectos para interfaz con mouse PS/2 usando FPGA Tang Primer 25K.

## 📋 Descripción

Este directorio contiene proyectos modulares que utilizan un mouse PS/2 como entrada. Todos comparten el módulo común `ps2_mouse_init.v` pero tienen diferentes aplicaciones finales.

## 🗂️ Estructura del Proyecto

```
PS2_Mouse_Projects/
├── common/                      # Módulos compartidos
│   ├── ps2_mouse_init.v        # Controlador PS/2 (común)
│   └── README.md               # Documentación del módulo PS/2
│
├── PS2_to_Screen/              # Proyecto 1: Mouse a pantalla LED
│   ├── src/                    # Código fuente Verilog
│   ├── constraints/            # Archivos .cst
│   ├── synthesis/              # Scripts .tcl
│   ├── sim/                    # Testbenches
│   ├── Makefile               # Compilación y síntesis
│   └── README.md              # Documentación específica
│
└── PS2_to_UART_ESP32/          # Proyecto 2: Mouse a UART/ESP32
    ├── fpga/                   # Parte FPGA
    │   ├── src/               # Código Verilog
    │   ├── constraints/       # Archivos .cst
    │   ├── synthesis/         # Scripts .tcl
    │   ├── sim/              # Testbenches
    │   └── Makefile          # Compilación FPGA
    ├── esp32/                 # Parte ESP32
    │   ├── PS2_Mouse_UART_ESP32.ino
    │   ├── examples/
    │   └── README.md
    └── README.md              # Documentación completa
```

## 📦 Proyectos Incluidos

### 1. PS2_to_Screen
**Descripción:** Muestra cursor del mouse en panel LED HUB75

**Características:**
- ✅ Cursor en pantalla LED 64x64
- ✅ Detección de botones
- ✅ Panel LED HUB75 (12 bpp)
- ✅ Movimiento suave

**Hardware requerido:**
- Mouse PS/2
- FPGA Tang Primer 25K
- Panel LED HUB75

### 2. PS2_to_UART_ESP32
**Descripción:** Envía datos del mouse por UART a ESP32

**Características:**
- ✅ Transmisión UART @ 115200 baud
- ✅ Protocolo de 6 bytes
- ✅ Programas Arduino para ESP32
- ✅ Servidor WiFi con dashboard
- ✅ Control de servomotores

**Hardware requerido:**
- Mouse PS/2
- FPGA Tang Primer 25K
- ESP32 Dev Board

## 🚀 Uso Rápido

### Opción 1: Makefile Global (desde este directorio)

```bash
# Ver ayuda
make help

# Compilar todo
make all

# Compilar solo PS2_to_Screen
make screen

# Compilar solo PS2_to_UART_ESP32
make uart

# Limpiar todo
make clean
```

### Opción 2: Makefiles Individuales

#### PS2_to_Screen:
```bash
cd PS2_to_Screen
make sim          # Simular
make synth        # Sintetizar
make program      # Programar FPGA
```

#### PS2_to_UART_ESP32:
```bash
cd PS2_to_UART_ESP32/fpga
make sim          # Simular
make synth        # Sintetizar
make program      # Programar FPGA

cd ../esp32
# Abrir en Arduino IDE
```

## 🔧 Requisitos

### Software:
- **Icarus Verilog** - Simulación
- **GTKWave** - Visualización de formas de onda
- **Gowin IDE** - Síntesis para Tang Primer 25K
- **Arduino IDE** - Para ESP32 (solo proyecto UART)
- **Make** - Automatización

### Hardware:
- **FPGA:** Tang Primer 25K (GW5A-LV25MG121)
- **Mouse PS/2:** Cualquier mouse estándar
- **Panel LED:** HUB75 64x64 (para PS2_to_Screen)
- **ESP32:** Dev Board (para PS2_to_UART_ESP32)

## 📖 Documentación

Cada proyecto tiene su propia documentación detallada:

- **Common:** `common/README.md` - Protocolo PS/2
- **PS2_to_Screen:** `PS2_to_Screen/README.md`
- **PS2_to_UART_ESP32:** `PS2_to_UART_ESP32/README.md`

## 🛠️ Desarrollo

### Agregar un nuevo proyecto:

1. Crear estructura de directorios:
   ```bash
   mkdir -p PS2_to_NewProject/{src,constraints,synthesis,sim}
   ```

2. Crear Makefile usando uno existente como plantilla

3. Reutilizar `../common/ps2_mouse_init.v`

4. Actualizar Makefile principal

## 📝 Licencia

Código abierto para uso educativo y comercial.

---

**Proyecto:** Digital_P
**Versión:** 2.0 (Modular)
**Fecha:** Diciembre 2025
