# PS/2 Mouse UART para ESP32

## 📋 Descripción

Programas Arduino para ESP32 que reciben datos de un mouse PS/2 desde una FPGA vía UART y los procesan para diversas aplicaciones.

## 🔌 Conexiones Hardware

```
┌──────────┐         ┌─────────┐         ┌──────────┐
│  Mouse   │   PS/2  │  FPGA   │  UART   │  ESP32   │
│   PS/2   │ ──────► │ (Tang)  │ ──────► │ Arduino  │
└──────────┘         └─────────┘         └──────────┘
```

### Conexión FPGA ↔ ESP32

| FPGA       | ESP32      | Descripción           |
|------------|------------|-----------------------|
| UART TX    | GPIO 16    | Transmisión de datos  |
| GND        | GND        | Tierra común          |

**IMPORTANTE:**
- La FPGA transmite a 3.3V (compatible con ESP32)
- Verificar que ambos dispositivos compartan tierra común
- La velocidad UART debe ser **115200 baud** en ambos lados

---

## 📁 Estructura del Proyecto

```
PS2_Mouse_UART_ESP32/
├── PS2_Mouse_UART_ESP32.ino       # Programa principal
├── examples/
│   ├── WiFi_Mouse_Server/          # Servidor web con WebSocket
│   │   └── WiFi_Mouse_Server.ino
│   └── Servo_Control/              # Control de servomotores
│       └── Servo_Control.ino
└── README.md                       # Esta documentación
```

---

## 🚀 Programa Principal

### PS2_Mouse_UART_ESP32.ino

Programa básico que recibe y muestra datos del mouse por el Serial Monitor.

**Características:**
- ✅ Recepción de paquetes UART de 6 bytes
- ✅ Decodificación de posición X, Y (9 bits con signo)
- ✅ Detección de 3 botones
- ✅ Monitor serial con formato visual
- ✅ Cursor virtual acumulativo
- ✅ Detección de clicks
- ✅ Estadísticas del sistema

**Uso:**
1. Abrir `PS2_Mouse_UART_ESP32.ino` en Arduino IDE
2. Seleccionar placa: **ESP32 Dev Module**
3. Seleccionar puerto COM correcto
4. Subir el programa
5. Abrir Serial Monitor (115200 baud)
6. Mover el mouse PS/2 conectado a la FPGA

**Salida esperada:**
```
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
║  Datos raw: AA 0A 00 FB 01 01                        ║
╚═══════════════════════════════════════════════════════╝
```

---

## 📡 Ejemplo: Servidor WiFi

### WiFi_Mouse_Server.ino

Crea un servidor web que muestra los datos del mouse en tiempo real en un navegador.

**Características:**
- 🌐 Servidor web asíncrono
- 📊 Dashboard HTML5 interactivo
- 🔄 WebSocket para comunicación en tiempo real
- 🎨 Canvas para dibujar con el mouse
- 📱 Responsive (funciona en móviles)

**Instalación de bibliotecas:**
```
Arduino IDE → Sketch → Include Library → Manage Libraries
Buscar e instalar:
  - ESPAsyncWebServer (por me-no-dev)
  - AsyncTCP (por me-no-dev)
```

**Configuración:**
```cpp
const char* ssid = "TU_SSID";         // Cambiar
const char* password = "TU_PASSWORD"; // Cambiar
```

**Uso:**
1. Configurar SSID y password
2. Subir el programa
3. Abrir Serial Monitor para ver la IP asignada
4. Abrir navegador en `http://IP_DE_ESP32`
5. Mover el mouse PS/2

**Características del dashboard:**
- Visualización en tiempo real de posición X, Y
- Indicadores visuales de botones
- Canvas de dibujo (botón izquierdo para dibujar)
- Contador de paquetes
- Cursor virtual

---

## 🤖 Ejemplo: Control de Servos

### Servo_Control.ino

Controla 2 servomotores (pan/tilt) con el mouse PS/2.

**Características:**
- 🔄 Servo X controlado por movimiento horizontal
- ↕️ Servo Y controlado por movimiento vertical
- 🎯 Reset a posición central con botón izquierdo
- 📍 Mostrar posición con botón medio
- ⚙️ Sensibilidad ajustable

**Conexiones adicionales:**

| ESP32   | Servo       |
|---------|-------------|
| GPIO 25 | Servo X (señal) |
| GPIO 26 | Servo Y (señal) |
| 5V      | VCC (servos) |
| GND     | GND (servos) |

**IMPORTANTE:** Para servos de alta corriente, usar fuente externa.

**Instalación de biblioteca:**
```
Arduino IDE → Sketch → Include Library → Manage Libraries
Buscar e instalar: ESP32Servo
```

**Configuración:**
```cpp
#define SENSITIVITY 2  // Ajustar sensibilidad (1-10)
```

**Uso:**
1. Conectar servos a GPIO 25 y 26
2. Subir el programa
3. Abrir Serial Monitor
4. Mover mouse para controlar servos
5. Click izquierdo para centrar
6. Click medio para ver posición actual

---

## ⚙️ Protocolo de Comunicación

### Formato del Paquete UART (6 bytes)

| Byte | Contenido | Descripción |
|------|-----------|-------------|
| 0 | `0xAA` | Sincronización |
| 1 | `X[7:0]` | 8 bits bajos de X |
| 2 | `X[8]` | Bit de signo de X |
| 3 | `Y[7:0]` | 8 bits bajos de Y |
| 4 | `Y[8]` | Bit de signo de Y |
| 5 | `buttons[2:0]` | Botones [M, R, L] |

### Decodificación en ESP32

```cpp
// Reconstruir valores de 9 bits
int16_t x = (x_high << 8) | x_low;
int16_t y = (y_high << 8) | y_low;

// Convertir a complemento a 2
if (x & 0x100) x = x - 512;
if (y & 0x100) y = y - 512;

// Extraer botones
bool left = (buttons & 0x01) != 0;
bool right = (buttons & 0x02) != 0;
bool middle = (buttons & 0x04) != 0;
```

---

## 🛠️ Solución de Problemas

### No se reciben datos

**Verificar:**
1. ✓ Conexión TX de FPGA → GPIO 16 de ESP32
2. ✓ GND común entre FPGA y ESP32
3. ✓ Baudrate 115200 en ambos lados
4. ✓ FPGA programada y funcionando
5. ✓ Mouse PS/2 conectado a la FPGA

**Comandos de diagnóstico:**
```cpp
// En setup(), agregar:
Serial.print("Bytes disponibles: ");
Serial.println(Serial2.available());
```

### Datos corruptos

**Posibles causas:**
- Cable demasiado largo (usar < 30 cm)
- Interferencia electromagnética
- Baudrate incorrecto

**Solución:**
- Usar cable blindado
- Acortar conexión
- Verificar baudrate con osciloscopio

### WebSocket no conecta

**Verificar:**
1. ✓ ESP32 conectado a WiFi (ver Serial Monitor)
2. ✓ PC/móvil en la misma red WiFi
3. ✓ IP correcta en el navegador
4. ✓ Bibliotecas instaladas correctamente

---

## 💡 Ideas de Proyectos

### Proyectos Básicos
- 🖱️ Mouse inalámbrico (WiFi/Bluetooth)
- 🎮 Joystick virtual para juegos
- 📊 Monitor de actividad del mouse
- 🔔 Alarma por inactividad

### Proyectos Intermedios
- 🤖 Control de robot con mouse
- 📷 Control de cámara pan-tilt
- 🎨 Dibujo en matriz LED
- 🔊 Control de volumen/reproducción

### Proyectos Avanzados
- 🌐 Gateway IoT (MQTT, HTTP API)
- 🎯 Sistema de apuntado láser
- 🖥️ Control remoto de escritorio
- 🎮 Emulador de mouse USB

---

## 📚 Recursos Adicionales

### Documentación relacionada
- `README_PS2_UART.md` - Documentación completa del sistema
- `README_PS2.md` - Detalles del protocolo PS/2

### Referencias ESP32
- [Documentación oficial ESP32](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [ESP32Servo Library](https://github.com/madhephaestus/ESP32Servo)
- [ESPAsyncWebServer](https://github.com/me-no-dev/ESPAsyncWebServer)

---

## 🔧 Personalización

### Cambiar sensibilidad del cursor
```cpp
// En updateCursor():
cursorX += mouseData.x * 2;  // Multiplicar por factor (1-10)
cursorY += mouseData.y * 2;
```

### Cambiar pines UART
```cpp
#define RXD2 16  // Cambiar a pin deseado
#define TXD2 17  // Cambiar a pin deseado
```

### Agregar más funciones a botones
```cpp
void detectClicks() {
  if (mouseData.leftButton && !lastLeftButton) {
    // Tu código aquí
    digitalWrite(LED_PIN, HIGH);
  }
  // ... más código
}
```

---

## 📄 Licencia

Código abierto para uso educativo y comercial.

---

## ✉️ Soporte

Para problemas o preguntas:
1. Revisar esta documentación
2. Verificar conexiones hardware
3. Revisar Serial Monitor para mensajes de error
4. Consultar `README_PS2_UART.md` para detalles del sistema completo

---

**Versión:** 1.0
**Fecha:** Diciembre 2025
**Proyecto:** Digital_P
