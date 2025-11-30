module ps2_mouse_controller_full (
    input wire clk, reset,
    inout wire ps2_clk, ps2_data,
    output reg [8:0] x_delta,
    output reg [8:0] y_delta,
    output reg left_btn, right_btn, mid_btn,
    output reg data_ready,
    output reg [1:0] state_debug // Para LEDs de depuración
);

    // Señales internas
    wire [7:0] rx_data;
    wire rx_done, tx_done;
    reg wr_en;
    reg [7:0] tx_cmd;
    
    // Instancia del PHY
    ps2_rx_tx_driver phy (
       .clk(clk),.reset(reset),
       .wr_en(wr_en),.din(tx_cmd),
       .dout(rx_data),.rx_done_tick(rx_done),.tx_done_tick(tx_done),
       .ps2_clk(ps2_clk),.ps2_data(ps2_data)
    );

    // Estados del Controlador Superior
    localparam [3:0]
        S_RESET = 0,
        S_WAIT_BAT = 1,      // Esperar 0xAA
        S_WAIT_ID = 2,       // Esperar 0x00
        S_SEND_EN = 3,       // Enviar 0xF4
        S_WAIT_ACK = 4,      // Esperar 0xFA
        S_READ_BYTE1 = 5,
        S_READ_BYTE2 = 6,
        S_READ_BYTE3 = 7,
        S_ERROR = 8;

    reg [3:0] state_reg, state_next;
    reg [7:0] byte1_reg, byte2_reg; // Buffers para el paquete

    assign state_debug = state_reg[1:0];

    always @(posedge clk or posedge reset) begin
        if (reset) state_reg <= S_RESET;
        else state_reg <= state_next;
    end

    // Lógica de Control de Flujo de Paquetes y Comandos
    always @* begin
        state_next = state_reg;
        wr_en = 0;
        tx_cmd = 0;
        data_ready = 0;
        
        case (state_reg)
            S_RESET: state_next = S_WAIT_BAT;

            S_WAIT_BAT: begin
                // El mouse envía 0xAA tras power-up
                if (rx_done && rx_data == 8'hAA) state_next = S_WAIT_ID;
            end

            S_WAIT_ID: begin
                // El mouse envía ID 0x00
                if (rx_done && rx_data == 8'h00) state_next = S_SEND_EN;
            end

            S_SEND_EN: begin
                tx_cmd = 8'hF4; // Enable Data Reporting
                wr_en = 1;      // Trigger transmisión
                state_next = S_WAIT_ACK;
            end

            S_WAIT_ACK: begin
                // Esperar a que la transmisión termine Y recibir el ACK 0xFA
                // Nota: La lógica del PHY debe manejar la recepción del ACK
                if (rx_done && rx_data == 8'hFA) state_next = S_READ_BYTE1;
            end

            S_READ_BYTE1: begin
                if (rx_done) begin
                    byte1_reg = rx_data;
                    // Verificación de sincronización: Bit 3 debe ser 1
                    if (rx_data == 1) state_next = S_READ_BYTE2;
                    else state_next = S_READ_BYTE1; // Descartar y reintentar
                end
            end

            S_READ_BYTE2: begin
                if (rx_done) begin
                    byte2_reg = rx_data;
                    state_next = S_READ_BYTE3;
                end
            end

            S_READ_BYTE3: begin
                if (rx_done) begin
                    // Byte 3 es Y movement. Ahora tenemos todo el paquete.
                    // Extraer datos
                    // X Movement: Sign bit (Byte1) + Byte2
                    // Y Movement: Sign bit (Byte1) + Byte3
                    
                    // Asignación de salida (Lógica secuencial recomendada aquí para glitches)
                    state_next = S_READ_BYTE1; // Volver al inicio
                    data_ready = 1;
                end
            end
        endcase
    end
    
    // Bloque secuencial para actualizar salidas x_delta, y_delta...
    //... (Código para asignar x_delta = {byte1_reg, byte2_reg} etc.)

endmodule