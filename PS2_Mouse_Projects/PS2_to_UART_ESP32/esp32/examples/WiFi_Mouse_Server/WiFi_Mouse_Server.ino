/*
 * WiFi_Mouse_Server.ino
 *
 * Ejemplo avanzado: Servidor WiFi que envía datos del mouse PS/2 a través de WebSocket
 * Los datos pueden ser visualizados en un navegador web en tiempo real
 *
 * Requiere:
 *   - Biblioteca ESPAsyncWebServer
 *   - Biblioteca AsyncTCP
 *
 * Instalación de bibliotecas:
 *   1. Arduino IDE -> Sketch -> Include Library -> Manage Libraries
 *   2. Buscar "ESPAsyncWebServer" y "AsyncTCP"
 *   3. Instalar ambas
 */

#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <AsyncTCP.h>

// ============================================================================
// CONFIGURACIÓN WiFi
// ============================================================================

const char* ssid = "TU_SSID";           // Cambiar por tu red WiFi
const char* password = "TU_PASSWORD";   // Cambiar por tu contraseña

// Crear servidor web en puerto 80
AsyncWebServer server(80);
AsyncWebSocket ws("/ws");

// ============================================================================
// CONFIGURACIÓN UART
// ============================================================================

#define RXD2 16
#define TXD2 17
#define BAUD_RATE 115200

// ============================================================================
// ESTRUCTURA DE DATOS
// ============================================================================

struct MouseData {
  int16_t x;
  int16_t y;
  bool leftButton;
  bool rightButton;
  bool middleButton;
  uint32_t timestamp;
};

MouseData mouseData;
uint8_t packetBuffer[6];
uint8_t bufferIndex = 0;
bool syncFound = false;

// Posición acumulada del cursor
int32_t cursorX = 960;  // Centro de 1920
int32_t cursorY = 540;  // Centro de 1080

// ============================================================================
// HTML + JavaScript para visualización
// ============================================================================

const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <title>PS/2 Mouse Monitor</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #1e1e1e;
      color: #ffffff;
      margin: 0;
      padding: 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    h1 {
      color: #4CAF50;
      text-align: center;
    }
    .container {
      max-width: 800px;
      width: 100%;
    }
    .info-panel {
      background-color: #2d2d2d;
      border-radius: 10px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.3);
    }
    .data-row {
      display: flex;
      justify-content: space-between;
      padding: 10px;
      border-bottom: 1px solid #444;
    }
    .data-label {
      font-weight: bold;
      color: #888;
    }
    .data-value {
      color: #4CAF50;
      font-family: monospace;
      font-size: 1.2em;
    }
    .button-indicator {
      display: inline-block;
      width: 30px;
      height: 30px;
      border-radius: 5px;
      background-color: #444;
      margin: 0 5px;
      transition: all 0.2s;
    }
    .button-indicator.active {
      background-color: #4CAF50;
      box-shadow: 0 0 10px #4CAF50;
    }
    #canvas {
      border: 2px solid #4CAF50;
      background-color: #000;
      cursor: none;
      margin: 20px 0;
    }
    .status {
      text-align: center;
      padding: 10px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    .status.connected {
      background-color: #4CAF50;
    }
    .status.disconnected {
      background-color: #f44336;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🖱️ PS/2 Mouse Monitor</h1>

    <div id="status" class="status disconnected">
      Desconectado
    </div>

    <div class="info-panel">
      <div class="data-row">
        <span class="data-label">Posición X:</span>
        <span class="data-value" id="posX">0</span>
      </div>
      <div class="data-row">
        <span class="data-label">Posición Y:</span>
        <span class="data-value" id="posY">0</span>
      </div>
      <div class="data-row">
        <span class="data-label">Movimiento ΔX:</span>
        <span class="data-value" id="deltaX">0</span>
      </div>
      <div class="data-row">
        <span class="data-label">Movimiento ΔY:</span>
        <span class="data-value" id="deltaY">0</span>
      </div>
      <div class="data-row">
        <span class="data-label">Botones:</span>
        <div>
          <span class="button-indicator" id="btnLeft" title="Izquierdo"></span>
          <span class="button-indicator" id="btnMiddle" title="Medio"></span>
          <span class="button-indicator" id="btnRight" title="Derecho"></span>
        </div>
      </div>
      <div class="data-row">
        <span class="data-label">Paquetes:</span>
        <span class="data-value" id="packetCount">0</span>
      </div>
    </div>

    <canvas id="canvas" width="800" height="600"></canvas>
  </div>

  <script>
    // WebSocket
    let ws;
    let cursorX = 400;
    let cursorY = 300;
    let packetCount = 0;

    // Canvas
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');

    // Conectar WebSocket
    function connectWebSocket() {
      ws = new WebSocket('ws://' + window.location.hostname + '/ws');

      ws.onopen = function() {
        document.getElementById('status').className = 'status connected';
        document.getElementById('status').textContent = 'Conectado';
        console.log('WebSocket conectado');
      };

      ws.onclose = function() {
        document.getElementById('status').className = 'status disconnected';
        document.getElementById('status').textContent = 'Desconectado';
        console.log('WebSocket desconectado, reconectando...');
        setTimeout(connectWebSocket, 2000);
      };

      ws.onmessage = function(event) {
        try {
          const data = JSON.parse(event.data);
          updateDisplay(data);
        } catch (e) {
          console.error('Error parsing message:', e);
        }
      };
    }

    // Actualizar visualización
    function updateDisplay(data) {
      // Actualizar valores
      document.getElementById('deltaX').textContent = data.dx;
      document.getElementById('deltaY').textContent = data.dy;

      // Actualizar posición del cursor
      cursorX += data.dx / 2;  // Escalar movimiento
      cursorY += data.dy / 2;

      // Limitar a canvas
      cursorX = Math.max(0, Math.min(800, cursorX));
      cursorY = Math.max(0, Math.min(600, cursorY));

      document.getElementById('posX').textContent = Math.floor(cursorX);
      document.getElementById('posY').textContent = Math.floor(cursorY);

      // Actualizar botones
      document.getElementById('btnLeft').className =
        data.left ? 'button-indicator active' : 'button-indicator';
      document.getElementById('btnMiddle').className =
        data.middle ? 'button-indicator active' : 'button-indicator';
      document.getElementById('btnRight').className =
        data.right ? 'button-indicator active' : 'button-indicator';

      // Contador
      packetCount++;
      document.getElementById('packetCount').textContent = packetCount;

      // Dibujar en canvas
      drawCanvas(data);
    }

    // Dibujar en canvas
    function drawCanvas(data) {
      // Dibujar trazo si botón izquierdo presionado
      if (data.left) {
        ctx.strokeStyle = '#4CAF50';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(cursorX - data.dx / 2, cursorY - data.dy / 2);
        ctx.lineTo(cursorX, cursorY);
        ctx.stroke();
      }

      // Dibujar cursor
      ctx.clearRect(cursorX - 12, cursorY - 12, 24, 24);  // Limpiar área del cursor
      ctx.fillStyle = data.left ? '#f44336' :
                      data.right ? '#2196F3' :
                      data.middle ? '#FFC107' : '#ffffff';
      ctx.beginPath();
      ctx.arc(cursorX, cursorY, 8, 0, 2 * Math.PI);
      ctx.fill();
      ctx.strokeStyle = '#000';
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // Iniciar
    connectWebSocket();
  </script>
</body>
</html>
)rawliteral";

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
  mouseData.timestamp = millis();

  // Actualizar posición del cursor
  cursorX += x;
  cursorY += y;
  cursorX = constrain(cursorX, 0, 1920);
  cursorY = constrain(cursorY, 0, 1080);
}

// ============================================================================
// FUNCIONES WebSocket
// ============================================================================

void onWebSocketEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
  if (type == WS_EVT_CONNECT) {
    Serial.printf("WebSocket client #%u connected\n", client->id());
  } else if (type == WS_EVT_DISCONNECT) {
    Serial.printf("WebSocket client #%u disconnected\n", client->id());
  }
}

void sendMouseData() {
  String json = "{";
  json += "\"dx\":" + String(mouseData.x) + ",";
  json += "\"dy\":" + String(mouseData.y) + ",";
  json += "\"x\":" + String(cursorX) + ",";
  json += "\"y\":" + String(cursorY) + ",";
  json += "\"left\":" + String(mouseData.leftButton ? "true" : "false") + ",";
  json += "\"right\":" + String(mouseData.rightButton ? "true" : "false") + ",";
  json += "\"middle\":" + String(mouseData.middleButton ? "true" : "false");
  json += "}";

  ws.textAll(json);
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  Serial2.begin(BAUD_RATE, SERIAL_8N1, RXD2, TXD2);

  // Conectar a WiFi
  Serial.println();
  Serial.println("Conectando a WiFi...");
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi conectado!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  // Configurar WebSocket
  ws.onEvent(onWebSocketEvent);
  server.addHandler(&ws);

  // Configurar servidor web
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html", index_html);
  });

  server.begin();
  Serial.println("Servidor web iniciado");
  Serial.println("Abre http://" + WiFi.localIP().toString() + " en tu navegador");
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
      sendMouseData();

      Serial.printf("Mouse: X=%d Y=%d [L:%d R:%d M:%d]\n",
                    mouseData.x, mouseData.y,
                    mouseData.leftButton, mouseData.rightButton, mouseData.middleButton);
    }
  }

  ws.cleanupClients();
  delay(1);
}
