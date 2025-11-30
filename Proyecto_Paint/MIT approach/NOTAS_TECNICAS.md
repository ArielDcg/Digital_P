# Notas Técnicas - Adaptación MIT PS/2 Mouse para 27MHz

## Resumen de cambios

Este documento describe la adaptación de los módulos MIT PS/2 Mouse para funcionar con el **Tang Primer 25K** a **27 MHz**, en lugar de los 50 MHz originales.

## 1. Análisis de Timing

### 1.1 Protocolo PS/2 - Especificaciones

El protocolo PS/2 tiene requisitos de timing independientes del reloj del sistema:

| Parámetro | Especificación | Notas |
|-----------|----------------|-------|
| Frecuencia CLK PS/2 | 10-16.7 kHz | Generado por el dispositivo |
| Período de CLK PS/2 | 60-100 μs | Típicamente ~80 μs |
| CLK Low time | 30-50 μs | Mínimo 30 μs |
| CLK High time | 30-50 μs | Mínimo 30 μs |
| Setup time | 5 μs | Data antes de CLK↓ |
| Hold time | 5 μs | Data después de CLK↓ |

### 1.2 Timers en el módulo MIT

El módulo usa dos timers principales:

#### Watchdog Timer
- **Propósito**: Detectar timeout de comunicación (400 μs)
- **Cálculo para 50 MHz**:
  ```
  400 μs / 20 ns = 20000 ciclos
  Valor usado: 19660 (compensación por latencias)
  ```
- **Cálculo para 27 MHz**:
  ```
  400 μs / 37.04 ns = 10798 ciclos
  Valor usado: 10800 (redondeado)
  Bits necesarios: log₂(10800) = 13.4 → 14 bits
  ```

#### Debounce Timer
- **Propósito**: Filtrar ruido en transiciones de CLK (~3.7 μs)
- **Cálculo para 50 MHz**:
  ```
  186 * 20 ns = 3.72 μs
  Valor usado: 186 ciclos
  ```
- **Cálculo para 27 MHz**:
  ```
  3.72 μs / 37.04 ns = 100.4 ciclos
  Valor usado: 100 ciclos
  Bits necesarios: log₂(100) = 6.6 → 7 bits
  ```

### 1.3 Tabla de conversión de parámetros

| Parámetro | 50 MHz | Tiempo | 27 MHz | Bits |
|-----------|--------|--------|--------|------|
| `WATCHDOG_TIMER_VALUE_PP` | 19660 | 400 μs | 10800 | 14 |
| `WATCHDOG_TIMER_BITS_PP` | 15 | - | 14 | - |
| `DEBOUNCE_TIMER_VALUE_PP` | 186 | 3.72 μs | 100 | 7 |
| `DEBOUNCE_TIMER_BITS_PP` | 8 | - | 7 | - |

## 2. Módulos MIT - Arquitectura

### 2.1 ps2_mouse_interface.v

Módulo de bajo nivel que implementa el protocolo PS/2 completo.

#### State Machines

**M1: Clock Debouncing**
```
m1_clk_h → m1_falling_edge → m1_falling_wait → m1_clk_l
    ↑                                              ↓
    ← m1_rising_wait ← m1_rising_edge ←────────────┘
```
- Función: Detecta edges limpios en ps2_clk
- Salidas: `falling_edge`, `rising_edge`, `clean_clk`

**M2: Protocol Handler**
```
m2_reset → m2_hold_clk_l → m2_data_low_1 → m2_data_high_1
                              ↓
        m2_await_response ← ... (sequence continues)
                ↓
          m2_wait → m2_gather → m2_verify → m2_use
              ↑         ↓           ↓
              └─────────┴───────────┘
```
- Función: Maneja inicialización y recepción de datos
- Envía comando 0xF4 (Enable Data Reporting) al mouse

**M3: Data Ready Handshake**
```
m3_data_ready_ack ←→ m3_data_ready
```
- Función: Señaliza datos válidos al usuario
- Protocolo simple de handshake

#### Shift Register
- **q[32:0]**: Almacena 3 bytes del mouse (33 bits)
  - 3 bytes × 11 bits/byte = 33 bits
  - Formato por byte: Start(0) + 8 Data + Parity + Stop(1)

#### Packet Verification
Verifica que el paquete recibido sea válido:
```verilog
packet_good = (
    (q[0]  == 0)  &&  // Start bit byte 1
    (q[10] == 1)  &&  // Stop bit byte 1
    (q[11] == 0)  &&  // Start bit byte 2
    (q[21] == 1)  &&  // Stop bit byte 2
    (q[22] == 0)  &&  // Start bit byte 3
    (q[32] == 1)  &&  // Stop bit byte 3
    (q[9]  == ~^q[8:1])    &&  // Parity byte 1 (odd)
    (q[20] == ~^q[19:12])  &&  // Parity byte 2 (odd)
    (q[31] == ~^q[30:23])      // Parity byte 3 (odd)
);
```

#### Output Mapping
```verilog
left_button  = q[1];           // Byte 1, bit 0
right_button = q[2];           // Byte 1, bit 1
x_increment  = {q[5], q[19:12]};  // Sign + 8 bits
y_increment  = {q[6], q[30:23]};  // Sign + 8 bits
```

### 2.2 ps2_mouse_xy.v

Wrapper de alto nivel que convierte deltas en posición absoluta.

#### Características
- Mantiene posición actual `mx[11:0]`, `my[11:0]`
- Límites configurables: `MAX_X`, `MAX_Y`
- Saturación en bordes (no permite salir del rango)
- Y invertido (para uso con displays)

#### Algoritmo de actualización
```verilog
// Para X:
if (sx) // Movimiento negativo
    mx = (mx > ndx) ? mx - ndx : 0
else    // Movimiento positivo
    mx = (mx < MAX_X - ndx) ? mx + ndx : MAX_X

// Para Y (invertido):
if (sy) // Negativo → hacia abajo en pantalla
    my = (my < MAX_Y - ndy) ? my + ndy : MAX_Y
else    // Positivo → hacia arriba en pantalla
    my = (my > ndy) ? my - ndy : 0
```

## 3. Testbench - Bus Functional Model (BFM)

### 3.1 Diseño del BFM

El testbench implementa un **Bus Functional Model** que simula el comportamiento de un mouse PS/2 real.

#### Componentes clave

**Pull-ups**
```verilog
pullup(ps2_clk);
pullup(ps2_data);
```
Crítico: Simula las resistencias pull-up del bus PS/2 (open-collector).

**Tri-state drivers**
```verilog
assign ps2_clk  = mouse_clk_en  ? mouse_clk_drive  : 1'bz;
assign ps2_data = mouse_data_en ? mouse_data_drive : 1'bz;
```
Permite control bidireccional del bus.

### 3.2 Tarea: mouse_send_byte

Implementa el protocolo de transmisión PS/2:

```
Timing por bit (~80 μs):
    ______          ________
CLK       |________|

    ←20us→←--40us--→←20us→
```

Secuencia:
1. **Start bit**: DATA=0
2. **8 Data bits**: LSB primero
3. **Parity bit**: Paridad impar
4. **Stop bit**: DATA=1

### 3.3 Tarea: expect_host_command

Simula la recepción de comandos del host:

1. Detecta inhibición (CLK low por >100 μs)
2. Espera start bit del host (CLK=1, DATA=0)
3. Genera pulsos de CLK para leer datos
4. Envía ACK (DATA=0 en pulso adicional)

### 3.4 Secuencia de prueba

```
1. Power-on:
   - Mouse → BAT (0xAA)
   - Mouse → Device ID (0x00)

2. Inicialización:
   - Host → Enable Data Reporting (0xF4)
   - Mouse → ACK (0xFA)

3. Stream Mode:
   - Mouse envía paquetes continuamente
   - Formato: Status + X_delta + Y_delta
```

### 3.5 Casos de prueba implementados

| # | X | Y | Status byte | Descripción |
|---|---|---|-------------|-------------|
| 1 | +5 | -1 | 0x28 | Movimiento simple |
| 2 | -10 | +20 | 0x19 | Con botón izquierdo |
| 3 | 0 | 0 | 0x0A | Solo botón derecho |
| 4 | +127 | -128 | 0x28 | Valores extremos |

#### Decodificación de status byte

Ejemplo: `0x28 = 0b00101000`
```
Bit 7 (YOvf): 0 - Sin overflow Y
Bit 6 (XOvf): 0 - Sin overflow X
Bit 5 (YSign): 1 - Y negativo
Bit 4 (XSign): 0 - X positivo
Bit 3: 1 - Always 1 (válido)
Bit 2 (MBtn): 0 - Middle button no presionado
Bit 1 (RBtn): 0 - Right button no presionado
Bit 0 (LBtn): 0 - Left button no presionado
```

## 4. Verificación

### 4.1 Señales críticas a monitorear

**Protocolo PS/2**
- `ps2_clk`: Debe oscilar entre 10-16.7 kHz cuando hay transmisión
- `ps2_data`: Debe cambiar solo cuando CLK está alto

**Decoding**
- `data_ready`: Pulso cuando hay paquete válido
- `x_increment`, `y_increment`: Deben coincidir con valores enviados
- `left_button`, `right_button`: Estados correctos

**Estado interno**
- `m2_state`: Debe pasar por secuencia de inicialización
- `bit_count`: Debe contar de 0 a 33 durante recepción
- `q[32:0]`: Shift register debe capturar bits correctamente

### 4.2 Debugging común

**Problema**: No se detectan datos
- Verificar que los pull-ups estén declarados
- Comprobar timing del BFM (debe ser ~80 μs por bit)
- Revisar que los parámetros del timer sean correctos

**Problema**: Packet verification falla
- Verificar paridad (debe ser impar)
- Comprobar start bits (deben ser 0)
- Verificar stop bits (deben ser 1)

**Problema**: Valores incorrectos
- Revisar orden de bits (LSB primero)
- Verificar complemento a 2 para negativos
- Comprobar mapeo en output_strobe

## 5. Integración con Tang Primer 25K

### 5.1 Conexiones físicas

```
Tang Primer 25K          PS/2 Mouse
---------------          ----------
GPIO_XX    ←→    PS2_CLK (Clock)
GPIO_YY    ←→    PS2_DATA (Data)
GND        ─     GND
VCC (5V)   ─     VCC
```

**Importante**:
- Usar pines con pull-up de 10kΩ a VCC
- PS/2 es open-collector (activo bajo)
- Nivel lógico: 5V tolerante

### 5.2 Constraints file (.cst)

```
IO_LOC "ps2_clk" XX;
IO_PORT "ps2_clk" IO_TYPE=LVCMOS33 PULL_MODE=UP;

IO_LOC "ps2_data" YY;
IO_PORT "ps2_data" IO_TYPE=LVCMOS33 PULL_MODE=UP;
```

### 5.3 Top-level module ejemplo

```verilog
module top_ps2_mouse (
    input clk_27mhz,
    input reset_n,
    inout ps2_clk,
    inout ps2_data,
    output [11:0] cursor_x,
    output [11:0] cursor_y,
    output [2:0] buttons
);

    wire reset = ~reset_n;

    ps2_mouse_xy #(
        .MAX_X(1023),
        .MAX_Y(767)
    ) mouse_inst (
        .clk(clk_27mhz),
        .reset(reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .mx(cursor_x),
        .my(cursor_y),
        .btn_click(buttons)
    );

endmodule
```

### 5.4 Ajuste fino de parámetros

Si encuentras problemas de timing:

**Para reloj más rápido** (ej. 27 MHz muy rápido):
- Aumentar `DEBOUNCE_TIMER_VALUE` en incrementos de 10-20
- Aumentar `WATCHDOG_TIMER_VALUE` en incrementos de 500-1000

**Para reloj más lento**:
- Reducir parámetros proporcionalmente
- Mantener la relación: Watchdog ≈ 100 × Debounce

**Fórmula general**:
```
WATCHDOG_TIMER_VALUE = round(400 μs / CLK_PERIOD)
DEBOUNCE_TIMER_VALUE = round(3.7 μs / CLK_PERIOD)
```

## 6. Diferencias con el approach original

### 6.1 Arquitectura

| Aspecto | MIT Approach | Your Approach |
|---------|-------------|---------------|
| Origen | MIT 6.111 Lab | Diseño custom |
| Complejidad | Media-Alta | ? |
| State Machines | 3 FSMs separadas | ? |
| Inicialización | Automática (envía 0xF4) | ? |
| Verificación | Parity + frame check | ? |

### 6.2 Ventajas MIT Approach

✅ Bien probado (usado en cursos del MIT)
✅ Documentado extensamente
✅ Maneja errores (no-ack detection)
✅ Inicialización automática del mouse
✅ Debouncing robusto

### 6.3 Cuándo usar cada uno

**MIT Approach**:
- Proyecto educativo/prototipo
- Necesitas funcionalidad probada
- Tienes espacio en FPGA (~200 LUTs)

**Custom Approach**:
- Optimización extrema de recursos
- Requisitos específicos de timing
- Integración con sistema existente

## 7. Referencias técnicas

### 7.1 Documentos

- **PS/2 Protocol**: Adam Chapweske's PS/2 Mouse Interface
  http://www.burtonsys.com/ps2_chapweske.htm

- **MIT 6.111**: Introduction to Digital Systems
  https://web.mit.edu/6.111/www/

- **Tang Primer 25K**: Sipeed Documentation
  https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html

### 7.2 Herramientas

- **Icarus Verilog**: http://iverilog.icarus.com/
- **GTKWave**: http://gtkwave.sourceforge.net/
- **Gowin EDA**: https://www.gowinsemi.com/en/support/download_eda/

## Autor y Licencia

**Adaptación**: Claude Code (Noviembre 2025)
**Módulos MIT**: MIT 6.111 Lab (ver licencia original)
**Testbench**: Dominio público / Uso libre

---

*Última actualización: 2025-11-30*
