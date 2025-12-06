# Sistema PS/2 Mouse a UART para FPGA

## 📋 Descripción General

Este proyecto implementa un sistema completo para leer datos de un mouse PS/2 y transmitirlos por UART a una computadora. El sistema está diseñado para ser implementado en una FPGA (Tang Primer 25K o similar).

### Características principales:

- ✅ Lectura completa de mouse PS/2 (posición X, Y y botones)
- ✅ Transmisión de datos por UART a 115200 baud
- ✅ Valores de posición de 9 bits con signo (-256 a +255)
- ✅ Detección de 3 botones (izquierdo, derecho, medio)
- ✅ Protocolo de comunicación robusto con byte de sincronización
- ✅ LEDs de depuración para monitoreo del estado

---

## 📁 Archivos del Proyecto

### Archivos Verilog (FPGA)

| Archivo | Descripción |
|---------|-------------|
| `ps2_mouse_to_uart.v` | Módulo principal que integra PS/2 y UART |
| `ps2_mouse_init.v` | Controlador del mouse PS/2 |
| `uart.v` | Módulo de comunicación UART |
| `ps2_mouse_to_uart_tb.v` | Testbench para simulación |

### Archivos de Software (PC/ESP32)

| Archivo | Descripción |
|---------|-------------|
| `uart_mouse_receiver.py` | Programa Python para recibir datos por UART |
| `PS2_Mouse_UART_ESP32/` | Programas Arduino para ESP32 |
| `PS2_Mouse_UART_ESP32/PS2_Mouse_UART_ESP32.ino` | Programa principal para ESP32 |
| `PS2_Mouse_UART_ESP32/examples/WiFi_Mouse_Server/` | Servidor web con WebSocket |
| `PS2_Mouse_UART_ESP32/examples/Servo_Control/` | Control de servomotores |

### Documentación

| Archivo | Descripción |
|---------|-------------|
| `README_PS2_UART.md` | Esta documentación |
| `README_PS2.md` | Documentación detallada del protocolo PS/2 |

---

## 🔌 Diagrama de Conexión

### Opción 1: Con PC
```
┌──────────┐         ┌─────────┐         ┌──────────┐
│  Mouse   │   PS/2  │  FPGA   │  UART   │    PC    │
│   PS/2   │ ──────► │ (Tang)  │ ──────► │  Python  │
└──────────┘         └─────────┘         └──────────┘
                     │  LEDs   │ (debug)
                     └─────────┘

### Opción 2: Con ESP32 (Recomendado)
```
┌──────────┐         ┌─────────┐         ┌──────────┐
│  Mouse   │   PS/2  │  FPGA   │  UART   │  ESP32   │
│   PS/2   │ ──────► │ (Tang)  │ ──────► │ Arduino  │
└──────────┘         └─────────┘         └──────────┘
                     │  LEDs   │         │  WiFi    │
                     └─────────┘         │  Servos  │
                                         │  etc.    │
                                         └──────────┘
```

### Pines de Conexión

#### Mouse PS/2 → FPGA
- **ps2_clk**: Reloj PS/2 (bidireccional, requiere pull-up)
- **ps2_data**: Datos PS/2 (bidireccional, requiere pull-up)
- **VCC**: 5V
- **GND**: Tierra

#### FPGA → PC (UART)
- **uart_txd**: Transmisión de datos (FPGA → PC)
- **uart_rxd**: Recepción de datos (PC → FPGA, no usado actualmente)
- **GND**: Tierra común

#### LEDs de Depuración
- **led[0]**: Inicialización PS/2 completa
- **led[1]**: Paquete PS/2 recibido
- **led[2]**: UART transmitiendo
- **led[3]**: Error de paridad PS/2

---

## 📦 Protocolo de Comunicación UART

### Formato del Paquete (6 bytes)

Cada movimiento del mouse se transmite como un paquete de 6 bytes:

| Byte | Contenido | Descripción |
|------|-----------|-------------|
| 0 | `0xAA` | Byte de sincronización (inicio de paquete) |
| 1 | `X[7:0]` | 8 bits bajos de posición X |
| 2 | `{7'b0, X[8]}` | Bit de signo de X (bit 0) |
| 3 | `Y[7:0]` | 8 bits bajos de posición Y |
| 4 | `{7'b0, Y[8]}` | Bit de signo de Y (bit 0) |
| 5 | `{5'b0, buttons[2:0]}` | Botones: [Middle, Right, Left] |

### Ejemplo de Paquete

**Movimiento: X=+10, Y=-5, Botón izquierdo presionado**

```
Byte 0: 0xAA  (sincronización)
Byte 1: 0x0A  (X bajo = 10)
Byte 2: 0x00  (X alto = 0, positivo)
Byte 3: 0xFB  (Y bajo = 251 en complemento a 2)
Byte 4: 0x01  (Y alto = 1, negativo)
Byte 5: 0x01  (botón izquierdo = bit 0)
```

### Decodificación de Posición

**Reconstrucción de valores de 9 bits:**
```verilog
X[8:0] = {Byte2[0], Byte1[7:0]}
Y[8:0] = {Byte4[0], Byte3[7:0]}
```

**Conversión a complemento a 2:**
```python
if X & 0x100:  # Si bit de signo activo
    X = X - 512  # Convertir a negativo
```

### Decodificación de Botones

Byte 5 contiene el estado de los botones:
- **Bit 0**: Botón izquierdo (1 = presionado)
- **Bit 1**: Botón derecho (1 = presionado)
- **Bit 2**: Botón medio (1 = presionado)

---

## 🚀 Uso del Sistema

### 1. Síntesis en la FPGA

#### Con Gowin IDE:
1. Crear nuevo proyecto para Tang Primer 25K
2. Agregar archivos:
   - `ps2_mouse_to_uart.v`
   - `ps2_mouse_init.v` (de `Proyecto_Paint/Conexion_PS2/`)
   - `uart.v` (de `Calculadora/modulos/uart/`)
3. Configurar pines en el constraint file (`.cst`):
   ```
   IO_LOC "ps2_clk" <pin>;
   IO_LOC "ps2_data" <pin>;
   IO_LOC "uart_txd" <pin>;
   IO_LOC "led[0]" <pin>;
   IO_LOC "led[1]" <pin>;
   IO_LOC "led[2]" <pin>;
   IO_LOC "led[3]" <pin>;
   ```
4. Compilar y programar la FPGA

### 2. Recepción de Datos en PC

#### Instalación de dependencias:
```bash
pip3 install pyserial
```

#### Ejecución del programa:
```bash
# Linux
python3 uart_mouse_receiver.py /dev/ttyUSB0

# Windows
python3 uart_mouse_receiver.py COM3

# macOS
python3 uart_mouse_receiver.py /dev/tty.usbserial-*
```

#### Salida esperada:
```
✓ Conectado a /dev/ttyUSB0 @ 115200 baud

╔═══════════════════════════════════════════════════════╗
║        RECEPTOR UART - MOUSE PS/2                    ║
╠═══════════════════════════════════════════════════════╣
║  Esperando datos del mouse...                        ║
║  Presiona Ctrl+C para salir                          ║
╚═══════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════╗
║  Paquete #1                                          ║
╠═══════════════════════════════════════════════════════╣
║  Posición X:   10 →                                  ║
║  Posición Y:   -5 ↓                                  ║
╠═══════════════════════════════════════════════════════╣
║  Botones:                                            ║
║    Izquierdo:  ■                                     ║
║    Derecho:    □                                     ║
║    Medio:      □                                     ║
╠═══════════════════════════════════════════════════════╣
║  Datos raw: 0A 00 FB 01 01                           ║
╚═══════════════════════════════════════════════════════╝
```

---

### 3. Recepción de Datos en ESP32 (Recomendado)

**La ESP32 es la opción recomendada** ya que permite:
- ✅ No necesita PC - sistema autónomo
- ✅ WiFi integrado para enviar datos remotamente
- ✅ Bluetooth disponible
- ✅ Control directo de servos, LEDs, relays, etc.
- ✅ Bajo consumo
- ✅ Programación sencilla con Arduino IDE

#### Conexión FPGA → ESP32:

| FPGA Pin | ESP32 Pin | Función |
|----------|-----------|---------|
| UART TX  | GPIO 16 (RX2) | Datos |
| GND      | GND       | Tierra común |

#### Instalación en Arduino IDE:

1. **Instalar soporte para ESP32:**
   - Arduino IDE → File → Preferences
   - En "Additional Board Manager URLs" agregar:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   - Tools → Board → Boards Manager
   - Buscar "esp32" e instalar

2. **Abrir programa:**
   ```
   Archivo → Abrir → PS2_Mouse_UART_ESP32/PS2_Mouse_UART_ESP32.ino
   ```

3. **Configurar:**
   - Tools → Board → ESP32 Dev Module
   - Tools → Port → Seleccionar puerto COM

4. **Subir programa:**
   - Click en "Upload"
   - Abrir Serial Monitor (115200 baud)

#### Ejemplos Incluidos:

**Programa Principal:** `PS2_Mouse_UART_ESP32.ino`
- Monitor serial con formato visual
- Cursor virtual acumulativo
- Detección de clicks
- Estadísticas del sistema

**Servidor WiFi:** `examples/WiFi_Mouse_Server/`
- Dashboard web en tiempo real
- WebSocket para comunicación
- Canvas de dibujo interactivo
- Visualización de posición y botones
- Acceso desde cualquier navegador

**Control de Servos:** `examples/Servo_Control/`
- Control pan/tilt con el mouse
- Botón izquierdo: reset a centro
- Botón medio: mostrar posición
- Sensibilidad ajustable

Ver `PS2_Mouse_UART_ESP32/README.md` para más detalles.

---

## 🧪 Simulación

### Compilación del testbench:
```bash
iverilog -o ps2_uart_sim.vvp \
    ps2_mouse_to_uart_tb.v \
    ps2_mouse_to_uart.v \
    Proyecto_Paint/Conexion_PS2/ps2_mouse_init.v \
    Calculadora/modulos/uart/uart.v
```

### Ejecución de la simulación:
```bash
vvp ps2_uart_sim.vvp
```

### Visualización de formas de onda:
```bash
gtkwave ps2_mouse_to_uart_tb.vcd &
```

#### Señales recomendadas en GTKWave:
- **Sistema**: `clk`, `rst_n`, `init_done`
- **PS/2**: `ps2_clk`, `ps2_data`, `dut.packet_ready`
- **Mouse**: `dut.mouse_x[8:0]`, `dut.mouse_y[8:0]`, `dut.buttons[2:0]`
- **UART**: `uart_txd`, `dut.uart_tx_busy`, `dut.uart_state[2:0]`
- **Debug**: `led[3:0]`

---

## 📊 Parámetros Configurables

### En el módulo `ps2_mouse_to_uart.v`:

```verilog
ps2_mouse_to_uart #(
    .FREQ_HZ(27000000),    // Frecuencia del reloj (27 MHz)
    .BAUD(115200)          // Velocidad UART
) inst (
    // ... conexiones ...
);
```

**Velocidades UART soportadas:**
- 9600 baud
- 19200 baud
- 38400 baud
- 57600 baud
- **115200 baud** (recomendado)
- 230400 baud

---

## 🔧 Solución de Problemas

### Problema: No se reciben datos en la PC

**Verificaciones:**
1. ✓ Verificar que `led[0]` esté encendido (inicialización completa)
2. ✓ Verificar que `led[1]` parpadee al mover el mouse
3. ✓ Comprobar conexiones UART (TX, GND)
4. ✓ Verificar puerto serial correcto
5. ✓ Verificar baudrate (115200)

### Problema: Datos corruptos

**Posibles causas:**
1. Baudrate incorrecto → Verificar parámetro `BAUD`
2. Frecuencia del reloj incorrecta → Verificar parámetro `FREQ_HZ`
3. Ruido en la línea UART → Agregar capacitor de desacople

### Problema: Mouse PS/2 no inicializa

**Verificaciones:**
1. ✓ Resistencias pull-up en `ps2_clk` y `ps2_data` (10kΩ)
2. ✓ Alimentación correcta del mouse (5V)
3. ✓ Ver `README_PS2.md` para detalles del protocolo PS/2

### Problema: led[3] encendido (error de paridad)

**Solución:**
1. Verificar integridad de las conexiones PS/2
2. Verificar que las resistencias pull-up estén presentes
3. Reducir longitud de cables PS/2
4. Verificar que el mouse esté funcionando correctamente

---

## 📈 Rendimiento

### Latencia:
- **PS/2 a registro interno**: ~10-16 KHz (frecuencia PS/2)
- **Transmisión UART (6 bytes)**: ~520 μs @ 115200 baud
- **Latencia total**: < 1 ms

### Tasa de actualización:
- **Máxima del mouse PS/2**: ~100 paquetes/seg
- **Limitada por UART**: ~190 paquetes/seg (6 bytes @ 115200)
- **Efectiva**: ~100 paquetes/seg

---

## 🔄 Diagrama de Estados

### Máquina de estados del módulo UART:

```
     ┌──────────┐
     │   IDLE   │
     └────┬─────┘
          │ packet_ready
          ▼
     ┌──────────┐
     │SEND_SYNC │ ──► Envía 0xAA
     └────┬─────┘
          ▼
     ┌──────────┐
     │ SEND_XL  │ ──► Envía X[7:0]
     └────┬─────┘
          ▼
     ┌──────────┐
     │ SEND_XH  │ ──► Envía X[8]
     └────┬─────┘
          ▼
     ┌──────────┐
     │ SEND_YL  │ ──► Envía Y[7:0]
     └────┬─────┘
          ▼
     ┌──────────┐
     │ SEND_YH  │ ──► Envía Y[8]
     └────┬─────┘
          ▼
     ┌──────────┐
     │SEND_BTN  │ ──► Envía buttons
     └────┬─────┘
          ▼
     ┌──────────┐
     │   WAIT   │ ──► Pequeño delay
     └────┬─────┘
          │
          └──────────► IDLE
```

---

## 📚 Referencias

### Protocolo PS/2:
- Ver `README_PS2.md` para documentación completa del protocolo
- [PS/2 Protocol - Adam Chapweske](http://www.burtonsys.com/ps2_chapweske.htm)

### UART:
- 8 bits de datos, sin paridad, 1 bit de stop (8N1)
- LSB primero

---

## 🛠️ Mejoras Futuras

### Posibles extensiones:
- [ ] Agregar recepción UART para configuración
- [ ] Implementar modo de bajo consumo
- [ ] Agregar buffer FIFO para paquetes
- [ ] Soporte para mouse con rueda (wheel)
- [ ] Interfaz USB adicional
- [ ] Modo de alta resolución

---

## 📝 Ejemplo de Uso en Aplicación

### Integración en Python (código adicional):

```python
import serial

class MouseController:
    def __init__(self, port):
        self.receiver = PS2MouseUARTReceiver(port)
        self.x_pos = 0
        self.y_pos = 0

    def update(self):
        packet = self.receiver.read_packet()
        if packet:
            # Acumular posición
            self.x_pos += packet['x']
            self.y_pos += packet['y']

            # Limitar a rango de pantalla
            self.x_pos = max(0, min(1920, self.x_pos))
            self.y_pos = max(0, min(1080, self.y_pos))

            return {
                'x': self.x_pos,
                'y': self.y_pos,
                'buttons': {
                    'left': packet['left'],
                    'right': packet['right'],
                    'middle': packet['middle']
                }
            }
        return None
```

---

## 📄 Licencia

Este proyecto es de código abierto y puede ser usado libremente para fines educativos y comerciales.

---

## ✉️ Contacto

Para preguntas o problemas:
1. Revisar esta documentación
2. Consultar `README_PS2.md` para detalles del protocolo PS/2
3. Verificar conexiones de hardware
4. Revisar simulación en GTKWave

---

**Versión:** 1.0
**Fecha:** Diciembre 2025
**Autor:** Digital_P Project
