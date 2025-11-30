#!/bin/bash
################################################################################
# Script de simulación para MIT PS/2 Mouse @ 27MHz
# Uso: ./simulate.sh [opciones]
################################################################################

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo ""
echo "============================================================"
echo "  Simulación MIT PS/2 Mouse Interface @ 27MHz"
echo "  Target: Tang Primer 25K (Gowin GW5A-25)"
echo "============================================================"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "mit_ps2_mouse_interface.v" ]; then
    print_error "No se encuentra mit_ps2_mouse_interface.v"
    print_error "Ejecuta este script desde el directorio 'MIT approach'"
    exit 1
fi

# Verificar que Icarus Verilog está instalado
if ! command -v iverilog &> /dev/null; then
    print_error "Icarus Verilog (iverilog) no está instalado"
    echo "  Para instalar en Ubuntu/Debian: sudo apt-get install iverilog"
    exit 1
fi

print_success "Icarus Verilog encontrado: $(iverilog -V | head -n1)"

# Limpiar archivos anteriores
print_info "Limpiando archivos anteriores..."
rm -f simulation.vvp tb_mit_ps2_mouse_27mhz.vcd

# Compilar
print_info "Compilando diseño..."
if iverilog -g2012 -Wall -Winfloop \
    -o simulation.vvp \
    mit_ps2_mouse_interface.v \
    tb_mit_ps2_mouse_27mhz.v; then
    print_success "Compilación exitosa"
else
    print_error "Error en la compilación"
    exit 1
fi

# Simular
print_info "Ejecutando simulación..."
echo ""
if vvp simulation.vvp; then
    echo ""
    print_success "Simulación completada"
else
    print_error "Error en la simulación"
    exit 1
fi

# Verificar que se generó el VCD
if [ -f "tb_mit_ps2_mouse_27mhz.vcd" ]; then
    VCD_SIZE=$(du -h tb_mit_ps2_mouse_27mhz.vcd | cut -f1)
    print_success "Archivo VCD generado: tb_mit_ps2_mouse_27mhz.vcd ($VCD_SIZE)"

    # Preguntar si quiere abrir GTKWave
    if command -v gtkwave &> /dev/null; then
        echo ""
        read -p "¿Deseas abrir GTKWave para ver las formas de onda? (s/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            print_info "Abriendo GTKWave..."
            gtkwave tb_mit_ps2_mouse_27mhz.vcd &
        fi
    else
        print_warning "GTKWave no está instalado (opcional)"
        echo "  Para instalar: sudo apt-get install gtkwave"
        echo "  Puedes ver el VCD manualmente: gtkwave tb_mit_ps2_mouse_27mhz.vcd"
    fi
else
    print_warning "No se generó el archivo VCD"
fi

echo ""
echo "============================================================"
echo "  Simulación finalizada"
echo "============================================================"
echo ""
