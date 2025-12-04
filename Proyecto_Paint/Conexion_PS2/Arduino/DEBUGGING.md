# GUÍA DE DEBUGGING - Sistema Mouse PS/2

## 🔍 CHECKLIST DE VERIFICACIÓN PASO A PASO

### Fase 1: Hardware PS/2
```
□ Verificar pinout del conector PS/2:
  Pin 1 (DATA) → Cuadrado con ranura
  Pin 5 (CLK)  → Redondo
  
□ Medir voltajes:
  VCC = 3.3V ±0.3V
  CLK y DATA en reposo = 3.3V (pull-up)
  
□ Verificar resistencias pull-up:
  10kΩ en CLK y DATA (si no las tiene el mouse)
  
□ Probar continuidad de cables:
  Especialmente si usas adaptadores o cables largos
```

### Fase 2: ESP32 - Inicialización
```
□ Abrir Serial Monitor (115200 baud)

□ Verificar mensajes de inicio:
  ✓ "Inicializando mouse PS/2..."
  ✓ "Mouse PS/2 inicializado correctamente"
  ✓ "Device ID: 0x00"
  
□ Si aparece "Error inicializando mouse":
  → Ver sección "Problemas de Inicialización"
```

### Fase 3: ESP32 - Lectura de Datos
```
□ Mover el mouse lentamente
  
□ Debes ver en Serial Monitor:
  X: 5    Y: -3   L: 0    R: 0    M: 0
  X: 12   Y: 0    L: 1    R: 0    M: 0
  
□ Verificar:
  ✓ X e Y cambian al mover
  ✓ L cambia a 1 al hacer click izquierdo
  ✓ R cambia a 1 al hacer click derecho
  ✓ M cambia a 1 al hacer click en la rueda
  
□ Si no hay datos:
  → Ver sección "Sin Datos del Mouse"
```

### Fase 4: FPGA - Recepción UART
```
□ Programar FPGA con mouse_top.v

□ Conectar ESP32 TX → FPGA RX

□ Verificar LEDs:
  LED[5] debe reflejar la señal UART (parpadeos rápidos)
  LED[3] debe parpadear al mover el mouse
  
□ Si LED[4] (error) está encendido:
  → Ver sección "Errores de Checksum"
```

### Fase 5: FPGA - Funcionamiento
```
□ Al mover el mouse:
  LED[3] parpadea continuamente
  
□ Al hacer clicks:
  LED[0] = click izquierdo
  LED[1] = click derecho
  LED[2] = click medio
  
□ LED[4] debe estar apagado (sin errores)
```

---

## 🐛 PROBLEMAS COMUNES Y SOLUCIONES

### 1. Problemas de Inicialización

#### Síntoma: "Error inicializando mouse PS/2"

**Causas posibles:**

A) **Mouse no responde:**
```cpp
// Agregar debug en ps2_mouse_init():
Serial.println("Enviando RESET...");
ps2_write(0xFF);
delay(500);

uint8_t response = ps2_read();
Serial.print("Respuesta: 0x");
Serial.println(response, HEX);
```

Resultados:
- `0x00` o timeout → Cable desconectado o malo
- `0xFC` → Mouse ocupado, reintentar
- `0xFA` pero no `0xAA` después → Mouse defectuoso

B) **Timing incorrecto:**
```cpp
// Aumentar delays:
delay(1000);  // después de RESET
delay(100);   // entre comandos
```

C) **Interferencia eléctrica:**
- Usar cables más cortos (<50cm)
- Agregar capacitor 100nF entre VCC y GND cerca del mouse
- Alejar de fuentes de ruido (motores, WiFi)

---

### 2. Sin Datos del Mouse

#### Síntoma: Mouse inicializa OK pero no hay datos

**Test de interrupción:**
```cpp
void loop() {
  static uint32_t last_interrupt = 0;
  static uint32_t interrupt_count = 0;
  
  if (ps2_frame_ready) {
    interrupt_count++;
    last_interrupt = millis();
  }
  
  // Imprimir cada segundo
  static uint32_t last_print = 0;
  if (millis() - last_print > 1000) {
    Serial.print("Interrupciones/seg: ");
    Serial.println(interrupt_count);
    interrupt_count = 0;
    last_print = millis();
  }
}
```

Resultados:
- **0 interrupciones/seg:**
  → Clock no funciona
  → Verificar GPIO 18 con osciloscopio
  → Probar cambiar pin

- **< 10 interrupciones/seg:**
  → Mouse en modo sleep
  → Enviar comando wake-up

- **> 100 interrupciones/seg:**
  → Normal al mover el mouse

**Verificar buffer:**
```cpp
if (ps2_frame_ready) {
  ps2_frame_ready = false;
  
  Serial.print("Raw frame: 0x");
  Serial.println(ps2_raw_data, HEX);
  
  if (verify_ps2_frame(ps2_raw_data)) {
    uint8_t data_byte = (ps2_raw_data >> 1) & 0xFF;
    Serial.print("Data byte: 0x");
    Serial.println(data_byte, HEX);
  }
}
```

---

### 3. Datos Corruptos

#### Síntoma: Valores aleatorios o inconsistentes

**A) Error de paridad frecuente:**
```
Error: Paridad incorrecta
Error: Paridad incorrecta
```

Soluciones:
1. Agregar capacitores de filtrado (100nF)
2. Reducir longitud de cables
3. Bajar pull-up a 4.7kΩ
4. Verificar niveles lógicos con osciloscopio

**B) Bit 3 del byte 0 no es 1:**
```
Error: Byte 0 inválido (bit 3 no está en 1)
```

Causa: Desincronización del buffer de 3 bytes

Solución:
```cpp
// Agregar timeout de sincronización:
static uint32_t last_byte_time = 0;

if (ps2_frame_ready) {
  uint32_t now = millis();
  
  // Si pasaron >100ms, resetear buffer
  if (now - last_byte_time > 100) {
    buffer_index = 0;
  }
  
  last_byte_time = now;
  // ... resto del código
}
```

---

### 4. Errores de Checksum (FPGA)

#### Síntoma: LED[4] encendido en FPGA

**Debug en ESP32:**
```cpp
void send_to_fpga() {
  // ... preparar paquete ...
  
  // Imprimir antes de enviar
  Serial.print("TX: ");
  for (int i = 0; i < 5; i++) {
    Serial.print("0x");
    Serial.print(fpga_packet[i], HEX);
    Serial.print(" ");
  }
  Serial.println();
  
  Serial2.write(fpga_packet, 5);
}
```

Verificar:
- Byte 0 siempre debe ser `0xFF`
- Checksum = `B1 XOR B2 XOR B3`

**Test de loopback:**
```cpp
// Conectar RX y TX del ESP32 juntos
void loop() {
  if (Serial2.available()) {
    uint8_t byte = Serial2.read();
    Serial.print("Loopback: 0x");
    Serial.println(byte, HEX);
  }
}
```

Si loopback no funciona → Problema con Serial2

---

### 5. UART No Funciona

#### Síntoma: LED[5] de FPGA no parpadea

**A) Verificar niveles lógicos:**
```
ESP32 GPIO 17 (TX) debe estar en HIGH cuando idle
FPGA uart_rx debe estar en HIGH cuando idle
```

Medir con multímetro:
- Idle: ~3.3V
- Durante transmisión: 0-3.3V pulsante

**B) Verificar GND común:**
```
CRÍTICO: ESP32 y FPGA deben compartir GND
```

**C) Test de baudrate:**
```cpp
// En ESP32, enviar patrón conocido:
void loop() {
  Serial2.write(0x55); // 01010101 binario
  delay(100);
}
```

Con osciloscopio medir periodo de bits:
- Debería ser ~8.68 μs (115200 baud)
- Si es diferente, ajustar CLKS_PER_BIT en Verilog

---

### 6. Mouse Funciona Intermitentemente

#### Síntoma: Funciona por momentos, luego se detiene

**A) Watchdog en ESP32:**
```cpp
void loop() {
  // Agregar al inicio:
  yield();  // Dar tiempo a WiFi task
  
  // O deshabilitar WiFi:
  WiFi.mode(WIFI_OFF);
}
```

**B) Power brownout:**
```cpp
// Verificar voltaje:
float voltage = analogRead(A0) * (3.3 / 4095.0);
Serial.print("Voltaje: ");
Serial.println(voltage);
```

Si <3.0V → Mejorar fuente de alimentación

**C) Timeout del mouse:**
```cpp
// Enviar "keep-alive" cada 5 segundos:
static uint32_t last_keepalive = 0;

void loop() {
  if (millis() - last_keepalive > 5000) {
    ps2_write(0xEB); // Read Data
    last_keepalive = millis();
  }
}
```

---

### 7. Coordenadas Erróneas en FPGA

#### Síntoma: Cursor se mueve al revés o muy rápido

**A) Invertir ejes:**
```verilog
// En mouse_position_integrator:
wire signed [15:0] delta_x = {{8{mouse_dx[7]}}, mouse_dx};
wire signed [15:0] delta_y = -{{8{mouse_dy[7]}}, mouse_dy}; // Invertir Y
```

**B) Ajustar sensibilidad:**
```verilog
// Dividir movimiento:
wire signed [16:0] temp_x = $signed({1'b0, pos_x}) + (delta_x >>> 1); // /2
```

**C) Verificar extensión de signo:**
```cpp
// Debug en ESP32:
int8_t x = current_mouse_data.x_movement;
Serial.print("X signed: ");
Serial.print(x);
Serial.print(" (0x");
Serial.print((uint8_t)x, HEX);
Serial.println(")");
```

---

## 🔬 HERRAMIENTAS DE DIAGNÓSTICO

### Osciloscopio

**Señales clave a medir:**

1. **PS/2 Clock (GPIO 18):**
   - Frecuencia: 10-16 kHz
   - Duty cycle: ~50%
   - Niveles: 0V y 3.3V

2. **PS/2 Data (GPIO 19):**
   - Cambios sincronizados con CLK
   - Setup time: >5 μs antes de falling edge

3. **UART TX (GPIO 17):**
   - Baud rate: 115200 (8.68 μs/bit)
   - Idle: HIGH (3.3V)
   - Frame: 10 bits (1 start + 8 data + 1 stop)

### Analizador Lógico

**Configuración recomendada:**
- CH0: PS/2 CLK
- CH1: PS/2 DATA
- CH2: UART TX
- CH3: UART RX (FPGA)

**Triggers útiles:**
- PS/2: Falling edge en CLK
- UART: Falling edge en TX (start bit)

### Multímetro

**Mediciones básicas:**
1. VCC del mouse: 3.3V ±10%
2. Pull-ups: 10kΩ ±5%
3. Continuidad de cables
4. Voltaje de GPIO en idle: 3.3V

---

## 📊 VALORES DE REFERENCIA

### Tiempos PS/2 (microsegundos)
```
Clock period:     60-100 μs
Clock low:        30-50 μs
Clock high:       30-50 μs
Data setup:       5 μs (min)
Data hold:        5 μs (min)
```

### Tiempos UART (microsegundos @ 115200)
```
Bit period:       8.68 μs
Start bit:        8.68 μs
Data bit:         8.68 μs cada uno
Stop bit:         8.68 μs
Frame completo:   86.8 μs (10 bits)
```

### Rangos de datos
```
Mouse delta:      -128 a +127 (signed 8-bit)
Posición FPGA:    0 a 65535 (unsigned 16-bit)
Botones:          0 o 1 (cada uno)
```

---

## 🎯 PRUEBAS FUNCIONALES

### Test 1: Movimiento Básico
```
1. Mover mouse lentamente a la derecha
   → X debe ser positivo (+5 a +20)
   
2. Mover mouse lentamente a la izquierda
   → X debe ser negativo (-5 a -20)
   
3. Mover mouse arriba
   → Y debe cambiar (signo depende de tu sistema)
   
4. Mover mouse abajo
   → Y debe cambiar (opuesto a arriba)
```

### Test 2: Botones
```
1. Click izquierdo
   → L=1, R=0, M=0
   
2. Click derecho
   → L=0, R=1, M=0
   
3. Click rueda (si tiene)
   → L=0, R=0, M=1
   
4. Click izquierdo + derecho
   → L=1, R=1, M=0
```

### Test 3: Movimiento Rápido
```
1. Mover mouse muy rápido
   → Verificar que no se pierdan datos
   → LED[3] debe parpadear continuamente
   → No debe haber errores (LED[4]=OFF)
```

### Test 4: Precisión
```
1. Mover mouse 10cm en línea recta
2. Contar pulsos en FPGA
3. Repetir 10 veces
   → Variación <5% entre mediciones
```

---

## 📝 LOG DE DEBUGGING

**Plantilla para documentar problemas:**

```
FECHA: ___________
PROBLEMA: _________________________________________

HARDWARE:
□ Mouse modelo: ____________
□ ESP32 modelo: ____________
□ FPGA: Tang Primer 25K
□ Longitud cables: ___ cm

SÍNTOMAS:
_____________________________________________________

MENSAJES DE ERROR:
_____________________________________________________

MEDICIONES:
VCC mouse: _____ V
GPIO 18 (idle): _____ V
GPIO 19 (idle): _____ V
GPIO 17 (idle): _____ V

PRUEBAS REALIZADAS:
□ _______________________________________________
□ _______________________________________________
□ _______________________________________________

SOLUCIÓN:
_____________________________________________________
```

---

## 🚀 OPTIMIZACIONES AVANZADAS

### Para Mayor Confiabilidad

**1. Filtro digital en PS/2:**
```cpp
// Filtrar glitches cortos
#define DEBOUNCE_SAMPLES 3

uint8_t debounce_buffer[DEBOUNCE_SAMPLES];
uint8_t debounce_index = 0;

bool debounced_read(int pin) {
  debounce_buffer[debounce_index++] = digitalRead(pin);
  if (debounce_index >= DEBOUNCE_SAMPLES) debounce_index = 0;
  
  // Mayoría simple
  uint8_t count = 0;
  for (int i = 0; i < DEBOUNCE_SAMPLES; i++) {
    if (debounce_buffer[i]) count++;
  }
  return (count > DEBOUNCE_SAMPLES/2);
}
```

**2. Buffer circular en UART:**
```verilog
// En lugar de simple registro
reg [7:0] uart_buffer [0:15];
reg [3:0] wr_ptr, rd_ptr;
```

**3. CRC en lugar de checksum:**
```cpp
uint8_t crc8(uint8_t *data, uint8_t len) {
  uint8_t crc = 0;
  for (uint8_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t j = 0; j < 8; j++) {
      crc = (crc & 0x80) ? (crc << 1) ^ 0x07 : crc << 1;
    }
  }
  return crc;
}
```

---

¡Suerte con tu proyecto! 🎮
