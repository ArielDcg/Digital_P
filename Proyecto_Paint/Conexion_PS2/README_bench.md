# Testbench PS/2 - bench_quark.v

## Descripción

Este testbench simula un mouse PS/2 para probar el módulo `top_ps2_test.v`.

## Estructura del Código

### Parámetros

```verilog
parameter tck = 37;         // clock del sistema 27MHz
parameter clk_ps2 = 60000;  // clock PS/2 de 60us
```

### Señales Importantes

- `CLK`, `RST_N`: Clock y reset del sistema
- `ps2_clk`, `ps2_data`: Líneas PS/2 bidireccionales
- `ps2_clk_tb`, `ps2_data_tb`: Controles desde el testbench
- Señales de debug: `debug_state`, `debug_pins`, `led_init_done`, etc.

### Pullups

```verilog
assign (weak1, weak0) ps2_clk = 1'b1;
assign (weak1, weak0) ps2_data = 1'b1;
```

Simulan las resistencias pull-up que mantienen las líneas en alto cuando nadie las controla.

## Funciones Principales

### enviar_byte_ps2

Envía un byte del mouse al host siguiendo el protocolo PS/2.

**Secuencia:**
1. Baja el clock (toma control)
2. Envía start bit (0)
3. Envía 8 bits de datos (LSB primero)
4. Envía bit de paridad impar
5. Envía stop bit (1)
6. Libera las líneas

**Ejemplo:**
```verilog
enviar_byte_ps2(8'hFA);  // Enviar ACK
```

### recibir_cmd

Recibe un comando del host al mouse.

**Secuencia:**
1. Espera que el host baje el clock (inhibit)
2. Espera request-to-send (data = 0)
3. Espera que el host libere el clock
4. Lee start bit, 8 bits de datos, paridad y stop bit
5. Envía ACK

**Ejemplo:**
```verilog
reg [7:0] cmd;
recibir_cmd(cmd);
if (cmd == 8'hFF) // Reset
```

## Protocolo PS/2

### Formato de Trama (Device → Host)

```
START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | PARITY | STOP
  0   | LSB                            MSB |  impar |  1
```

- Cada bit dura 60µs (dos medios períodos de 30µs)
- Los datos cambian en flanco de bajada del clock
- El host lee en flanco de subida del clock

### Paridad Impar

```verilog
par = ~^dato;
```

Calcula XOR de todos los bits y lo niega. Si hay un número par de 1's, la paridad es 1.

**Ejemplo:**
- dato = 0xFA = 11111010 → 6 unos → par = 0
- dato = 0xFF = 11111111 → 8 unos → par = 0
- dato = 0xAA = 10101010 → 4 unos → par = 0

## Simulación del Mouse

El testbench simula la inicialización completa:

### 1. Espera después del reset
```verilog
wait(RST_N == 1);
#200000000;  // 200ms
```

### 2. Comando RESET (0xFF)
```
Host → Mouse: 0xFF
Mouse → Host: 0xFA (ACK)
Mouse → Host: 0xAA (BAT completion)
Mouse → Host: 0x00 (Device ID)
```

### 3. Enable Data Reporting (0xF4)
```
Host → Mouse: 0xF4
Mouse → Host: 0xFA (ACK)
```

### 4. Stream Mode

El mouse envía paquetes de 3 bytes:

**Byte 1: Estado**
```
Bit 7: Y overflow
Bit 6: X overflow
Bit 5: Y sign
Bit 4: X sign
Bit 3: Siempre 1
Bit 2: Botón medio
Bit 1: Botón derecho
Bit 0: Botón izquierdo
```

**Byte 2:** Movimiento X (8 bits con signo)
**Byte 3:** Movimiento Y (8 bits con signo)

**Ejemplo: Botón izquierdo + movimiento**
```verilog
enviar_byte_ps2(8'b00001001);  // Left=1, siempre1=1
enviar_byte_ps2(8'd5);         // X = +5
enviar_byte_ps2(8'd253);       // Y = -3 (en complemento a 2)
```

## Uso

### Compilar y simular

```bash
cd Proyecto_Paint/Conexion_PS2
make sim_quark
```

Esto ejecuta:
- `iverilog` para compilar
- `vvp` para simular
- `gtkwave` para ver las ondas

### Ver resultados

El archivo `bench.vcd` contiene las formas de onda. En GTKWave puedes ver:

- `ps2_clk`: Pulsos de clock de ~60µs
- `ps2_data`: Datos transmitidos
- `debug_state`: Estados de la FSM (0x00=IDLE, 0x07=STREAM_MODE, etc.)
- `debug_pins`: Últimos datos recibidos

## Tiempos Importantes

- Clock PS/2: 60µs por ciclo (30µs alto, 30µs bajo)
- Trama completa: 11 bits × 60µs = 660µs
- Espera POST: 200ms
- BAT: 500ms
- Delays entre bytes: 100-1000µs

## Notas

- Las líneas PS/2 son open-drain (necesitan pullups)
- Cuando `ps2_clk_tb = 1'bz`, el pullup mantiene la línea en 1
- El protocolo usa paridad IMPAR para detectar errores
- LSB se transmite primero en cada byte
