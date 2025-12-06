/*
 * Servo_Control.ino
 *
 * Ejemplo: Controlar servomotores con el mouse PS/2
 * - Movimiento X controla servo horizontal (pan)
 * - Movimiento Y controla servo vertical (tilt)
 * - Botones pueden activar/desactivar o resetear posición
 *
 * Conexiones:
 *   FPGA TX -> ESP32 GPIO16
 *   Servo X -> ESP32 GPIO25
 *   Servo Y -> ESP32 GPIO26
 */

#include <ESP32Servo.h>

// ============================================================================
// CONFIGURACIÓN
// ============================================================================

#define RXD2 16
#define TXD2 17
#define BAUD_RATE 115200

#define SERVO_X_PIN 25  // Servo horizontal (pan)
#define SERVO_Y_PIN 26  // Servo vertical (tilt)

// Límites de los servos
#define SERVO_MIN 0
#define SERVO_MAX 180
#define SERVO_CENTER 90

// Sensibilidad del mouse (ajustar según necesidad)
#define SENSITIVITY 2

// ============================================================================
// OBJETOS
// ============================================================================

Servo servoX;  // Servo horizontal
Servo servoY;  // Servo vertical

// ============================================================================
// VARIABLES
// ============================================================================

struct MouseData {
  int16_t x;
  int16_t y;
  bool leftButton;
  bool rightButton;
  bool middleButton;
};

MouseData mouseData;
uint8_t packetBuffer[6];
uint8_t bufferIndex = 0;
bool syncFound = false;

// Posiciones actuales de los servos
int servoXPos = SERVO_CENTER;
int servoYPos = SERVO_CENTER;

// Estados anteriores de botones para detectar clicks
bool lastLeftButton = false;
bool lastRightButton = false;
bool lastMiddleButton = false;

// ============================================================================
// FUNCIONES UART
// ============================================================================

void findSync() {
  while (Serial2.available() > 0) {
    uint8_t byte = Serial2.read();
    if (byte == 0xAA) {
      packetBuffer[0] = byte;
      bufferIndex = 1;
      syncFound = true;
      break;
    }
  }
}

bool readPacket() {
  while (Serial2.available() > 0 && bufferIndex < 6) {
    packetBuffer[bufferIndex] = Serial2.read();
    bufferIndex++;
  }

  if (bufferIndex == 6) {
    bufferIndex = 0;
    syncFound = false;
    return true;
  }
  return false;
}

void decodePacket() {
  uint8_t x_low = packetBuffer[1];
  uint8_t x_high = packetBuffer[2] & 0x01;
  uint8_t y_low = packetBuffer[3];
  uint8_t y_high = packetBuffer[4] & 0x01;
  uint8_t buttons = packetBuffer[5] & 0x07;

  int16_t x = (x_high << 8) | x_low;
  int16_t y = (y_high << 8) | y_low;

  if (x & 0x100) x = x - 512;
  if (y & 0x100) y = y - 512;

  mouseData.x = x;
  mouseData.y = y;
  mouseData.leftButton = (buttons & 0x01) != 0;
  mouseData.rightButton = (buttons & 0x02) != 0;
  mouseData.middleButton = (buttons & 0x04) != 0;
}

// ============================================================================
// FUNCIONES DE CONTROL
// ============================================================================

void updateServos() {
  // Actualizar posición basado en movimiento del mouse
  servoXPos += mouseData.x / SENSITIVITY;
  servoYPos -= mouseData.y / SENSITIVITY;  // Invertir Y para que sea más intuitivo

  // Limitar a rango válido
  servoXPos = constrain(servoXPos, SERVO_MIN, SERVO_MAX);
  servoYPos = constrain(servoYPos, SERVO_MIN, SERVO_MAX);

  // Mover servos
  servoX.write(servoXPos);
  servoY.write(servoYPos);

  // Mostrar posición si hay movimiento
  if (mouseData.x != 0 || mouseData.y != 0) {
    Serial.printf("Servos: X=%d° Y=%d°\n", servoXPos, servoYPos);
  }
}

void handleButtons() {
  // Botón izquierdo: Reset a centro
  if (mouseData.leftButton && !lastLeftButton) {
    Serial.println("🔄 RESET - Centrando servos");
    servoXPos = SERVO_CENTER;
    servoYPos = SERVO_CENTER;
    servoX.write(servoXPos);
    servoY.write(servoYPos);
  }

  // Botón derecho: Movimiento rápido (aumentar sensibilidad temporalmente)
  // (ya implementado en updateServos si se desea agregar modo turbo)

  // Botón medio: Mostrar posición actual
  if (mouseData.middleButton && !lastMiddleButton) {
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("📍 POSICIÓN ACTUAL");
    Serial.printf("   Servo X (Pan):  %d°\n", servoXPos);
    Serial.printf("   Servo Y (Tilt): %d°\n", servoYPos);
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  }

  // Actualizar estados
  lastLeftButton = mouseData.leftButton;
  lastRightButton = mouseData.rightButton;
  lastMiddleButton = mouseData.middleButton;
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  Serial2.begin(BAUD_RATE, SERIAL_8N1, RXD2, TXD2);

  // Configurar servos
  servoX.attach(SERVO_X_PIN);
  servoY.attach(SERVO_Y_PIN);

  // Centrar servos
  servoX.write(SERVO_CENTER);
  servoY.write(SERVO_CENTER);

  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.println("║     CONTROL DE SERVOS CON MOUSE PS/2                ║");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  Movimiento X → Servo horizontal (Pan)              ║");
  Serial.println("║  Movimiento Y → Servo vertical (Tilt)               ║");
  Serial.println("║  Botón izq.   → Reset a centro                      ║");
  Serial.println("║  Botón medio  → Mostrar posición                    ║");
  Serial.println("╚═══════════════════════════════════════════════════════╝");
  Serial.println();

  delay(1000);
}

// ============================================================================
// LOOP
// ============================================================================

void loop() {
  if (!syncFound) {
    findSync();
  }

  if (syncFound) {
    if (readPacket()) {
      decodePacket();
      updateServos();
      handleButtons();
    }
  }

  delay(10);  // Pequeño delay para suavizar movimiento
}
