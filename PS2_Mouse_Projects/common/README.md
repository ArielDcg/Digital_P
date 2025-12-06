# Módulo Común PS/2 Mouse

## 📋 Descripción

Este directorio contiene el módulo PS/2 compartido por todos los proyectos. El archivo `ps2_mouse_init.v` es el controlador principal del mouse PS/2.

## 📁 Archivos

| Archivo | Descripción |
|---------|-------------|
| `ps2_mouse_init.v` | Controlador completo del mouse PS/2 |

## 🔌 Interfaz del Módulo

### Puertos de Entrada:
```verilog
input  wire       clk         // Reloj del sistema (27 MHz)
input  wire       rst_n       // Reset asíncrono activo bajo
inout  wire       ps2_clk     // Reloj PS/2 (bidireccional)
inout  wire       ps2_data    // Datos PS/2 (bidireccional)
```

### Puertos de Salida:
```verilog
output wire [8:0] mouse_x      // Movimiento X (9 bits con signo)
output wire [8:0] mouse_y      // Movimiento Y (9 bits con signo)
output wire [2:0] buttons      // Botones [Middle, Right, Left]
output wire       packet_ready // Pulso cuando hay paquete válido
output wire       rx_error     // Error de paridad
output wire       init_done    // Inicialización completa
```

## 📊 Formato de Datos

### Movimientos X, Y (9 bits con signo):
- **Rango:** -256 a +255
- **Formato:** Complemento a 2
- **bit[8]:** Signo (0=positivo, 1=negativo)
- **bit[7:0]:** Magnitud

### Botones (3 bits):
- **bit[0]:** Botón izquierdo (1=presionado)
- **bit[1]:** Botón derecho (1=presionado)
- **bit[2]:** Botón medio (1=presionado)

## ⚙️ Parámetros Configurables

```verilog
parameter CLK_FREQ = 27_000_000;     // Frecuencia del reloj del sistema
parameter PS2_CLK_FREQ = 33_000;     // Frecuencia del reloj PS/2
```

## 🔄 Protocolo PS/2

### Inicialización:
1. Enviar comando `0xFF` (Reset)
2. Recibir `0xAA` (BAT successful)
3. Recibir `0x00` (Device ID)
4. Enviar comando `0xF4` (Enable Data Reporting)
5. Recibir `0xFA` (ACK)
6. Modo streaming (recepción continua de paquetes)

### Paquete de Datos (3 bytes):

**Byte 1: Status**
```
bit[7]: Y overflow
bit[6]: X overflow
bit[5]: Y sign
bit[4]: X sign
bit[3]: Always 1 (validación)
bit[2]: Middle button
bit[1]: Right button
bit[0]: Left button
```

**Byte 2:** Movimiento X (8 bits)
**Byte 3:** Movimiento Y (8 bits)

## 🔌 Conexiones Hardware

### Conector PS/2 (Mini-DIN 6):
```
  ___
 / 6 5 \
| 4   1 |
 \3___2/
```

| Pin | Señal | Descripción |
|-----|-------|-------------|
| 1 | DATA | Datos (bidireccional) |
| 2 | N/C | No conectado |
| 3 | GND | Tierra |
| 4 | VCC | +5V |
| 5 | CLK | Reloj (bidireccional) |
| 6 | N/C | No conectado |

### Resistencias Pull-up:
- **ps2_clk:** 10kΩ a VCC
- **ps2_data:** 10kΩ a VCC

### Level Shifter (si FPGA es 3.3V):
Si el mouse es 5V y la FPGA 3.3V, usar level shifter bidireccional.

## 📝 Ejemplo de Uso

```verilog
// Instanciar el módulo
ps2_mouse_init mouse_ctrl (
    .clk(clk_27mhz),
    .rst_n(reset_n),
    .ps2_clk(ps2_clk_pin),
    .ps2_data(ps2_data_pin),
    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .buttons(buttons),
    .packet_ready(new_packet),
    .rx_error(error),
    .init_done(initialized),
    .debug_state(),
    .debug_data(),
    .debug_busy(),
    .debug_ack(),
    .rx_data(),
    .rx_data_valid()
);

// Usar los datos
always @(posedge clk_27mhz) begin
    if (new_packet) begin
        // Procesar movimiento
        cursor_x <= cursor_x + mouse_x;
        cursor_y <= cursor_y + mouse_y;

        // Procesar botones
        if (buttons[0]) begin
            // Botón izquierdo presionado
        end
    end
end
```

## 🐛 Depuración

### Señales de Debug:
```verilog
output wire [7:0] debug_state    // Estado FSM
output wire [7:0] debug_data     // Datos en transmisión
output wire       debug_busy     // Transmisión activa
output wire       debug_ack      // ACK recibido
```

### Problemas Comunes:

**1. init_done nunca se activa:**
- Verificar resistencias pull-up
- Verificar conexiones ps2_clk y ps2_data
- Verificar alimentación del mouse (5V)

**2. rx_error activado frecuentemente:**
- Error de paridad - posible ruido
- Cables demasiado largos
- Interferencia electromagnética

**3. packet_ready no se activa:**
- Mouse no inicializado correctamente
- Verificar que bit[3] del status byte = 1

## 📚 Referencias

- Ver `../../README_PS2.md` para documentación completa del protocolo
- [PS/2 Protocol - Adam Chapweske](http://www.burtonsys.com/ps2_chapweske.htm)

---

**Nota:** Este módulo es compartido por todos los proyectos. Cualquier modificación afectará a todos los proyectos que lo usen.
