# Simulación MIT PS/2 Mouse @ 27MHz

## Descripción

Este directorio contiene los módulos del MIT para control de mouse PS/2 adaptados para funcionar con el **Tang Primer 25K** (Gowin GW5A-25) a **27MHz**.

## Archivos

### Módulos de diseño (MIT)
- **mit_ps2_mouse_interface.v** - Driver de bajo nivel para protocolo PS/2
  - Maneja la comunicación bidireccional con el mouse
  - Implementa state machines para debouncing y protocolo
  - Diseñado originalmente para 50MHz, ahora adaptable a 27MHz

- **mit_ps2_mouse_xy.v** - Wrapper de alto nivel
  - Mantiene posición absoluta (x, y) del cursor
  - Interfaz simplificada con parámetros configurables

### Testbench
- **tb_mit_ps2_mouse_27mhz.v** - Testbench completo con BFM
  - Bus Functional Model (BFM) que simula un mouse PS/2 real
  - Parámetros de timing ajustados para 27MHz
  - Incluye secuencias de:
    - Power-on (BAT + Device ID)
    - Comando de habilitación (0xF4)
    - Stream mode con múltiples paquetes de movimiento
    - Pruebas de botones y movimientos en diferentes direcciones

### Scripts
- **Makefile** - Compilación y simulación automatizada
- **simulate.sh** - Script bash con interfaz amigable

## Ajustes de Timing para 27MHz

### Cálculos realizados

| Parámetro | Valor @ 50MHz | Tiempo | Valor @ 27MHz |
|-----------|---------------|--------|---------------|
| Período de reloj | 20 ns | - | 37.04 ns |
| Watchdog Timer | 19660 | 400 μs | 10800 |
| Debounce Timer | 186 | 3.7 μs | 100 |

### Parámetros configurados en el testbench

```verilog
parameter WATCHDOG_TIMER_VALUE = 10800;  // 400 μs @ 27MHz
parameter WATCHDOG_TIMER_BITS  = 14;     // 2^14 = 16384 > 10800
parameter DEBOUNCE_TIMER_VALUE = 100;    // ~3.7 μs @ 27MHz
parameter DEBOUNCE_TIMER_BITS  = 7;      // 2^7 = 128 > 100
```

## Instalación de Icarus Verilog

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install iverilog gtkwave
```

### Fedora/RHEL
```bash
sudo dnf install iverilog gtkwave
```

### macOS (con Homebrew)
```bash
brew install icarus-verilog gtkwave
```

### Windows
Descarga desde: http://bleyer.org/icarus/

## Uso

### Opción 1: Usando Makefile

```bash
# Compilar y simular
make all

# Solo compilar
make compile

# Solo simular (requiere compilación previa)
make simulate

# Ver formas de onda con GTKWave
make wave

# Flujo completo (limpiar + compilar + simular)
make run

# Limpiar archivos generados
make clean

# Ayuda
make help
```

### Opción 2: Usando script bash

```bash
# Ejecutar simulación interactiva
./simulate.sh
```

El script:
1. Verifica que Icarus Verilog esté instalado
2. Compila el diseño
3. Ejecuta la simulación
4. Genera el archivo VCD
5. Opcionalmente abre GTKWave

### Opción 3: Comandos manuales

```bash
# Compilar
iverilog -g2012 -Wall -Winfloop \
    -o simulation.vvp \
    mit_ps2_mouse_interface.v \
    tb_mit_ps2_mouse_27mhz.v

# Simular
vvp simulation.vvp

# Ver formas de onda
gtkwave tb_mit_ps2_mouse_27mhz.vcd
```

## Salida esperada

La simulación genera:

1. **Consola**: Mensajes de debug mostrando
   - Secuencia de power-on
   - Comandos enviados/recibidos
   - Paquetes de movimiento
   - Datos decodificados (botones, X, Y)

2. **Archivo VCD**: `tb_mit_ps2_mouse_27mhz.vcd`
   - Todas las señales internas
   - Visualizable con GTKWave

### Ejemplo de salida en consola

```
========================================
  Test MIT PS/2 Mouse @ 27MHz
========================================

[500200] 1. Enviando BAT (Basic Assurance Test) = 0xAA
[500200] Mouse enviando byte: 0xAA
[868278] 2. Enviando Device ID = 0x00 (Standard Mouse)
[868278] Mouse enviando byte: 0x00
[1236356] 3. Esperando comando de habilitación (0xF4) del Host...
...
[DATA READY] LB=0 RB=0 X=+5 Y=-1
```

## Verificación de resultados

### Señales a observar en GTKWave

1. **Protocolo PS/2**
   - `ps2_clk` - Reloj bidireccional (~10-16 kHz)
   - `ps2_data` - Datos bidireccionales

2. **Datos decodificados**
   - `x_increment[8:0]` - Delta X (con signo)
   - `y_increment[8:0]` - Delta Y (con signo)
   - `left_button`, `right_button`
   - `data_ready` - Pulso cuando hay datos válidos

3. **Estado interno**
   - `dut.m1_state` - State machine de debouncing
   - `dut.m2_state` - State machine de protocolo
   - `dut.bit_count` - Contador de bits recibidos

### Casos de prueba implementados

| Test | Descripción | X | Y | Botones |
|------|-------------|---|---|---------|
| 1 | Movimiento simple | +5 | -1 | Ninguno |
| 2 | Mov. con botón | -10 | +20 | Izquierdo |
| 3 | Solo botón | 0 | 0 | Derecho |
| 4 | Valores máximos | +127 | -128 | Ninguno |

## Adaptación para tu diseño

Si quieres usar estos módulos en tu proyecto:

### 1. Instanciar el módulo con parámetros para 27MHz

```verilog
ps2_mouse_interface #(
    .WATCHDOG_TIMER_VALUE_PP(10800),  // 27MHz
    .WATCHDOG_TIMER_BITS_PP(14),
    .DEBOUNCE_TIMER_VALUE_PP(100),
    .DEBOUNCE_TIMER_BITS_PP(7)
) mouse_if (
    .clk(clk_27mhz),
    .reset(reset),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .left_button(left_btn),
    .right_button(right_btn),
    .x_increment(x_delta),
    .y_increment(y_delta),
    .data_ready(data_valid),
    .read(1'b1),
    .error_no_ack(error)
);
```

### 2. O usar el wrapper de alto nivel

```verilog
ps2_mouse_xy #(
    .MAX_X(1023),
    .MAX_Y(767)
) mouse_xy (
    .clk(clk_27mhz),
    .reset(reset),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .mx(mouse_x),      // [11:0] posición absoluta
    .my(mouse_y),      // [11:0] posición absoluta
    .btn_click(buttons) // [2:0] L-M-R
);
```

**Nota**: El wrapper `ps2_mouse_xy` ya tiene parámetros configurados para ~65MHz. Para 27MHz, puedes:
- Usar los valores del testbench (más conservadores)
- Ajustar según los valores mostrados en la tabla anterior

## Protocolo PS/2 Mouse - Referencia rápida

### Secuencia de inicialización
1. Mouse envía BAT (0xAA)
2. Mouse envía Device ID (0x00)
3. Host envía Enable Data Reporting (0xF4)
4. Mouse responde ACK (0xFA)
5. Mouse entra en Stream Mode

### Formato de paquete de datos (3 bytes)

**Byte 1 (Status)**
```
Bit 7: Y overflow
Bit 6: X overflow
Bit 5: Y sign (1=negativo)
Bit 4: X sign (1=negativo)
Bit 3: Always 1
Bit 2: Middle button
Bit 1: Right button
Bit 0: Left button
```

**Byte 2**: X movement (8 bits)
**Byte 3**: Y movement (8 bits)

### Timing del protocolo
- Frecuencia de reloj PS/2: 10-16.7 kHz
- Período de bit: ~60-100 μs
- Frame: 11 bits (Start + 8 Data + Parity + Stop)

## Troubleshooting

### Error: "No se encuentra mit_ps2_mouse_interface.v"
- Verifica que estás en el directorio correcto: `Proyecto_Paint/MIT approach/`

### Error de compilación: "syntax error"
- Verifica que estás usando Icarus Verilog >= 10.0
- Usa el flag `-g2012` para SystemVerilog

### La simulación no genera datos
- Revisa el VCD en GTKWave
- Verifica que las señales `ps2_clk` y `ps2_data` tengan pull-ups
- Comprueba los timings del BFM

### Warnings sobre "implicit wire"
- Son normales en Verilog, no afectan la funcionalidad
- Se pueden eliminar declarando explícitamente las señales

## Referencias

- MIT OpenCourseWare 6.111 Lab
- PS/2 Protocol: http://www.burtonsys.com/ps2_chapweske.htm
- Gowin GW5A-25 Datasheet
- Tang Primer 25K Documentation

## Autor

Adaptación para 27MHz y testbench: Claude Code
Módulos originales: MIT 6.111 Lab

## Licencia

Código MIT: Según licencia original del MIT
Testbench y adaptaciones: Uso libre
