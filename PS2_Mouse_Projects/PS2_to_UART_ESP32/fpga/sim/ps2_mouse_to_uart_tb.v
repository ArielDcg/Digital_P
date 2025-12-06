// ps2_mouse_to_uart_tb.v
// Testbench para verificar la comunicación PS/2 a UART

`timescale 1ns / 1ps

module ps2_mouse_to_uart_tb;

    // Parámetros
    parameter CLK_PERIOD = 37;           // ~27 MHz (37 ns)
    parameter PS2_CLK_PERIOD = 60000;    // ~16.6 KHz para PS/2

    // Señales del DUT
    reg clk;
    reg rst_n;

    // PS/2 signals
    reg ps2_clk_in;
    reg ps2_data_in;
    wire ps2_clk, ps2_data;
    reg ps2_clk_drive, ps2_data_drive;

    // UART signals
    wire uart_txd;
    reg uart_rxd;

    // Debug signals
    wire init_done;
    wire packet_sent;
    wire [3:0] led;

    // Control de líneas bidireccionales PS/2
    assign ps2_clk = ps2_clk_drive ? ps2_clk_in : 1'bz;
    assign ps2_data = ps2_data_drive ? ps2_data_in : 1'bz;

    //-----------------------------------------------------
    // Instancia del DUT
    //-----------------------------------------------------
    ps2_mouse_to_uart #(
        .FREQ_HZ(27000000),
        .BAUD(115200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .init_done(init_done),
        .packet_sent(packet_sent),
        .led(led)
    );

    //-----------------------------------------------------
    // Generación de reloj
    //-----------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //-----------------------------------------------------
    // Monitor UART - Decodifica bytes recibidos
    //-----------------------------------------------------
    reg [7:0] uart_byte_buffer [0:5];  // Buffer para 6 bytes
    integer uart_byte_count = 0;
    integer uart_bit_count = 0;
    reg [7:0] uart_shift_reg;
    reg uart_receiving = 0;
    reg uart_txd_prev;

    // Parámetro UART
    parameter UART_BIT_PERIOD = 8681;  // Para 115200 baud a 27 MHz: 27000000/115200 ≈ 234 ciclos, 234*37ns ≈ 8658ns

    always @(posedge clk) begin
        uart_txd_prev <= uart_txd;

        // Detectar flanco de bajada (start bit)
        if (!uart_receiving && uart_txd_prev && !uart_txd) begin
            uart_receiving = 1;
            uart_bit_count = 0;
            uart_shift_reg = 0;
            // Esperar 1.5 bits para muestrear en el medio del primer bit de datos
            #(UART_BIT_PERIOD * 1.5);

            // Recibir 8 bits de datos
            repeat(8) begin
                uart_shift_reg = {uart_txd, uart_shift_reg[7:1]};
                #UART_BIT_PERIOD;
            end

            // Verificar stop bit
            if (uart_txd) begin
                // Byte recibido correctamente
                uart_byte_buffer[uart_byte_count] = uart_shift_reg;

                // Si es el byte de sincronización, reiniciar contador
                if (uart_shift_reg == 8'hAA) begin
                    uart_byte_count = 0;
                    uart_byte_buffer[0] = 8'hAA;
                    uart_byte_count = 1;
                end else begin
                    uart_byte_count = uart_byte_count + 1;
                end

                // Si recibimos 6 bytes completos, mostrar paquete
                if (uart_byte_count == 6) begin
                    display_uart_packet();
                    uart_byte_count = 0;
                end
            end else begin
                $display("ERROR UART: Stop bit incorrecto en tiempo %0t", $time);
            end

            uart_receiving = 0;
        end
    end

    //-----------------------------------------------------
    // Task para mostrar paquete UART decodificado
    //-----------------------------------------------------
    task display_uart_packet;
        reg signed [8:0] pos_x;
        reg signed [8:0] pos_y;
        reg [2:0] btn;
        begin
            // Reconstruir datos
            pos_x = {uart_byte_buffer[2][0], uart_byte_buffer[1]};
            pos_y = {uart_byte_buffer[4][0], uart_byte_buffer[3]};
            btn = uart_byte_buffer[5][2:0];

            $display("\n╔══════════════════════════════════════════════════════╗");
            $display("║  UART PACKET RECEIVED at time %0t ns", $time);
            $display("╠══════════════════════════════════════════════════════╣");
            $display("║  Raw bytes: %02h %02h %02h %02h %02h %02h",
                     uart_byte_buffer[0], uart_byte_buffer[1], uart_byte_buffer[2],
                     uart_byte_buffer[3], uart_byte_buffer[4], uart_byte_buffer[5]);
            $display("╠══════════════════════════════════════════════════════╣");
            $display("║  Position X: %4d (0x%03h) %s",
                     pos_x, pos_x[8:0], pos_x[8] ? "←" : "→");
            $display("║  Position Y: %4d (0x%03h) %s",
                     pos_y, pos_y[8:0], pos_y[8] ? "↓" : "↑");
            $display("║  Buttons: [L:%b M:%b R:%b]",
                     btn[0], btn[2], btn[1]);
            $display("╚══════════════════════════════════════════════════════╝\n");
        end
    endtask

    //-----------------------------------------------------
    // Task: Enviar byte por PS/2
    //-----------------------------------------------------
    task ps2_send_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            parity = ~^data;  // Paridad impar

            $display("→ Sending PS/2 byte: 0x%02h (parity=%b)", data, parity);

            // Start bit
            ps2_clk_in = 1;
            ps2_data_in = 0;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_in = 0;
            #(PS2_CLK_PERIOD/2);

            // 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                ps2_clk_in = 1;
                ps2_data_in = data[i];
                #(PS2_CLK_PERIOD/2);
                ps2_clk_in = 0;
                #(PS2_CLK_PERIOD/2);
            end

            // Parity bit
            ps2_clk_in = 1;
            ps2_data_in = parity;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_in = 0;
            #(PS2_CLK_PERIOD/2);

            // Stop bit
            ps2_clk_in = 1;
            ps2_data_in = 1;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_in = 0;
            #(PS2_CLK_PERIOD/2);

            // Idle
            ps2_clk_in = 1;
            ps2_data_in = 1;
            #(PS2_CLK_PERIOD);
        end
    endtask

    //-----------------------------------------------------
    // Task: Enviar paquete del mouse
    //-----------------------------------------------------
    task ps2_send_mouse_packet;
        input [7:0] status;
        input [7:0] x_move;
        input [7:0] y_move;
        begin
            $display("\n╔═══ SENDING PS/2 MOUSE PACKET ═══╗");
            ps2_send_byte(status);
            ps2_send_byte(x_move);
            ps2_send_byte(y_move);
            $display("╚═══ PS/2 Packet sent ═══╝\n");
        end
    endtask

    //-----------------------------------------------------
    // Secuencia de prueba principal
    //-----------------------------------------------------
    initial begin
        $display("\n");
        $display("╔══════════════════════════════════════════════════════╗");
        $display("║       PS/2 MOUSE TO UART TESTBENCH                 ║");
        $display("╚══════════════════════════════════════════════════════╝");
        $display("\n");

        // Inicialización
        rst_n = 0;
        uart_rxd = 1;
        ps2_clk_drive = 0;
        ps2_data_drive = 0;
        ps2_clk_in = 1;
        ps2_data_in = 1;

        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        //-----------------------------------------------------
        // Secuencia de inicialización PS/2
        //-----------------------------------------------------
        $display("⏳ Waiting for RESET command (0xFF) from host...");
        wait(ps2_clk == 0 && ps2_data == 0);
        $display("✓ Host inhibiting PS/2 lines...");

        #(PS2_CLK_PERIOD * 200);

        // Tomar control como dispositivo
        ps2_clk_drive = 1;
        ps2_data_drive = 1;
        ps2_clk_in = 1;
        ps2_data_in = 1;

        #(PS2_CLK_PERIOD * 50);

        // Enviar respuesta BAT OK
        $display("→ Sending BAT successful (0xAA)...");
        ps2_send_byte(8'hAA);
        #(PS2_CLK_PERIOD * 10);

        // Enviar ID del mouse
        $display("→ Sending Mouse ID (0x00)...");
        ps2_send_byte(8'h00);
        #(PS2_CLK_PERIOD * 10);

        // Esperar comando ENABLE
        $display("⏳ Waiting for ENABLE command (0xF4) from host...");
        wait(ps2_clk == 0 && ps2_data == 0);
        $display("✓ Host sending ENABLE...");

        #(PS2_CLK_PERIOD * 200);

        ps2_clk_drive = 1;
        ps2_data_drive = 1;
        ps2_clk_in = 1;
        ps2_data_in = 1;

        #(PS2_CLK_PERIOD * 50);

        // Enviar ACK
        $display("→ Sending ACK (0xFA)...");
        ps2_send_byte(8'hFA);
        #(PS2_CLK_PERIOD * 10);

        $display("\n✓ Initialization complete!");
        $display("→ Starting data streaming mode...\n");

        //-----------------------------------------------------
        // Enviar paquetes de prueba del mouse
        //-----------------------------------------------------

        // Paquete 1: Sin movimiento, sin botones
        $display("TEST 1: No movement, no buttons");
        ps2_send_mouse_packet(8'b00001000, 8'h00, 8'h00);
        #(PS2_CLK_PERIOD * 300);

        // Paquete 2: Movimiento derecha (+10), sin botones
        $display("TEST 2: Move right (+10)");
        ps2_send_mouse_packet(8'b00001000, 8'h0A, 8'h00);
        #(PS2_CLK_PERIOD * 300);

        // Paquete 3: Movimiento izquierda (-20), botón izquierdo
        $display("TEST 3: Move left (-20), left button");
        ps2_send_mouse_packet(8'b00011001, 8'hEC, 8'h00);  // -20 = 0xEC en complemento a 2
        #(PS2_CLK_PERIOD * 300);

        // Paquete 4: Movimiento arriba (+15), botón derecho
        $display("TEST 4: Move up (+15), right button");
        ps2_send_mouse_packet(8'b00001010, 8'h00, 8'h0F);
        #(PS2_CLK_PERIOD * 300);

        // Paquete 5: Movimiento diagonal, todos los botones
        $display("TEST 5: Diagonal movement (+5, -8), all buttons");
        ps2_send_mouse_packet(8'b00101111, 8'h05, 8'hF8);  // X=+5, Y=-8
        #(PS2_CLK_PERIOD * 300);

        // Paquete 6: Movimiento grande
        $display("TEST 6: Large movement (+127, -127)");
        ps2_send_mouse_packet(8'b00101000, 8'h7F, 8'h81);  // X=+127, Y=-127
        #(PS2_CLK_PERIOD * 300);

        //-----------------------------------------------------
        // Finalizar simulación
        //-----------------------------------------------------
        #(PS2_CLK_PERIOD * 500);

        $display("\n");
        $display("╔══════════════════════════════════════════════════════╗");
        $display("║       SIMULATION FINISHED SUCCESSFULLY              ║");
        $display("╚══════════════════════════════════════════════════════╝");
        $display("\n");

        $finish;
    end

    //-----------------------------------------------------
    // Generación de archivo VCD para GTKWave
    //-----------------------------------------------------
    initial begin
        $dumpfile("ps2_mouse_to_uart_tb.vcd");
        $dumpvars(0, ps2_mouse_to_uart_tb);
        $dumpvars(0, dut);
    end

    //-----------------------------------------------------
    // Monitor de señales de depuración
    //-----------------------------------------------------
    always @(posedge clk) begin
        if (packet_sent) begin
            $display("✓ UART packet transmission completed at time %0t", $time);
        end
    end

    // Timeout de seguridad
    initial begin
        #100000000;  // 100 ms
        $display("\n⚠ TIMEOUT: Simulation took too long!");
        $finish;
    end

endmodule
