# Módulos MIT PS/2 Mouse - Análisis Técnico Detallado

## Índice
1. [Visión General](#visión-general)
2. [mit_ps2_mouse_interface.v - Análisis Profundo](#mit_ps2_mouse_interfacev)
3. [mit_ps2_mouse_xy.v - Análisis Profundo](#mit_ps2_mouse_xyv)
4. [Protocolo PS/2 - Detalles de Implementación](#protocolo-ps2)
5. [Adaptación para 27MHz](#adaptación-para-27mhz)
6. [Preguntas Frecuentes del Profesor](#preguntas-frecuentes)

---

## Visión General

Los módulos del MIT implementan un **controlador de mouse PS/2 completo** dividido en dos niveles de abstracción:

```
┌─────────────────────────────────────────────────┐
│  mit_ps2_mouse_xy.v (Alto nivel)                │
│  - Mantiene posición absoluta (x, y)            │
│  - Saturación en bordes                         │
│  - Interfaz simplificada                        │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  mit_ps2_mouse_interface.v (Bajo nivel)         │
│  - Protocolo PS/2 completo                      │
│  - 3 State Machines concurrentes                │
│  - Debouncing de señales                        │
│  - Inicialización automática                    │
└─────────────────────────────────────────────────┘
```

**Origen:** MIT 6.111 - Introduction to Digital Systems
**Diseño original:** 50 MHz clock
**Adaptación:** 27 MHz para Tang Primer 25K

---

## mit_ps2_mouse_interface.v

### Arquitectura General

Este módulo implementa la capa física y de enlace del protocolo PS/2. Es un **HOST** que controla un mouse PS/2.

#### Puertos y Señales

```verilog
module ps2_mouse_interface (
  // Sistema
  input  clk,              // 27 MHz (adaptado de 50 MHz)
  input  reset,            // Reset síncrono activo alto

  // Bus PS/2 (bidireccional)
  inout  ps2_clk,          // Open-collector, pull-up externo
  inout  ps2_data,         // Open-collector, pull-up externo

  // Datos del mouse (salidas)
  output left_button,      // Estado botón izquierdo
  output right_button,     // Estado botón derecho
  output [8:0] x_increment,// Delta X con signo (2's complement)
  output [8:0] y_increment,// Delta Y con signo (2's complement)

  // Control de flujo
  output data_ready,       // Pulso: datos válidos disponibles
  input  read,             // Handshake: datos leídos (típicamente '1')

  // Estado
  output error_no_ack      // Error: mouse no respondió ACK
);
```

#### Parámetros Configurables

```verilog
// Para 50 MHz (original):
parameter WATCHDOG_TIMER_VALUE_PP = 19660;  // 400 μs
parameter WATCHDOG_TIMER_BITS_PP  = 15;
parameter DEBOUNCE_TIMER_VALUE_PP = 186;    // 3.7 μs
parameter DEBOUNCE_TIMER_BITS_PP  = 8;

// Para 27 MHz (adaptado):
parameter WATCHDOG_TIMER_VALUE_PP = 10800;  // 400 μs
parameter WATCHDOG_TIMER_BITS_PP  = 14;
parameter DEBOUNCE_TIMER_VALUE_PP = 100;    // 3.7 μs
parameter DEBOUNCE_TIMER_BITS_PP  = 7;
```

**Cálculo de parámetros:**
```
WATCHDOG_VALUE = tiempo_deseado / período_clock
               = 400 μs / (1/27MHz)
               = 400 μs / 37.04 ns
               = 10800 ciclos

BITS_NECESARIOS = ceil(log₂(10800)) = 14 bits
```

---

### State Machine M1: Clock Debouncing

**Propósito:** Eliminar ruido y rebotes en la señal ps2_clk, generando edges limpios.

#### Diagrama de Estados

```
      ┌─────────────┐
      │  m1_clk_h   │ ps2_clk = 1
      │   (state 0) │ clean_clk = 1
      └──────┬──────┘
             │ ps2_clk = 0
             ▼
      ┌─────────────┐
      │m1_falling_  │ falling_edge = 1
      │edge (state 1)│ (1 ciclo)
      └──────┬──────┘
             │
             ▼
      ┌─────────────┐
      │m1_falling_  │ Espera debounce
      │wait (state 3)│ (100 ciclos @ 27MHz)
      └──────┬──────┘
             │ debounce_timer_done
             ▼
      ┌─────────────┐
      │  m1_clk_l   │ ps2_clk = 0
      │   (state 2) │ clean_clk = 0
      └──────┬──────┘
             │ ps2_clk = 1
             ▼
      ┌─────────────┐
      │ m1_rising_  │ rising_edge = 1
      │edge (state 6)│ (1 ciclo)
      └──────┬──────┘
             │
             ▼
      ┌─────────────┐
      │ m1_rising_  │ Espera debounce
      │wait (state 4)│ (100 ciclos)
      └──────┬──────┘
             │ debounce_timer_done
             └──────► m1_clk_h
```

#### Salidas de M1

| Señal | Descripción |
|-------|-------------|
| `clean_clk` | Versión filtrada de ps2_clk |
| `falling_edge` | Pulso de 1 ciclo en bajada de CLK |
| `rising_edge` | Pulso de 1 ciclo en subida de CLK |

**Código clave:**
```verilog
// Debounce timer (reinicia en cada edge)
always @(posedge clk) begin
  if (reset || falling_edge || rising_edge)
    debounce_timer_count <= 0;
  else
    debounce_timer_count <= debounce_timer_count + 1;
end

assign debounce_timer_done =
  (debounce_timer_count == DEBOUNCE_TIMER_VALUE_PP - 1);
```

---

### State Machine M2: Protocol Handler

**Propósito:** Implementar el protocolo PS/2 completo (inicialización y recepción de datos).

#### Diagrama de Estados Completo

```
              RESET
                │
                ▼
         ┌────────────┐
         │  m2_reset  │ Estado inicial
         │  (state 14)│
         └──────┬─────┘
                │
                ▼
         ┌────────────┐
         │m2_hold_clk_│ Inhibir CLK (>100μs)
         │l (state 6) │ Preparar comando 0xF4
         └──────┬─────┘
                │ watchdog_timer_done && !clean_clk
                ▼
         ┌────────────┐
         │m2_data_low_│ Enviar Start + d[0] + d[1]
         │1 (state 4) │ DATA = 0
         └──────┬─────┘
                │ bit_count = 3
                ▼
         ┌────────────┐
         │m2_data_high│ Enviar d[2]
         │1 (state 5) │ DATA = 1
         └──────┬─────┘
                │ bit_count = 4
                ▼
         ┌────────────┐
         │m2_data_low_│ Enviar d[3]
         │2 (state 7) │ DATA = 0
         └──────┬─────┘
                │ bit_count = 5
                ▼
         ┌────────────┐
         │m2_data_high│ Enviar d[4..7]
         │2 (state 8) │ DATA = 1
         └──────┬─────┘
                │ bit_count = 9
                ▼
         ┌────────────┐
         │m2_data_low_│ Enviar Parity
         │3 (state 9) │ DATA = 0
         └──────┬─────┘
                │
                ▼
         ┌────────────┐
         │m2_data_high│ Stop bit + espera ACK
         │3 (state 11)│ Mouse debe bajar DATA
         └──────┬─────┘
                │ falling_edge
       ┌────────┴────────┐
       │ ps2_data = 0?   │
       ├─NO───────────YES┤
       ▼                 ▼
┌────────────┐    ┌────────────┐
│m2_error_no_│    │m2_await_   │ Esperar respuesta
│ack (st. 15)│    │response(10)│ del mouse (0xFA)
└────────────┘    └──────┬─────┘
                         │ bit_count = 22
                         ▼
                  ┌────────────┐
                  │  m2_wait   │ Esperar datos
                  │  (state 0) │ del mouse
                  └──────┬─────┘
                         │ falling_edge
                         ▼
                  ┌────────────┐
                  │ m2_gather  │ Recibir paquete
                  │ (state 1)  │ (3 bytes = 33 bits)
                  └──────┬─────┘
                         │ bit_count = 33
                         ▼
                  ┌────────────┐
                  │ m2_verify  │ Verificar framing
                  │ (state 3)  │ y paridad
                  └──────┬─────┘
                         │ packet_good
                         ▼
                  ┌────────────┐
                  │  m2_use    │ Datos válidos
                  │ (state 2)  │ output_strobe = 1
                  └──────┬─────┘
                         │
                         └──────► m2_wait
```

#### Secuencia de Comando 0xF4 (Enable Data Reporting)

El módulo codifica 0xF4 = 11110100 de forma especial:

```
Bit sequence en ps2_data:
  Start: 0
  d[0]:  0  ┐
  d[1]:  0  │ m2_data_low_1
  d[2]:  1  ← m2_data_high_1
  d[3]:  0  ← m2_data_low_2
  d[4]:  1  ┐
  d[5]:  1  │
  d[6]:  1  │ m2_data_high_2
  d[7]:  1  ┘
  Parity:0  ← m2_data_low_3
  Stop:  1  ← m2_data_high_3

Resultado: 0 00101111 0 1 = 0xF4 con framing
```

**Por qué esta codificación:**
- Reduce complejidad de hardware
- Cada estado controla múltiples bits
- 0xF4 = "00101111" en binario (LSB first en PS/2)

#### Contador de Bits

```verilog
// Incrementa en cada falling edge
always @(posedge clk) begin
  if (reset)
    bit_count <= 0;
  else if (falling_edge)
    bit_count <= bit_count + 1;
  else if (watchdog_timer_done)
    bit_count <= 0;  // Reset si timeout
end
```

**Puntos críticos:**
- bit_count = 11: Comando enviado
- bit_count = 22: Respuesta ACK recibida
- bit_count = 33: Paquete completo recibido

---

### State Machine M3: Data Ready Handshake

**Propósito:** Controlar la señal data_ready con handshake.

```
┌──────────────────┐
│m3_data_ready_ack │ data_ready = 0
│    (state 0)     │ Esperando datos
└─────────┬────────┘
          │ output_strobe
          ▼
┌──────────────────┐
│  m3_data_ready   │ data_ready = 1
│    (state 1)     │ Datos válidos
└─────────┬────────┘
          │ read = 1
          └─────────► m3_data_ready_ack
```

**Protocolo:**
1. M2 genera `output_strobe` cuando packet_good
2. M3 eleva `data_ready`
3. Usuario debe poner `read = 1` para ACK
4. M3 baja `data_ready`

En modo auto-read (`read = 1` constante), M3 solo genera un pulso.

---

### Shift Register y Packet Verification

#### Shift Register de 33 bits

```verilog
reg [32:0] q;  // 3 bytes × 11 bits/byte

always @(posedge clk) begin
  if (reset)
    q <= 0;
  else if (falling_edge)
    q <= {ps2_data, q[32:1]};  // Shift right, LSB first
end
```

**Contenido después de 33 bits:**
```
q[32:23] = Byte 3: Start(0) + Y[7:0] + Parity + Stop(1)
q[22:12] = Byte 2: Start(0) + X[7:0] + Parity + Stop(1)
q[11:0]  = Byte 1: Start(0) + Status[7:0] + Parity + Stop(1)
```

#### Verificación de Paquete

```verilog
assign packet_good = (
  // Start bits (deben ser 0)
  (q[0]  == 0) && (q[11] == 0) && (q[22] == 0) &&

  // Stop bits (deben ser 1)
  (q[10] == 1) && (q[21] == 1) && (q[32] == 1) &&

  // Paridad impar para cada byte
  (q[9]  == ~^q[8:1])   &&  // Byte 1
  (q[20] == ~^q[19:12]) &&  // Byte 2
  (q[31] == ~^q[30:23])     // Byte 3
);
```

**Operador ~^:** XOR reducido negado (paridad impar)
- `^q[8:1]`: XOR de todos los bits de datos
- `~^q[8:1]`: Complemento = paridad impar esperada

---

### Output Logic: Decodificación de Datos

```verilog
always @(posedge clk) begin
  if (reset) begin
    left_button  <= 0;
    right_button <= 0;
    x_increment  <= 0;
    y_increment  <= 0;
  end
  else if (output_strobe) begin
    left_button  <= q[1];           // Bit 0 del status byte
    right_button <= q[2];           // Bit 1 del status byte
    x_increment  <= {q[5], q[19:12]}; // Sign + 8 bits
    y_increment  <= {q[6], q[30:23]}; // Sign + 8 bits
  end
end
```

**Mapeo de bits:**

| Campo | Bits en q | Descripción |
|-------|-----------|-------------|
| Left Button | q[1] | Status byte bit 0 |
| Right Button | q[2] | Status byte bit 1 |
| X Sign | q[5] | Status byte bit 4 |
| X Data | q[19:12] | Byte 2 completo |
| Y Sign | q[6] | Status byte bit 5 |
| Y Data | q[30:23] | Byte 3 completo |

**Formato de incrementos:**
- bit[8]: Signo (1 = negativo)
- bit[7:0]: Magnitud
- Representación: Complemento a 2 de 9 bits

---

### Watchdog Timer

```verilog
always @(posedge clk) begin
  if (reset || rising_edge || falling_edge)
    watchdog_timer_count <= 0;
  else if (~watchdog_timer_done)
    watchdog_timer_count <= watchdog_timer_count + 1;
end

assign watchdog_timer_done =
  (watchdog_timer_count == WATCHDOG_TIMER_VALUE_PP - 1);
```

**Propósito:**
- Detectar pérdida de comunicación (400 μs sin actividad)
- Reiniciar bit_count si timeout
- Forzar reinicialización si el mouse no responde

---

## mit_ps2_mouse_xy.v

### Arquitectura General

Wrapper de alto nivel que:
1. Instancia `ps2_mouse_interface`
2. Acumula deltas en posición absoluta
3. Aplica saturación en bordes
4. Invierte eje Y para uso con displays

#### Puertos

```verilog
module ps2_mouse_xy(
  input  clk,
  input  reset,
  inout  ps2_clk,
  inout  ps2_data,
  output [11:0] mx, my,    // Posición absoluta 12 bits
  output [2:0]  btn_click  // [Left, Middle, Right]
);

parameter MAX_X = 1023;  // Resolución horizontal - 1
parameter MAX_Y = 767;   // Resolución vertical - 1
```

### Instanciación del Interface

```verilog
wire [8:0] dx, dy;
wire [2:0] btn_click;
wire data_ready;

ps2_mouse_interface #(
  .WATCHDOG_TIMER_VALUE_PP(26000),  // Ajustado para 65MHz
  .WATCHDOG_TIMER_BITS_PP(15),
  .DEBOUNCE_TIMER_VALUE_PP(246),
  .DEBOUNCE_TIMER_BITS_PP(8)
) m1 (
  .clk(clk),
  .reset(reset),
  .ps2_clk(ps2_clk),
  .ps2_data(ps2_data),
  .x_increment(dx),
  .y_increment(dy),
  .data_ready(data_ready),
  .read(1'b1),  // Auto-read
  .left_button(btn_click[2]),
  .right_button(btn_click[0])
);
```

**Nota:** Parámetros para ~65MHz en el código original. Para 27MHz usar los valores adaptados (10800/100).

### Acumulador de Posición

```verilog
reg [11:0] mx, my;

// Extraer signo y magnitud
wire sx = dx[8];                       // 1 = negativo
wire sy = dy[8];
wire [8:0] ndx = sx ? {0,~dx[7:0]}+1 : {0,dx[7:0]};  // Valor absoluto
wire [8:0] ndy = sy ? {0,~dy[7:0]}+1 : {0,dy[7:0]};

always @(posedge clk) begin
  // Movimiento en X
  mx <= reset ? 0 :
        data_ready ? (sx ? (mx > ndx ? mx - ndx : 0)         // Negativo
                         : (mx < MAX_X - ndx ? mx + ndx : MAX_X)) // Positivo
                   : mx;

  // Movimiento en Y (INVERTIDO para video)
  my <= reset ? 0 :
        data_ready ? (sy ? (my < MAX_Y - ndy ? my + ndy : MAX_Y)  // Negativo → abajo
                         : (my > ndy ? my - ndy : 0))             // Positivo → arriba
                   : my;
end
```

**Lógica de saturación:**
- Si movimiento negativo y posición > magnitud: resta
- Si movimiento negativo y posición < magnitud: satura a 0
- Si movimiento positivo y hay espacio: suma
- Si movimiento positivo y no hay espacio: satura a MAX

**Inversión de Y:**
- PS/2 Y positivo = arriba
- Video Y positivo = abajo
- Solución: invertir sentido del delta

---

## Protocolo PS/2

### Frame de Datos

```
Bit  │ 0 │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │
─────┼───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┤
     │St │D0 │D1 │D2 │D3 │D4 │D5 │D6 │D7 │Par│Sp │
     └───────────────────────────────────────────┘
       0  LSB                         MSB  Odd  1
```

### Paquete del Mouse (3 bytes)

**Byte 1: Status**
```
Bit │ 7 │ 6 │ 5 │ 4 │ 3 │ 2 │ 1 │ 0 │
────┼───┴───┴───┴───┴───┴───┴───┴───┤
    │YOv│XOv│YSg│XSg│ 1 │Mid│Rgt│Lft│
    └───────────────────────────────┘
```
- YOv, XOv: Overflow (movimiento > 255)
- YSg, XSg: Signo (1 = negativo)
- Bit 3: Siempre 1 (sincronización)

**Byte 2: X Movement (8 bits)**
**Byte 3: Y Movement (8 bits)**

### Timing del Protocolo

```
       ┌───────┐       ┌───────┐
CLK ───┘       └───────┘       └───
       ←──60μs──→
           ┌───────────┐
DATA ──────┘           └──────────
       Setup Hold
       5μs   5μs
```

- Frecuencia CLK: 10-16.7 kHz (típico ~15 kHz)
- Período: 60-100 μs
- Data setup: 5 μs antes de CLK↓
- Data hold: 5 μs después de CLK↓

### Comandos del Host

| Comando | Código | Función |
|---------|--------|---------|
| Reset | 0xFF | Reiniciar mouse |
| Enable Data Reporting | 0xF4 | Activar stream mode |
| Disable Data Reporting | 0xF5 | Desactivar stream mode |
| Set Sample Rate | 0xF3 | Configurar tasa de muestreo |
| Get Device ID | 0xF2 | Leer ID del dispositivo |

**El módulo MIT usa solo 0xF4.**

---

## Adaptación para 27MHz

### Tabla de Conversión

| Parámetro | 50 MHz | Tiempo | 27 MHz | Fórmula |
|-----------|--------|--------|--------|---------|
| Período CLK | 20 ns | - | 37.04 ns | 1/freq |
| Watchdog | 19660 | 400 μs | 10800 | 400μs / 37ns |
| Watchdog bits | 15 | - | 14 | log₂(10800) |
| Debounce | 186 | 3.7 μs | 100 | 3.7μs / 37ns |
| Debounce bits | 8 | - | 7 | log₂(100) |

### Instanciación para 27MHz

```verilog
ps2_mouse_interface #(
  .WATCHDOG_TIMER_VALUE_PP(10800),
  .WATCHDOG_TIMER_BITS_PP(14),
  .DEBOUNCE_TIMER_VALUE_PP(100),
  .DEBOUNCE_TIMER_BITS_PP(7)
) ps2_ctrl (
  .clk(clk_27mhz),
  // ... resto de puertos
);
```

### Recursos Estimados (GW5A-25)

| Recurso | Uso estimado | Observaciones |
|---------|--------------|---------------|
| LUTs | ~200-250 | 3 FSMs + contadores |
| FFs | ~80-100 | Registros de estado |
| Pines I/O | 2 | ps2_clk, ps2_data |
| Freq. máxima | >100 MHz | Diseño conservador |

---

## Preguntas Frecuentes del Profesor

### 1. ¿Por qué 3 state machines separadas?

**Respuesta:**
- **M1 (Debouncing):** Opera a nivel físico, necesita responder rápido a cambios en ps2_clk
- **M2 (Protocol):** Opera a nivel lógico, implementa el protocolo PS/2
- **M3 (Handshake):** Opera a nivel de aplicación, controla flujo de datos

**Ventajas:**
- Separación de responsabilidades
- M1 puede detectar edges mientras M2 procesa
- M3 independiente permite diferentes modos de lectura
- Más fácil de verificar y debuggear

### 2. ¿Por qué el watchdog timer es de 400 μs?

**Respuesta:**
El protocolo PS/2 especifica que:
- El host debe mantener CLK bajo por >100 μs para inhibir
- Cada bit dura ~60-80 μs
- Un frame completo (11 bits) dura ~660-880 μs

400 μs es suficiente para:
- Detectar que un frame se interrumpió (timeout)
- No tan largo que demore la recuperación de errores
- Reiniciar bit_count y volver a estado de espera

### 3. ¿Por qué debounce de 3.7 μs?

**Respuesta:**
- Ruido eléctrico típico dura <1 μs
- Rebotes mecánicos duran <5 μs en conectores PS/2
- 3.7 μs filtra ruido sin añadir latencia significativa
- Con 27 MHz: 100 ciclos = 3.7 μs
- Trade-off: más tiempo = más robusto pero más lento

### 4. ¿Cómo funciona el open-collector?

**Respuesta:**
PS/2 usa bus open-collector:

```verilog
assign ps2_clk = ps2_clk_hi_z ? 1'bz : 1'b0;
```

- 1'bz (Hi-Z): Pull-up externo lleva señal a '1'
- 1'b0: FPGA tira señal a '0' (activo bajo)
- Ambos dispositivos pueden controlar el bus sin cortocircuito
- Si uno pone '0', el bus queda en '0' (wired-AND)

### 5. ¿Por qué bit_count llega a 22 y no 11?

**Respuesta:**
La secuencia de inicialización es:
1. Host envía 0xF4 (11 bits): bit_count 0→11
2. Mouse responde ACK (11 bits): bit_count 11→22
3. En 22, el módulo verifica respuesta y pasa a stream mode

**No reinicia bit_count** entre comando y respuesta porque ambos son parte de la misma transacción.

### 6. ¿Qué pasa si packet_good = 0?

**Respuesta:**
```verilog
m2_verify: begin
  if (packet_good)
    m2_next_state <= m2_use;
  else
    m2_next_state <= m2_wait;  // Descarta paquete
end
```

- El paquete se descarta silenciosamente
- bit_count se reiniciará en próximo watchdog timeout
- No genera error visible (diseño robusto ante ruido)
- Usuario simplemente no ve data_ready

### 7. ¿Cómo se calcula la paridad impar?

**Respuesta:**
```verilog
// Para byte de datos d[7:0]:
parity_bit = ~^d[7:0]

// Explicación:
^d[7:0] = d[7] ^ d[6] ^ ... ^ d[0]  // XOR reducido
~^d[7:0] = complemento               // Paridad impar
```

**Verificación:**
- Si datos tienen cantidad PAR de 1's → XOR = 0 → ~XOR = 1
- Si datos tienen cantidad IMPAR de 1's → XOR = 1 → ~XOR = 0
- Total de 1's (datos + paridad) siempre impar

### 8. ¿Por qué usar shift register en lugar de contador de bytes?

**Respuesta:**

**Ventaja del shift register:**
```verilog
q <= {ps2_data, q[32:1]};  // 1 línea, 1 ciclo
```

**Alternativa con contador:**
```verilog
case(byte_count)
  0: byte1[bit_count] <= ps2_data;
  1: byte2[bit_count] <= ps2_data;
  2: byte3[bit_count] <= ps2_data;
endcase
// Más código, más lógica
```

**Beneficios:**
- Más simple y compacto
- Menos propensa a errores
- Verificación de framing más fácil (bits están en posiciones fijas)

### 9. ¿Puede conectarse a un mouse USB?

**Respuesta:**
**No directamente.** Razones:
- Diferentes protocolos (PS/2 vs USB)
- Diferentes niveles de voltaje (5V vs 3.3V/5V)
- Diferentes conectores físicos

**Solución:**
- Usar adaptador PS/2-a-USB pasivo (solo si el mouse soporta PS/2)
- O usar mouse PS/2 nativo
- O implementar controlador USB (mucho más complejo)

### 10. ¿Qué hace el módulo _xy.v que no hace _interface.v?

**Respuesta:**

**_interface.v proporciona:**
- Deltas de movimiento (dx, dy)
- Estados de botones
- Señal data_ready

**_xy.v añade:**
- Acumulación de posición absoluta (mx, my)
- Saturación en bordes (0 a MAX_X/Y)
- Inversión de Y para compatibilidad con video
- Interfaz simplificada

**Cuándo usar cada uno:**
- Solo _interface: Si quieres control total (ej. aceleración custom)
- Con _xy: Para aplicaciones típicas (cursor en pantalla)

---

## Integración en Proyecto Final

### Top-level básico (solo lectura de mouse)

```verilog
module top_ps2_test (
  input clk_27mhz,
  input reset_n,
  inout ps2_clk,
  inout ps2_data,
  output [7:0] leds
);

wire [8:0] dx, dy;
wire lb, rb;
wire data_ready;

ps2_mouse_interface #(
  .WATCHDOG_TIMER_VALUE_PP(10800),
  .WATCHDOG_TIMER_BITS_PP(14),
  .DEBOUNCE_TIMER_VALUE_PP(100),
  .DEBOUNCE_TIMER_BITS_PP(7)
) mouse (
  .clk(clk_27mhz),
  .reset(~reset_n),
  .ps2_clk(ps2_clk),
  .ps2_data(ps2_data),
  .left_button(lb),
  .right_button(rb),
  .x_increment(dx),
  .y_increment(dy),
  .data_ready(data_ready),
  .read(1'b1),
  .error_no_ack()
);

// Mostrar estado en LEDs
assign leds = {lb, rb, data_ready, dx[4:0]};

endmodule
```

### Constraints (.cst)

```tcl
// Clock
IO_LOC "clk_27mhz" H11;
IO_PORT "clk_27mhz" PULL_MODE=NONE;

// PS/2
IO_LOC "ps2_clk" XX;
IO_PORT "ps2_clk" IO_TYPE=LVCMOS33 PULL_MODE=UP;
IO_LOC "ps2_data" YY;
IO_PORT "ps2_data" IO_TYPE=LVCMOS33 PULL_MODE=UP;

// Reset
IO_LOC "reset_n" ZZ;
IO_PORT "reset_n" PULL_MODE=UP;
```

**IMPORTANTE:** Necesitas pull-ups en los pines PS/2 (configurados en constraints o externos de 10kΩ).

---

## Referencias

1. **MIT 6.111 Lab:** https://web.mit.edu/6.111/www/
2. **PS/2 Protocol Spec:** Adam Chapweske - http://www.burtonsys.com/ps2_chapweske.htm
3. **Gowin GW5A-25:** https://www.gowinsemi.com/
4. **Tang Primer 25K:** https://wiki.sipeed.com/

---

*Documento preparado para explicación técnica detallada del proyecto de Mouse PS/2 @ 27MHz*
