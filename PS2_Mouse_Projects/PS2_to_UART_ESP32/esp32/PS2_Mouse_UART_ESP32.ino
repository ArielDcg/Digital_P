/*
 * PS2_Mouse_UART_ESP32.ino
 *
 * Programa para ESP32 que recibe datos de un mouse PS/2 desde una FPGA vía UART
 *
 * Protocolo UART (6 bytes por paquete):
 *   Byte 0: 0xAA (Sincronización)
 *   Byte 1: X[7:0] (8 bits bajos de X)
 *   Byte 2: {7'b0, X[8]} (bit de signo de X)
 *   Byte 3: Y[7:0] (8 bits bajos de Y)
 *   Byte 4: {7'b0, Y[8]} (bit de signo de Y)
 *   Byte 5: {5'b0, buttons[2:0]} (botones)
 *
 * Conexiones:
 *   FPGA TX -> ESP32 RX (GPIO 16 por defecto)
 *   FPGA GND -> ESP32 GND
 *
 * Autor: Digital_P Project
 * Fecha: Diciembre 2025
 */

// ============================================================================
// CONFIGURACIÓN
// ============================================================================

// Pines UART (Serial2 en ESP32)
#define RXD2 16  // GPIO16 - Conectar a UART TX de la FPGA
#define TXD2 17  // GPIO17 - No usado por ahora

// Velocidad UART (debe coincidir con la FPGA)
#define BAUD_RATE 115200

// LED integrado para indicar actividad
#define LED_BUILTIN 2

// Configuración de depuración
#define DEBUG true  // Cambiar a false para desactivar mensajes de depuración

// ============================================================================
// ESTRUCTURA DE DATOS DEL MOUSE
// ============================================================================

struct MouseData {
  int16_t x;           // Posición X (-256 a +255)
  int16_t y;           // Posición Y (-256 a +255)
  bool leftButton;     // Botón izquierdo
  bool rightButton;    // Botón derecho
  bool middleButton;   // Botón medio
  uint32_t timestamp;  // Timestamp del paquete
};

// ============================================================================
// VARIABLES GLOBALES
// ============================================================================

MouseData mouseData;
uint32_t packetCount = 0;
uint32_t errorCount = 0;
unsigned long lastPacketTime = 0;

// Buffer para paquetes UART
uint8_t packetBuffer[6];
uint8_t bufferIndex = 0;
bool syncFound = false;

// ============================================================================
// FUNCIONES DE DECODIFICACIÓN
// ============================================================================

/**
 * Busca el byte de sincronización (0xAA)
 */
void findSync() {
  while (Serial2.available() > 0) {
    uint8_t byte = Serial2.read();

    if (byte == 0xAA) {
      packetBuffer[0] = byte;
      bufferIndex = 1;
      syncFound = true;

      if (DEBUG) {
        Serial.println("→ Sync byte found!");
      }
      break;
    }
  }
}

/**
 * Lee el resto del paquete (5 bytes después de sync)
 */
bool readPacket() {
  while (Serial2.available() > 0 && bufferIndex < 6) {
    packetBuffer[bufferIndex] = Serial2.read();
    bufferIndex++;
  }

  if (bufferIndex == 6) {
    // Paquete completo
    bufferIndex = 0;
    syncFound = false;
    return true;
  }

  return false;
}

/**
 * Decodifica el paquete y actualiza mouseData
 */
void decodePacket() {
  // Extraer bytes
  uint8_t x_low = packetBuffer[1];
  uint8_t x_high = packetBuffer[2] & 0x01;
  uint8_t y_low = packetBuffer[3];
  uint8_t y_high = packetBuffer[4] & 0x01;
  uint8_t buttons = packetBuffer[5] & 0x07;

  // Reconstruir valores de 9 bits
  int16_t x = (x_high << 8) | x_low;
  int16_t y = (y_high << 8) | y_low;

  // Convertir a complemento a 2 si es necesario
  if (x & 0x100) {  // Si bit de signo está activo
    x = x - 512;    // 2^9 = 512
  }

  if (y & 0x100) {
    y = y - 512;
  }

  // Actualizar estructura
  mouseData.x = x;
  mouseData.y = y;
  mouseData.leftButton = (buttons & 0x01) != 0;
  mouseData.rightButton = (buttons & 0x02) != 0;
  mouseData.middleButton = (buttons & 0x04) != 0;
  mouseData.timestamp = millis();

  packetCount++;
  lastPacketTime = millis();

  // Parpadear LED
  digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
}

/**
 * Muestra el paquete recibido en formato legible
 */
void displayPacket() {
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.printf("║  Paquete #%-4lu                                     ║\n", packetCount);
  Serial.println("╠═══════════════════════════════════════════════════════╣");

  // Símbolos de dirección
  const char* x_dir = (mouseData.x < 0) ? "←" : (mouseData.x > 0) ? "→" : "·";
  const char* y_dir = (mouseData.y < 0) ? "↓" : (mouseData.y > 0) ? "↑" : "·";

  Serial.printf("║  Posición X: %4d %-2s                               ║\n",
                mouseData.x, x_dir);
  Serial.printf("║  Posición Y: %4d %-2s                               ║\n",
                mouseData.y, y_dir);
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  Botones:                                            ║");
  Serial.printf("║    Izquierdo:  %s                                        ║\n",
                mouseData.leftButton ? "■" : "□");
  Serial.printf("║    Derecho:    %s                                        ║\n",
                mouseData.rightButton ? "■" : "□");
  Serial.printf("║    Medio:      %s                                        ║\n",
                mouseData.middleButton ? "■" : "□");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.printf("║  Datos raw: %02X %02X %02X %02X %02X %02X              ║\n",
                packetBuffer[0], packetBuffer[1], packetBuffer[2],
                packetBuffer[3], packetBuffer[4], packetBuffer[5]);
  Serial.println("╚═══════════════════════════════════════════════════════╝");
}

/**
 * Muestra estadísticas del sistema
 */
void displayStats() {
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.println("║              ESTADÍSTICAS DEL SISTEMA                ║");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.printf("║  Paquetes recibidos: %-8lu                       ║\n", packetCount);
  Serial.printf("║  Errores:            %-8lu                       ║\n", errorCount);
  Serial.printf("║  Tiempo activo:      %-8lu ms                   ║\n", millis());

  if (packetCount > 0) {
    float rate = (float)packetCount / (millis() / 1000.0);
    Serial.printf("║  Tasa de paquetes:   %.2f paq/s                    ║\n", rate);
  }

  Serial.println("╚═══════════════════════════════════════════════════════╝");
  Serial.println();
}

// ============================================================================
// FUNCIONES DE APLICACIÓN (EJEMPLOS DE USO)
// ============================================================================

/**
 * Ejemplo 1: Control de cursor virtual
 * Mantiene posición acumulada del cursor
 */
int32_t cursorX = 0;
int32_t cursorY = 0;

void updateCursor() {
  // Acumular movimiento
  cursorX += mouseData.x;
  cursorY += mouseData.y;

  // Limitar a rango (ejemplo: pantalla 1920x1080)
  cursorX = constrain(cursorX, 0, 1920);
  cursorY = constrain(cursorY, 0, 1080);

  if (DEBUG && (mouseData.x != 0 || mouseData.y != 0)) {
    Serial.printf("→ Cursor: (%ld, %ld)\n", cursorX, cursorY);
  }
}

/**
 * Ejemplo 2: Detectar eventos de clicks
 */
bool lastLeftButton = false;
bool lastRightButton = false;
bool lastMiddleButton = false;

void detectClicks() {
  // Click izquierdo
  if (mouseData.leftButton && !lastLeftButton) {
    Serial.println("🖱️  CLICK IZQUIERDO!");
    // Aquí puedes agregar tu código para manejar el click
  }

  // Click derecho
  if (mouseData.rightButton && !lastRightButton) {
    Serial.println("🖱️  CLICK DERECHO!");
  }

  // Click medio
  if (mouseData.middleButton && !lastMiddleButton) {
    Serial.println("🖱️  CLICK MEDIO!");
  }

  // Actualizar estados anteriores
  lastLeftButton = mouseData.leftButton;
  lastRightButton = mouseData.rightButton;
  lastMiddleButton = mouseData.middleButton;
}

/**
 * Ejemplo 3: Enviar datos por WiFi (preparado para implementar)
 */
void sendDataViaWiFi() {
  // TODO: Implementar envío por WiFi/MQTT/WebSocket
  // Ejemplo:
  // String json = "{\"x\":" + String(mouseData.x) +
  //               ",\"y\":" + String(mouseData.y) +
  //               ",\"left\":" + String(mouseData.leftButton) + "}";
  // mqttClient.publish("mouse/data", json);
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
  // Inicializar Serial USB para depuración
  Serial.begin(115200);
  delay(1000);  // Esperar a que se estabilice

  // Inicializar Serial2 para UART con FPGA
  Serial2.begin(BAUD_RATE, SERIAL_8N1, RXD2, TXD2);

  // Configurar LED
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  // Mensaje de inicio
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.println("║        ESP32 - RECEPTOR UART MOUSE PS/2              ║");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  Esperando datos del mouse desde FPGA...            ║");
  Serial.printf("║  Puerto UART: GPIO%d (RX)                            ║\n", RXD2);
  Serial.printf("║  Baud rate:   %lu                                 ║\n", (unsigned long)BAUD_RATE);
  Serial.println("╚═══════════════════════════════════════════════════════╝");
  Serial.println();

  // Limpiar buffer UART
  while (Serial2.available()) {
    Serial2.read();
  }
}

// ============================================================================
// LOOP PRINCIPAL
// ============================================================================

void loop() {
  // Si no hemos encontrado sync, buscarlo
  if (!syncFound) {
    findSync();
  }

  // Si tenemos sync, leer el resto del paquete
  if (syncFound) {
    if (readPacket()) {
      // Paquete completo recibido
      decodePacket();
      displayPacket();

      // Aplicar funciones de ejemplo
      updateCursor();
      detectClicks();

      // Descomentar para usar WiFi:
      // sendDataViaWiFi();
    }
  }

  // Timeout: si pasa mucho tiempo sin paquetes, reiniciar búsqueda
  if (syncFound && (millis() - lastPacketTime > 1000)) {
    Serial.println("⚠️  Timeout: Reiniciando búsqueda de sync...");
    syncFound = false;
    bufferIndex = 0;
    errorCount++;
  }

  // Mostrar estadísticas cada 30 segundos
  static unsigned long lastStatsTime = 0;
  if (millis() - lastStatsTime > 30000) {
    displayStats();
    lastStatsTime = millis();
  }

  // Pequeño delay para no saturar el CPU
  delay(1);
}
