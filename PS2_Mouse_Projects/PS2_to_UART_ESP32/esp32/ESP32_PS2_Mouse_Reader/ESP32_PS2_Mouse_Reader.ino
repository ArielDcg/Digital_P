/*
 * ESP32_PS2_Mouse_Reader.ino
 *
 * Lee datos del mouse PS/2 directamente desde la ESP32
 * y los transmite a la FPGA por UART
 *
 * Arquitectura:
 *   Mouse PS/2 → ESP32 (este programa) → UART → FPGA
 *
 * Conexiones PS/2:
 *   Mouse CLK  → ESP32 GPIO 36 (VP) + pull-up 10kΩ a 3.3V/5V
 *   Mouse DATA → ESP32 GPIO 39 (VN) + pull-up 10kΩ a 3.3V/5V
 *   Mouse VCC  → 5V
 *   Mouse GND  → GND
 *
 * IMPORTANTE: GPIO 36 y 39 NO tienen pull-ups internos
 *             Usar resistencias pull-up EXTERNAS de 10kΩ
 *
 * Conexiones UART:
 *   ESP32 TX (GPIO 17) → FPGA RX
 *   ESP32 GND → FPGA GND
 *
 * Autor: Digital_P Project
 * Fecha: Diciembre 2025
 */

//============================================================================
// CONFIGURACIÓN
//============================================================================

// Pines PS/2 (solo lectura desde ESP32)
// IMPORTANTE: GPIO 36 y 39 son input-only, requieren pull-ups EXTERNOS (10kΩ)
#define PS2_CLK_PIN  36  // GPIO36 (VP) - Reloj PS/2 (input only, sin pull-up interno)
#define PS2_DATA_PIN 39  // GPIO39 (VN) - Datos PS/2 (input only, sin pull-up interno)

// UART para comunicación con FPGA
#define UART_TX 17  // TX hacia FPGA
#define UART_RX 16  // RX desde FPGA (no usado)
#define BAUD_RATE 115200

// LED de debug
#define LED_BUILTIN 2

// Configuración
#define DEBUG true  // Activar mensajes de debug

//============================================================================
// PROTOCOLO PS/2 - CONSTANTES
//============================================================================

// Comandos PS/2
#define PS2_CMD_RESET      0xFF
#define PS2_CMD_ENABLE     0xF4
#define PS2_CMD_DISABLE    0xF5
#define PS2_CMD_SET_SAMPLE 0xF3

// Respuestas PS/2
#define PS2_RESP_ACK       0xFA
#define PS2_RESP_BAT_OK    0xAA
#define PS2_RESP_DEVICE_ID 0x00

// Estados de recepción PS/2
enum PS2State {
  PS2_IDLE,
  PS2_START_BIT,
  PS2_DATA_BITS,
  PS2_PARITY_BIT,
  PS2_STOP_BIT
};

//============================================================================
// VARIABLES GLOBALES
//============================================================================

// Datos del mouse
struct MouseData {
  int16_t dx;          // Movimiento X
  int16_t dy;          // Movimiento Y
  bool leftButton;
  bool rightButton;
  bool middleButton;
  bool xSign;
  bool ySign;
  bool xOverflow;
  bool yOverflow;
};

MouseData mouse;

// Estadísticas
uint32_t packetCount = 0;
uint32_t errorCount = 0;

// Estado de recepción PS/2
volatile uint8_t ps2_data_buffer = 0;
volatile uint8_t ps2_bit_count = 0;
volatile PS2State ps2_state = PS2_IDLE;
volatile bool ps2_data_ready = false;
volatile bool ps2_error = false;

// Buffer para paquetes del mouse (3 bytes)
uint8_t mouse_packet[3];
uint8_t packet_index = 0;

// Timing para timeout
unsigned long lastPacketTime = 0;
#define PACKET_TIMEOUT 1000  // 1 segundo

//============================================================================
// INTERRUPCIÓN PS/2
//============================================================================

void IRAM_ATTR ps2_clk_interrupt() {
  // Esta función se llama en cada flanco de bajada del reloj PS/2

  static uint8_t data_byte = 0;
  static uint8_t bit_count = 0;
  static bool parity_bit = false;

  bool data_bit = digitalRead(PS2_DATA_PIN);

  switch (ps2_state) {
    case PS2_IDLE:
      // Detectar start bit (debe ser 0)
      if (data_bit == 0) {
        ps2_state = PS2_DATA_BITS;
        data_byte = 0;
        bit_count = 0;
      }
      break;

    case PS2_DATA_BITS:
      // Leer 8 bits de datos (LSB primero)
      data_byte |= (data_bit << bit_count);
      bit_count++;

      if (bit_count == 8) {
        ps2_state = PS2_PARITY_BIT;
      }
      break;

    case PS2_PARITY_BIT:
      parity_bit = data_bit;

      // Verificar paridad impar
      uint8_t calculated_parity = 1;  // Empieza en 1 para paridad impar
      for (int i = 0; i < 8; i++) {
        if (data_byte & (1 << i)) {
          calculated_parity ^= 1;
        }
      }

      if (calculated_parity != parity_bit) {
        ps2_error = true;
        ps2_state = PS2_IDLE;
      } else {
        ps2_state = PS2_STOP_BIT;
      }
      break;

    case PS2_STOP_BIT:
      // Stop bit debe ser 1
      if (data_bit == 1) {
        ps2_data_buffer = data_byte;
        ps2_data_ready = true;
      } else {
        ps2_error = true;
      }
      ps2_state = PS2_IDLE;
      break;
  }
}

//============================================================================
// INICIALIZACIÓN PS/2
//============================================================================

void ps2_init() {
  // Configurar pines como entradas
  // NOTA: GPIO 36 y 39 NO tienen pull-ups internos
  // DEBES usar resistencias pull-up EXTERNAS de 10kΩ a 3.3V o 5V
  pinMode(PS2_CLK_PIN, INPUT);
  pinMode(PS2_DATA_PIN, INPUT);

  // Configurar interrupción en flanco de bajada del reloj
  attachInterrupt(digitalPinToInterrupt(PS2_CLK_PIN), ps2_clk_interrupt, FALLING);

  Serial.println("✓ PS/2 inicializado");
  Serial.println("⚠ IMPORTANTE: GPIO 36 y 39 requieren pull-ups EXTERNOS (10kΩ)");
}

//============================================================================
// LECTURA DE DATOS PS/2
//============================================================================

bool ps2_read_byte(uint8_t* data, uint32_t timeout_ms) {
  unsigned long start = millis();

  ps2_data_ready = false;
  ps2_error = false;

  while (!ps2_data_ready && !ps2_error) {
    if (millis() - start > timeout_ms) {
      return false;  // Timeout
    }
    yield();  // Permitir tareas de fondo
  }

  if (ps2_error) {
    errorCount++;
    return false;
  }

  *data = ps2_data_buffer;
  return true;
}

//============================================================================
// PROCESAMIENTO DE PAQUETES DEL MOUSE
//============================================================================

void process_mouse_packet() {
  // Verificar que el primer byte tenga el bit 3 en 1
  if (!(mouse_packet[0] & 0x08)) {
    if (DEBUG) {
      Serial.println("⚠ Byte 1 inválido (bit 3 != 1)");
    }
    packet_index = 0;
    return;
  }

  // Extraer datos del paquete
  uint8_t status = mouse_packet[0];
  uint8_t x_raw = mouse_packet[1];
  uint8_t y_raw = mouse_packet[2];

  // Status byte:
  // bit 0: Left button
  // bit 1: Right button
  // bit 2: Middle button
  // bit 3: Always 1
  // bit 4: X sign (1 = negative)
  // bit 5: Y sign (1 = negative)
  // bit 6: X overflow
  // bit 7: Y overflow

  mouse.leftButton = (status & 0x01) != 0;
  mouse.rightButton = (status & 0x02) != 0;
  mouse.middleButton = (status & 0x04) != 0;
  mouse.xSign = (status & 0x10) != 0;
  mouse.ySign = (status & 0x20) != 0;
  mouse.xOverflow = (status & 0x40) != 0;
  mouse.yOverflow = (status & 0x80) != 0;

  // Construir movimientos con signo (9 bits)
  mouse.dx = x_raw;
  mouse.dy = y_raw;

  // Aplicar signo (complemento a 2 de 9 bits)
  if (mouse.xSign) {
    mouse.dx = (int16_t)x_raw - 256;
  }
  if (mouse.ySign) {
    mouse.dy = (int16_t)y_raw - 256;
  }

  // Enviar por UART a la FPGA
  send_to_fpga();

  // Mostrar en Serial Monitor si DEBUG
  if (DEBUG) {
    display_mouse_data();
  }

  packetCount++;
  lastPacketTime = millis();
  packet_index = 0;
}

//============================================================================
// TRANSMISIÓN UART A FPGA
//============================================================================

void send_to_fpga() {
  // Protocolo: 6 bytes
  // Byte 0: 0xAA (sincronización)
  // Byte 1: X[7:0] (8 bits bajos)
  // Byte 2: {7'b0, X[8]} (bit de signo)
  // Byte 3: Y[7:0] (8 bits bajos)
  // Byte 4: {7'b0, Y[8]} (bit de signo)
  // Byte 5: {5'b0, buttons[2:0]}

  uint8_t packet[6];

  packet[0] = 0xAA;  // Sync
  packet[1] = (uint8_t)(mouse.dx & 0xFF);  // X bajo
  packet[2] = mouse.xSign ? 0x01 : 0x00;   // X signo
  packet[3] = (uint8_t)(mouse.dy & 0xFF);  // Y bajo
  packet[4] = mouse.ySign ? 0x01 : 0x00;   // Y signo
  packet[5] = (mouse.leftButton ? 0x01 : 0x00) |
              (mouse.rightButton ? 0x02 : 0x00) |
              (mouse.middleButton ? 0x04 : 0x00);

  // Enviar por Serial2 (UART a FPGA)
  Serial2.write(packet, 6);

  // LED parpadeo
  digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
}

//============================================================================
// VISUALIZACIÓN EN SERIAL MONITOR
//============================================================================

void display_mouse_data() {
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.printf("║  Paquete #%-4lu                                     ║\n", packetCount);
  Serial.println("╠═══════════════════════════════════════════════════════╣");

  const char* x_dir = (mouse.dx < 0) ? "←" : (mouse.dx > 0) ? "→" : "·";
  const char* y_dir = (mouse.dy < 0) ? "↓" : (mouse.dy > 0) ? "↑" : "·";

  Serial.printf("║  Movimiento X: %4d %-2s                             ║\n", mouse.dx, x_dir);
  Serial.printf("║  Movimiento Y: %4d %-2s                             ║\n", mouse.dy, y_dir);
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  Botones:                                            ║");
  Serial.printf("║    Izquierdo:  %s                                        ║\n",
                mouse.leftButton ? "■" : "□");
  Serial.printf("║    Derecho:    %s                                        ║\n",
                mouse.rightButton ? "■" : "□");
  Serial.printf("║    Medio:      %s                                        ║\n",
                mouse.middleButton ? "■" : "□");

  if (mouse.xOverflow || mouse.yOverflow) {
    Serial.println("╠═══════════════════════════════════════════════════════╣");
    Serial.printf("║  ⚠ OVERFLOW: X:%s Y:%s                              ║\n",
                  mouse.xOverflow ? "Sí" : "No",
                  mouse.yOverflow ? "Sí" : "No");
  }

  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.printf("║  Raw bytes: %02X %02X %02X                              ║\n",
                mouse_packet[0], mouse_packet[1], mouse_packet[2]);
  Serial.println("╚═══════════════════════════════════════════════════════╝");
}

//============================================================================
// SETUP
//============================================================================

void setup() {
  // Serial USB para debug
  Serial.begin(115200);
  delay(1000);

  // Serial2 para UART con FPGA
  Serial2.begin(BAUD_RATE, SERIAL_8N1, UART_RX, UART_TX);

  // LED
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  // Mensaje de inicio
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════╗");
  Serial.println("║     ESP32 - LECTOR DE MOUSE PS/2 → UART → FPGA      ║");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  Arquitectura:                                       ║");
  Serial.println("║  Mouse PS/2 → ESP32 → UART → FPGA                   ║");
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.printf("║  PS/2 CLK:  GPIO%d (VP)  + pull-up 10kΩ            ║\n", PS2_CLK_PIN);
  Serial.printf("║  PS/2 DATA: GPIO%d (VN)  + pull-up 10kΩ            ║\n", PS2_DATA_PIN);
  Serial.printf("║  UART TX:   GPIO%d → FPGA RX                       ║\n", UART_TX);
  Serial.printf("║  Baud rate: %lu                                 ║\n", (unsigned long)BAUD_RATE);
  Serial.println("╠═══════════════════════════════════════════════════════╣");
  Serial.println("║  ⚠ GPIO 36/39 requieren pull-ups EXTERNOS           ║");
  Serial.println("╚═══════════════════════════════════════════════════════╝");
  Serial.println();

  // Inicializar PS/2
  ps2_init();

  Serial.println("✓ Esperando datos del mouse PS/2...");
  Serial.println();

  delay(100);
}

//============================================================================
// LOOP PRINCIPAL
//============================================================================

void loop() {
  // Verificar si hay un byte disponible del mouse
  uint8_t received_byte;

  if (ps2_read_byte(&received_byte, 100)) {  // Timeout 100ms

    // Acumular bytes del paquete (3 bytes)
    if (packet_index == 0) {
      // Primer byte: verificar bit 3
      if (received_byte & 0x08) {
        mouse_packet[packet_index++] = received_byte;
      }
      // Si no tiene bit 3, descartar (podría ser respuesta de inicialización)
    } else {
      mouse_packet[packet_index++] = received_byte;

      // Si tenemos 3 bytes, procesar paquete
      if (packet_index == 3) {
        process_mouse_packet();
      }
    }

  } else if (ps2_error) {
    if (DEBUG) {
      Serial.println("⚠ Error de paridad PS/2");
    }
    ps2_error = false;
  }

  // Timeout: resetear si pasa mucho tiempo sin paquetes
  if (packet_index > 0 && (millis() - lastPacketTime > PACKET_TIMEOUT)) {
    if (DEBUG) {
      Serial.println("⚠ Timeout - Reiniciando recepción");
    }
    packet_index = 0;
  }

  // Estadísticas cada 30 segundos
  static unsigned long lastStats = 0;
  if (millis() - lastStats > 30000) {
    Serial.println();
    Serial.println("╔═══════════════════════════════════════════════════════╗");
    Serial.println("║              ESTADÍSTICAS                            ║");
    Serial.println("╠═══════════════════════════════════════════════════════╣");
    Serial.printf("║  Paquetes enviados: %-8lu                       ║\n", packetCount);
    Serial.printf("║  Errores:           %-8lu                       ║\n", errorCount);
    Serial.printf("║  Tiempo activo:     %-8lu s                    ║\n", millis()/1000);
    Serial.println("╚═══════════════════════════════════════════════════════╝");
    Serial.println();
    lastStats = millis();
  }

  delay(1);
}
