# Testbench PS/2 - bench_quark.v

## Descripción General

El archivo `bench_quark.v` es un testbench completo que simula el comportamiento de un mouse PS/2 para probar el módulo `top_ps2_test.v` y su controlador `ps2_mouse_init.v`.

## Análisis Línea por Línea

### Líneas 1-9: Declaración del Módulo y Parámetros

```verilog
1:  module bench();
```
- Declara el módulo testbench llamado `bench`
- No tiene puertos porque es el módulo de nivel superior en la simulación

```verilog
2-3:  // Comentarios
4:  parameter tck = 37;
```
- `tck = 37 ns`: Período del clock del sistema
- Representa 27 MHz (1/27MHz = 37.037 ns ≈ 37 ns)
- Este es el clock de la FPGA Tang Primer 25K

```verilog
8:  parameter PS2_CLK_PERIOD = 60000;
```
- Define el período del clock PS/2 en nanosegundos
- 60000 ns = 60 µs
- Frecuencia: 1/60µs ≈ 16.7 kHz (dentro del rango 10-16.7 kHz del estándar PS/2)

```verilog
9:  parameter PS2_CLK_HALF = PS2_CLK_PERIOD / 2;
```
- Calcula el medio período: 30000 ns = 30 µs
- Se usa para generar flancos de subida y bajada del clock PS/2

### Líneas 11-20: Declaración de Señales

```verilog
11:  reg CLK;
```
- Registro para el clock del sistema (27 MHz)
- Se generará con un `always` más adelante

```verilog
12:  reg RST_N;
```
- Registro para el reset activo en bajo
- `RST_N = 0`: Reset activo
- `RST_N = 1`: Sistema funcionando

```verilog
15:  wire ps2_clk;
16:  wire ps2_data;
```
- Wires bidireccionales para las líneas PS/2
- Conectan el testbench con el módulo `top_ps2_test`
- Permiten que tanto el testbench como el módulo controlen las líneas

```verilog
19:  reg ps2_clk_tb = 1'bz;
20:  reg ps2_data_tb = 1'bz;
```
- Registros para controlar las líneas PS/2 desde el testbench
- `1'bz`: Alta impedancia (Z-state)
- Cuando están en `z`, las líneas flotan y los pullups las mantienen en alto
- El testbench las cambia a `0` o `1` para enviar datos

### Líneas 22-28: Implementación de Pullups y Control Bidireccional

```verilog
23:  assign (weak1, weak0) ps2_clk = 1'b1;
24:  assign (weak1, weak0) ps2_data = 1'b1;
```
- `(weak1, weak0)`: Especifica drivers débiles
- `weak1`: Pullup débil (fuerza la línea a '1' con baja impedancia)
- `weak0`: Pulldown débil (no usado aquí)
- Simula las resistencias pull-up físicas de ~10kΩ en hardware real
- **Importante**: Si ningún driver fuerte controla la línea, el pullup la mantiene en '1'

```verilog
27:  assign ps2_clk = ps2_clk_tb;
28:  assign ps2_data = ps2_data_tb;
```
- Conecta los registros del testbench a los wires
- **Driver fuerte**: Cuando `ps2_clk_tb` es `0` o `1`, sobrescribe el pullup débil
- **Alta impedancia**: Cuando `ps2_clk_tb` es `z`, el pullup toma control y pone la línea en '1'

**Ejemplo de comportamiento:**
```
ps2_clk_tb = 1'bz  → ps2_clk = 1 (por pullup)
ps2_clk_tb = 1'b0  → ps2_clk = 0 (driver fuerte)
ps2_clk_tb = 1'b1  → ps2_clk = 1 (driver fuerte)
```

### Líneas 30-36: Señales de Debug

```verilog
31:  wire [7:0] debug_state;
```
- Bus de 8 bits que muestra el estado actual de la FSM
- Valores: 0x00=IDLE, 0x01=RESET_WAIT, 0x02=SEND_RESET, etc.

```verilog
32:  wire [7:0] debug_pins;
```
- Bus de 8 bits que muestra los datos recibidos del mouse
- Contiene el último byte recibido

```verilog
33:  wire led_init_done;
```
- Señal que indica que la inicialización del mouse está completa
- '1' cuando el mouse está en Stream Mode

```verilog
34:  wire led_activity;
```
- Pulso que indica que se recibieron datos válidos del mouse

```verilog
35:  wire led_error;
```
- Señal de error (no implementada en este diseño)

```verilog
36:  wire uart_tx;
```
- Salida UART para debug opcional (no usada en este testbench)

### Líneas 38-50: Instanciación del Módulo Bajo Prueba

```verilog
39:  top_ps2_test uut (
```
- Instancia del módulo `top_ps2_test` con el nombre `uut` (Unit Under Test)
- Este es el módulo que estamos probando

```verilog
40:     .clk(CLK),
```
- Conecta el clock del sistema del testbench al puerto `clk` del módulo
- El punto `.clk` es el puerto del módulo, `(CLK)` es la señal del testbench

```verilog
41:     .rst_n(RST_N),
```
- Conecta la señal de reset del testbench al puerto `rst_n`

```verilog
42:     .ps2_clk(ps2_clk),
43:     .ps2_data(ps2_data),
```
- Conecta las líneas PS/2 bidireccionales
- Tanto el testbench como el módulo pueden controlar estas líneas

```verilog
44-49: Conexiones de señales de debug y LEDs
```
- Todas son salidas del módulo que monitoreamos en el testbench

### Líneas 52-54: Generación del Clock del Sistema

```verilog
53:  initial CLK = 0;
```
- `initial`: Bloque que se ejecuta una sola vez al inicio de la simulación
- Inicializa el clock en '0'

```verilog
54:  always #(tck/2) CLK = ~CLK;
```
- `always`: Bloque que se ejecuta continuamente
- `#(tck/2)`: Espera medio período (37/2 = 18.5 ns)
- `CLK = ~CLK`: Invierte el clock
- **Resultado**: Clock que oscila cada 18.5 ns → período total = 37 ns = 27 MHz

**Forma de onda generada:**
```
Tiempo: 0    18.5  37   55.5  74   ...
CLK:    0     1    0     1    0    ...
```

## Arquitectura del Testbench

### Parámetros de Temporización

```verilog
parameter tck = 37;                    // Clock del sistema: 27 MHz (período ~37ns)
parameter PS2_CLK_PERIOD = 60000;      // Clock PS/2: 60µs (≈16.7 kHz)
parameter PS2_CLK_HALF = PS2_CLK_PERIOD / 2;  // Medio período: 30µs
```

### Señales Principales

#### Señales del Sistema
- `CLK`: Clock del sistema (27 MHz)
- `RST_N`: Reset activo en bajo

#### Señales PS/2 Bidireccionales
- `ps2_clk`: Línea de clock PS/2 (bidireccional con pullup)
- `ps2_data`: Línea de datos PS/2 (bidireccional con pullup)
- `ps2_clk_tb`: Control del clock desde el testbench
- `ps2_data_tb`: Control de datos desde el testbench

#### Señales de Debug
- `debug_state[7:0]`: Estado actual de la FSM
- `debug_pins[7:0]`: Datos recibidos del mouse
- `led_init_done`: Indica que la inicialización está completa
- `led_activity`: Indica actividad en el bus PS/2
- `led_error`: Indica errores

### Implementación de Señales Bidireccionales

```verilog
// Pullups débiles (simulan resistencias pull-up físicas)
assign (weak1, weak0) ps2_clk = 1'b1;
assign (weak1, weak0) ps2_data = 1'b1;

// Control desde el testbench
assign ps2_clk = ps2_clk_tb;
assign ps2_data = ps2_data_tb;
```

## Protocolo PS/2 Implementado

### Formato de Trama (Device → Host)

```
┌─────┬───┬───┬───┬───┬───┬───┬───┬───┬──────┬──────┐
│START│ 0 │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │PARITY│ STOP │
└─────┴───┴───┴───┴───┴───┴───┴───┴───┴──────┴──────┘
   0    LSB                      MSB   Impar     1
```

- **Start bit**: `0`
- **8 bits de datos**: LSB primero
- **Bit de paridad**: Paridad impar (XOR negado de todos los bits)
- **Stop bit**: `1`

### Tarea: PS2_SEND_BYTE (Líneas 56-108)

Simula el envío de un byte desde el mouse al host.

```verilog
58:  task PS2_SEND_BYTE;
59:     input [7:0] data;
```
- **Línea 58**: Declaración de la tarea con nombre `PS2_SEND_BYTE`
- **Línea 59**: Parámetro de entrada: byte de 8 bits a enviar

```verilog
60:     integer i;
61:     reg parity;
```
- **Línea 60**: Variable entera `i` para el loop de bits
- **Línea 61**: Registro `parity` para calcular y almacenar el bit de paridad

```verilog
64:        parity = ~^data;
```
- **Línea 64**: Cálculo de paridad impar
- `^data`: XOR de todos los bits (0^1^0^1... = cuenta de unos módulo 2)
- `~`: Negación (para hacer paridad impar)
- **Ejemplo**: `data = 0xFA = 11111010` → 6 unos → XOR = 0 → ~0 = 1

```verilog
66:        $display("[%0t] PS2_SEND_BYTE: Enviando 0x%02h (paridad=%b)", $time, data, parity);
```
- **Línea 66**: Imprime mensaje en consola
- `%0t`: Tiempo actual de simulación
- `%02h`: Datos en hexadecimal (2 dígitos)
- `%b`: Paridad en binario

```verilog
69:        ps2_clk_tb = 1'b0;
70:        #PS2_CLK_HALF;
```
- **Línea 69**: Baja el clock PS/2 (toma control del bus)
- **Línea 70**: Espera 30µs (medio período)
- **Propósito**: Señalar al host que viene una transmisión

```verilog
73:        ps2_data_tb = 1'b0;
74:        ps2_clk_tb = 1'b1;
75:        #PS2_CLK_HALF;
76:        ps2_clk_tb = 1'b0;
77:        #PS2_CLK_HALF;
```
- **Línea 73**: Start bit = 0 (pone data en bajo)
- **Línea 74**: Sube el clock (primer flanco de subida)
- **Línea 75**: Espera 30µs (clock en alto)
- **Línea 76**: Baja el clock (flanco de bajada)
- **Línea 77**: Espera 30µs (clock en bajo)
- **Resultado**: Un ciclo completo de clock con data = 0

**Forma de onda del start bit:**
```
Tiempo:  0      30µs    60µs
clk:     0       1       0
data:    0       0       0
```

```verilog
80-86:     for (i = 0; i < 8; i = i + 1) begin
              ps2_data_tb = data[i];
              ps2_clk_tb = 1'b1;
              #PS2_CLK_HALF;
              ps2_clk_tb = 1'b0;
              #PS2_CLK_HALF;
           end
```
- **Línea 80**: Loop de 8 iteraciones (i = 0 a 7)
- **Línea 81**: Pone en data el bit `i` del byte (LSB primero)
- **Líneas 82-85**: Genera un pulso de clock completo
- **Importante**: Los datos cambian en el flanco de bajada, el host lee en flanco de subida

**Ejemplo con data = 0xFA (11111010):**
```
Iteración: 0    1    2    3    4    5    6    7
data[i]:   0    1    0    1    1    1    1    1
           LSB                              MSB
```

```verilog
89-93:     ps2_data_tb = parity;
           ps2_clk_tb = 1'b1;
           #PS2_CLK_HALF;
           ps2_clk_tb = 1'b0;
           #PS2_CLK_HALF;
```
- **Línea 89**: Pone el bit de paridad calculado
- **Líneas 90-93**: Genera un pulso de clock para el bit de paridad

```verilog
96-100:    ps2_data_tb = 1'b1;
           ps2_clk_tb = 1'b1;
           #PS2_CLK_HALF;
           ps2_clk_tb = 1'b0;
           #PS2_CLK_HALF;
```
- **Línea 96**: Stop bit = 1 (pone data en alto)
- **Líneas 97-100**: Genera el último pulso de clock

```verilog
103:       ps2_clk_tb = 1'bz;
104:       ps2_data_tb = 1'bz;
```
- **Línea 103**: Libera el clock (alta impedancia)
- **Línea 104**: Libera data (alta impedancia)
- **Resultado**: Los pullups ponen ambas líneas en '1'

```verilog
106:       $display("[%0t] PS2_SEND_BYTE: Byte enviado completamente", $time);
```
- **Línea 106**: Confirma que la transmisión terminó

**Cronograma completo de PS2_SEND_BYTE(0xFA):**
```
Bit:     START  0   1   0   1   1   1   1   1   PAR STOP
data:      0    0   1   0   1   1   1   1   1    1   1
         ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
clk:  ___┘ └┐│└┐│└┐│└┐│└┐│└┐│└┐│└┐│└┐│└┐│└┐│└───
           └─┘└─┘└─┘└─┘└─┘└─┘└─┘└─┘└─┘└─┘└─
Duración: 11 ciclos × 60µs = 660µs total
```

### Tarea: PS2_WAIT_HOST_COMMAND (Líneas 110-176)

Simula la recepción de un comando del host al mouse.

```verilog
112:  task PS2_WAIT_HOST_COMMAND;
113:     output [7:0] cmd;
```
- **Línea 112**: Declaración de la tarea
- **Línea 113**: Parámetro de salida `cmd` donde se almacenará el comando recibido

```verilog
114:     integer i;
115:     reg parity_received;
116:     reg parity_calc;
```
- **Línea 114**: Variable `i` para loops
- **Línea 115**: Registro para almacenar el bit de paridad recibido
- **Línea 116**: Registro para la paridad calculada (para verificación)

```verilog
118:        cmd = 8'h00;
```
- **Línea 118**: Inicializa el comando en 0x00

```verilog
121:        wait(ps2_clk == 1'b0);
122:        $display("[%0t] PS2_WAIT_HOST_COMMAND: Host tomó control del clock", $time);
```
- **Línea 121**: `wait()` pausa la ejecución hasta que `ps2_clk` sea '0'
- **Propósito**: El host baja el clock para inhibir la comunicación (inicio de transmisión host→device)
- **Línea 122**: Mensaje de debug

**Protocolo host→device:**
```
1. Host baja CLK por >100µs (inhibit)
2. Host baja DATA (request-to-send)
3. Host libera CLK
4. Device genera los pulsos de clock
```

```verilog
125:        wait(ps2_data == 1'b0);
126:        $display("[%0t] PS2_WAIT_HOST_COMMAND: Host puso data=0 (request)", $time);
```
- **Línea 125**: Espera que el host baje data (request-to-send)
- **Línea 126**: Confirmación del request

```verilog
129:        wait(ps2_clk == 1'b1);
```
- **Línea 129**: Espera que el host libere el clock (vuelva a alto por pullup)
- **Importante**: Ahora el device (mouse) toma control y genera los pulsos de clock

```verilog
133:        wait(ps2_clk == 1'b0);
134:        #(PS2_CLK_HALF/2);
135:        if (ps2_data != 1'b0) begin
136:           $display("[%0t] ERROR: Start bit no es 0!", $time);
137:        end
```
- **Línea 133**: Espera el flanco de bajada del clock
- **Línea 134**: Espera 15µs (cuarto de período) para estabilización
- **Líneas 135-137**: Verifica que el start bit sea '0'
- **Timing**: Se lee en medio del ciclo de clock para evitar glitches

```verilog
140-145:   for (i = 0; i < 8; i = i + 1) begin
              wait(ps2_clk == 1'b1);
              wait(ps2_clk == 1'b0);
              #(PS2_CLK_HALF/2);
              cmd[i] = ps2_data;
           end
```
- **Línea 140**: Loop de 8 bits
- **Línea 141**: Espera flanco de subida del clock
- **Línea 142**: Espera flanco de bajada del clock
- **Línea 143**: Espera 15µs (estabilización)
- **Línea 144**: Lee el bit `i` de data
- **Importante**: Los bits se leen en orden LSB primero (bit 0 primero)

**Ejemplo recibiendo 0xFF (Reset):**
```
Iteración: 0   1   2   3   4   5   6   7
Bit leído: 1   1   1   1   1   1   1   1
cmd[i]:    └─> cmd = 0xFF = 11111111
```

```verilog
148-151:   wait(ps2_clk == 1'b1);
           wait(ps2_clk == 1'b0);
           #(PS2_CLK_HALF/2);
           parity_received = ps2_data;
```
- **Líneas 148-149**: Espera el siguiente ciclo de clock
- **Línea 150**: Estabilización
- **Línea 151**: Lee el bit de paridad enviado por el host

```verilog
154:        parity_calc = ~^cmd;
155-158:    if (parity_received != parity_calc) begin
               $display("[%0t] ERROR: Paridad incorrecta! Recibida=%b, Calculada=%b",
                        $time, parity_received, parity_calc);
            end
```
- **Línea 154**: Calcula la paridad esperada del comando recibido
- **Líneas 155-158**: Compara y reporta error si no coinciden
- **Ejemplo**: `cmd = 0xFF` → 8 unos → XOR = 0 → ~0 = 1 (paridad debe ser 1)

```verilog
161-165:   wait(ps2_clk == 1'b1);
           wait(ps2_clk == 1'b0);
           #(PS2_CLK_HALF/2);
           if (ps2_data != 1'b1) begin
              $display("[%0t] ERROR: Stop bit no es 1!", $time);
           end
```
- **Líneas 161-163**: Lee el stop bit
- **Líneas 164-165**: Verifica que sea '1'

```verilog
169:        wait(ps2_clk == 1'b1);
170:        ps2_data_tb = 1'b0;
171:        wait(ps2_clk == 1'b0);
172:        ps2_data_tb = 1'bz;
```
- **Línea 169**: Espera el siguiente flanco de subida
- **Línea 170**: Pone data en '0' (ACK del device al host)
- **Línea 171**: Espera el flanco de bajada
- **Línea 172**: Libera data (vuelve a alta impedancia)
- **Resultado**: El host sabe que el device recibió el comando correctamente

**Cronograma completo de recepción (0xFF):**
```
Enviado por host:
Bit:     REQ  START  1   1   1   1   1   1   1   1   PAR STOP  ACK
data:     0    0    1   1   1   1   1   1   1   1    1   1    0
         ────┐    ┌───────────────────────────────┐       ┌──
             └────┘                               └───────┘
                  │<──  Host genera estos bits  ──>│     │<─Device

clk:     ────┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
             └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─
             Inhibit  │<──Device genera el clock ──>│
```

```verilog
174:       $display("[%0t] PS2_WAIT_HOST_COMMAND: Comando recibido: 0x%02h", $time, cmd);
```
- **Línea 174**: Confirma el comando recibido

## Simulación del Mouse PS/2

El testbench simula el comportamiento completo de inicialización de un mouse PS/2:

### 1. Power-On Self Test (POST)
```verilog
#200000000;  // Espera 200ms después del reset
```

### 2. Comando RESET (0xFF)
```
Host → Mouse: 0xFF (RESET)
Mouse → Host: 0xFA (ACK)
Mouse → Host: 0xAA (BAT completion)
Mouse → Host: 0x00 (Device ID)
```

**Implementación:**
```verilog
PS2_WAIT_HOST_COMMAND(cmd);
if (cmd == 8'hFF) begin
    #100000;
    PS2_SEND_BYTE(8'hFA);  // ACK
    #500000000;            // Ejecutar BAT (500ms)
    PS2_SEND_BYTE(8'hAA);  // BAT completion
    PS2_SEND_BYTE(8'h00);  // Mouse ID
end
```

### 3. Enable Data Reporting (0xF4)
```
Host → Mouse: 0xF4 (Enable Data Reporting)
Mouse → Host: 0xFA (ACK)
```

**Implementación:**
```verilog
PS2_WAIT_HOST_COMMAND(cmd);
if (cmd == 8'hF4) begin
    #100000;
    PS2_SEND_BYTE(8'hFA);  // ACK
    // Entrar en Stream Mode
end
```

### 4. Stream Mode - Paquetes de Datos

En Stream Mode, el mouse envía paquetes de 3 bytes:

#### Byte 1: Estado de Botones y Signos
```
Bit 7: Y overflow
Bit 6: X overflow
Bit 5: Y sign (1 = negativo)
Bit 4: X sign (1 = negativo)
Bit 3: Siempre 1
Bit 2: Botón medio
Bit 1: Botón derecho
Bit 0: Botón izquierdo
```

#### Byte 2: Movimiento X (complemento a 2)
#### Byte 3: Movimiento Y (complemento a 2)

**Ejemplo: Botón izquierdo presionado, X=+5, Y=-3**
```verilog
PS2_SEND_BYTE(8'b00001001);  // Byte 1: Y_sign=1, Always1=1, Left=1
PS2_SEND_BYTE(8'd5);         // Byte 2: X = +5
PS2_SEND_BYTE(8'd253);       // Byte 3: Y = -3 (en complemento a 2)
```

## Monitores de Debug

El testbench incluye monitores que muestran información en consola:

### Monitor de Estado FSM
```verilog
always @(debug_state) begin
    $display("[%0t] Estado FSM: 0x%02h", $time, debug_state);
end
```

### Monitor de Inicialización
```verilog
always @(posedge led_init_done) begin
    $display("[%0t] *** INICIALIZACIÓN COMPLETADA ***", $time);
end
```

### Monitor de Actividad
```verilog
always @(posedge led_activity) begin
    $display("[%0t] Actividad detectada - Datos recibidos: 0x%02h",
             $time, debug_pins);
end
```

## Uso del Testbench

### Compilar y Ejecutar

```bash
cd Proyecto_Paint/Conexion_PS2
make sim_quark
```

Esto ejecuta:
1. `iverilog` para compilar
2. `vvp` para ejecutar la simulación
3. `gtkwave` para visualizar las formas de onda

### Salidas Generadas

- `bench.vcd`: Archivo de formas de onda para GTKWave
- Mensajes en consola con timestamps de eventos

### Ejemplo de Salida en Consola

```
[370] Reset liberado
[370] Mouse PS/2: Reset liberado, esperando comandos...
[200000370] Mouse PS/2: Esperando comando RESET...
[203100000] PS2_WAIT_HOST_COMMAND: Host tomó control del clock
[203200000] PS2_WAIT_HOST_COMMAND: Comando recibido: 0xFF
[203200370] Mouse PS/2: RESET recibido, ejecutando BAT...
[203300370] PS2_SEND_BYTE: Enviando 0xFA (paridad=0)
[203900370] PS2_SEND_BYTE: Byte enviado completamente
[703900370] PS2_SEND_BYTE: Enviando 0xAA (paridad=1)
[704500370] Mouse PS/2: BAT completado (0xAA)
[704510370] PS2_SEND_BYTE: Enviando 0x00 (paridad=1)
...
```

## Verificación de Formas de Onda

Al abrir `bench.vcd` en GTKWave, puedes verificar:

### Señales a Observar

1. **ps2_clk** - Debe mostrar pulsos de ~60µs de período
2. **ps2_data** - Debe mostrar la trama PS/2 completa
3. **debug_state** - Debe transicionar por los estados:
   - 0x00: IDLE
   - 0x01: RESET_WAIT
   - 0x02: SEND_RESET
   - 0x03: WAIT_BAT
   - 0x04: WAIT_ID
   - 0x05: SEND_F4
   - 0x06: WAIT_F4_ACK
   - 0x07: STREAM_MODE

### Verificar una Trama PS/2

1. Localiza un byte enviado (ej: 0xFA = 11111010)
2. Verifica la secuencia en ps2_data:
   ```
   Start: 0
   Bit 0: 0
   Bit 1: 1
   Bit 2: 0
   Bit 3: 1
   Bit 4: 1
   Bit 5: 1
   Bit 6: 1
   Bit 7: 1
   Parity: 0 (paridad impar de 0xFA = 6 unos → par → paridad = 0)
   Stop: 1
   ```

## Duración de la Simulación

```verilog
#1000000000;  // 1 segundo
$finish;
```

La simulación se ejecuta por 1 segundo (1,000,000,000 ns), suficiente para:
- Completar el reset
- Realizar el BAT
- Inicializar el mouse
- Enviar varios paquetes de datos de prueba

## Notas Importantes

### Timing PS/2
- El clock PS/2 real opera entre 10-16.7 kHz
- Este testbench usa 16.7 kHz (60µs de período)
- Los datos cambian en el flanco de bajada del clock
- El host lee en el flanco de subida del clock

### Paridad Impar
```verilog
parity = ~^data;  // XOR de todos los bits, negado
```
Si hay un número par de '1's, la paridad debe ser '1' (para hacer impar el total).

### Alta Impedancia
```verilog
ps2_clk_tb = 1'bz;   // Liberar el bus
ps2_data_tb = 1'bz;
```
Cuando no se está transmitiendo, las líneas se ponen en alta impedancia para que los pullups las mantengan en '1'.

## Referencias

- [PS/2 Protocol Specification](https://web.archive.org/web/20180205132425/http://www.computer-engineering.org/ps2protocol/)
- Diagrama de flujo: `Diagrama de flujo comunicacion PS2.pdf`
- Conexiones: `CONEXIONES.md`
