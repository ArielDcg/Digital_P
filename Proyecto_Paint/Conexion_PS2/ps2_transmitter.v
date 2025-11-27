// ps2_transmitter.v
// Modulo transmisor PS/2 (host to device)
// Envia comandos del host al dispositivo PS/2

module ps2_transmitter (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] tx_data,
    input  wire tx_start,
    input  wire ps2_clk_in,
    input  wire ps2_data_in,
    output reg  ps2_clk_out,
    output reg  ps2_data_out,
    output reg  ps2_clk_oe,
    output reg  ps2_data_oe,
    output reg  busy,
    output reg  ack_received,
    output reg  error
);

    // Estados del transmisor
    localparam TX_IDLE = 0;
    localparam TX_INHIBIT = 1;
    localparam TX_REQUEST = 2;
    localparam TX_CLOCK_WAIT = 3;
    localparam TX_SEND_BIT = 4;
    localparam TX_RELEASE = 5;
    localparam TX_WAIT_ACK = 6;

    reg [3:0] tx_state;
    reg [15:0] timer;
    reg [3:0] bit_count;
    reg [10:0] tx_shift_reg;
    reg ps2_clk_sync, ps2_clk_prev;
    reg parity;

    // Sincronizacion del clock PS/2
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk_in;
        ps2_clk_prev <= ps2_clk_sync;
    end

    // Deteccion de flanco de bajada
    wire ps2_clk_negedge = ps2_clk_prev & ~ps2_clk_sync;

    // Calculo de paridad (impar)
    always @(*) begin
        parity = ~^tx_data;  // Paridad impar
    end

    // Maquina de estados del transmisor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            timer <= 0;
            bit_count <= 0;
            busy <= 0;
            ack_received <= 0;
            error <= 0;
            ps2_clk_oe <= 0;
            ps2_data_oe <= 0;
            ps2_clk_out <= 1;
            ps2_data_out <= 1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    if (tx_start) begin
                        busy <= 1;
                        ack_received <= 0;
                        error <= 0;
                        // Preparar frame: start(0) + data + parity + stop(1)
                        tx_shift_reg <= {1'b1, parity, tx_data, 1'b0};
                        bit_count <= 0;
                        timer <= 3000; // ~111us @ 27MHz
                        // Inhibir comunicacion
                        ps2_clk_oe <= 1;
                        ps2_clk_out <= 0;
                        ps2_data_oe <= 0;
                        tx_state <= TX_INHIBIT;
                    end
                end

                TX_INHIBIT: begin
                    if (timer > 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Request to send
                        ps2_data_oe <= 1;
                        ps2_data_out <= 0;
                        timer <= 20;
                        tx_state <= TX_REQUEST;
                    end
                end

                TX_REQUEST: begin
                    if (timer > 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Liberar clock
                        ps2_clk_oe <= 0;
                        tx_state <= TX_CLOCK_WAIT;
                    end
                end

                TX_CLOCK_WAIT: begin
                    // Esperar flanco de bajada del clock
                    if (ps2_clk_negedge) begin
                        ps2_data_out <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[10:1]};
                        bit_count <= bit_count + 1;
                        tx_state <= TX_SEND_BIT;
                    end
                end

                TX_SEND_BIT: begin
                    if (bit_count < 11) begin
                        if (ps2_clk_negedge) begin
                            ps2_data_out <= tx_shift_reg[0];
                            tx_shift_reg <= {1'b0, tx_shift_reg[10:1]};
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        // Liberar linea de datos
                        ps2_data_oe <= 0;
                        tx_state <= TX_WAIT_ACK;
                    end
                end

                TX_WAIT_ACK: begin
                    if (ps2_clk_negedge) begin
                        // El mouse debe poner data en bajo (ACK)
                        if (!ps2_data_in) begin
                            ack_received <= 1;
                        end else begin
                            error <= 1;
                        end
                        busy <= 0;
                        tx_state <= TX_IDLE;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule
