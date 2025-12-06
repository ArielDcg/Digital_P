# PS2_to_UART_ESP32

Sistema completo para transmitir datos de mouse PS/2 desde FPGA a ESP32 vía UART.

## 📋 Descripción

Este proyecto lee datos de un mouse PS/2 en la FPGA y los transmite por UART a una ESP32, donde pueden ser procesados y usados para diversas aplicaciones (WiFi, servos, displays, etc.).

## 🗂️ Estructura

```
PS2_to_UART_ESP32/
├── fpga/                    # Parte FPGA
│   ├── src/                # Código Verilog
│   │   ├── ps2_mouse_to_uart.v
│   │   └── uart.v
│   ├── sim/                # Testbenches
│   ├── constraints/        # Archivos .cst
│   ├── synthesis/          # Scripts .tcl
│   └── Makefile           # Compilación FPGA
└── esp32/                  # Parte ESP32
    ├── PS2_Mouse_UART_ESP32.ino
    ├── examples/
    │   ├── WiFi_Mouse_Server/
    │   └── Servo_Control/
    └── README.md
```

## 🔌 Conexión

```
┌──────────┐    PS/2    ┌─────────┐    UART    ┌──────────┐
│  Mouse   │ ─────────► │  FPGA   │ ─────────► │  ESP32   │
│   PS/2   │            │  Tang   │  115200    │ Arduino  │
└──────────┘            └─────────┘   baud     └──────────┘
```

### Pines:
| FPGA | ESP32 | Función |
|------|-------|---------|
| UART TX | GPIO 16 (RX2) | Datos |
| GND | GND | Tierra común |

## 🚀 Uso Rápido

### Parte FPGA:

```bash
cd fpga

# Simular
make sim

# Ver formas de onda
make wave

# Sintetizar
make synth

# Ayuda
make help
```

### Parte ESP32:

1. Abrir `esp32/PS2_Mouse_UART_ESP32.ino` en Arduino IDE
2. Seleccionar placa ESP32 Dev Module
3. Subir programa
4. Abrir Serial Monitor (115200 baud)

Ver `esp32/README.md` para detalles completos.

## 📦 Protocolo UART

Paquete de 6 bytes por cada movimiento del mouse:

| Byte | Contenido | Descripción |
|------|-----------|-------------|
| 0 | `0xAA` | Sincronización |
| 1 | `X[7:0]` | 8 bits bajos de X |
| 2 | `X[8]` | Bit de signo de X |
| 3 | `Y[7:0]` | 8 bits bajos de Y |
| 4 | `Y[8]` | Bit de signo de Y |
| 5 | `buttons[2:0]` | Botones [M,R,L] |

## 💡 Aplicaciones Incluidas

### Programa Principal:
- Monitor serial con formato visual
- Cursor virtual acumulativo
- Detección de clicks

### Servidor WiFi:
- Dashboard web en tiempo real
- WebSocket para baja latencia
- Canvas de dibujo interactivo

### Control de Servos:
- Control pan/tilt con el mouse
- Reset a posición central
- Sensibilidad ajustable

## 📚 Documentación

- **FPGA:** Ver `fpga/Makefile` para opciones de compilación
- **ESP32:** Ver `esp32/README.md` para programas Arduino
- **Protocolo:** Ver `../../README_PS2_UART.md` (documentación original)

## 🛠️ Requisitos

### Hardware:
- Mouse PS/2
- FPGA Tang Primer 25K
- ESP32 Dev Board
- Cables de conexión

### Software:
- **FPGA:** Gowin IDE, Icarus Verilog, GTKWave
- **ESP32:** Arduino IDE con soporte ESP32

## 📝 Licencia

Código abierto para uso educativo y comercial.

---

**Proyecto:** Digital_P - PS2 Mouse Projects
**Versión:** 2.0 (Modular)
