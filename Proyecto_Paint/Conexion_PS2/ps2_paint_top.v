module ps2_paint_top(
    input  wire clk,
    input  wire rst_n,

    input  wire uart_rx,

    output wire LP_CLK,
    output wire LATCH,
    output wire NOE,
    output wire [4:0] ROW,
    output wire [2:0] RGB0,
    output wire [2:0] RGB1,

    output wire led_error,
    output wire led_activity,
    output wire [7:0] debug_mouse_x,
    output wire [7:0] debug_mouse_y
);

    wire [7:0] mouse_x_uart;
    wire [7:0] mouse_y_uart;
    wire mouse_left;
    wire mouse_right;
    wire mouse_middle;
    wire data_valid;
    wire error_flag;

    wire [8:0] mouse_x_signed;
    wire [8:0] mouse_y_signed;

    wire wr0, wr1;
    wire [11:0] wdata;
    wire [11:0] address;
    wire [11:0] b_rdata0;
    wire [11:0] b_rdata1;

    wire [23:0] mem_rdata;
    wire [10:0] pix_addr;

    assign mouse_x_signed = {{mouse_x_uart[7]}, mouse_x_uart};
    assign mouse_y_signed = {{mouse_y_uart[7]}, mouse_y_uart};

    assign debug_mouse_x = mouse_x_uart;
    assign debug_mouse_y = mouse_y_uart;
    assign led_error = error_flag;
    assign led_activity = data_valid;

    ps2_mouse_receiver uart_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .mouse_x(mouse_x_uart),
        .mouse_y(mouse_y_uart),
        .mouse_left(mouse_left),
        .mouse_right(mouse_right),
        .mouse_middle(mouse_middle),
        .data_valid(data_valid),
        .error_flag(error_flag)
    );

    Mouse_to_screen #(
        .X_MAX(63),
        .Y_MAX(63),
        .IMG_WIDTH(64),
        .IMG_DIV(32),
        .PIXEL_COLOR(12'h004)
    ) mouse_converter (
        .clk(clk),
        .reset(~rst_n),
        .packet_ready(data_valid),
        .PS2_Xdata(mouse_x_signed),
        .PS2_Ydata(mouse_y_signed),
        .b_rdata0(b_rdata0),
        .b_rdata1(b_rdata1),
        .wr0(wr0),
        .wr1(wr1),
        .wdata(wdata),
        .address(address)
    );

    memory #(
        .size(2047),
        .width(11)
    ) frame_memory (
        .clk(clk),
        .address(pix_addr),
        .rd(1'b1),
        .wr0(wr0),
        .wr1(wr1),
        .wdata(wdata),
        .rdata(mem_rdata),
        .b_rdata0(b_rdata0),
        .b_rdata1(b_rdata1)
    );

    led_panel_4k_external led_controller (
        .clk(clk),
        .rst(~rst_n),
        .init(1'b1),
        .mem_rdata(mem_rdata),
        .pix_addr(pix_addr),
        .LP_CLK(LP_CLK),
        .LATCH(LATCH),
        .NOE(NOE),
        .ROW(ROW),
        .RGB0(RGB0),
        .RGB1(RGB1)
    );

endmodule
