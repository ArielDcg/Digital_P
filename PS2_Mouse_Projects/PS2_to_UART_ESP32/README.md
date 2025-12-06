# PS2_to_UART_ESP32

Sistema completo donde **ESP32 lee el mouse PS/2** y transmite los datos a la **FPGA vía UART**.

## 📋 Arquitectura

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│  Mouse   │  PS/2   │  ESP32   │  UART   │  FPGA    │
│   PS/2   │ ──────► │ Arduino  │ ──────► │  Tang    │
└──────────┘         └──────────┘         └──────────┘
   CLK/DATA         GPIO 34/35          GPIO 17→RX
```

**La ESP32 es el intermediario que:**
1. Lee el mouse PS/2 directamente (mediante interrupciones)
2. Decodifica el protocolo PS/2
3. Codifica los datos en un paquete de 6 bytes
4. Los transmite por UART a la FPGA

**La FPGA:**
1. Recibe el paquete por UART
2. Decodifica los datos del mouse
3. Los puede usar para cualquier aplicación

## 🗂️ Estructura

```
PS2_to_UART_ESP32/
├── esp32/                   # Parte ESP32/Arduino
│   ├── ESP32_PS2_Mouse_Reader/
│   │   └── ESP32_PS2_Mouse_Reader.ino  ⭐ Programa principal
│   ├── examples/
│   │   ├── WiFi_Mouse_Server/          # (Compatibilidad)
│   │   └── Servo_Control/              # (Compatibilidad)
│   └── README.md
│
├── fpga/                    # Parte FPGA
│   ├── src/
│   │   ├── uart_mouse_receiver.v       # Receptor UART
│   │   ├── mouse_display_top.v         # Top module
│   │   └── uart.v                      # Módulo UART
│   ├── sim/
│   │   └── uart_mouse_receiver_tb.v    # Testbench
│   ├── constraints/
│   │   └── mouse_uart_rx.cst           # Constraints
│   ├── synthesis/
│   │   └── build.tcl                   # Script síntesis
│   └── Makefile
│
└── README.md                # Esta documentación
```

## 🔌 Conexiones Hardware

### Mouse PS/2 → ESP32

| Mouse PS/2 | ESP32 | Notas |
|------------|-------|-------|
| CLK | GPIO 34 | Input only (con pull-up) |
| DATA | GPIO 35 | Input only (con pull-up) |
| VCC | 5V | ESP32 tolera 5V en GPIO 34/35 |
| GND | GND | Tierra común |

**IMPORTANTE:**
- GPIO 34 y 35 son solo entrada pero toleran 5V
- Usar resistencias pull-up de 10kΩ si el mouse no las tiene
- El mouse requiere alimentación de 5V

### ESP32 → FPGA

| ESP32 | FPGA | Función |
|-------|------|---------|
| TX (GPIO 17) | RX (pin 18) | Datos UART |
| GND | GND | Tierra común |

**Configuración UART:** 115200 baud, 8N1

## 📦 Protocolo de Comunicación

### Paquete UART (6 bytes):

| Byte | Contenido | Descripción |
|------|-----------|-------------|
| 0 | `0xAA` | Sincronización |
| 1 | `X[7:0]` | 8 bits bajos de movimiento X |
| 2 | `{7'b0, X[8]}` | Bit de signo de X (0=+, 1=-) |
| 3 | `Y[7:0]` | 8 bits bajos de movimiento Y |
| 4 | `{7'b0, Y[8]}` | Bit de signo de Y (0=+, 1=-) |
| 5 | `{5'b0, buttons[2:0]}` | Botones [Middle, Right, Left] |

### Movimiento:
- **Rango:** -256 a +255 (9 bits con signo)
- **Formato:** Complemento a 2

## 🚀 Uso del Sistema

### Parte ESP32:

```bash
# 1. Abrir en Arduino IDE
Arduino IDE → Abrir → esp32/ESP32_PS2_Mouse_Reader/ESP32_PS2_Mouse_Reader.ino

# 2. Instalar soporte ESP32 (si no está)
File → Preferences → Additional Board Manager URLs:
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json

Tools → Board → Boards Manager → Buscar "esp32" → Instalar

# 3. Configurar
Tools → Board → ESP32 Dev Module
Tools → Port → Seleccionar puerto COM

# 4. Subir
Click en Upload (→)

# 5. Ver Serial Monitor
Tools → Serial Monitor (115200 baud)
```

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

## 🧪 Simulación

El testbench simula la recepción de paquetes UART:

```bash
cd fpga
make sim
```

**Pruebas incluidas:**
- Sin movimiento
- Movimientos en todas direcciones
- Valores positivos y negativos
- Valores máximos (+255, -256)
- Todos los botones
- Combinaciones

## 💻 Programación ESP32

### Características del programa:

**ESP32_PS2_Mouse_Reader.ino**
- ✅ Lectura PS/2 mediante interrupciones
- ✅ Decodificación completa del protocolo
- ✅ Verificación de paridad
- ✅ Transmisión UART automática
- ✅ Monitor serial con formato visual
- ✅ Estadísticas del sistema
- ✅ Detección de errores

### Configuración:

```cpp
// Pines PS/2
#define PS2_CLK_PIN  34
#define PS2_DATA_PIN 35

// UART
#define UART_TX 17
#define BAUD_RATE 115200

// Debug
#define DEBUG true  // Mensajes en Serial Monitor
```

## 🔧 FPGA - Módulos Verilog

### 1. `uart_mouse_receiver.v`
Recibe paquetes UART y los decodifica.

**Salidas:**
- `mouse_x[8:0]` - Movimiento X
- `mouse_y[8:0]` - Movimiento Y
- `buttons[2:0]` - Botones
- `packet_ready` - Pulso cuando hay datos nuevos

### 2. `mouse_display_top.v`
Top module de ejemplo que:
- Instancia el receptor UART
- Mantiene un cursor acumulativo
- Proporciona salidas para otros módulos

**Puedes modificar este módulo para:**
- Mostrar cursor en pantalla LED
- Controlar otros periféricos
- Implementar funcionalidad de "paint"
- etc.

## 📊 LEDs de Depuración

| LED | Función |
|-----|---------|
| LED[0] | Toggle con cada paquete |
| LED[1] | Error UART |
| LED[2] | Recibiendo paquete |
| LED[3] | Botón izquierdo presionado |

## 🛠️ Solución de Problemas

### ESP32 no lee el mouse:

**Verificar:**
1. ✓ Conexiones CLK→GPIO34, DATA→GPIO35
2. ✓ Pull-ups en CLK y DATA (10kΩ)
3. ✓ Alimentación del mouse (5V)
4. ✓ Serial Monitor muestra mensajes de inicialización

**Debug:**
- El mouse puede tardar unos segundos en iniciar
- Ver Serial Monitor para mensajes de error
- Verificar con osciloscopio que hay pulsos en CLK

### FPGA no recibe datos:

**Verificar:**
1. ✓ Conexión ESP32 TX→FPGA RX
2. ✓ GND común
3. ✓ Baudrate correcto (115200)
4. ✓ ESP32 está enviando (LED0 de FPGA parpadeando)

**Debug:**
- LED[2] debe encenderse al recibir
- LED[0] debe parpadear con cada paquete
- Usar simulación para verificar lógica

### Datos corruptos:

**Causas:**
- Cable demasiado largo
- Baudrate incorrecto
- Ruido en la línea

**Solución:**
- Usar cable corto (<30 cm)
- Verificar baudrate en ambos lados
- Cable blindado si hay interferencia

## 📚 Ventajas de esta Arquitectura

### ✅ ESP32 como intermediario:
- Maneja el complejo protocolo PS/2 en software
- La FPGA solo necesita UART (más simple)
- Fácil debug por Serial Monitor

### ✅ Flexibilidad:
- ESP32 puede procesar los datos antes de enviar
- Puede agregar WiFi, Bluetooth, etc.
- FPGA se enfoca en su aplicación específica

### ✅ Modular:
- Puedes actualizar el código ESP32 fácilmente
- FPGA no necesita resintetizarse para cambios en PS/2
- Fácil de mantener y expandir

## 📖 Documentación Adicional

- **Protocolo PS/2:** `../common/README.md`
- **ESP32 Arduino:** `esp32/README.md`
- **FPGA Makefile:** `fpga/Makefile` (ejecutar `make help`)

## 📝 Licencia

Código abierto para uso educativo y comercial.

---

**Proyecto:** Digital_P - PS2 Mouse Projects
**Versión:** 2.0 (Modular) - Arquitectura ESP32→FPGA
**Fecha:** Diciembre 2025
