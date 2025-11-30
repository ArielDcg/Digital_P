`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Testbench para MIT PS/2 Mouse Interface
// Clock del sistema: 27 MHz (período 37.04 ns)
// Adaptado del testbench comprehensive con BFM completo
////////////////////////////////////////////////////////////////////////////////

module tb_mit_ps2_mouse_27mhz;

    // Parámetros de timing para 27MHz
    // Período del sistema: 1/27MHz = 37.04 ns
    parameter real CLK_PERIOD = 37.04;  // ns

    // Cálculo de parámetros para ps2_mouse_interface @ 27MHz:
    // Watchdog timer: 400 μs / 37.04 ns ≈ 10800 ciclos
    // Debounce timer: ~3.7 μs / 37.04 ns ≈ 100 ciclos
    parameter WATCHDOG_TIMER_VALUE = 10800;  // 400 μs @ 27MHz
    parameter WATCHDOG_TIMER_BITS  = 14;     // 2^14 = 16384 > 10800
    parameter DEBOUNCE_TIMER_VALUE = 100;    // ~3.7 μs @ 27MHz
    parameter DEBOUNCE_TIMER_BITS  = 7;      // 2^7 = 128 > 100

    // Señales del Testbench
    reg clk, reset;
    wire ps2_clk, ps2_data; // Bidireccionales

    // Señales de salida del DUT
    wire left_button, right_button;
    wire [8:0] x_increment, y_increment;
    wire data_ready;
    wire error_no_ack;

    // Variables internas del BFM (Mouse Simulado)
    reg mouse_clk_drive, mouse_data_drive;
    reg mouse_clk_en, mouse_data_en;

    // Resistencias Pull-up simuladas (Crítico para simular Open Collector)
    pullup(ps2_clk);
    pullup(ps2_data);

    // Conexión del bus tri-state del BFM
    assign ps2_clk = (mouse_clk_en) ? mouse_clk_drive : 1'bz;
    assign ps2_data = (mouse_data_en) ? mouse_data_drive : 1'bz;

    // Instancia del DUT MIT con parámetros ajustados para 27MHz
    ps2_mouse_interface #(
        .WATCHDOG_TIMER_VALUE_PP(WATCHDOG_TIMER_VALUE),
        .WATCHDOG_TIMER_BITS_PP(WATCHDOG_TIMER_BITS),
        .DEBOUNCE_TIMER_VALUE_PP(DEBOUNCE_TIMER_VALUE),
        .DEBOUNCE_TIMER_BITS_PP(DEBOUNCE_TIMER_BITS)
    ) dut (
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

    // Generador de Reloj del Sistema: 27 MHz
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;  // 18.52 ns half period

    // Monitor de señales de salida
    always @(posedge data_ready) begin
        $display("[%0t] DATA READY: LB=%b RB=%b X=%d (0x%h) Y=%d (0x%h)",
                 $time, left_button, right_button,
                 $signed(x_increment), x_increment,
                 $signed(y_increment), y_increment);
    end

    // Monitor de errores
    always @(posedge error_no_ack) begin
        $error("[%0t] ERROR: No ACK recibido del mouse!", $time);
    end

    // --- Tareas del BFM (Bus Functional Model) ---

    // Tarea para enviar un byte desde el Mouse al Host
    // Protocolo PS/2: Start(0) + 8 Data bits (LSB first) + Parity(odd) + Stop(1)
    task mouse_send_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            parity = ~(^data); // Paridad impar

            $display("[%0t] Mouse enviando byte: 0x%h", $time, data);

            // 1. Start Bit (Data Low, Clock pulse)
            mouse_data_drive = 0;
            mouse_data_en = 1; // Data Low
            #20000; // Tiempo antes de bajar el reloj
            mouse_clk_drive = 0;
            mouse_clk_en = 1; // CLK Low
            #40000; // Período bajo del reloj (40 μs)
            mouse_clk_drive = 1;
            mouse_clk_en = 0; // CLK High (Float con pull-up)
            #20000; // Período alto del reloj

            // 2. Data Bits (LSB first)
            for (i=0; i<8; i=i+1) begin
                mouse_data_drive = data[i];
                #20000;
                mouse_clk_drive = 0;
                mouse_clk_en = 1;
                #40000;
                mouse_clk_drive = 1;
                mouse_clk_en = 0;
                #20000;
            end

            // 3. Parity Bit
            mouse_data_drive = parity;
            #20000;
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #40000;
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
            #20000;

            // 4. Stop Bit (Data High)
            mouse_data_drive = 1;
            #20000;
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #40000;
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
            #20000;

            mouse_data_en = 0; // Liberar bus de datos
            #50000; // Delay entre bytes
        end
    endtask

    // Tarea para enviar un paquete completo de movimiento del mouse
    task mouse_send_movement;
        input [7:0] status_byte;  // YOvf, XOvf, YSign, XSign, 1, MBtn, RBtn, LBtn
        input [7:0] x_movement;
        input [7:0] y_movement;
        begin
            $display("[%0t] === Enviando paquete de movimiento ===", $time);
            mouse_send_byte(status_byte);
            mouse_send_byte(x_movement);
            mouse_send_byte(y_movement);
            $display("[%0t] === Paquete enviado ===", $time);
        end
    endtask

    // Tarea para esperar comando del Host y enviar ACK
    task expect_host_command;
        input [7:0] expected_cmd;
        reg [7:0] received_cmd;
        integer i;
        begin
            $display("[%0t] Esperando comando del host...", $time);

            // Esperar inhibición del Host (CLK Low por más de 100μs)
            wait(ps2_clk === 0);
            #150000; // Esperar > 100μs de inhibición
            $display("[%0t] Host inhibición detectada.", $time);

            // Esperar que host suelte CLK y baje DATA (Start bit)
            wait(ps2_clk === 1);
            #10000;
            wait(ps2_data === 0);
            $display("[%0t] Start bit del Host detectado.", $time);

            // El Mouse genera el reloj para leer los datos del Host
            received_cmd = 0;
            #20000;

            for (i=0; i<8; i=i+1) begin
                // Generar pulso de reloj (el mouse controla el reloj durante recepción)
                mouse_clk_drive = 0;
                mouse_clk_en = 1;
                #20000; // Sample en medio del período bajo
                received_cmd[i] = ps2_data;
                #20000;
                mouse_clk_drive = 1;
                mouse_clk_en = 0;
                #20000;
            end

            // Leer bit de paridad
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #40000;
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
            #20000;

            // Leer stop bit
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #40000;
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
            #20000;

            // Enviar ACK Bit (Mouse tira Data Low)
            mouse_data_drive = 0;
            mouse_data_en = 1;
            mouse_clk_drive = 0;
            mouse_clk_en = 1;
            #40000;
            mouse_clk_drive = 1;
            mouse_clk_en = 0;
            #20000;
            mouse_data_en = 0; // Liberar DATA
            mouse_clk_en = 0;  // Liberar CLK

            if (received_cmd == expected_cmd)
                $display("[%0t] Comando correcto recibido: 0x%h", $time, received_cmd);
            else
                $error("[%0t] Error! Esperaba 0x%h, recibió 0x%h", $time, expected_cmd, received_cmd);
        end
    endtask

    // --- Secuencia Principal de Prueba ---
    initial begin
        // Configurar dump de señales para visualización
        $dumpfile("tb_mit_ps2_mouse_27mhz.vcd");
        $dumpvars(0, tb_mit_ps2_mouse_27mhz);

        // Inicialización
        clk = 0;
        reset = 1;
        mouse_clk_en = 0;
        mouse_data_en = 0;
        mouse_clk_drive = 1;
        mouse_data_drive = 1;

        #200 reset = 0;
        $display("\n========================================");
        $display("  Test MIT PS/2 Mouse @ 27MHz");
        $display("========================================\n");

        // 1. Simular Power-On secuencia del Mouse
        #500000; // Tiempo de encendido realista
        $display("[%0t] 1. Enviando BAT (Basic Assurance Test) = 0xAA", $time);
        mouse_send_byte(8'hAA);

        $display("[%0t] 2. Enviando Device ID = 0x00 (Standard Mouse)", $time);
        mouse_send_byte(8'h00);

        // 2. Esperar que el Host envíe comando de habilitación (0xF4)
        #100000;
        $display("[%0t] 3. Esperando comando de habilitación (0xF4) del Host...", $time);
        expect_host_command(8'hF4);

        // 3. Responder con ACK (0xFA)
        #200000;
        $display("[%0t] 4. Enviando ACK (0xFA)", $time);
        mouse_send_byte(8'hFA);

        // 4. Stream Mode: Enviar varios paquetes de movimiento
        #500000;

        // Paquete 1: Movimiento X=+5, Y=-1, sin botones
        // Status: YSign=1 (negativo), XSign=0 (positivo), Always1=1
        // Bit 3 debe ser siempre 1
        // [7:YOvf 6:XOvf 5:YSign 4:XSign 3:1 2:MBtn 1:RBtn 0:LBtn]
        $display("[%0t] 5. Enviando paquete 1: X=+5, Y=-1, sin botones", $time);
        mouse_send_movement(8'b00101000, 8'd5, 8'hFF);  // Y=-1 en complemento a 2
        #1000000;

        // Paquete 2: Movimiento X=-10, Y=+20, botón izquierdo presionado
        $display("[%0t] 6. Enviando paquete 2: X=-10, Y=+20, botón izquierdo", $time);
        mouse_send_movement(8'b00011001, 8'hF6, 8'd20);  // X=-10 en complemento a 2
        #1000000;

        // Paquete 3: Sin movimiento, botón derecho presionado
        $display("[%0t] 7. Enviando paquete 3: Sin movimiento, botón derecho", $time);
        mouse_send_movement(8'b00001010, 8'd0, 8'd0);
        #1000000;

        // Paquete 4: Movimiento grande X=+127, Y=-128
        $display("[%0t] 8. Enviando paquete 4: X=+127, Y=-128", $time);
        mouse_send_movement(8'b00101000, 8'd127, 8'h80);
        #1000000;

        $display("\n========================================");
        $display("  Simulación completada exitosamente");
        $display("========================================\n");
        #500000;
        $finish;
    end

    // Timeout de seguridad
    initial begin
        #50000000; // 50 ms timeout
        $display("\n*** TIMEOUT: La simulación excedió el tiempo máximo ***");
        $finish;
    end

endmodule
