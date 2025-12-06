# Digital_P - Proyectos PS/2 Mouse (Estructura Modular)

## 🎯 Nuevo: Estructura Modular

Este proyecto ha sido reorganizado en una estructura modular para facilitar el desarrollo y mantenimiento.

## 📂 Estructura Actualizada

```
Digital_P/
├── PS2_Mouse_Projects/          # ← NUEVO: Proyectos modulares
│   ├── common/                  # Módulos compartidos
│   │   └── ps2_mouse_init.v    # Controlador PS/2
│   ├── PS2_to_Screen/          # Proyecto 1: Mouse → LED Panel
│   │   ├── src/
│   │   ├── sim/
│   │   ├── constraints/
│   │   ├── synthesis/
│   │   ├── Makefile
│   │   └── README.md
│   ├── PS2_to_UART_ESP32/      # Proyecto 2: Mouse → ESP32
│   │   ├── fpga/
│   │   ├── esp32/
│   │   └── README.md
│   ├── Makefile                # Makefile principal
│   └── README.md               # Documentación principal
│
├── Proyecto_Paint/              # Proyecto original (preservado)
├── Calculadora/                 # Proyecto calculadora (preservado)
└── ... (otros archivos originales)
```

## 🚀 Comienzo Rápido

### Opción 1: Usar Proyectos Modulares (Recomendado)

```bash
cd PS2_Mouse_Projects

# Ver ayuda
make help

# Simular PS2_to_UART_ESP32
make uart-sim

# Simular PS2_to_Screen
make screen-sim

# Sintetizar todos
make screen-synth
make uart-synth
```

### Opción 2: Trabajar en Proyectos Individuales

```bash
# Proyecto PS2_to_UART_ESP32
cd PS2_Mouse_Projects/PS2_to_UART_ESP32/fpga
make help
make sim

# Proyecto PS2_to_Screen
cd PS2_Mouse_Projects/PS2_to_Screen
make help
make sim
```

## 📦 Proyectos Disponibles

### 1. PS2_to_UART_ESP32
**Descripción:** Envía datos del mouse PS/2 desde FPGA a ESP32 por UART

**Características:**
- ✅ Comunicación UART @ 115200 baud
- ✅ Programas Arduino completos para ESP32
- ✅ Servidor WiFi con dashboard web
- ✅ Control de servomotores
- ✅ Ejemplos de uso avanzados

**Hardware:** Mouse PS/2 + Tang Primer 25K + ESP32

**Documentación:** `PS2_Mouse_Projects/PS2_to_UART_ESP32/README.md`

### 2. PS2_to_Screen
**Descripción:** Muestra cursor del mouse en panel LED HUB75

**Características:**
- ✅ Panel LED 64x64 píxeles
- ✅ Color de 12 bits (4096 colores)
- ✅ Movimiento suave del cursor
- ✅ Detección de botones

**Hardware:** Mouse PS/2 + Tang Primer 25K + Panel LED HUB75

**Documentación:** `PS2_Mouse_Projects/PS2_to_Screen/README.md`

## 🔄 Migración desde Estructura Anterior

Si estabas usando la estructura anterior:

### Archivos Antiguos → Nuevos:
| Anterior | Nuevo |
|----------|-------|
| `ps2_mouse_to_uart.v` | `PS2_Mouse_Projects/PS2_to_UART_ESP32/fpga/src/` |
| `PS2_Mouse_UART_ESP32/` | `PS2_Mouse_Projects/PS2_to_UART_ESP32/esp32/` |
| `Proyecto_Paint/Conexion_PS2/ps2_mouse_init.v` | `PS2_Mouse_Projects/common/` |
| `Proyecto_Paint/Conexion_PS2/PS2_to_screen/` | `PS2_Mouse_Projects/PS2_to_Screen/src/` |

### Los archivos originales se mantienen intactos en:
- `Proyecto_Paint/`
- `Calculadora/`

## 📖 Documentación

### Documentación Principal:
- **Estructura Modular:** `PS2_Mouse_Projects/README.md` ⭐ EMPEZAR AQUÍ
- **Protocolo PS/2:** `PS2_Mouse_Projects/common/README.md`
- **PS2_to_UART_ESP32:** `PS2_Mouse_Projects/PS2_to_UART_ESP32/README.md`
- **PS2_to_Screen:** `PS2_Mouse_Projects/PS2_to_Screen/README.md`

### Documentación Original (Preservada):
- **README_PS2.md** - Protocolo PS/2 detallado
- **README_PS2_UART.md** - Sistema PS/2 a UART (original)

## 🛠️ Ventajas de la Estructura Modular

### ✅ Organización Clara:
- Cada proyecto tiene su propia carpeta
- Separación de código fuente, testbenches, constraints y síntesis
- Módulos comunes compartidos

### ✅ Makefiles Específicos:
- Makefile por proyecto con targets relevantes
- Makefile principal para gestión global
- Fácil compilación y simulación

### ✅ Scripts de Síntesis:
- Archivos .tcl específicos para cada proyecto
- Configuración automática de rutas
- Fácil integración con Gowin IDE

### ✅ Escalabilidad:
- Fácil agregar nuevos proyectos
- Reutilización de módulos comunes
- Mantenimiento simplificado

## 🎓 Tutoriales

### Cómo usar un proyecto:

```bash
# 1. Navegar al proyecto
cd PS2_Mouse_Projects/PS2_to_UART_ESP32/fpga

# 2. Ver ayuda
make help

# 3. Simular
make sim

# 4. Ver formas de onda
make wave

# 5. Sintetizar
make synth
```

### Cómo crear un nuevo proyecto:

```bash
# 1. Crear estructura
cd PS2_Mouse_Projects
mkdir -p MiNuevoProyecto/{src,sim,constraints,synthesis}

# 2. Copiar Makefile de referencia
cp PS2_to_UART_ESP32/fpga/Makefile MiNuevoProyecto/

# 3. Editar Makefile para tu proyecto

# 4. Reutilizar módulo PS/2
# En tu código Verilog:
# ../common/ps2_mouse_init.v

# 5. Actualizar Makefile principal
```

## 🔧 Requisitos

### Software:
- **Make** - Automatización de compilación
- **Icarus Verilog** - Simulación
- **GTKWave** - Visualización de formas de onda
- **Gowin IDE** - Síntesis para Tang Primer 25K
- **Arduino IDE** - Para proyectos con ESP32

### Hardware:
- **FPGA:** Tang Primer 25K (GW5A-LV25MG121NC1/I0)
- **Mouse:** PS/2 estándar
- **Adicional según proyecto:**
  - ESP32 Dev Board (para PS2_to_UART_ESP32)
  - Panel LED HUB75 (para PS2_to_Screen)

## 📝 Comandos Útiles

```bash
# Desde la raíz del proyecto
cd PS2_Mouse_Projects

# Ver información de proyectos
make info

# Compilar todos los proyectos
make compile-all

# Simular todos los proyectos
make sim-all

# Limpiar todos
make clean

# Proyecto específico
make screen-sim      # Simular PS2_to_Screen
make uart-synth      # Sintetizar PS2_to_UART_ESP32
make screen-wave     # Ver formas PS2_to_Screen
make uart-clean      # Limpiar PS2_to_UART_ESP32
```

## 💡 Notas Importantes

1. **Los proyectos originales NO han sido modificados** - están en `Proyecto_Paint/` y `Calculadora/`
2. **La nueva estructura es una reorganización modular** - todo el código funciona igual
3. **Se pueden usar ambas estructuras** - la antigua y la nueva coexisten
4. **Se recomienda usar la estructura modular** para nuevos desarrollos

## 📧 Soporte

Para problemas o preguntas:
1. Revisar `PS2_Mouse_Projects/README.md`
2. Revisar README específico de cada proyecto
3. Usar `make help` en cualquier Makefile

---

**Proyecto:** Digital_P
**Versión:** 2.0 (Modular)
**Fecha:** Diciembre 2025
**Mantenimiento:** Estructura modular compatible con versión anterior
