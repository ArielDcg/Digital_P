/*
 * PS/2 Mouse Reader para ESP32/Arduino
 * Lee datos del mouse PS/2, verifica tramas y envía a FPGA
 * 
 * Conexiones:
 * PS/2 CLK  -> GPIO 18
 * PS/2 DATA -> GPIO 19
 * FPGA TX   -> GPIO 17 (Serial2)
 * 
 * Protocolo de salida a FPGA (UART 115200):
 * Byte 0: 0xFF (inicio de trama)
 * Byte 1: Botones (bit 0=L, bit 1=R, bit 2=M)
 * Byte 2: Movimiento X (signed)
 * Byte 3: Movimiento Y (signed)
 * Byte 4: Checksum
 */

// Pines del PS/2
#define PS2_CLK  18
#define PS2_DATA 19

// Variables globales
volatile uint8_t ps2_data = 0;
volatile uint8_t ps2_bit_count = 0;
volatile bool ps2_frame_ready = false;
volatile uint32_t ps2_raw_data = 0;

// Buffer para el mouse (3 bytes por paquete)
uint8_t mouse_buffer[3];
uint8_t buffer_index = 0;

// Estructura de datos del mouse
struct MouseData {
  int8_t x_movement;
  int8_t y_movement;
  bool left_button;
  bool right_button;
  bool middle_button;
  bool x_overflow;
  bool y_overflow;
  bool x_sign;
  bool y_sign;
};

MouseData current_mouse_data;

void setup() {
  // Inicializar comunicación serial con PC (debug)
  Serial.begin(115200);
  
  // Inicializar comunicación serial con FPGA
  Serial2.begin(115200, SERIAL_8N1, 16, 17); // RX=16, TX=17
  
  delay(1000);
  Serial.println("Inicializando mouse PS/2...");
  
  // Configurar pines PS/2
  pinMode(PS2_CLK, INPUT_PULLUP);
  pinMode(PS2_DATA, INPUT_PULLUP);
  
  // Esperar estabilización
  delay(500);
  
  // Inicializar mouse
  if (ps2_mouse_init()) {
    Serial.println("Mouse PS/2 inicializado correctamente");
  } else {
    Serial.println("Error inicializando mouse PS/2");
  }
  
  // Configurar interrupción en flanco de bajada del clock
  attachInterrupt(digitalPinToInterrupt(PS2_CLK), ps2_clock_isr, FALLING);
}

void loop() {
  // Si hay un byte completo del PS/2
  if (ps2_frame_ready) {
    ps2_frame_ready = false;
    
    // Verificar paridad y bits de frame
    if (verify_ps2_frame(ps2_raw_data)) {
      // Extraer el dato (bits 1-8)
      uint8_t data_byte = (ps2_raw_data >> 1) & 0xFF;
      
      // Agregar al buffer del mouse
      mouse_buffer[buffer_index++] = data_byte;
      
      // Si tenemos los 3 bytes del paquete del mouse
      if (buffer_index >= 3) {
        buffer_index = 0;
        
        // Procesar paquete del mouse
        if (parse_mouse_packet(mouse_buffer)) {
          // Mostrar datos en serial (debug)
          print_mouse_data();
          
          // Enviar datos a la FPGA
          send_to_fpga();
        }
      }
    } else {
      Serial.println("Error: Frame PS/2 inválido");
      buffer_index = 0; // Resetear buffer
    }
  }
  
  delay(1); // Pequeño delay
}

// Interrupción del clock PS/2
void IRAM_ATTR ps2_clock_isr() {
  static uint32_t temp_data = 0;
  
  // Leer bit de datos
  bool bit_value = digitalRead(PS2_DATA);
  
  // Almacenar bit
  temp_data |= (bit_value ? 1 : 0) << ps2_bit_count;
  ps2_bit_count++;
  
  // Frame completo: 1 start + 8 data + 1 parity + 1 stop = 11 bits
  if (ps2_bit_count >= 11) {
    ps2_raw_data = temp_data;
    ps2_frame_ready = true;
    ps2_bit_count = 0;
    temp_data = 0;
  }
}

// Verificar frame PS/2 (start bit, paridad, stop bit)
bool verify_ps2_frame(uint32_t frame) {
  // Start bit debe ser 0
  if (frame & 0x01) {
    Serial.println("Error: Start bit incorrecto");
    return false;
  }
  
  // Stop bit debe ser 1
  if (!(frame & 0x400)) {
    Serial.println("Error: Stop bit incorrecto");
    return false;
  }
  
  // Verificar paridad (bit 9)
  uint8_t data = (frame >> 1) & 0xFF;
  uint8_t parity_bit = (frame >> 9) & 0x01;
  
  // Contar bits en 1
  uint8_t count = 0;
  for (int i = 0; i < 8; i++) {
    if (data & (1 << i)) count++;
  }
  
  // Paridad impar: total de bits (data + parity) debe ser impar
  if (((count + parity_bit) & 0x01) == 0) {
    Serial.println("Error: Paridad incorrecta");
    return false;
  }
  
  return true;
}

// Parsear paquete del mouse (3 bytes)
bool parse_mouse_packet(uint8_t* packet) {
  // Byte 0: [Y ovf][X ovf][Y sign][X sign][1][Middle][Right][Left]
  uint8_t byte0 = packet[0];
  
  // Verificar bit 3 (siempre debe ser 1 en el primer byte)
  if (!(byte0 & 0x08)) {
    Serial.println("Error: Byte 0 inválido (bit 3 no está en 1)");
    return false;
  }
  
  // Extraer información del byte 0
  current_mouse_data.left_button = byte0 & 0x01;
  current_mouse_data.right_button = byte0 & 0x02;
  current_mouse_data.middle_button = byte0 & 0x04;
  current_mouse_data.x_sign = byte0 & 0x10;
  current_mouse_data.y_sign = byte0 & 0x20;
  current_mouse_data.x_overflow = byte0 & 0x40;
  current_mouse_data.y_overflow = byte0 & 0x80;
  
  // Bytes 1 y 2: Movimiento X e Y
  int16_t x_raw = packet[1];
  int16_t y_raw = packet[2];
  
  // Aplicar signo (extender signo de 9 bits)
  if (current_mouse_data.x_sign) {
    x_raw |= 0xFF00; // Extender signo negativo
  }
  if (current_mouse_data.y_sign) {
    y_raw |= 0xFF00; // Extender signo negativo
  }
  
  current_mouse_data.x_movement = (int8_t)x_raw;
  current_mouse_data.y_movement = (int8_t)y_raw;
  
  return true;
}

// Imprimir datos del mouse (debug)
void print_mouse_data() {
  Serial.print("X: ");
  Serial.print(current_mouse_data.x_movement);
  Serial.print("\tY: ");
  Serial.print(current_mouse_data.y_movement);
  Serial.print("\tL: ");
  Serial.print(current_mouse_data.left_button);
  Serial.print("\tR: ");
  Serial.print(current_mouse_data.right_button);
  Serial.print("\tM: ");
  Serial.println(current_mouse_data.middle_button);
}

// Enviar datos a la FPGA
void send_to_fpga() {
  // Preparar paquete para FPGA
  uint8_t fpga_packet[5];
  
  // Byte 0: Marcador de inicio
  fpga_packet[0] = 0xFF;
  
  // Byte 1: Estado de botones (bit 0=L, 1=R, 2=M)
  fpga_packet[1] = (current_mouse_data.left_button ? 0x01 : 0x00) |
                   (current_mouse_data.right_button ? 0x02 : 0x00) |
                   (current_mouse_data.middle_button ? 0x04 : 0x00);
  
  // Byte 2: Movimiento X (complemento a 2)
  fpga_packet[2] = (uint8_t)current_mouse_data.x_movement;
  
  // Byte 3: Movimiento Y (complemento a 2)
  fpga_packet[3] = (uint8_t)current_mouse_data.y_movement;
  
  // Byte 4: Checksum (XOR de bytes 1-3)
  fpga_packet[4] = fpga_packet[1] ^ fpga_packet[2] ^ fpga_packet[3];
  
  // Enviar a FPGA
  Serial2.write(fpga_packet, 5);
}

// Inicialización del mouse PS/2
bool ps2_mouse_init() {
  // Enviar comando RESET (0xFF)
  if (!ps2_write(0xFF)) {
    return false;
  }
  
  delay(500); // Esperar reset
  
  // Leer ACK (0xFA)
  uint8_t response = ps2_read();
  if (response != 0xFA) {
    Serial.print("No ACK después de reset: 0x");
    Serial.println(response, HEX);
    return false;
  }
  
  // Leer BAT result (0xAA)
  response = ps2_read();
  if (response != 0xAA) {
    Serial.print("BAT fallido: 0x");
    Serial.println(response, HEX);
    return false;
  }
  
  // Leer Device ID (0x00 para mouse estándar)
  response = ps2_read();
  Serial.print("Device ID: 0x");
  Serial.println(response, HEX);
  
  // Habilitar reporte de datos (0xF4)
  if (!ps2_write(0xF4)) {
    return false;
  }
  
  // Leer ACK
  response = ps2_read();
  if (response != 0xFA) {
    Serial.print("No ACK después de Enable: 0x");
    Serial.println(response, HEX);
    return false;
  }
  
  return true;
}

// Escribir un byte al PS/2
bool ps2_write(uint8_t data) {
  // Deshabilitar interrupciones
  detachInterrupt(digitalPinToInterrupt(PS2_CLK));
  
  // Request-to-Send
  pinMode(PS2_CLK, OUTPUT);
  digitalWrite(PS2_CLK, LOW);
  delayMicroseconds(100);
  
  pinMode(PS2_DATA, OUTPUT);
  digitalWrite(PS2_DATA, LOW); // Start bit
  
  pinMode(PS2_CLK, INPUT_PULLUP);
  
  // Calcular paridad
  uint8_t parity = 1;
  for (int i = 0; i < 8; i++) {
    if (data & (1 << i)) parity ^= 1;
  }
  
  // Enviar 8 bits de datos
  for (int i = 0; i < 8; i++) {
    while (digitalRead(PS2_CLK) == LOW); // Esperar clock alto
    while (digitalRead(PS2_CLK) == HIGH); // Esperar clock bajo
    
    digitalWrite(PS2_DATA, (data >> i) & 0x01);
  }
  
  // Enviar bit de paridad
  while (digitalRead(PS2_CLK) == LOW);
  while (digitalRead(PS2_CLK) == HIGH);
  digitalWrite(PS2_DATA, parity);
  
  // Stop bit
  while (digitalRead(PS2_CLK) == LOW);
  while (digitalRead(PS2_CLK) == HIGH);
  pinMode(PS2_DATA, INPUT_PULLUP);
  
  // Esperar ACK del dispositivo
  while (digitalRead(PS2_CLK) == LOW);
  while (digitalRead(PS2_CLK) == HIGH);
  bool ack = (digitalRead(PS2_DATA) == LOW);
  
  while (digitalRead(PS2_CLK) == LOW);
  
  // Rehabilitar interrupciones
  delay(20);
  attachInterrupt(digitalPinToInterrupt(PS2_CLK), ps2_clock_isr, FALLING);
  
  return ack;
}

// Leer un byte del PS/2 (modo polling, sin interrupciones)
uint8_t ps2_read() {
  uint32_t timeout = millis() + 1000;
  uint8_t data = 0;
  uint8_t bit_count = 0;
  
  while (bit_count < 11 && millis() < timeout) {
    // Esperar flanco de bajada del clock
    while (digitalRead(PS2_CLK) == HIGH && millis() < timeout);
    if (millis() >= timeout) break;
    
    // Leer bit
    if (bit_count > 0 && bit_count < 9) {
      data |= (digitalRead(PS2_DATA) ? 1 : 0) << (bit_count - 1);
    }
    
    bit_count++;
    
    // Esperar que el clock vuelva a alto
    while (digitalRead(PS2_CLK) == LOW && millis() < timeout);
  }
  
  return data;
}
