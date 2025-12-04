# 🚀 INICIO RÁPIDO - Mouse PS/2 a FPGA

## ⚡ Setup en 5 Minutos

### 1️⃣ Hardware (2 min)

**Conectar Mouse PS/2 a ESP32:**
```
Mouse Pin 5 (CLK)  → ESP32 GPIO 18
Mouse Pin 1 (DATA) → ESP32 GPIO 19
Mouse Pin 4 (VCC)  → ESP32 3.3V
Mouse Pin 3 (GND)  → ESP32 GND
```

**Conectar ESP32 a FPGA:**
```
ESP32 GPIO 17 (TX) → FPGA pin H11 (uart_rx)
ESP32 GND          → FPGA GND
```

### 2️⃣ Software ESP32 (2 min)

1. Abrir `ps2_mouse_to_fpga.ino` en Arduino IDE
2. Seleccionar placa: ESP32 Dev Module
3. Seleccionar puerto COM correcto
4. Click en "Upload"
5. Abrir Serial Monitor (115200 baud)

**Debes ver:**
```
Inicializando mouse PS/2...
Mouse PS/2 inicializado correctamente
Device ID: 0x00
```

### 3️⃣ Software FPGA (1 min)

1. Abrir Gowin IDE
2. Crear proyecto nuevo para Tang Primer 25K
3. Agregar `ps2_mouse_receiver.v`
4. Agregar `mouse_constraints.cst`
5. Compilar y programar

**Los LEDs deben:**
- LED[3]: Parpadear al mover mouse
- LED[0-2]: Encender con clicks
- LED[4]: Estar apagado (sin errores)

---

## ✅ Verificación Rápida

### Test 1: ESP32 Solo
```
1. Subir código al ESP32
2. Abrir Serial Monitor
3. Mover mouse
   ✓ Debes ver: X: ## Y: ## L: # R: # M: #
```

### Test 2: Sistema Completo
```
1. Programar FPGA
2. Conectar ESP32 TX a FPGA RX
3. Mover mouse
   ✓ LED[3] parpadea
4. Hacer clicks
   ✓ LED[0-2] encienden
```

---

## 🔧 Configuración por Defecto

**Pines ESP32:**
- CLK: GPIO 18
- DATA: GPIO 19
- TX a FPGA: GPIO 17

**FPGA:**
- Clock: 27 MHz
- UART RX: pin H11
- Baud rate: 115200

**Protocolo:**
- 5 bytes por paquete
- Header: 0xFF
- Checksum: XOR

---

## 📦 Archivos Incluidos

1. **ps2_mouse_to_fpga.ino** - Código ESP32/Arduino
2. **ps2_mouse_receiver.v** - Módulos Verilog para FPGA
3. **mouse_constraints.cst** - Pines para Tang Primer 25K
4. **README.md** - Documentación completa
5. **DIAGRAMA_SISTEMA.txt** - Diagrama del sistema
6. **DEBUGGING.md** - Guía de solución de problemas

---

## 🎯 Uso en Tu Proyecto

### Opción A: Solo Deltas (Simple)

```verilog
wire [7:0] dx, dy;
wire left, right, middle;
wire valid;

ps2_mouse_receiver receiver (
    .clk(clk_27mhz),
    .rst_n(rst_n),
    .uart_rx(uart_rx_pin),
    .mouse_x(dx),
    .mouse_y(dy),
    .mouse_left(left),
    .mouse_right(right),
    .mouse_middle(middle),
    .data_valid(valid),
    .error_flag()
);

// Usar dx, dy cuando valid = 1
always @(posedge clk_27mhz) begin
    if (valid) begin
        // dx y dy son signed 8-bit
        // left, right, middle son 1 bit
    end
end
```

### Opción B: Con Posición Absoluta

```verilog
wire [15:0] pos_x, pos_y;

mouse_position_integrator integrator (
    .clk(clk_27mhz),
    .rst_n(rst_n),
    .mouse_dx(dx),
    .mouse_dy(dy),
    .data_valid(valid),
    .pos_x(pos_x),
    .pos_y(pos_y),
    .max_x(16'd639),    // Ajustar a tu resolución
    .max_y(16'd479)
);

// pos_x y pos_y son coordenadas absolutas
```

---

## ⚠️ Si Algo No Funciona

### Problema: "Error inicializando mouse PS/2"
→ Verificar conexiones CLK y DATA
→ Probar con otro mouse
→ Ver DEBUGGING.md sección 1

### Problema: No hay datos en Serial Monitor
→ Verificar interrupciones funcionan
→ Ver DEBUGGING.md sección 2

### Problema: LED[4] encendido en FPGA
→ Error de checksum
→ Verificar GND común ESP32-FPGA
→ Ver DEBUGGING.md sección 4

### Problema: Coordenadas incorrectas
→ Ajustar sensibilidad
→ Invertir ejes si es necesario
→ Ver DEBUGGING.md sección 7

---

## 📊 Valores Típicos

**Movimiento lento:**
- X, Y: ±5 a ±15 por paquete
- Frecuencia: ~60 paquetes/segundo

**Movimiento rápido:**
- X, Y: ±50 a ±127 por paquete
- Frecuencia: ~100 paquetes/segundo

**Reposo:**
- X, Y: 0
- Frecuencia: 0 paquetes/segundo (no envía)

---

## 🎮 Próximos Pasos

1. **Integrar con pantalla:**
   - Usar pos_x, pos_y para dibujar cursor
   - Ejemplo: VGA 640x480

2. **Agregar aceleración:**
   - Multiplicar deltas grandes
   - Suavizar movimiento

3. **Implementar GUI:**
   - Detectar clicks en botones
   - Menús interactivos

4. **Soporte scroll:**
   - Modificar para 4 bytes por paquete
   - Agregar wheel_delta

---

## 🔗 Referencias Rápidas

**Pinout PS/2 (vista desde frente):**
```
   6   5
  ┌─┴─┴─┐
  │ 4 3 │
  │ 2 1 │
  └─────┘

1 - DATA
2 - NC
3 - GND
4 - VCC
5 - CLK
6 - NC
```

**Formato de Paquete UART:**
```
[0xFF][Botones][Delta X][Delta Y][Checksum]
  ^       ^        ^         ^        ^
  |       |        |         |        XOR(B1^B2^B3)
  |       |        |         Signed 8-bit
  |       |        Signed 8-bit
  |       [0][0][0][0][0][M][R][L]
  Marcador
```

**Comandos PS/2 Útiles:**
```
0xFF - Reset
0xF4 - Enable Data Reporting
0xF5 - Disable Data Reporting
0xEB - Read Data (on demand)
0xE8 - Set Resolution
```

---

## 💡 Tips

1. Usar cables cortos (<50cm) para PS/2
2. Siempre conectar GND común entre dispositivos
3. Monitor Serial es tu amigo para debug
4. LEDs en FPGA muestran estado en tiempo real
5. Si mouse no funciona, probar con otro mouse PS/2

---

## 📞 ¿Necesitas Ayuda?

Consulta los archivos incluidos:
- **DEBUGGING.md** - Soluciones detalladas
- **README.md** - Documentación completa
- **DIAGRAMA_SISTEMA.txt** - Arquitectura visual

¡Disfruta tu proyecto! 🎉
