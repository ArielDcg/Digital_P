// bench_quark.v
// Testbench simplificado para PS/2 Mouse
// Este testbench se enfoca en probar la recepción y decodificación de paquetes del mouse

`timescale 1ns/1ps

module bench_quark();

    // Parámetros de tiempo
    parameter CLK_PERIOD = 37;        // ~27MHz (37ns period)
    parameter PS2_CLK_PERIOD = 30000; // ~33KHz PS/2 clock (reducido para simulación)

    // Señales del DUT
    reg clk;
    reg rst_n;
    reg ps2_clk_in;
    reg ps2_data_in;

    wire [7:0] rx_data;
    wire rx_ready;
    wire rx_error;

    // Señales del módulo completo
    wire [8:0] mouse_x;
    wire [8:0] mouse_y;
    wire [2:0] buttons;
    wire packet_ready;
    wire [7:0] debug_state;
    wire init_done;

    // Instancia del receptor PS/2 para pruebas directas
    ps2_receiver dut_rx (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk_in),
        .ps2_data(ps2_data_in),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_error(rx_error)
    );

    // Instancia del módulo completo ps2_mouse_init en modo simplificado
    // Forzaremos el estado a STREAM_MODE para probar solo la recepción
    reg force_stream_mode;
    wire ps2_clk_wire;
    wire ps2_data_wire;

    assign ps2_clk_wire = ps2_clk_in;
    assign ps2_data_wire = ps2_data_in;

    ps2_mouse_init dut_full (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk_wire),
        .ps2_data(ps2_data_wire),
        .debug_state(debug_state),
        .debug_data(),
        .debug_busy(),
        .debug_ack(),
        .init_done(init_done),
        .rx_data(),
        .rx_data_valid(),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .rx_error()
    );

    // Generador de clock 27MHz
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Registros para acumular posición del mouse
    reg signed [15:0] mouse_pos_x;
    reg signed [15:0] mouse_pos_y;
    integer packet_count;

    // Monitor de paquetes recibidos del módulo completo
    always @(posedge clk) begin
        if (packet_ready) begin
            mouse_pos_x = mouse_pos_x + $signed(mouse_x);
            mouse_pos_y = mouse_pos_y + $signed(mouse_y);
            packet_count = packet_count + 1;

            $display("[%0t] PAQUETE #%0d RECIBIDO:", $time, packet_count);
            $display("       Delta X = %0d (0x%02X)", $signed(mouse_x), mouse_x[7:0]);
            $display("       Delta Y = %0d (0x%02X)", $signed(mouse_y), mouse_y[7:0]);
            $display("       Botones = [M=%b R=%b L=%b]", buttons[2], buttons[1], buttons[0]);
            $display("       Posición Acumulada: X=%0d, Y=%0d", mouse_pos_x, mouse_pos_y);
            $display("");
        end
    end

    // Monitor del receptor individual
    always @(posedge clk) begin
        if (rx_ready) begin
            $display("[%0t] RX: Byte recibido = 0x%02X", $time, rx_data);
        end
        if (rx_error) begin
            $display("[%0t] RX: ERROR de paridad!", $time);
        end
    end

    //==========================================================================
    // Task para enviar byte PS/2 desde el mouse al host
    // TIMING CORRECTO: El flanco de bajada debe estar EN LA MITAD del bit
    //==========================================================================
    task ps2_send_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            parity = ~^data;  // Paridad impar

            $display("📤 Sending byte: 0x%02h (parity=%b)", data, parity);

            // Start bit (0)
            ps2_clk_in = 1;           // CLK alto
            ps2_data_in = 0;          // Cambiar dato mientras CLK está alto (setup time)
            #(PS2_CLK_PERIOD/2);      // Setup time (a) - dato estable
            ps2_clk_in = 0;           // Flanco de bajada EN LA MITAD del bit
            #(PS2_CLK_PERIOD/2);      // Hold time (b) - dato sigue estable

            // 8 bits de datos (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                ps2_clk_in = 1;       // CLK alto
                ps2_data_in = data[i]; // Cambiar dato mientras CLK está alto (setup time)
                #(PS2_CLK_PERIOD/2);  // Setup time - dato estable antes del flanco
                ps2_clk_in = 0;       // Flanco de bajada en la mitad del bit
                #(PS2_CLK_PERIOD/2);  // Hold time - dato sigue estable después del flanco
            end

            // Bit de paridad
            ps2_clk_in = 1;           // CLK alto
            ps2_data_in = parity;     // Cambiar dato mientras CLK está alto (setup time)
            #(PS2_CLK_PERIOD/2);      // Setup time
            ps2_clk_in = 0;           // Flanco de bajada en la mitad
            #(PS2_CLK_PERIOD/2);      // Hold time

            // Stop bit (1)
            ps2_clk_in = 1;           // CLK alto
            ps2_data_in = 1;          // Cambiar dato mientras CLK está alto (setup time)
            #(PS2_CLK_PERIOD/2);      // Setup time
            ps2_clk_in = 0;           // Flanco de bajada en la mitad
            #(PS2_CLK_PERIOD/2);      // Hold time

            // Volver a idle
            ps2_clk_in = 1;
            ps2_data_in = 1;
            #(PS2_CLK_PERIOD);
        end
    endtask

    //==========================================================================
    // Task para enviar paquete completo de mouse (3 bytes)
    //==========================================================================
    task send_mouse_packet;
        input signed [8:0] delta_x;
        input signed [8:0] delta_y;
        input left_btn;
        input right_btn;
        input middle_btn;
        reg [7:0] status_byte;
        reg [7:0] x_byte;
        reg [7:0] y_byte;
        begin
            // Construir status byte: [YOvf, XOvf, YSign, XSign, 1, MBtn, RBtn, LBtn]
            status_byte[0] = left_btn;
            status_byte[1] = right_btn;
            status_byte[2] = middle_btn;
            status_byte[3] = 1'b1;           // Siempre debe ser 1
            status_byte[4] = delta_x[8];     // Bit de signo X
            status_byte[5] = delta_y[8];     // Bit de signo Y
            status_byte[6] = 1'b0;           // X overflow
            status_byte[7] = 1'b0;           // Y overflow

            x_byte = delta_x[7:0];
            y_byte = delta_y[7:0];

            $display("[%0t] Enviando paquete: X=%0d, Y=%0d, Btns=[M=%b R=%b L=%b]",
                     $time, $signed(delta_x), $signed(delta_y), middle_btn, right_btn, left_btn);

            // Enviar los 3 bytes
            ps2_send_byte(status_byte);
            ps2_send_byte(x_byte);
            ps2_send_byte(y_byte);

            #(PS2_CLK_PERIOD * 3);
        end
    endtask

    //==========================================================================
    // Proceso principal de simulación
    //==========================================================================
    initial begin
        $dumpfile("bench_quark.vcd");
        $dumpvars(0, bench_quark);

        // Inicialización
        clk = 0;
        rst_n = 0;
        ps2_clk_in = 1;
        ps2_data_in = 1;
        mouse_pos_x = 0;
        mouse_pos_y = 0;
        packet_count = 0;
        force_stream_mode = 0;

        $display("========================================");
        $display("  PS/2 MOUSE TESTBENCH SIMPLIFICADO");
        $display("========================================");
        $display("Este testbench prueba directamente la");
        $display("recepción y decodificación de paquetes");
        $display("del mouse sin inicialización completa.");
        $display("========================================\n");

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        $display("[%0t] Reset liberado\n", $time);
        #(CLK_PERIOD * 50);

        // Forzar estado STREAM_MODE en el DUT completo para pruebas
        force dut_full.state = 8'h07;  // STATE_STREAM_MODE
        force dut_full.init_complete = 1'b1;

        $display("[%0t] Estado forzado a STREAM_MODE para pruebas\n", $time);
        #(CLK_PERIOD * 20);

        //----------------------------------------------------------------------
        // PRUEBA 1: Bytes individuales al receptor
        //----------------------------------------------------------------------
        $display("========================================");
        $display("PRUEBA 1: Receptor individual");
        $display("========================================\n");

        $display("Enviando byte 0xAA...");
        ps2_send_byte(8'hAA);
        #(PS2_CLK_PERIOD * 5);

        $display("Enviando byte 0x55...");
        ps2_send_byte(8'h55);
        #(PS2_CLK_PERIOD * 5);

        $display("\nPrueba 1 completada.\n");

        //----------------------------------------------------------------------
        // PRUEBA 2: Paquetes de mouse completos
        //----------------------------------------------------------------------
        $display("========================================");
        $display("PRUEBA 2: Paquetes de mouse completos");
        $display("========================================\n");

        // Paquete 1: Movimiento diagonal pequeño (+5, +5), sin botones
        send_mouse_packet(9'd5, 9'd5, 1'b0, 1'b0, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 2: Movimiento (+10, +10), botón izquierdo presionado
        send_mouse_packet(9'd10, 9'd10, 1'b1, 1'b0, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 3: Movimiento (+15, +15), botón derecho presionado
        send_mouse_packet(9'd15, 9'd15, 1'b0, 1'b1, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 4: Movimiento (+8, +8), botón medio presionado
        send_mouse_packet(9'd8, 9'd8, 1'b0, 1'b0, 1'b1);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 5: Movimiento negativo (-7, -7), todos los botones
        send_mouse_packet(-9'd7, -9'd7, 1'b1, 1'b1, 1'b1);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 6: Movimiento grande (+20, +20), sin botones
        send_mouse_packet(9'd20, 9'd20, 1'b0, 1'b0, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 7: Movimiento negativo (-12, -12), izquierdo y derecho
        send_mouse_packet(-9'd12, -9'd12, 1'b1, 1'b1, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        // Paquete 8: Movimiento grande (+50, +50), sin botones
        send_mouse_packet(9'd50, 9'd50, 1'b0, 1'b0, 1'b0);
        #(PS2_CLK_PERIOD * 10);

        //----------------------------------------------------------------------
        // PRUEBA 3: Prueba de error de paridad
        //----------------------------------------------------------------------
        $display("========================================");
        $display("PRUEBA 3: Error de paridad");
        $display("========================================\n");

        $display("Enviando byte con paridad incorrecta...");
        // Enviar manualmente un byte con paridad incorrecta usando el TIMING CORRECTO
        // Start bit
        ps2_clk_in = 1;
        ps2_data_in = 0;
        #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 0;
        #(PS2_CLK_PERIOD/2);

        // Datos: 0xAA (10101010)
        ps2_clk_in = 1; ps2_data_in = 0; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 1; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 0; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 1; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 0; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 1; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 0; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);
        ps2_clk_in = 1; ps2_data_in = 1; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);

        // Paridad incorrecta (debería ser 1 para 0xAA, enviamos 0)
        ps2_clk_in = 1; ps2_data_in = 0; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);

        // Stop bit
        ps2_clk_in = 1; ps2_data_in = 1; #(PS2_CLK_PERIOD/2); ps2_clk_in = 0; #(PS2_CLK_PERIOD/2);

        #(PS2_CLK_PERIOD * 5);
        $display("Debe haberse detectado error de paridad.\n");

        //----------------------------------------------------------------------
        // Finalizar simulación
        //----------------------------------------------------------------------
        #(PS2_CLK_PERIOD * 20);

        release dut_full.state;
        release dut_full.init_complete;

        $display("========================================");
        $display("RESUMEN DE SIMULACIÓN");
        $display("========================================");
        $display("Total de paquetes recibidos: %0d", packet_count);
        $display("Posición final del mouse:");
        $display("  X = %0d", mouse_pos_x);
        $display("  Y = %0d", mouse_pos_y);
        $display("========================================");
        $display("\n¡Simulación completada exitosamente!");

        #(CLK_PERIOD * 100);
        $finish;
    end

    // Timeout de seguridad (mucho más corto)
    initial begin
        #20000000;  // 20ms timeout
        $display("\nERROR: Timeout de simulación alcanzado");
        $finish;
    end

endmodule
