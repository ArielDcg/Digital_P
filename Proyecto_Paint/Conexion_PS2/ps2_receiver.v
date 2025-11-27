// ps2_receiver.v
// Modulo receptor PS/2 (device to host)
// Recibe datos del dispositivo PS/2

module ps2_receiver (
    input  wire clk,
    input  wire rst_n,
    input  wire ps2_clk,
    input  wire ps2_data,
    output reg  [7:0] rx_data,
    output reg  rx_ready
);

    reg [10:0] rx_shift_reg;
    reg [3:0] bit_count;
    reg ps2_clk_sync, ps2_clk_prev;
    reg ps2_data_sync;
    reg receiving;

    // Sincronizacion
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_prev <= ps2_clk_sync;
        ps2_data_sync <= ps2_data;
    end

    // Deteccion de flanco de bajada
    wire ps2_clk_negedge = ps2_clk_prev & ~ps2_clk_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift_reg <= 0;
            bit_count <= 0;
            rx_data <= 0;
            rx_ready <= 0;
            receiving <= 0;
        end else begin
            rx_ready <= 0;  // Pulso de un ciclo

            if (!receiving) begin
                // Detectar bit de start
                if (ps2_clk_negedge && !ps2_data_sync) begin
                    receiving <= 1;
                    bit_count <= 0;
                    rx_shift_reg <= 0;
                end
            end else begin
                if (ps2_clk_negedge) begin
                    if (bit_count < 10) begin
                        rx_shift_reg <= {ps2_data_sync, rx_shift_reg[10:1]};
                        bit_count <= bit_count + 1;
                    end else begin
                        // Frame completo
                        if (rx_shift_reg[10]) begin  // Verificar stop bit
                            rx_data <= rx_shift_reg[8:1];  // Extraer datos
                            rx_ready <= 1;
                        end
                        receiving <= 0;
                    end
                end
            end
        end
    end

endmodule
