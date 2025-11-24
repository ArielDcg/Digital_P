# Proyecto Digital - Calculadora Basada en Hardware

## Integrantes del Equipo

| Nombre Completo | Identificación SIA |
|----------------|-------------------|
| [Nombre 1] | [ID 1] |
| [Nombre 2] | [ID 2] |
| [Nombre 3] | [ID 3] |

---

## Descripción General del Proyecto

Este proyecto implementa una calculadora completa basada en hardware digital, diseñada para ser implementada en FPGAs (Tang Nano 20K y Tang Primer 25K). El sistema utiliza un procesador RISC-V FemtoRV32 y múltiples periféricos especializados para operaciones aritméticas.

### Arquitectura del Sistema

El sistema está compuesto por:
- **Procesador**: FemtoRV32 (RISC-V de 32 bits)
- **Memoria**: BRAM para instrucciones y datos
- **Comunicación**: UART para interfaz serie
- **Periféricos Aritméticos**:
  - Multiplicador de 16 bits
  - Divisor de 16 bits
  - Raíz cuadrada de 16 bits
  - Conversor BIN ↔ BCD

### Hardware Objetivo
- **FPGA**: Sipeed Tang Primer 25K (Efinix Trion T20)
- **Frecuencia de reloj**: 50 MHz
- **Comunicación**: UART 115200 baudios

---

## 1. Multiplicador de 16 bits

### Especificaciones Iniciales

El multiplicador implementa el algoritmo de multiplicación por sumas y desplazamientos (shift-and-add), procesando dos operandos de 16 bits para generar un resultado de 32 bits.

**Características:**
- Entradas: Dos operandos de 16 bits (op_A, op_B)
- Salida: Resultado de 32 bits
- Protocolo: Señales init/done para control de inicio y finalización
- Arquitectura: ASM (Algorithmic State Machine) con separación entre camino de datos y control

### Diagrama de Flujo del Algoritmo

![Diagrama de Flujo Multiplicador](Calculadora/modulos/mult/Diagrama%20de%20flujo%20multiplicador.pdf)

El algoritmo sigue estos pasos:
1. Inicialización: PP=0, DONE=0
2. Verificar LSB de B
3. Si LSB=1: PP = PP + A
4. Desplazar: A << 1, B >> 1
5. Verificar si B=0, si no, repetir desde paso 2
6. DONE = 1

### Diagrama de Bloques del Camino de Datos

![Camino de Datos Multiplicador](Calculadora/modulos/mult/Camino%20de%20datos%20multiplicador.pdf)

**Componentes principales:**
- **LSR (Left Shift Register)**: Desplaza A hacia la izquierda
- **RSR (Right Shift Register)**: Desplaza B hacia la derecha
- **ACC (Acumulador)**: Suma parcial de productos
- **COMP (Comparador)**: Verifica si B=0

### Diagrama de Estados de la Máquina de Control

![Máquina de Estados Multiplicador](Calculadora/modulos/mult/Maquina%20de%20estados%20multiplicador.pdf)

**Estados:**
- **START**: Inicialización del sistema, RESET=1
- **CHECK**: Verifica el LSB de B
- **ADD**: Suma A al acumulador si LSB=1
- **SHIFT**: Desplaza registros
- **END1**: Operación completada, DONE=1

### Código Fuente Sintetizable

#### Módulo Principal: mult.v
```verilog
module mult (
	input              reset,
	input              clk,
	// Control lines
	input              init,
	output reg         done,
	//
	output reg [31:0]  result,
	input      [15:0]  op_A,
	input      [15:0]  op_B
);

parameter START  = 3'b000;
parameter CHECK  = 3'b001;
parameter SHIFT  = 3'b010;
parameter ADD    = 3'b011;
parameter END    = 3'b100;
parameter START1 = 3'b101;

reg [2:0]  state;
reg [15:0] A;
reg [15:0] B;

initial begin
	result = 0;
	done   = 0;
end

reg [4:0] count;

always @(posedge clk or posedge reset)
begin
	if (reset) begin
		done   <= 0;
		result <= 0;
		state   = START;
	end else begin
		case(state)
			START: begin
				count  =  0;
				done   <= 0;
				result =  0;
				if(init)
					state = START1;
				else
					state = START;
			end

			START1:begin
				A      <= op_A;
				B      <= op_B;
				done   <= 0;
				result =  0;
				state  =  CHECK;
			end

			CHECK: begin
				if(B[0])
					state = ADD;
				else
					state = SHIFT;
			end

			SHIFT: begin
				B    = B >> 1;
				A    = A << 1;
				done = 0;
				if(B==0)
					state = END;
				else
					state = CHECK;
			end

			ADD: begin
				result <= result + A;
				done    = 0;
				state   = SHIFT;
			end

			END:begin
				done = 1;
				count = count + 1;
				state = (count>29) ? START : END ;
			end

			default: state = START;

		endcase
	end
end

endmodule
```

**Ubicación**: [`Calculadora/modulos/mult/mult.v`](Calculadora/modulos/mult/mult.v)

#### Periférico: perip_mult.v

El módulo periférico proporciona interfaz de registros mapeados en memoria para el CPU.

**Ubicación**: [`Calculadora/modulos/mult/perip_mult.v`](Calculadora/modulos/mult/perip_mult.v)

### Simulaciones

![Simulación Multiplicador](ruta/a/imagen/simulacion_mult.png)

> **Nota**: Agregar capturas de pantalla de las simulaciones realizadas con GTKWave o herramienta similar.

### Videos de Implementación

- [Video demostrando funcionamiento en FPGA](#)

> **Nota**: Agregar enlaces a videos mostrando el funcionamiento del multiplicador en la FPGA.

---

## 2. Divisor de 16 bits

### Especificaciones Iniciales

El divisor implementa el algoritmo de división por restauración, procesando dividendo y divisor de 16 bits para generar cociente y residuo.

**Características:**
- Entradas: Dividendo (op_A) y Divisor (op_B) de 16 bits
- Salida: Cociente de 16 bits (en result[15:0])
- Iteraciones: 16 ciclos
- Arquitectura: ASM con camino de datos y control separados

### Diagrama de Flujo del Algoritmo

![Diagrama de Flujo División](Calculadora/modulos/div/Diagrama%20de%20flujo%20Division.pdf)

**Pasos del algoritmo:**
1. Cargar DV (dividendo) y DR (divisor), count=N, A=0
2. Desplazar {A,DV} << 1, count--
3. Si A >= DR: DV[0]=1, A=A-DR
4. Si A < DR: DV[0]=0
5. Si count≠0, repetir desde paso 2
6. Resultado en DV (cociente) y A (residuo)

### Diagrama de Bloques del Camino de Datos

![Camino de Datos División](Calculadora/modulos/div/Camino%20de%20datos%20Division.pdf)

**Componentes:**
- **Registro A-DV**: Registro de 32 bits para dividendo extendido
- **Sumador/Restador C2**: Realiza A - DR
- **Comparador**: Verifica si el resultado es negativo
- **Contador descendente**: Controla las 16 iteraciones

### Diagrama de Estados de la Máquina de Control

![Máquina de Estados División](Calculadora/modulos/div/Maquina%20de%20estados%20Division.pdf)

**Estados:**
- **START**: Inicialización, carga de operandos
- **CHECK**: Verifica MSB del bit actual
- **SHIFT_DEC**: Desplaza y decrementa contador
- **ADD**: Actualiza bit de cociente según comparación
- **END1**: Operación completada

### Código Fuente Sintetizable

#### Módulo Principal: div.v
```verilog
module div (
	input              reset,
	input              clk,
	// Control lines
	input              init,
	output reg         done,
	//
	output reg [31:0]  result,
	input      [15:0]  op_A,
	input      [15:0]  op_B
);

parameter START          = 3'b000;
parameter CHECK_GREATER  = 3'b001;
parameter CHECK_END      = 3'b011;
parameter SHIFT          = 3'b010;
parameter END            = 3'b100;
parameter START1         = 3'b101;

reg  [2:0]  state;
reg  [31:0] A;
reg  [15:0] B;
reg  [15:0] opB;
wire [15:0] A_minus_B;

initial begin
	result = 0;
	done   = 0;
end
reg [4:0] count;

assign  A_minus_B = A[31:16] + (~B + 1) ;

always @(posedge clk or posedge reset)
begin
	if (reset) begin
		done   <= 0;
		result <= 0;
		state   = START;
	end else begin
		case(state)
			START: begin
				count  =  16;
				done   <= 0;
				result =  0;
				if(init)
					state = START1;
				else
					state = START;
			end

			START1:begin
				A      <= {16'b0,op_A};
				B      <= op_B;
				done   <= 0;
				result =  0;
				state  =  SHIFT;
			end

			SHIFT: begin
				A     = A << 1;
				count = count - 1;
				done  = 0;
				state = CHECK_GREATER;
			end

			CHECK_GREATER: begin
				if(A_minus_B[15])
					A[0]     = 0;
				else begin
					A[0]  = 1;
					A[31:16] = A_minus_B;
				end
				done  = 0;
				state = CHECK_END;
			end

			CHECK_END: begin
				if(count == 0) begin
					result[15:0] = A;
					state   = END;
				end
				else begin
					state   = SHIFT;
				end
			end

			END:begin
				done = 1;
				count = count + 1;
				state = (count>29) ? START : END ;
			end

			default: state = START;

		endcase
	end
end

endmodule
```

**Ubicación**: [`Calculadora/modulos/div/div.v`](Calculadora/modulos/div/div.v)

### Simulaciones

![Simulación Divisor](ruta/a/imagen/simulacion_div.png)

> **Nota**: Agregar capturas de pantalla de las simulaciones del divisor.

### Videos de Implementación

- [Video demostrando división en FPGA](#)

---

## 3. Raíz Cuadrada de 16 bits

### Especificaciones Iniciales

Implementación del algoritmo de raíz cuadrada por aproximaciones sucesivas (non-restoring square root).

**Características:**
- Entrada: Operando de 16 bits
- Salida: Raíz cuadrada de 16 bits
- Precisión: Resultado entero (parte entera de la raíz)
- Iteraciones: N/2 = 8 para 16 bits

### Diagrama de Flujo del Algoritmo

![Diagrama de Flujo SQRT](Calculadora/modulos/sqrt_ASM/Diagrama%20de%20flujo%20SQRT.pdf)

**Algoritmo:**
1. Inicializar: done=0, result=0, count=N/2, tmp=0, A={0,op_A}, R=0
2. Desplazar A << 2, R << 1, count--
3. tmp = R
4. Si A'' < (tmp << 1) + 1: R[0]=0
5. Si A'' >= (tmp << 1) + 1: R[0]=1, A''=A''-(tmp << 1)+1
6. Si count≠0, repetir desde paso 2
7. done=1, result=R

### Diagrama de Bloques del Camino de Datos

![Camino de Datos SQRT](Calculadora/modulos/sqrt_ASM/Camino%20de%20Datos%20SQRT.pdf)

**Componentes principales:**
- **LDA2**: Registro de doble desplazamiento para A
- **LSR R**: Registro de resultado
- **LSR TMP**: Registro temporal
- **SUM_C2**: Sumador/restador en complemento a 2
- **Contador**: Control de iteraciones

### Diagrama de Estados de la Máquina de Control

![Máquina de Estados SQRT](Calculadora/modulos/sqrt_ASM/Maquina%20de%20estados%20SQRT.pdf)

**Estados:**
- **START**: Inicialización
- **SHIFT_DEC**: Desplazamientos y decremento
- **LOAD_TMP**: Carga valor temporal
- **CHECK**: Verifica comparación
- **LOAD_A2**: Actualiza A según resultado
- **CHECK_Z**: Verifica fin de iteraciones
- **END1**: Completado

### Código Fuente Sintetizable

#### Módulo Principal: sqrt.v
```verilog
module sqrt(clk , rst , init , A , result , done);

  input         rst;
  input         clk;
  input         init;
  input  [15:0] A;
  output [15:0] result;
  output        done;

  wire w_sh;
  wire w_ld;
  wire w_lda2;
  wire w_ld_tmp;
  wire w_z;
  wire w_r0;

  wire [15:0] w_tmp;
  wire [15:0] w_lda_out;
  wire [15:0] w_lda2_in;

  lsr2 lsr20    (.clk(clk), .rst_ld(w_ld), .shift(w_sh), .lda2(w_lda2), .in_R1(A), .in_R2(w_lda2_in), .out_R(w_lda_out));
  lsr lsr_R     (.clk(clk), .reset(w_ld), .in_A(16'h0000),  .shift(w_sh), .load(1'b0),      .load_R0(w_lda2), .in_bit(w_r0), .out_r(result));
  lsr lsr_TMP   (.clk(clk), .reset(w_ld), .in_A(result),    .shift(1'b0), .load(w_ld_tmp) , .load_R0(1'b0),   .in_bit(1'b0), .out_r(w_tmp));
  addc2 addsub0 (.in_A(w_lda_out), .in_B({w_tmp[14:0], 1'b1}), .Result(w_lda2_in));
  count count0  (.clk(clk), .ld(w_ld) , .dec(w_sh), .z(w_z));
  control_sqrt control0 (.clk(clk), .rst(rst), .init(init), .msb(w_lda2_in[15]), .z(w_z), .done(done), .ld_tmp(w_ld_tmp), .r0(w_r0), .sh(w_sh), .ld(w_ld), .lda2(w_lda2));

endmodule
```

**Ubicación**: [`Calculadora/modulos/sqrt_ASM/sqrt.v`](Calculadora/modulos/sqrt_ASM/sqrt.v)

**Control**: [`Calculadora/modulos/sqrt_ASM/control.v`](Calculadora/modulos/sqrt_ASM/control.v)

### Simulaciones

![Simulación SQRT](ruta/a/imagen/simulacion_sqrt.png)

> **Nota**: Agregar capturas de simulación de raíz cuadrada.

### Videos de Implementación

- [Video demostrando SQRT en FPGA](#)

---

## 4. Conversor BCD a Binario

### Especificaciones Iniciales

Conversor de formato BCD (Binary Coded Decimal) a formato binario natural, utilizando el algoritmo Double Dabble inverso.

**Características:**
- Entrada: 20 bits BCD (5 dígitos decimales: 0-99999)
- Salida: 16 bits binarios (0-65535)
- Algoritmo: Desplazamiento con ajuste condicional
- Operación: Si nibble > 4, restar 3

### Diagrama de Flujo del Algoritmo

![Diagrama de Flujo BCD2BIN](Calculadora/modulos/bcd2bin/Diagrama%20de%20flujo%20BCD%202%20BIN.pdf)

**Pasos:**
1. Cargar BCD[19:0], Bin[15:0], N=16
2. Desplazar {BCD,Bin} >> 1, N--
3. Para cada nibble de BCD[i:i+3]:
   - Si nibble > 4: nibble = nibble - 3
4. Si N≠0, repetir desde paso 2
5. Resultado en Bin[15:0]

### Diagrama de Bloques del Camino de Datos

![Camino de Datos BCD2BIN](Calculadora/modulos/bcd2bin/Camino%20de%20Datos%20BCD%202%20BIN.pdf)

**Componentes:**
- **RSR4**: Registro de desplazamiento de 36 bits (BCD + BIN)
- **MUX**: Selecciona entre -3 (-5 en C2) o -11 según modo
- **SUM_C2**: 5 sumadores para los 5 nibbles BCD
- **REG_MSB**: Registro de bits más significativos
- **COUNT**: Contador de iteraciones

### Diagrama de Estados de la Máquina de Control

![Máquina de Estados BCD2BIN](Calculadora/modulos/bcd2bin/Maquina%20de%20Estados.pdf)

**Estados:**
- **START**: Inicialización, carga de entrada BCD
- **SHIFT_DEC**: Desplaza y decrementa contador
- **CHECK**: Verifica MSB de cada nibble
- **ADD**: Ajusta nibbles que son > 4
- **LOAD_BIN2**: Actualiza registro
- **DONE**: Operación completada

### Código Fuente Sintetizable

#### Módulo Principal: bcd2bin.v
```verilog
module bcd2bin(clk , rst , init , A , result , done);

  input         rst;
  input         clk;
  input         init;
  input  [19:0] A;
  output [15:0] result;
  output        done;

  wire w_sh;
  wire w_ld;
  wire w_sel;
  wire w_ld_msb;
  wire w_add;
  wire w_z;
  wire [4:0] w_LD;
  wire [4:0] w_MSB;

  wire [3:0] w_uni;
  wire [3:0] w_dec;
  wire [3:0] w_cen;
  wire [3:0] w_umi;
  wire [3:0] w_dmi;
  wire [19:0] w_ld_in;
  wire [19:0] w_MUX;

  assign w_MSB ={ w_ld_in[19], w_ld_in[15], w_ld_in[11], w_ld_in[7], w_ld_in[3] };

  rsr4 rsr40        ( .clk(clk), .rst_ld(w_ld), .shift(w_sh), .lda2(w_LD), .in_R1(A), .in_R2(w_ld_in), .out_R({w_dmi, w_umi, w_cen, w_dec, w_uni}), .out_R2(result) );
  mux mux0          ( .in1(4'b1101), .in2(4'b1011), .out(w_MUX[3:0]),   .sel(w_sel) );
  mux mux1          ( .in1(4'b1101), .in2(4'b1011), .out(w_MUX[7:4]),   .sel(w_sel) );
  mux mux2          ( .in1(4'b1101), .in2(4'b1011), .out(w_MUX[11:8]),  .sel(w_sel) );
  mux mux3          ( .in1(4'b1101), .in2(4'b1011), .out(w_MUX[15:12]), .sel(w_sel) );
  mux mux4          ( .in1(4'b1101), .in2(4'b1011), .out(w_MUX[19:16]), .sel(w_sel) );
  add_sub_c2 comp0  ( .in_A(w_uni), .in_B(w_MUX[3:0]),   .Result(w_ld_in[3:0])   );
  add_sub_c2 comp1  ( .in_A(w_dec), .in_B(w_MUX[7:4]),   .Result(w_ld_in[7:4])   );
  add_sub_c2 comp2  ( .in_A(w_cen), .in_B(w_MUX[11:8]),  .Result(w_ld_in[11:8])  );
  add_sub_c2 comp3  ( .in_A(w_umi), .in_B(w_MUX[15:12]),  .Result(w_ld_in[15:12]) );
  add_sub_c2 comp4  ( .in_A(w_dmi), .in_B(w_MUX[19:16]), .Result(w_ld_in[19:16]) );
  reg_msb    reg0   ( .clk(clk), .reset(w_ld), .in(w_MSB), .out(w_LD), .ld(w_ld_msb), .oe(w_add) );

  cnt_bin2bcd count0 ( .clk(clk), .ld(w_ld) , .dec(w_sh), .z(w_z));
  ctrl_b2b control0 ( .clk(clk), .rst(rst), .init(init), .done(done), .sh(w_sh), .ld(w_ld), .sel(w_sel), .ld_msb(w_ld_msb), .add(w_add), .z(w_z) );

endmodule
```

**Ubicación**: [`Calculadora/modulos/bcd2bin/bcd2bin.v`](Calculadora/modulos/bcd2bin/bcd2bin.v)

**Control**: [`Calculadora/modulos/bcd2bin/ctrl_b2b.v`](Calculadora/modulos/bcd2bin/ctrl_b2b.v)

### Simulaciones

![Simulación BCD2BIN](Calculadora/modulos/bcd2bin/sims.pdf)

> **Nota**: Ver archivo `sims.pdf` para simulaciones detalladas.

### Videos de Implementación

- [Video demostrando BCD2BIN en FPGA](#)

---

## 5. Conversor Binario a BCD

### Especificaciones Iniciales

Conversor de formato binario natural a formato BCD, utilizando el algoritmo Double Dabble.

**Características:**
- Entrada: 16 bits binarios (0-65535)
- Salida: 20 bits BCD (5 dígitos: 0-99999)
- Algoritmo: Desplazamiento con ajuste condicional
- Operación: Si nibble > 4, sumar 3

### Diagrama de Flujo del Algoritmo

![Diagrama de Flujo BIN2BCD](Calculadora/modulos/bin2bcd/Diagrama%20de%20flujo%20BIN%202%20BCD.pdf)

**Pasos:**
1. Inicializar A={A'',op_A}, count=N
2. Desplazar A << 1, count--
3. Si count=0: terminar
4. Para cada nibble A[i:i+3]:
   - Si nibble > 4: nibble = nibble + 3
5. Repetir desde paso 2
6. Resultado en A (formato BCD)

### Diagrama de Bloques del Camino de Datos

![Camino de Datos BIN2BCD](Calculadora/modulos/bin2bcd/Camino%20de%20Datos%20BIN%202%20BCD.pdf)

**Componentes:**
- **LSR4**: Registro de desplazamiento izquierdo de 36 bits
- **MUX**: Selecciona entre +3 o -11 según modo
- **SUM_C2**: 4 sumadores para los nibbles BCD
- **REG_MSB**: Almacena bits más significativos
- **COUNT**: Contador de iteraciones

### Diagrama de Estados de la Máquina de Control

![Máquina de Estados BIN2BCD](Calculadora/modulos/bin2bcd/Maquina%20de%20Estados%20BIn%202%20BCD.pdf)

**Estados:**
- **START**: Inicialización del sistema
- **SHIFT_DEC**: Desplaza y decrementa
- **CHECK**: Verifica MSB de nibbles
- **LOAD_A2**: Actualiza con suma/resta
- **ADD**: Procesa ajuste de nibbles
- **END1**: Completado

### Código Fuente Sintetizable

#### Módulo Principal: bin2bcd.v
```verilog
module bin2bcd(clk , rst , init , A , result , done);

  input         rst;
  input         clk;
  input         init;
  input  [15:0] A;
  output [19:0] result;
  output        done;

  wire w_sh;
  wire w_ld;
  wire w_sel;
  wire w_ld_msb;
  wire w_add;
  wire w_z;
  wire [4:0] w_LD;
  wire [4:0] w_MSB;

  wire [3:0] w_uni;
  wire [3:0] w_dec;
  wire [3:0] w_cen;
  wire [3:0] w_umi;
  wire [3:0] w_dmi;
  wire [19:0] w_ld_in;
  wire [19:0] w_MUX;

  assign w_MSB ={ w_ld_in[19], w_ld_in[15], w_ld_in[11], w_ld_in[7], w_ld_in[3] };
  assign result = {w_dmi, w_umi, w_cen, w_dec, w_uni};

  lsr4 lsr40        ( .clk(clk), .rst_ld(w_ld), .shift(w_sh), .lda2(w_LD), .in_R1(A), .in_R2(w_ld_in), .out_R({w_dmi, w_umi, w_cen, w_dec, w_uni}) );
  mux mux0          ( .in1(4'b0011), .in2(4'b1011), .out(w_MUX[3:0]),   .sel(w_sel) );
  mux mux1          ( .in1(4'b0011), .in2(4'b1011), .out(w_MUX[7:4]),   .sel(w_sel) );
  mux mux2          ( .in1(4'b0011), .in2(4'b1011), .out(w_MUX[11:8]),  .sel(w_sel) );
  mux mux3          ( .in1(4'b0011), .in2(4'b1011), .out(w_MUX[15:12]), .sel(w_sel) );
  mux mux4          ( .in1(4'b0011), .in2(4'b1011), .out(w_MUX[19:16]), .sel(w_sel) );
  add_sub_c2 comp0  ( .in_A(w_uni), .in_B(w_MUX[3:0]),   .Result(w_ld_in[3:0])   );
  add_sub_c2 comp1  ( .in_A(w_dec), .in_B(w_MUX[7:4]),   .Result(w_ld_in[7:4])   );
  add_sub_c2 comp2  ( .in_A(w_cen), .in_B(w_MUX[11:8]),  .Result(w_ld_in[11:8])  );
  add_sub_c2 comp3  ( .in_A(w_umi), .in_B(w_MUX[15:12]),  .Result(w_ld_in[15:12]) );
  add_sub_c2 comp4  ( .in_A(w_dmi), .in_B(w_MUX[19:16]), .Result(w_ld_in[19:16]) );
  reg_msb    reg0   ( .clk(clk), .reset(w_ld), .in(w_MSB), .out(w_LD), .ld(w_ld_msb), .oe(w_add) );

  cnt_bin2bcd count0 ( .clk(clk), .ld(w_ld) , .dec(w_sh), .z(w_z));
  ctrl_b2b control0 ( .clk(clk), .rst(rst), .init(init), .done(done), .sh(w_sh), .ld(w_ld), .sel(w_sel), .ld_msb(w_ld_msb), .add(w_add), .z(w_z) );

endmodule
```

**Ubicación**: [`Calculadora/modulos/bin2bcd/bin2bcd.v`](Calculadora/modulos/bin2bcd/bin2bcd.v)

### Simulaciones

![Simulación BIN2BCD](Calculadora/modulos/bin2bcd/sims.pdf)

> **Nota**: Ver archivo `sims.pdf` para simulaciones detalladas.

### Videos de Implementación

- [Video demostrando BIN2BCD en FPGA](#)

---

## 6. Calculadora Completa (SOC)

### Especificaciones Iniciales

Sistema completo que integra todos los módulos anteriores con un procesador RISC-V y comunicación UART.

**Características del Sistema:**
- **CPU**: FemtoRV32 (RISC-V RV32I)
- **Memoria**: BRAM de 8KB para programa y datos
- **Periféricos**:
  - UART (115200 baud, configurable)
  - Multiplicador (dirección base 0x04)
  - Divisor (dirección base 0x08)
  - Raíz cuadrada (dirección base 0x0C)
  - BIN2BCD (dirección base 0x10)
  - BCD2BIN (dirección base 0x14)
- **LEDs**: Indicador de actividad UART

### Arquitectura del Sistema

El SOC implementa una arquitectura Harvard modificada con bus único y chip select para cada periférico.

### Código Fuente del Sistema

#### Módulo Principal: SOC.v
```verilog
module SOC (
    input        clk,
    input        resetn,
    output wire  LEDS,
    input        RXD,
    output       TXD
);

   wire [31:0] mem_addr;
   reg  [31:0] mem_rdata;
   wire mem_rstrb;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;

   FemtoRV32 CPU(
      .clk(clk),
      .reset(resetn),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask),
      .mem_rbusy(1'b0),
      .mem_wbusy(1'b0)
   );

   wire [31:0] RAM_rdata;
   wire [31:0] uart_dout;
   wire [31:0] mult_dout;
   wire [31:0] div_dout;
   wire [31:0] sqrt_dout;
   wire [31:0] bin2bcd_dout;
   wire [31:0] bcd2bin_dout;

   wire  wr = |mem_wmask;
   wire  rd = mem_rstrb;

   // Periféricos instanciados...
   // (Ver archivo completo para detalles)

endmodule
```

**Ubicación**: [`Calculadora/SOC.v`](Calculadora/SOC.v)

### Mapa de Memoria

| Periférico | Dirección Base | Registros |
|------------|----------------|-----------|
| RAM | 0x0000_0000 | Memoria principal |
| BIN2BCD | 0x0400_0000 | A, init, result, done |
| DIV | 0x0800_0000 | A, B, init, result, done |
| MULT | 0x0C00_0000 | A, B, init, result, done |
| SQRT | 0x1000_0000 | A, init, result, done |
| UART | 0x1400_0000 | TX, RX, status |
| BCD2BIN | 0x1800_0000 | A, init, result, done |

### Compilación y Síntesis

El proyecto utiliza el toolchain de Efinix para síntesis e implementación:

```bash
# Síntesis
make -f Makefile

# Programación
make -f Makefile flash
```

### Simulaciones del Sistema

![Simulación SOC](ruta/a/simulacion_soc.png)

> **Nota**: Agregar capturas de simulación del sistema completo.

### Videos de Implementación Final

- [Video demostrando calculadora completa en FPGA](#)
- [Video demostrando comunicación UART](#)

---

## Herramientas Utilizadas

- **Síntesis**: Efinix Efinity 2023.2
- **Simulación**: Icarus Verilog + GTKWave
- **Lenguaje**: Verilog HDL
- **Toolchain RISC-V**: GCC RISC-V
- **Hardware**: Sipeed Tang Primer 25K

## Estructura del Repositorio

```
Digital_P/
├── Calculadora/
│   ├── modulos/
│   │   ├── mult/          # Multiplicador
│   │   ├── div/           # Divisor
│   │   ├── sqrt_ASM/      # Raíz cuadrada
│   │   ├── bin2bcd/       # Conversor Binario a BCD
│   │   ├── bcd2bin/       # Conversor BCD a Binario
│   │   ├── uart/          # Comunicación UART
│   │   ├── bram/          # Memoria RAM
│   │   ├── spi_flash/     # Memoria Flash SPI
│   │   └── cpu/           # Procesador FemtoRV32
│   ├── IC/                # Módulos integrados
│   ├── SOC.v              # Sistema completo
│   ├── Makefile           # Scripts de compilación principal
│   ├── Makefile.flash     # Scripts para versión con Flash
│   ├── Makefile.ice       # Scripts para iCE40
│   ├── firmware.hex       # Firmware para el CPU
│   ├── sipeed_tang_primer_25k.cst  # Configuración Tang Primer 25K
│   └── sipeed_tang_primer_25k.sdc  # Timing constraints
└── README.md              # Este archivo
```

## Cómo Usar

### Requisitos Previos

1. Instalar Efinix Efinity Toolchain
2. Instalar Icarus Verilog (para simulación)
3. Instalar GTKWave (para visualización)
4. Toolchain RISC-V GCC (para compilar firmware)

### Simulación

Para simular un módulo individual:

```bash
cd Calculadora/modulos/mult
make sim
gtkwave mult.gtkw
```

### Síntesis y Programación

```bash
cd Calculadora
make
make program
```

### Comunicación UART

Usar un terminal serial a 115200 baudios:

```bash
picocom -b 115200 /dev/ttyUSB0
```

## Referencias

- [FemtoRV32 GitHub](https://github.com/BrunoLevy/learn-fpga)
- [Efinix Documentation](https://www.efinixinc.com/support/docsdl.php)
- Apuntes de clase de Electrónica Digital

---

## Licencia

Este proyecto es de carácter académico para la Universidad Nacional de Colombia.

---

**Última actualización**: Noviembre 2024
