`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Testbench para MIT PS/2 Mouse Interface @ 27MHz
// Estructura basada en bench_quark.v
////////////////////////////////////////////////////////////////////////////////

module bench();

// Parámetros de timing
parameter tck = 37;  // 27 MHz clock period (37 ns)
parameter PS2_BIT_PERIOD = 6000;  // 6 us per PS/2 bit (10x faster for simulation)

// Parámetros del DUT para 27MHz
parameter WATCHDOG_TIMER_VALUE = 10800;  // 400 μs @ 27MHz
parameter WATCHDOG_TIMER_BITS  = 14;
parameter DEBOUNCE_TIMER_VALUE = 100;    // ~3.7 μs @ 27MHz
parameter DEBOUNCE_TIMER_BITS  = 7;

// Señales del sistema
reg clk;
reg reset;

// Bus PS/2 (bidireccional con pull-ups)
wire ps2_clk, ps2_data;

// Señales de salida del DUT
wire left_button, right_button;
wire [8:0] x_increment, y_increment;
wire data_ready;
wire error_no_ack;

// Variables del BFM (Bus Functional Model - Mouse simulado)
reg mouse_clk_drive, mouse_data_drive;
reg mouse_clk_en, mouse_data_en;

// Pull-ups (crítico para PS/2 open-collector)
pullup(ps2_clk);
pullup(ps2_data);

// Tri-state drivers del BFM
assign ps2_clk = mouse_clk_en ? mouse_clk_drive : 1'bz;
assign ps2_data = mouse_data_en ? mouse_data_drive : 1'bz;

// Instancia del DUT (Device Under Test)
ps2_mouse_interface #(
    .WATCHDOG_TIMER_VALUE_PP(WATCHDOG_TIMER_VALUE),
    .WATCHDOG_TIMER_BITS_PP(WATCHDOG_TIMER_BITS),
    .DEBOUNCE_TIMER_VALUE_PP(DEBOUNCE_TIMER_VALUE),
    .DEBOUNCE_TIMER_BITS_PP(DEBOUNCE_TIMER_BITS)
) uut (
    .clk(clk),
    .reset(reset),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .left_button(left_button),
    .right_button(right_button),
    .x_increment(x_increment),
    .y_increment(y_increment),
    .data_ready(data_ready),
    .read(1'b1),  // Auto-read mode
    .error_no_ack(error_no_ack)
);

// Generador de clock
initial clk = 0;
always #(tck/2) clk = ~clk;

// Monitor de datos recibidos
always @(posedge data_ready) begin
    $display("[%0t] DATA READY: LB=%b RB=%b X=%d Y=%d",
             $time, left_button, right_button,
             $signed(x_increment), $signed(y_increment));
end

// Monitor de errores
always @(posedge error_no_ack) begin
    $display("[%0t] ERROR: No ACK from mouse!", $time);
    $finish;
end

// ====================================================================
// TAREAS DEL BFM (Bus Functional Model - Simula Mouse PS/2)
// ====================================================================

// Tarea: Enviar un byte desde el Mouse al Host
// Formato PS/2: Start(0) + 8_Data_bits(LSB first) + Parity(odd) + Stop(1)
task mouse_send_byte;
    input [7:0] data;
    integer i;
    reg parity;
    begin
        parity = ~(^data); // Paridad impar

        // Start Bit
        mouse_data_drive = 0;
        mouse_data_en = 1;
        #(PS2_BIT_PERIOD/3);
        mouse_clk_drive = 0;
        mouse_clk_en = 1;
        #(PS2_BIT_PERIOD*2/3);
        mouse_clk_drive = 1;
        mouse_clk_en = 0;

        // 8 Data Bits (LSB first)
        for (i=0; i<8; i=i+1) begin
            mouse_data_drive = data[i];
            #(PS2_BIT_PERIOD/3);
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #(PS2_BIT_PERIOD*2/3);
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
        end

        // Parity Bit
        mouse_data_drive = parity;
        #(PS2_BIT_PERIOD/3);
        mouse_clk_drive = 0;
        mouse_clk_en = 1;
        #(PS2_BIT_PERIOD*2/3);
        mouse_clk_drive = 1;
        mouse_clk_en = 0;

        // Stop Bit
        mouse_data_drive = 1;
        #(PS2_BIT_PERIOD/3);
        mouse_clk_drive = 0;
        mouse_clk_en = 1;
        #(PS2_BIT_PERIOD*2/3);
        mouse_clk_drive = 1;
        mouse_clk_en = 0;

        mouse_data_en = 0; // Liberar DATA
        #(PS2_BIT_PERIOD); // Inter-byte delay
    end
endtask

// Tarea: Leer comando del Host (el host controla el CLK)
task receive_host_command;
    output [7:0] received_cmd;
    integer i;
    begin
        received_cmd = 0;

        $display("[%0t] Esperando comando del host...", $time);

        // Esperar primer falling edge (start bit)
        wait(ps2_clk === 0);
        #(PS2_BIT_PERIOD/2);

        // Leer 8 bits de datos en cada rising edge
        for (i=0; i<8; i=i+1) begin
            wait(ps2_clk === 1);
            #(PS2_BIT_PERIOD/4);
            wait(ps2_clk === 0);
            #(PS2_BIT_PERIOD/4);
            received_cmd[i] = ps2_data;
        end

        // Leer Parity bit
        wait(ps2_clk === 1);
        wait(ps2_clk === 0);

        // Leer Stop bit
        wait(ps2_clk === 1);
        wait(ps2_clk === 0);

        // Esperar que CLK vuelva a HIGH
        wait(ps2_clk === 1);

        $display("[%0t] Comando recibido: 0x%h", $time, received_cmd);
        #(PS2_BIT_PERIOD);
    end
endtask

// Tarea: Enviar paquete de movimiento completo (3 bytes)
task mouse_send_packet;
    input [7:0] status;  // [YOvf XOvf YSign XSign 1 MBtn RBtn LBtn]
    input [7:0] x_mov;
    input [7:0] y_mov;
    begin
        mouse_send_byte(status);
        mouse_send_byte(x_mov);
        mouse_send_byte(y_mov);
    end
endtask

// ====================================================================
// SECUENCIA DE PRUEBA
// ====================================================================

integer idx;
reg [7:0] cmd;

initial begin
    $dumpfile("bench.vcd");
    $dumpvars(0, bench);

    clk = 0;
    reset = 1;
    mouse_clk_en = 0;
    mouse_data_en = 0;
    mouse_clk_drive = 1;
    mouse_data_drive = 1;

    #(tck*10) reset = 1;
    #(tck*20) reset = 0;

    $display("\n========================================");
    $display("  MIT PS/2 Mouse Test @ 27MHz");
    $display("========================================\n");

    // 1. Recibir comando 0xF4 del host
    receive_host_command(cmd);

    if (cmd != 8'hF4) begin
        $display("[%0t] ERROR: Esperaba 0xF4, recibió 0x%h", $time, cmd);
        $finish;
    end

    // 2. Enviar ACK (0xFA)
    $display("[%0t] Enviando ACK (0xFA)...", $time);
    mouse_send_byte(8'hFA);

    // 3. Enviar paquetes de movimiento
    $display("[%0t] Paquete 1: X=+5, Y=-1", $time);
    mouse_send_packet(8'b00101000, 8'd5, 8'hFF);

    $display("[%0t] Paquete 2: X=-10, Y=+20, LBtn", $time);
    mouse_send_packet(8'b00011001, 8'hF6, 8'd20);

    $display("[%0t] Paquete 3: X=0, Y=0, RBtn", $time);
    mouse_send_packet(8'b00001010, 8'd0, 8'd0);

    $display("[%0t] Paquete 4: X=+127, Y=-128", $time);
    mouse_send_packet(8'b00101000, 8'd127, 8'h80);

    #(tck*50000);
    $display("\n========================================");
    $display("  Test completado");
    $display("========================================\n");
    $finish;
end

// Timeout de seguridad
initial begin
    #(tck*5000000); // 185 ms timeout
    $display("\n*** TIMEOUT ***");
    $finish;
end

endmodule
