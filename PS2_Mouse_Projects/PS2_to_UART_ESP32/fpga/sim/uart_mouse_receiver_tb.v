// uart_mouse_receiver_tb.v
// Testbench para el receptor UART de datos del mouse

`timescale 1ns / 1ps

module uart_mouse_receiver_tb;

    //=========================================================================
    // PARÁMETROS
    //=========================================================================

    parameter CLK_PERIOD = 37;          // 27 MHz
    parameter BAUD_RATE = 115200;
    parameter BIT_PERIOD = 1000000000 / BAUD_RATE;  // En nanosegundos

    //=========================================================================
    // SEÑALES DEL DUT
    //=========================================================================

    reg clk;
    reg rst_n;
    reg uart_rxd;

    wire [8:0] mouse_x;
    wire [8:0] mouse_y;
    wire [2:0] buttons;
    wire packet_ready;
    wire [3:0] led;

    //=========================================================================
    // INSTANCIA DEL DUT
    //=========================================================================

    uart_mouse_receiver #(
        .FREQ_HZ(27000000),
        .BAUD(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .led(led)
    );

    //=========================================================================
    // GENERACIÓN DE RELOJ
    //=========================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //=========================================================================
    // TASK PARA ENVIAR BYTE POR UART
    //=========================================================================

    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            uart_rxd = 0;
            #BIT_PERIOD;

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = data[i];
                #BIT_PERIOD;
            end

            // Stop bit
            uart_rxd = 1;
            #BIT_PERIOD;
        end
    endtask

    //=========================================================================
    // TASK PARA ENVIAR PAQUETE DEL MOUSE
    //=========================================================================

    task send_mouse_packet;
        input signed [8:0] dx;
        input signed [8:0] dy;
        input [2:0] btn;
        begin
            $display("\n→ Enviando paquete: dX=%0d, dY=%0d, Botones=[L:%b R:%b M:%b]",
                     dx, dy, btn[0], btn[1], btn[2]);

            // Byte 0: Sync (0xAA)
            send_uart_byte(8'hAA);

            // Byte 1: X[7:0]
            send_uart_byte(dx[7:0]);

            // Byte 2: X[8] (signo)
            send_uart_byte({7'b0, dx[8]});

            // Byte 3: Y[7:0]
            send_uart_byte(dy[7:0]);

            // Byte 4: Y[8] (signo)
            send_uart_byte({7'b0, dy[8]});

            // Byte 5: Botones
            send_uart_byte({5'b0, btn});

            #(BIT_PERIOD * 5);  // Esperar un poco
        end
    endtask

    //=========================================================================
    // MONITOR DE PAQUETES RECIBIDOS
    //=========================================================================

    always @(posedge clk) begin
        if (packet_ready) begin
            $display("\n╔═══════════════════════════════════════════════════════╗");
            $display("║  PAQUETE RECIBIDO EN FPGA                            ║");
            $display("╠═══════════════════════════════════════════════════════╣");
            $display("║  Posición X: %4d (0x%03h) %s                    ║",
                     $signed(mouse_x), mouse_x,
                     mouse_x[8] ? "←" : "→");
            $display("║  Posición Y: %4d (0x%03h) %s                    ║",
                     $signed(mouse_y), mouse_y,
                     mouse_y[8] ? "↓" : "↑");
            $display("║  Botones: [L:%b M:%b R:%b]                            ║",
                     buttons[0], buttons[2], buttons[1]);
            $display("╚═══════════════════════════════════════════════════════╝");
        end
    end

    //=========================================================================
    // SECUENCIA DE PRUEBA
    //=========================================================================

    initial begin
        // Inicialización
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════╗");
        $display("║     TESTBENCH - UART MOUSE RECEIVER                  ║");
        $display("╚═══════════════════════════════════════════════════════╝");
        $display("\n");

        uart_rxd = 1;
        rst_n = 0;

        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("✓ Reset completado\n");

        //---------------------------------------------------------------------
        // PRUEBA 1: Sin movimiento, sin botones
        //---------------------------------------------------------------------
        $display("═══ TEST 1: Sin movimiento ═══");
        send_mouse_packet(9'sd0, 9'sd0, 3'b000);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 2: Movimiento derecha (+10)
        //---------------------------------------------------------------------
        $display("\n═══ TEST 2: Movimiento derecha (+10) ═══");
        send_mouse_packet(9'sd10, 9'sd0, 3'b000);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 3: Movimiento izquierda (-15)
        //---------------------------------------------------------------------
        $display("\n═══ TEST 3: Movimiento izquierda (-15) ═══");
        send_mouse_packet(-9'sd15, 9'sd0, 3'b000);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 4: Movimiento arriba (+20), botón izquierdo
        //---------------------------------------------------------------------
        $display("\n═══ TEST 4: Movimiento arriba (+20), botón izquierdo ═══");
        send_mouse_packet(9'sd0, 9'sd20, 3'b001);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 5: Movimiento abajo (-25), botón derecho
        //---------------------------------------------------------------------
        $display("\n═══ TEST 5: Movimiento abajo (-25), botón derecho ═══");
        send_mouse_packet(9'sd0, -9'sd25, 3'b010);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 6: Diagonal, todos los botones
        //---------------------------------------------------------------------
        $display("\n═══ TEST 6: Diagonal (+5, -8), todos los botones ═══");
        send_mouse_packet(9'sd5, -9'sd8, 3'b111);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 7: Movimiento grande (-100, +100)
        //---------------------------------------------------------------------
        $display("\n═══ TEST 7: Movimiento grande (-100, +100) ═══");
        send_mouse_packet(-9'sd100, 9'sd100, 3'b000);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 8: Máximo positivo (+255)
        //---------------------------------------------------------------------
        $display("\n═══ TEST 8: Máximo positivo (+255, +255) ═══");
        send_mouse_packet(9'sd255, 9'sd255, 3'b000);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // PRUEBA 9: Máximo negativo (-256)
        //---------------------------------------------------------------------
        $display("\n═══ TEST 9: Máximo negativo (-256, -256) ═══");
        send_mouse_packet(-9'sd256, -9'sd256, 3'b100);
        #(BIT_PERIOD * 50);

        //---------------------------------------------------------------------
        // Fin
        //---------------------------------------------------------------------
        #(BIT_PERIOD * 100);

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════╗");
        $display("║     SIMULACIÓN COMPLETADA EXITOSAMENTE               ║");
        $display("╚═══════════════════════════════════════════════════════╝");
        $display("\n");

        $finish;
    end

    //=========================================================================
    // GENERACIÓN DE VCD
    //=========================================================================

    initial begin
        $dumpfile("uart_mouse_receiver_tb.vcd");
        $dumpvars(0, uart_mouse_receiver_tb);
    end

    // Timeout
    initial begin
        #100000000;  // 100ms
        $display("\n⚠ TIMEOUT");
        $finish;
    end

endmodule
