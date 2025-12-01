// bench_quark.v
// Testbench para PS/2 Mouse con tiempos reducidos para simulación rápida

`timescale 1ns/1ps

module bench_quark();

    // Parámetros de tiempo
    parameter CLK_PERIOD = 37;     // ~27MHz (37ns period)
    parameter PS2_CLK_PERIOD = 60000; // ~16.7KHz PS/2 clock (reducido para simulación)

    // Señales del DUT
    reg clk;
    reg rst_n;
    wire ps2_clk;
    wire ps2_data;
    wire [7:0] debug_state;
    wire [7:0] debug_pins;
    wire led_init_done;
    wire led_activity;
    wire led_error;
    wire [8:0] mouse_x;
    wire [8:0] mouse_y;
    wire [2:0] buttons;
    wire packet_ready;
    wire uart_tx;

    // Señales para simulación PS/2
    reg ps2_clk_drive;
    reg ps2_data_drive;
    reg ps2_clk_oe;
    reg ps2_data_oe;

    // Control bidireccional
    assign ps2_clk = ps2_clk_oe ? ps2_clk_drive : 1'bz;
    assign ps2_data = ps2_data_oe ? ps2_data_drive : 1'bz;

    // Instancia del módulo a probar
    top_ps2_test dut (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .debug_state(debug_state),
        .debug_pins(debug_pins),
        .led_init_done(led_init_done),
        .led_activity(led_activity),
        .led_error(led_error),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .uart_tx(uart_tx)
    );

    // Generador de clock 27MHz
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Registros para acumular posición del mouse
    reg signed [15:0] mouse_pos_x;
    reg signed [15:0] mouse_pos_y;

    // Monitor de paquetes recibidos
    always @(posedge clk) begin
        if (packet_ready) begin
            // Acumular movimiento
            mouse_pos_x = mouse_pos_x + $signed(mouse_x);
            mouse_pos_y = mouse_pos_y + $signed(mouse_y);

            $display("[%0t] PACKET: X=%0d Y=%0d Buttons=[M=%b R=%b L=%b] | PosX=%0d PosY=%0d",
                     $time, $signed(mouse_x), $signed(mouse_y),
                     buttons[2], buttons[1], buttons[0],
                     mouse_pos_x, mouse_pos_y);
        end
    end

    //==========================================================================
    // Task para enviar byte PS/2 desde el mouse al host
    //==========================================================================
    task ps2_send_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            parity = ~^data;  // Paridad impar

            // Liberar líneas para empezar
            ps2_clk_oe = 1;
            ps2_data_oe = 1;
            ps2_clk_drive = 1;
            ps2_data_drive = 1;
            #(PS2_CLK_PERIOD);

            // Start bit
            ps2_clk_drive = 0;
            ps2_data_drive = 0;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_drive = 1;
            #(PS2_CLK_PERIOD/2);

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                ps2_clk_drive = 0;
                ps2_data_drive = data[i];
                #(PS2_CLK_PERIOD/2);
                ps2_clk_drive = 1;
                #(PS2_CLK_PERIOD/2);
            end

            // Parity bit
            ps2_clk_drive = 0;
            ps2_data_drive = parity;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_drive = 1;
            #(PS2_CLK_PERIOD/2);

            // Stop bit
            ps2_clk_drive = 0;
            ps2_data_drive = 1;
            #(PS2_CLK_PERIOD/2);
            ps2_clk_drive = 1;
            #(PS2_CLK_PERIOD/2);

            // Liberar líneas
            ps2_data_oe = 0;
            ps2_clk_oe = 0;
            #(PS2_CLK_PERIOD);
        end
    endtask

    //==========================================================================
    // Task para recibir byte PS/2 desde el host (comandos)
    //==========================================================================
    task ps2_receive_byte;
        output [7:0] data;
        integer i;
        begin
            // Esperar a que el host tome control
            ps2_clk_oe = 0;
            ps2_data_oe = 0;

            // Esperar inhibit (clk=0) del host
            wait(ps2_clk == 0);
            #(PS2_CLK_PERIOD);

            // Esperar request-to-send (data=0)
            wait(ps2_data == 0);

            // Esperar que el host libere el clock
            wait(ps2_clk == 1);

            // Leer start bit
            wait(ps2_clk == 0);
            #(PS2_CLK_PERIOD/2);

            // Leer 8 bits de datos
            for (i = 0; i < 8; i = i + 1) begin
                wait(ps2_clk == 1);
                wait(ps2_clk == 0);
                #(PS2_CLK_PERIOD/4);
                data[i] = ps2_data;
                #(PS2_CLK_PERIOD/4);
            end

            // Leer parity bit
            wait(ps2_clk == 1);
            wait(ps2_clk == 0);
            #(PS2_CLK_PERIOD/2);

            // Leer stop bit
            wait(ps2_clk == 1);
            wait(ps2_clk == 0);
            #(PS2_CLK_PERIOD/2);

            // Enviar ACK (llevar data a 0)
            ps2_data_oe = 1;
            ps2_data_drive = 0;
            wait(ps2_clk == 1);
            wait(ps2_clk == 0);
            #(PS2_CLK_PERIOD/2);

            // Liberar líneas
            ps2_data_oe = 0;
            #(PS2_CLK_PERIOD);
        end
    endtask

    //==========================================================================
    // Task para enviar paquete de mouse (3 bytes)
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
            status_byte[3] = 1'b1;  // Siempre 1
            status_byte[4] = delta_x[8];  // X sign bit
            status_byte[5] = delta_y[8];  // Y sign bit
            status_byte[6] = 1'b0;  // X overflow
            status_byte[7] = 1'b0;  // Y overflow

            x_byte = delta_x[7:0];
            y_byte = delta_y[7:0];

            // Enviar los 3 bytes
            ps2_send_byte(status_byte);
            ps2_send_byte(x_byte);
            ps2_send_byte(y_byte);

            #(PS2_CLK_PERIOD * 2);
        end
    endtask

    //==========================================================================
    // Proceso principal de simulación
    //==========================================================================
    reg [7:0] received_cmd;
    integer packet_count;

    initial begin
        $dumpfile("bench_quark.vcd");
        $dumpvars(0, bench_quark);

        // Inicialización
        rst_n = 0;
        ps2_clk_oe = 0;
        ps2_data_oe = 0;
        ps2_clk_drive = 1;
        ps2_data_drive = 1;
        mouse_pos_x = 0;
        mouse_pos_y = 0;
        packet_count = 0;

        $display("========================================");
        $display("PS/2 Mouse Testbench Started");
        $display("========================================");

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 100);

        //----------------------------------------------------------------------
        // Esperar y responder al comando RESET (0xFF)
        //----------------------------------------------------------------------
        $display("[%0t] Waiting for RESET command...", $time);
        ps2_receive_byte(received_cmd);
        $display("[%0t] Received command: 0x%02X", $time, received_cmd);

        if (received_cmd == 8'hFF) begin
            $display("[%0t] Sending ACK for RESET", $time);
            #(PS2_CLK_PERIOD * 2);
            ps2_send_byte(8'hFA);  // ACK

            #(PS2_CLK_PERIOD * 5);
            $display("[%0t] Sending BAT completion (0xAA)", $time);
            ps2_send_byte(8'hAA);  // BAT completion

            #(PS2_CLK_PERIOD * 2);
            $display("[%0t] Sending Mouse ID (0x00)", $time);
            ps2_send_byte(8'h00);  // Mouse ID
        end

        //----------------------------------------------------------------------
        // Esperar y responder al comando Enable Data Reporting (0xF4)
        //----------------------------------------------------------------------
        #(PS2_CLK_PERIOD * 10);
        $display("[%0t] Waiting for Enable Data Reporting command...", $time);
        ps2_receive_byte(received_cmd);
        $display("[%0t] Received command: 0x%02X", $time, received_cmd);

        if (received_cmd == 8'hF4) begin
            $display("[%0t] Sending ACK for Enable Data Reporting", $time);
            #(PS2_CLK_PERIOD * 2);
            ps2_send_byte(8'hFA);  // ACK
        end

        //----------------------------------------------------------------------
        // Enviar 8 paquetes de datos de mouse con movimiento diagonal
        //----------------------------------------------------------------------
        #(PS2_CLK_PERIOD * 10);
        $display("\n========================================");
        $display("Starting Mouse Data Stream");
        $display("========================================");

        // Paquete 1: Movimiento diagonal (+5, +5), sin botones
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 1: X=+5, Y=+5, Buttons=000", $time);
        send_mouse_packet(9'd5, 9'd5, 1'b0, 1'b0, 1'b0);
        packet_count = packet_count + 1;

        // Paquete 2: Movimiento diagonal (+10, +10), botón izquierdo
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 2: X=+10, Y=+10, Buttons=001 (Left)", $time);
        send_mouse_packet(9'd10, 9'd10, 1'b1, 1'b0, 1'b0);
        packet_count = packet_count + 1;

        // Paquete 3: Movimiento diagonal (+15, +15), botón derecho
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 3: X=+15, Y=+15, Buttons=010 (Right)", $time);
        send_mouse_packet(9'd15, 9'd15, 1'b0, 1'b1, 1'b0);
        packet_count = packet_count + 1;

        // Paquete 4: Movimiento diagonal (+8, +8), botón medio
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 4: X=+8, Y=+8, Buttons=100 (Middle)", $time);
        send_mouse_packet(9'd8, 9'd8, 1'b0, 1'b0, 1'b1);
        packet_count = packet_count + 1;

        // Paquete 5: Movimiento diagonal negativo (-7, -7), todos los botones
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 5: X=-7, Y=-7, Buttons=111 (All)", $time);
        send_mouse_packet(-9'd7, -9'd7, 1'b1, 1'b1, 1'b1);
        packet_count = packet_count + 1;

        // Paquete 6: Movimiento diagonal (+20, +20), sin botones
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 6: X=+20, Y=+20, Buttons=000", $time);
        send_mouse_packet(9'd20, 9'd20, 1'b0, 1'b0, 1'b0);
        packet_count = packet_count + 1;

        // Paquete 7: Movimiento diagonal (-12, -12), botón izquierdo y derecho
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 7: X=-12, Y=-12, Buttons=011 (L+R)", $time);
        send_mouse_packet(-9'd12, -9'd12, 1'b1, 1'b1, 1'b0);
        packet_count = packet_count + 1;

        // Paquete 8: Movimiento grande (+50, +50), sin botones
        #(PS2_CLK_PERIOD * 5);
        $display("[%0t] Sending packet 8: X=+50, Y=+50, Buttons=000", $time);
        send_mouse_packet(9'd50, 9'd50, 1'b0, 1'b0, 1'b0);
        packet_count = packet_count + 1;

        //----------------------------------------------------------------------
        // Finalizar simulación
        //----------------------------------------------------------------------
        #(PS2_CLK_PERIOD * 20);
        $display("\n========================================");
        $display("Simulation Summary");
        $display("========================================");
        $display("Total packets sent: %0d", packet_count);
        $display("Final mouse position: X=%0d, Y=%0d", mouse_pos_x, mouse_pos_y);
        $display("Init done: %b", led_init_done);
        $display("========================================");

        #(CLK_PERIOD * 1000);
        $display("\nTestbench completed successfully!");
        $finish;
    end

    // Timeout de seguridad
    initial begin
        #50000000;  // 50ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
