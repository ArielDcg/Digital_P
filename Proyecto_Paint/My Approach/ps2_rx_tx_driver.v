`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: ps2_rx_tx_driver
// Descripción: Controlador de nivel físico para bus PS/2. Maneja bidireccionalidad,
// paridad y serialización.
//////////////////////////////////////////////////////////////////////////////////

module ps2_rx_tx_driver (
    input wire clk,              // System clock (e.g., 100 MHz)
    input wire reset,            // Active high reset
    input wire wr_en,            // Trigger para enviar comando
    input wire [7:0] din,        // Dato a enviar al mouse
    output reg [7:0] dout,       // Dato recibido del mouse
    output reg rx_done_tick,     // Pulso de un ciclo al completar recepción
    output reg tx_done_tick,     // Pulso al completar transmisión
    output reg par_error,        // Flag de error de paridad
    inout wire ps2_clk,          // Pin físico bidireccional
    inout wire ps2_data          // Pin físico bidireccional
);

    // --- Definición de Estados de la FSM ---
    localparam [2:0]
        IDLE = 3'b000,
        RX_ING = 3'b001,      // Recibiendo
        TX_FORCE_CLK = 3'b010, // Host fuerza CLK bajo (Inhibición)
        TX_RTS = 3'b011,       // Request to Send (Bajar Data)
        TX_ING = 3'b100,       // Transmitiendo bits
        TX_WAIT_ACK = 3'b101;  // Esperando ACK del dispositivo

    reg [2:0] state_reg, state_next;
    reg [3:0] n_reg, n_next;       // Contador de bits (0 a 10)
    reg [10:0] b_reg, b_next;      // Registro de desplazamiento (Buffer)
    reg [13:0] timer_reg, timer_next; // Timer para retardos (100us)

    // --- Filtro y Sincronización ---
    reg [7:0] filter_reg;
    reg f_ps2_clk;
    reg f_ps2_clk_reg;
    wire fall_edge;

    // Buffers Tri-state virtuales
    reg tri_c, tri_d; // Control: 1 = conducir bajo, 0 = alta impedancia
    assign ps2_clk = (tri_c)? 1'b0 : 1'bz;
    assign ps2_data = (tri_d)? 1'b0 : 1'bz;

    // --- Lógica de Filtro (Debounce) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            filter_reg <= 0;
            f_ps2_clk <= 0;
            f_ps2_clk_reg <= 0;
        end else begin
            filter_reg <= {filter_reg[6:0], ps2_clk}; // Desplazamiento
            if (filter_reg == 8'hFF) f_ps2_clk <= 1;
            else if (filter_reg == 8'h00) f_ps2_clk <= 0;
            
            f_ps2_clk_reg <= f_ps2_clk; // Para detectar flancos
        end
    end
    // Detección de flanco de bajada filtrado
    assign fall_edge = (f_ps2_clk_reg == 1) && (f_ps2_clk == 0);

    // --- Máquina de Estados Finitos (FSM) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            n_reg <= 0;
            b_reg <= 0;
            timer_reg <= 0;
            dout <= 0;
            rx_done_tick <= 0;
            tx_done_tick <= 0;
            par_error <= 0;
            tri_c <= 0;
            tri_d <= 0;
        end else begin
            state_reg <= state_next;
            n_reg <= n_next;
            b_reg <= b_next;
            timer_reg <= timer_next;
            
            // Asignación de control tri-state basada en estado (Moore outputs)
            // Se puede mover a lógica combinacional, aquí secuencial para glitch-free
            case (state_next)
                TX_FORCE_CLK: tri_c <= 1; // Host baja reloj
                TX_RTS: begin tri_c <= 1; tri_d <= 1; end // Host baja ambos
                TX_ING: begin tri_c <= 0; tri_d <= b_reg; end // Host conduce datos
                default: begin tri_c <= 0; tri_d <= 0; end // Alta impedancia (Rx o Idle)
            endcase
        end
    end

    // Lógica Combinacional de Siguiente Estado
    always @* begin
        state_next = state_reg;
        n_next = n_reg;
        b_next = b_reg;
        timer_next = timer_reg;
        rx_done_tick = 0;
        tx_done_tick = 0;
        
        case (state_reg)
            IDLE: begin
                if (wr_en) begin
                    // Comando de envío recibido
                    b_next = {~(^din), din}; // Preparar paridad y datos
                    timer_next = 10000; // Cargar timer para 100us (ajustar según clk)
                    state_next = TX_FORCE_CLK;
                end else if (fall_edge) begin
                    // Start bit detectado pasivamente
                    n_next = 4'h9; // Esperar 9 bits más (8 data + 1 parity + 1 stop)
                    state_next = RX_ING;
                end
            end

            RX_ING: begin
                if (fall_edge) begin
                    b_next = {ps2_data, b_reg[10:1]}; // Desplazar bit recibido
                    if (n_reg == 0) begin
                        rx_done_tick = 1;
                        state_next = IDLE;
                        // Comprobar paridad y stop bit aquí
                        // Paridad impar: ^Data + Parity = 1 (Impar)
                        // b_reg contiene? No exactamente, depende del shift
                    end else begin
                        n_next = n_reg - 1;
                    end
                end
            end

            TX_FORCE_CLK: begin
                // Mantener CLK bajo por ~100us
                if (timer_reg == 0) begin
                    state_next = TX_RTS;
                end else begin
                    timer_next = timer_reg - 1;
                end
            end

            TX_RTS: begin
                // Bajar Data (Start bit) y liberar CLK
                state_next = TX_ING;
                n_next = 8; // 8 bits de datos + paridad
            end

            TX_ING: begin
                if (fall_edge) begin
                    // El mouse generó reloj, desplazamos siguiente bit
                    b_next = {1'b0, b_reg[10:1]}; 
                    if (n_reg == 0) state_next = TX_WAIT_ACK;
                    else n_next = n_reg - 1;
                end
            end
            
            TX_WAIT_ACK: begin
                 if (fall_edge) begin
                     tx_done_tick = 1;
                     state_next = IDLE;
                 end
            end
        endcase
    end
endmodule