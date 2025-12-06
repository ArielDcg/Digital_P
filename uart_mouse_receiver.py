#!/usr/bin/env python3
"""
uart_mouse_receiver.py
Programa para recibir datos del mouse PS/2 a través de UART desde la FPGA

Protocolo del paquete UART (6 bytes):
  Byte 0: 0xAA (Sincronización)
  Byte 1: X[7:0] (8 bits bajos de X)
  Byte 2: {7'b0, X[8]} (bit de signo de X)
  Byte 3: Y[7:0] (8 bits bajos de Y)
  Byte 4: {7'b0, Y[8]} (bit de signo de Y)
  Byte 5: {5'b0, buttons[2:0]} (botones: [Middle, Right, Left])

Uso:
  python3 uart_mouse_receiver.py /dev/ttyUSB0
  python3 uart_mouse_receiver.py COM3
"""

import serial
import sys
import struct
import time

class PS2MouseUARTReceiver:
    def __init__(self, port, baudrate=115200):
        """
        Inicializa el receptor UART

        Args:
            port: Puerto serial (ej: '/dev/ttyUSB0' o 'COM3')
            baudrate: Velocidad de transmisión (default: 115200)
        """
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.packet_count = 0

    def connect(self):
        """Conecta al puerto serial"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=1
            )
            print(f"✓ Conectado a {self.port} @ {self.baudrate} baud")
            return True
        except serial.SerialException as e:
            print(f"✗ Error al conectar: {e}")
            return False

    def find_sync(self):
        """Busca el byte de sincronización (0xAA)"""
        while True:
            byte = self.ser.read(1)
            if len(byte) == 0:
                continue
            if byte[0] == 0xAA:
                return True

    def read_packet(self):
        """
        Lee un paquete completo del mouse

        Returns:
            dict con keys: 'x', 'y', 'left', 'right', 'middle'
            None si hay error
        """
        # Buscar sincronización
        if not self.find_sync():
            return None

        # Leer los siguientes 5 bytes
        data = self.ser.read(5)

        if len(data) != 5:
            print("✗ Error: Paquete incompleto")
            return None

        # Decodificar datos
        x_low = data[0]
        x_high = data[1] & 0x01
        y_low = data[2]
        y_high = data[3] & 0x01
        buttons = data[4] & 0x07

        # Reconstruir valores de 9 bits con signo
        x = (x_high << 8) | x_low
        y = (y_high << 8) | y_low

        # Convertir a complemento a 2 si es necesario
        if x & 0x100:  # Si el bit de signo está activo
            x = x - 512  # 2^9 = 512

        if y & 0x100:
            y = y - 512

        # Decodificar botones
        left_btn = (buttons & 0x01) != 0
        right_btn = (buttons & 0x02) != 0
        middle_btn = (buttons & 0x04) != 0

        return {
            'x': x,
            'y': y,
            'left': left_btn,
            'right': right_btn,
            'middle': middle_btn,
            'raw_data': data
        }

    def display_packet(self, packet):
        """Muestra el paquete de forma legible"""
        self.packet_count += 1

        # Símbolos de dirección
        x_dir = "←" if packet['x'] < 0 else "→" if packet['x'] > 0 else "·"
        y_dir = "↓" if packet['y'] < 0 else "↑" if packet['y'] > 0 else "·"

        # Indicadores de botones
        btn_left = "■" if packet['left'] else "□"
        btn_right = "■" if packet['right'] else "□"
        btn_middle = "■" if packet['middle'] else "□"

        print(f"\n╔═══════════════════════════════════════════════════════╗")
        print(f"║  Paquete #{self.packet_count:<4}                                    ║")
        print(f"╠═══════════════════════════════════════════════════════╣")
        print(f"║  Posición X: {packet['x']:4d} {x_dir}                              ║")
        print(f"║  Posición Y: {packet['y']:4d} {y_dir}                              ║")
        print(f"╠═══════════════════════════════════════════════════════╣")
        print(f"║  Botones:                                            ║")
        print(f"║    Izquierdo:  {btn_left}                                        ║")
        print(f"║    Derecho:    {btn_right}                                        ║")
        print(f"║    Medio:      {btn_middle}                                        ║")
        print(f"╠═══════════════════════════════════════════════════════╣")
        print(f"║  Datos raw: {' '.join(f'{b:02X}' for b in packet['raw_data'])}              ║")
        print(f"╚═══════════════════════════════════════════════════════╝")

    def run(self):
        """Loop principal de recepción"""
        if not self.connect():
            return

        print("\n╔═══════════════════════════════════════════════════════╗")
        print("║        RECEPTOR UART - MOUSE PS/2                    ║")
        print("╠═══════════════════════════════════════════════════════╣")
        print("║  Esperando datos del mouse...                        ║")
        print("║  Presiona Ctrl+C para salir                          ║")
        print("╚═══════════════════════════════════════════════════════╝\n")

        try:
            while True:
                packet = self.read_packet()
                if packet:
                    self.display_packet(packet)
                else:
                    time.sleep(0.01)

        except KeyboardInterrupt:
            print("\n\n✓ Recepción detenida por el usuario")
        except Exception as e:
            print(f"\n✗ Error: {e}")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print("✓ Puerto serial cerrado")

def main():
    """Función principal"""
    if len(sys.argv) != 2:
        print("Uso: python3 uart_mouse_receiver.py <puerto>")
        print("\nEjemplos:")
        print("  Linux:   python3 uart_mouse_receiver.py /dev/ttyUSB0")
        print("  Windows: python3 uart_mouse_receiver.py COM3")
        print("  macOS:   python3 uart_mouse_receiver.py /dev/tty.usbserial-*")
        sys.exit(1)

    port = sys.argv[1]
    receiver = PS2MouseUARTReceiver(port)
    receiver.run()

if __name__ == "__main__":
    main()
