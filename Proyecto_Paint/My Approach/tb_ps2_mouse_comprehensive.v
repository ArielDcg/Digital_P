`timescale 1ns / 1ps

module tb_ps2_mouse_comprehensive;

    // Señales del Testbench
    reg clk, reset;
    wire ps2_clk, ps2_data; // Bidireccionales
    
    // Señales de observación
    wire [8:0] tx_x, tx_y;
    wire valid_out;

    // Variables internas del BFM (Mouse Simulado)
    reg mouse_clk_drive, mouse_data_drive;
    reg mouse_clk_en, mouse_data_en;
    
    // Resistencias Pull-up simuladas (Crítico para simular Open Collector)
    pullup(ps2_clk);
    pullup(ps2_data);

    // Conexión del bus tri-state del BFM
    assign ps2_clk = (mouse_clk_en)? mouse_clk_drive : 1'bz;
    assign ps2_data = (mouse_data_en)? mouse_data_drive : 1'bz;

    // Instancia del DUT (Device Under Test)
    ps2_mouse_controller_full dut (
       .clk(clk),.reset(reset),
       .ps2_clk(ps2_clk),.ps2_data(ps2_data),
       .x_delta(tx_x),.y_delta(tx_y),.data_ready(valid_out)
    );

    // Generador de Reloj del Sistema
    always #5 clk = ~clk; // 100 MHz clock

    // --- Tareas del BFM ---

    // Tarea para enviar un byte desde el Mouse al Host (Protocolo estándar)
    task mouse_send_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            parity = ~(^data); // Paridad impar
            
            // 1. Start Bit (Data Low, Clock pulse)
            mouse_data_drive = 0; mouse_data_en = 1; // Data Low
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1; // CLK Low
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0; // CLK High (Float)
            
            // 2. Data Bits (LSB first)
            for (i=0; i<8; i=i+1) begin
                mouse_data_drive = data[i];
                #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
                #40000; mouse_clk_drive = 1; mouse_clk_en = 0; 
            end
            
            // 3. Parity Bit
            mouse_data_drive = parity;
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0;
            
            // 4. Stop Bit (Data High)
            mouse_data_drive = 1;
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0;
            
            mouse_data_en = 0; // Liberar bus
            #50000; // Delay entre bytes
        end
    endtask

    // Tarea para simular la respuesta al Host (Handshake)
    task expect_host_command;
        input [7:0] expected_cmd;
        reg [7:0] received_cmd;
        integer i;
        begin
            // Esperar inhibición del Host (CLK Low)
            wait(ps2_clk === 0); 
            $display(" Host Inhibición detectada.");
            
            // Esperar liberación del CLK y bajada de DATA (Start bit del Host)
            wait(ps2_clk === 1 && ps2_data === 0);
            $display(" Start bit del Host detectado. Iniciando lectura...");

            // El Mouse genera el reloj para leer los datos del Host
            received_cmd = 0;
            for (i=0; i<8; i=i+1) begin
                // Generar pulso de reloj
                #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
                // Muestrear dato en flanco de subida (convención BFM, o bajada según protocolo)
                // En realidad el host cambia en bajada, el mouse lee en subida.
                #20000; mouse_clk_drive = 1; mouse_clk_en = 0;
                received_cmd[i] = ps2_data; 
            end
            
            // Leer paridad (ignorar chequeo en sim simple)
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0;

            // Stop bit
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0;
            
            // Enviar ACK Bit (Mouse tira Data Low)
            mouse_data_drive = 0; mouse_data_en = 1;
            #20000; mouse_clk_drive = 0; mouse_clk_en = 1;
            #40000; mouse_clk_drive = 1; mouse_clk_en = 0;
            mouse_data_en = 0;

            if (received_cmd == expected_cmd) 
                $display(" Comando correcto recibido: %h", received_cmd);
            else
                $error(" Error! Esperaba %h, recibió %h", expected_cmd, received_cmd);
        end
    endtask

    // --- Secuencia Principal de Prueba ---
    initial begin
        // Inicialización
        clk = 0; reset = 1;
        mouse_clk_en = 0; mouse_data_en = 0; mouse_clk_drive = 1; mouse_data_drive = 1;
        
        #100 reset = 0;
        $display("--- Inicio de Simulación ---");

        // 1. Simular Power-On secuencia del Mouse
        #500000; // Tiempo realista de encendido
        $display("1. Enviando BAT (0xAA)");
        mouse_send_byte(8'hAA);
        
        $display("2. Enviando ID (0x00)");
        mouse_send_byte(8'h00);

        // 2. Esperar que el Host envíe 0xF4
        $display("3. Esperando comando de habilitación (0xF4) del Host...");
        expect_host_command(8'hF4);

        // 3. Responder con ACK (0xFA)
        #200000;
        $display("4. Enviando ACK (0xFA)");
        mouse_send_byte(8'hFA);

        // 4. El sistema ahora está en Stream Mode. Enviar movimiento.
        $display("5. Enviando paquete de movimiento (X=+5, Y=-1)");
        // Byte 1: Overflow=0, SignX=0, SignY=1, Always1=1, Btn=0 -> 00101000 -> 0x28
        // SignY=1 indica negativo.
        mouse_send_byte(8'b00101000); 
        mouse_send_byte(8'd5);        // X delta = 5
        mouse_send_byte(8'hFF);       // Y delta = -1 (en complemento a 2, truncado)

        #1000000;
        $display("--- Fin de Simulación ---");
        $finish;
    end

endmodule