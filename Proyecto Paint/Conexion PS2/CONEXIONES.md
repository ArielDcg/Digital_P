# Diagrama de Conexiones - Tang Primer 25K + PS/2 Mouse + Analizador Lógico

## IMPORTANTE: Resistencias Pull-Up

✅ **NO NECESITAS RESISTENCIAS EXTERNAS**
La FPGA Tang Primer 25K tiene resistencias pull-up internas configurables.
Están activadas en el archivo de constraints con: `PULL_MODE=UP`

---

## 1. Conexión del Mouse PS/2 a la FPGA

### Pinout del conector PS/2 (vista frontal, mirando los pines hembra):
```
     ___
   /  6  \     1 = Data
  | 5   4 |    2 = NC (No Connect)
  | 3   2 |    3 = GND
  | 1     |    4 = VCC (+5V)
   \_____/     5 = Clock
               6 = NC (No Connect)
```

### Conexiones:

| Pin PS/2 | Señal      | Cable a FPGA  | Pin FPGA | Notas                          |
|----------|------------|---------------|----------|--------------------------------|
| Pin 1    | DATA       | → Cable       | C11      | Pull-up interna activada       |
| Pin 2    | NC         | -             | -        | No conectar                    |
| Pin 3    | GND        | → Cable       | GND      | Tierra común con FPGA          |
| Pin 4    | VCC        | → USB 5V      | -        | Alimentar desde laptop (USB)   |
| Pin 5    | CLOCK      | → Cable       | B12      | Pull-up interna activada       |
| Pin 6    | NC         | -             | -        | No conectar                    |

### ⚡ Alimentación del Mouse:
- **Opción 1 (Recomendada):** Usar adaptador USB-a-PS/2 conectado al laptop
- **Opción 2:** Conectar VCC del mouse al pin 5V de la Tang Primer 25K
- ⚠️ **IMPORTANTE:** GND del mouse DEBE estar conectado a GND de la FPGA

### 🔌 Esquema de conexión:
```
Mouse PS/2                 Tang Primer 25K
┌────────┐                 ┌──────────┐
│        │                 │          │
│  Data  ├─────────────────► C11      │ (con pull-up interna)
│        │                 │          │
│  Clock ├─────────────────► B12      │ (con pull-up interna)
│        │                 │          │
│  GND   ├─────────────────► GND      │
│        │                 │          │
│  VCC   ├───┐             └──────────┘
└────────┘   │
             │  USB 5V
             └─── Laptop USB

```

---

## 2. Conexión del Analizador Lógico

### Señales para monitorear el estado de la FSM (8 bits)

Conecta **8 canales del analizador lógico** a estos pines de la FPGA:

| Canal  | Pin FPGA | Señal          | Descripción           |
|--------|----------|----------------|-----------------------|
| CH 0   | A11      | debug_state[0] | Bit 0 del estado FSM  |
| CH 1   | A10      | debug_state[1] | Bit 1 del estado FSM  |
| CH 2   | B10      | debug_state[2] | Bit 2 del estado FSM  |
| CH 3   | C10      | debug_state[3] | Bit 3 del estado FSM  |
| CH 4   | E11      | debug_state[4] | Bit 4 del estado FSM  |
| CH 5   | D11      | debug_state[5] | Bit 5 del estado FSM  |
| CH 6   | C12      | debug_state[6] | Bit 6 del estado FSM  |
| CH 7   | D12      | debug_state[7] | Bit 7 del estado FSM  |
| GND    | GND      | GND            | Tierra común          |

### Señales adicionales opcionales (datos RX del mouse):

| Canal  | Pin FPGA | Señal          | Descripción           |
|--------|----------|----------------|-----------------------|
| CH 8   | E12      | debug_pins[0]  | Bit 0 datos recibidos |
| CH 9   | F12      | debug_pins[1]  | Bit 1 datos recibidos |
| CH 10  | F13      | debug_pins[2]  | Bit 2 datos recibidos |
| CH 11  | E13      | debug_pins[3]  | Bit 3 datos recibidos |
| CH 12  | B14      | debug_pins[4]  | Bit 4 datos recibidos |
| CH 13  | C14      | debug_pins[5]  | Bit 5 datos recibidos |
| CH 14  | D14      | debug_pins[6]  | Bit 6 datos recibidos |
| CH 15  | E14      | debug_pins[7]  | Bit 7 datos recibidos |

### Configuración del analizador lógico:
```
- Sample rate: 10 MHz (suficiente para PS/2 ~10-16 kHz)
- Trigger: Canal PS/2 Clock (flanco de bajada)
- Buffer: 1M samples mínimo
- Voltaje: 3.3V
```

---

## 3. LEDs de Indicación (en la FPGA)

Estos LEDs están en la placa Tang Primer 25K:

| LED   | Pin  | Señal         | Comportamiento                    |
|-------|------|---------------|-----------------------------------|
| LED 1 | L14  | led_init_done | 🟢 Se enciende al completar init  |
| LED 2 | L13  | led_activity  | 💚 Parpadea al recibir datos      |
| LED 3 | K14  | led_error     | 🔴 Error (no usado actualmente)   |

---

## 4. Diagrama completo de conexiones

```
                    ┌─────────────────────────────────────┐
                    │      Tang Primer 25K FPGA           │
                    │                                     │
Mouse PS/2          │  PS/2 Interface:                    │
┌────────┐          │  - B12 (ps2_clk)  ◄──── Pull-up    │
│ Data   ├──────────┼─►C11 (ps2_data) ◄──── Pull-up    │
│ Clock  ├──────────┼─►B12 (ps2_clk)                    │
│ GND    ├──────────┼─►GND                               │
└────────┘          │                                     │
    │               │  Debug State (FSM):                 │
    │ 5V USB        │  - A11-D12 (8 pines) ──────┐       │
    │               │                             │       │
    └─Laptop USB    │  Debug Data (RX):           │       │
                    │  - E12-E14 (8 pines) ──────┤       │
                    │                             │       │
                    │  LEDs:                      │       │
                    │  - L14 🟢 Init Done         │       │
                    │  - L13 💚 Activity          │       │
                    │  - K14 🔴 Error             │       │
                    └─────────────────────────────┼───────┘
                                                  │
                                                  │
                                          ┌───────▼───────┐
                                          │  Analizador   │
                                          │  Lógico       │
                                          │  CH0-CH15     │
                                          │  + GND        │
                                          └───────────────┘
```

---

## 5. Valores de los Estados de la FSM

Cuando observes en el analizador lógico, estos son los valores hex del estado:

| Estado (hex) | Estado (nombre)     | Descripción                          |
|--------------|---------------------|--------------------------------------|
| `0x00`       | STATE_IDLE          | Espera inicial (~100ms)              |
| `0x01`       | STATE_RESET_WAIT    | Preparando comando RESET             |
| `0x02`       | STATE_SEND_RESET    | Enviando RESET (0xFF) al mouse       |
| `0x03`       | STATE_WAIT_BAT      | Esperando BAT complete (0xAA)        |
| `0x04`       | STATE_WAIT_ID       | Esperando Mouse ID (0x00)            |
| `0x05`       | STATE_SEND_F4       | Enviando Enable Data (0xF4)          |
| `0x06`       | STATE_WAIT_F4_ACK   | Esperando ACK (0xFA)                 |
| `0x07`       | STATE_STREAM_MODE   | ✅ Mouse operativo, recibiendo datos |

---

## 6. Checklist de conexión

Antes de programar la FPGA:

- [ ] Mouse PS/2 conectado:
  - [ ] Data → C11
  - [ ] Clock → B12
  - [ ] GND → GND
  - [ ] VCC → 5V (USB laptop)

- [ ] Analizador lógico conectado:
  - [ ] CH0-CH7 → A11, A10, B10, C10, E11, D11, C12, D12
  - [ ] GND → GND común con FPGA

- [ ] Tang Primer 25K:
  - [ ] Conectada al laptop via USB-C
  - [ ] Botón RESET presionado (opcional para reset manual)

---

## 7. Secuencia de operación esperada

1. **Power-On:** LED1, LED2, LED3 apagados
2. **Init (1 segundo):** Analizador muestra transiciones 0x00→0x01→0x02→...
3. **Init Complete:** LED1 se enciende (estado = 0x07)
4. **Mouse activo:** LED2 parpadea al mover el mouse
5. **Analizador:** Muestra paquetes de 3 bytes cuando mueves el mouse

---

## 8. Troubleshooting

| Problema                     | Causa probable              | Solución                           |
|------------------------------|-----------------------------|------------------------------------|
| LED1 nunca se enciende       | Mouse no responde           | Verifica 5V y GND del mouse        |
| Estado se queda en 0x03      | No llega BAT (0xAA)         | Verifica conexión Data/Clock       |
| LED2 parpadea sin mover mouse| Ruido en líneas PS/2        | Verifica conexiones, usa cables cortos |
| Nada funciona                | FPGA no programada          | Ejecuta `make program`             |

---

**¡Listo para probar!** Ejecuta `make synth` y luego `make program` 🚀
