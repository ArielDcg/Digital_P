# PS/2 Mouse Controller para Tang Primer 25K

Implementación de controlador PS/2 para mouse en Verilog, diseñado para la FPGA Tang Primer 25K (GW5A-LV25MG121NES).

## Archivos del Proyecto

- `ps2_mouse_init.v` - Módulo principal con FSM, transmisor y receptor PS/2
- `top_ps2_test.v` - Top module con conexiones e indicadores
- `ps2_mouse_constraints.cst` - Restricciones de pines para Tang Primer 25K
- `ps2_mouse.gprj` - Archivo de proyecto Gowin EDA
- `build.tcl` - Script TCL para síntesis automatizada
- `Makefile` - Automatización de build y programación

## Requisitos

### Software
- **Gowin EDA** (GOWIN FPGA Designer) - [Descargar aquí](https://www.gowinsemi.com/en/support/download_eda/)
- **openFPGALoader** (opcional, para programación CLI)
  ```bash
  sudo apt install openfpgaloader
  ```

### Hardware
- Tang Primer 25K (GW5A-LV25MG121NES)
- Mouse PS/2
- Adaptador PS/2 a pines
- Resistencias pull-up 4.7kΩ (x2) para PS/2 Clock y Data

## Síntesis y Programación

### Opción 1: Usando Makefile (CLI)

```bash
# Sintetizar el diseño
make synth

# Programar FPGA (volátil - se borra al apagar)
make program

# Programar Flash (persistente)
make program-flash

# Limpiar archivos generados
make clean
```

### Opción 2: Usando scripts directamente

```bash
# Síntesis con Gowin Shell
gw_sh build.tcl

# Programar con openFPGALoader
openFPGALoader -b tangprimer25k impl/pnr/project.fs
```

### Opción 3: GUI de Gowin EDA

1. Abrir **Gowin FPGA Designer**
2. `File > Open Project`
3. Seleccionar `ps2_mouse.gprj`
4. Verificar configuración:
   - Device: `GW5A-25A (GW5A-LV25MG121NES)`
   - Top module: `top_ps2_test`
5. Ejecutar: `Process > Run All` o hacer clic en el botón de síntesis
6. Programar: `Tools > Programmer`
   - Seleccionar archivo: `impl/pnr/project.fs`
   - Conectar Tang Primer 25K vía USB
   - Click en "Program"

## Conexiones Hardware

### Mouse PS/2 → Tang Primer 25K

| PS/2 Pin | Señal     | FPGA Pin | PMOD    | Notas                    |
|----------|-----------|----------|---------|--------------------------|
| 1        | Data      | A11      | PMOD1_2 | Pull-up 4.7kΩ a 3.3V    |
| 3        | GND       | GND      | -       | -                        |
| 4        | VCC (5V)  | 5V       | -       | Usar fuente externa     |
| 5        | Clock     | B10      | PMOD1_1 | Pull-up 4.7kΩ a 3.3V    |

### LEDs Indicadores

| LED   | Pin  | Señal           | Descripción                    |
|-------|------|-----------------|--------------------------------|
| LED1  | L14  | init_done       | Inicialización completa        |
| LED2  | L13  | rx_data_valid   | Dato recibido (parpadea)       |
| LED3  | N16  | debug_busy      | Transmisión activa             |
| LED4  | N15  | debug_ack       | ACK recibido del mouse         |

### Debug (Analizador Lógico)

Conectar al PMOD2 para monitorear `debug_state[7:0]`:

| Canal | Pin | Señal           |
|-------|-----|-----------------|
| CH0   | E10 | debug_state[0]  |
| CH1   | D10 | debug_state[1]  |
| CH2   | D11 | debug_state[2]  |
| CH3   | D12 | debug_state[3]  |
| CH4   | E12 | debug_state[4]  |
| CH5   | E13 | debug_state[5]  |
| CH6   | F13 | debug_state[6]  |
| CH7   | F12 | debug_state[7]  |

## Estados de la FSM

| Estado              | Valor | Descripción                          |
|---------------------|-------|--------------------------------------|
| STATE_IDLE          | 0x00  | Espera inicial                       |
| STATE_RESET_WAIT    | 0x01  | Esperando antes de reset             |
| STATE_SEND_RESET    | 0x02  | Enviando comando RESET (0xFF)        |
| STATE_WAIT_BAT      | 0x03  | Esperando BAT completion (0xAA)      |
| STATE_WAIT_ID       | 0x04  | Esperando Mouse ID (0x00)            |
| STATE_SEND_F4       | 0x05  | Enviando Enable Data Reporting (0xF4)|
| STATE_WAIT_F4_ACK   | 0x06  | Esperando ACK (0xFA)                 |
| STATE_STREAM_MODE   | 0x07  | Modo streaming - recibiendo datos    |

## Verificación

Después de programar:

1. **LED1 (init_done)** debe encenderse tras ~1 segundo
2. **LED2 (rx_data_valid)** debe parpadear al mover el mouse
3. Si LED1 no se enciende, revisar:
   - Conexiones PS/2 (especialmente GND)
   - Resistencias pull-up en Clock y Data
   - Alimentación del mouse (5V)

## Solución de Problemas

### Síntesis falla
```bash
# Verificar que todos los archivos existen
ls -l *.v *.cst *.gprj

# Limpiar y reintentar
make clean
make synth
```

### openFPGALoader no encuentra FPGA
```bash
# Verificar conexión USB
lsusb | grep Gowin

# Ejecutar con permisos
sudo openFPGALoader -b tangprimer25k impl/pnr/project.fs

# Agregar reglas udev (permanente)
sudo cp /usr/share/openFPGALoader/udev-rules/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### Mouse no responde
- Verificar voltaje: el mouse PS/2 necesita 5V
- Verificar pull-ups: 4.7kΩ son críticas para el protocolo PS/2
- Usar analizador lógico en PMOD2 para ver estados de FSM

## Características

✅ Código sintetizable (sin warnings de múltiples drivers)
✅ FSM con separación correcta de lógica secuencial/combinacional
✅ Protocolo PS/2 completo (host-to-device y device-to-host)
✅ Inicialización automática del mouse
✅ Señales de debug para análisis
✅ Compatible con Gowin EDA

## Licencia

Proyecto educativo - uso libre
