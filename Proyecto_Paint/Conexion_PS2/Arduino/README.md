# Sistema de Mouse PS/2 para ESP32 + FPGA

Sistema completo para leer un mouse PS/2 con ESP32/Arduino y enviar los datos a una FPGA.

## 📋 Componentes

1. **ps2_mouse_to_fpga.ino**: Código Arduino/ESP32
2. **ps2_mouse_receiver.v**: Módulos Verilog para FPGA
3. **mouse_constraints.cst**: Archivo de constraints para Tang Primer 25K

## 🔌 Conexiones Hardware

### Mouse PS/2 → ESP32

```
Mouse PS/2         ESP32
───────────       ────────
CLK (pin 5)   →   GPIO 18
DATA (pin 1)  →   GPIO 19
VCC (pin 4)   →   3.3V
GND (pin 3)   →   GND
```

**Nota**: Usar resistencias pull-up de 10kΩ en CLK y DATA si el mouse no las tiene internas.

### ESP32 → FPGA

```
ESP32              FPGA
────────          ─────────
GPIO 17 (TX2) →   uart_rx
GND           →   GND
```

## 🚀 Uso del Código Arduino

### 1. Configuración

El código está configurado para:
- **PS/2 CLK**: GPIO 18
- **PS/2 DATA**: GPIO 19
- **UART a FPGA**: GPIO 17 (Serial2 TX)
- **Baud rate**: 115200

### 2. Funcionalidades

#### Inicialización del Mouse
```cpp
bool ps2_mouse_init()
```
- Envía comando RESET (0xFF)
- Verifica respuesta BAT (Basic Assurance Test)
- Habilita reporte de datos (0xF4)

#### Lectura de Datos
- Interrupción en flanco de bajada del CLK
- Lee 11 bits por frame: 1 start + 8 data + 1 parity + 1 stop
- Buffer de 3 bytes para paquete completo del mouse

#### Verificación de Tramas
```cpp
bool verify_ps2_frame(uint32_t frame)
```
Verifica:
- Start bit = 0
- Stop bit = 1
- Paridad impar (correcta)

#### Parseo de Paquetes
```cpp
bool parse_mouse_packet(uint8_t* packet)
```

**Formato del paquete PS/2 (3 bytes):**

```
Byte 0: [Y ovf][X ovf][Y sign][X sign][1][Middle][Right][Left]
Byte 1: X Movement (8 bits)
Byte 2: Y Movement (8 bits)
```

### 3. Protocolo de Comunicación a FPGA

**Formato del paquete UART (5 bytes @ 115200 baud):**

```
Byte 0: 0xFF          - Marcador de inicio
Byte 1: [0][0][0][0][0][M][R][L] - Estado de botones
Byte 2: X Movement    - Movimiento X (complemento a 2)
Byte 3: Y Movement    - Movimiento Y (complemento a 2)
Byte 4: Checksum      - XOR de bytes 1-3
```

**Botones:**
- Bit 0: Left button
- Bit 1: Right button
- Bit 2: Middle button

**Movimiento:**
- Formato: Signed 8-bit (complemento a 2)
- Rango: -128 a +127
- Valores positivos: derecha/arriba
- Valores negativos: izquierda/abajo

## 🔧 Código Verilog

### 1. Módulo Principal: ps2_mouse_receiver

```verilog
module ps2_mouse_receiver (
    input wire clk,           // 27 MHz
    input wire rst_n,
    input wire uart_rx,
    
    output reg [7:0] mouse_x,
    output reg [7:0] mouse_y,
    output reg mouse_left,
    output reg mouse_right,
    output reg mouse_middle,
    output reg data_valid,
    output reg error_flag
);
```

**Características:**
- Receptor UART a 115200 baud
- Sincronización de entrada (2 FF)
- Verificación de checksum
- Pulso `data_valid` cuando hay datos nuevos
- Flag de error si checksum falla

### 2. Módulo Integrador: mouse_position_integrator

```verilog
module mouse_position_integrator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] mouse_dx,
    input wire [7:0] mouse_dy,
    input wire data_valid,
    output reg [15:0] pos_x,
    output reg [15:0] pos_y,
    input wire [15:0] max_x,
    input wire [15:0] max_y
);
```

**Funcionalidad:**
- Integra movimientos delta del mouse
- Mantiene posición absoluta X,Y
- Limita coordenadas a rango definido
- Maneja valores con signo correctamente

### 3. Top Module: mouse_top

Módulo de ejemplo que instancia:
- Receptor UART
- Integrador de posición
- LEDs de debug

**LEDs de Debug:**
- LED[0]: Botón izquierdo
- LED[1]: Botón derecho
- LED[2]: Botón medio
- LED[3]: Data valid (parpadea al recibir datos)
- LED[4]: Error flag
- LED[5]: Estado UART RX

## 📊 Ejemplo de Uso en FPGA

### Integración Básica

```verilog
// Instanciar receptor
wire [7:0] mouse_x, mouse_y;
wire mouse_left, mouse_right, mouse_middle;
wire data_valid;

ps2_mouse_receiver receiver (
    .clk(clk_27mhz),
    .rst_n(rst_n),
    .uart_rx(uart_rx_pin),
    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_left(mouse_left),
    .mouse_right(mouse_right),
    .mouse_middle(mouse_middle),
    .data_valid(data_valid),
    .error_flag()
);

// Usar los datos
always @(posedge clk_27mhz) begin
    if (data_valid) begin
        // mouse_x y mouse_y contienen los deltas de movimiento
        // mouse_left/right/middle son los estados de botones
        
        // Tu lógica aquí...
    end
end
```

### Con Integrador de Posición

```verilog
wire [15:0] cursor_x, cursor_y;

mouse_position_integrator integrator (
    .clk(clk_27mhz),
    .rst_n(rst_n),
    .mouse_dx(mouse_x),
    .mouse_dy(mouse_y),
    .data_valid(data_valid),
    .pos_x(cursor_x),      // Posición absoluta X
    .pos_y(cursor_y),      // Posición absoluta Y
    .max_x(16'd639),       // Límite horizontal
    .max_y(16'd479)        // Límite vertical
);

// Usar cursor_x y cursor_y para dibujar cursor en pantalla
```

## 🐛 Debugging

### Monitor Serial (ESP32)

El código envía información de debug por Serial (115200):

```
Inicializando mouse PS/2...
Mouse PS/2 inicializado correctamente
Device ID: 0x00
X: 5    Y: -3   L: 0    R: 0    M: 0
X: 12   Y: 0    L: 1    R: 0    M: 0
```

### LEDs (FPGA)

Observar los LEDs para verificar:
- **LED[3]** debe parpadear al mover el mouse
- **LED[0-2]** deben encender al presionar botones
- **LED[4]** indica errores de checksum
- **LED[5]** refleja la línea UART RX

### Problemas Comunes

1. **Mouse no inicializa**
   - Verificar conexiones CLK y DATA
   - Verificar resistencias pull-up (10kΩ)
   - Probar con otro mouse PS/2

2. **Datos erróneos en FPGA**
   - Verificar baud rate (115200)
   - Verificar conexión UART GND común
   - Revisar LED[4] para errores de checksum

3. **Mouse se detiene después de un tiempo**
   - Verificar alimentación (3.3V estable)
   - Revisar Serial Monitor para mensajes de error

## 📝 Notas Técnicas

### Protocolo PS/2

- **Clock**: Generado por el dispositivo (mouse)
- **Frecuencia**: 10-16.7 kHz típico
- **Frame**: 11 bits (start, 8 data, parity, stop)
- **Paridad**: Impar (odd parity)

### Timing PS/2

- Clock low: mínimo 30 μs
- Clock high: mínimo 30 μs
- Data setup: 5 μs antes de clock falling edge
- Data hold: 5 μs después de clock falling edge

### Comandos PS/2 Mouse

```
0xFF - Reset
0xF6 - Set Defaults
0xF5 - Disable Data Reporting
0xF4 - Enable Data Reporting
0xF3 - Set Sample Rate
0xF2 - Read Device Type
0xE8 - Set Resolution
```

### Respuestas del Mouse

```
0xFA - Acknowledge
0xFE - Resend
0xAA - BAT Complete
0x00 - Device ID (standard mouse)
```

## 🔄 Extensiones Posibles

1. **Mouse con scroll wheel**: Agregar soporte para 4 bytes por paquete
2. **Mayor resolución**: Implementar protocolo extendido
3. **Aceleración**: Aplicar curva de aceleración al movimiento
4. **Filtrado**: Agregar filtro digital para suavizar movimiento
5. **Calibración**: Auto-calibración de sensibilidad

## 📚 Referencias

- [PS/2 Mouse Protocol](http://www.computer-engineering.org/ps2mouse/)
- [PS/2 Keyboard/Mouse Interface](https://wiki.osdev.org/PS/2_Mouse)
- [Tang Primer 25K Documentation](https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html)

## 📄 Licencia

Código de ejemplo para uso educativo y proyectos personales.
