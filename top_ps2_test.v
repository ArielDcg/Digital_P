// top_ps2_test.v
module top_ps2_test (
    input  wire clk,
    input  wire rst_n,
    
    // PS/2 interface
    inout  wire ps2_clk,
    inout  wire ps2_data,
    
    // Debug outputs para analizador lógico
    output wire [7:0] debug_state,
    output wire [7:0] debug_pins,  // Para ver datos en pines adicionales
    
    // LEDs
    output wire led_init_done,
    output wire led_activity,
    output wire led_error,
    
    // UART para debug (opcional)
    output wire uart_tx
);

    wire [7:0] rx_data;
    wire rx_valid;
    wire init_done;
    wire [7:0] debug_data;
    wire debug_busy, debug_ack;
    
    // Instancia del módulo PS/2
    ps2_mouse_init mouse_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .debug_state(debug_state),
        .debug_data(debug_data),
        .debug_busy(debug_busy),
        .debug_ack(debug_ack),
        .init_done(init_done),
        .rx_data(rx_data),
        .rx_data_valid(rx_valid)
    );
    
    // Asignar señales de debug adicionales
    assign debug_pins = rx_data;
    
    // LEDs indicadores
    assign led_init_done = init_done;
    assign led_activity = rx_valid;
    assign led_error = 1'b0;
    
    // UART para debug (implementación simplificada)
    // Puedes agregar un módulo UART aquí si necesitas debug serial
    assign uart_tx = 1'b1;  // Idle high cuando no se usa

endmodule