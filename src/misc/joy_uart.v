/*
    joy_uart.v

    A joystick fed over a serial line. A wireless receiver next to the
    board (an ESP32 with a Bluetooth controller paired to it) sends one
    byte whenever the state changes, 115200 8N1, and repeats it now and
    then. Bit order is that of the companion's HID joysticks: 0 right,
    1 left, 2 down, 3 up, 4 fire, 5 second button. The byte is OR'd into
    the ST's joystick port, so a USB joystick keeps working as well.

    A watchdog releases everything when no byte has arrived for half a
    second: a controller that drops off the air must not leave a
    direction stuck.
*/

module joy_uart #(
    parameter integer CLK_HZ = 32000000,
    parameter integer BAUD   = 115200
)(
    input            clk,
    input            resetn,
    input            rxd,
    output reg [7:0] joy
);

localparam integer PERIOD = CLK_HZ / BAUD;
localparam integer HOLD   = CLK_HZ / 2;           // half a second

reg [1:0]  rx_sync;
always @(posedge clk) rx_sync <= { rx_sync[0], rxd };
wire rx_in = rx_sync[1];

reg [15:0] rx_cnt;
reg [3:0]  rx_bit;      // 0 = idle, 1 = start, 2..9 = data, 10 = stop
reg [7:0]  rx_shift;
reg [24:0] hold;

always @(posedge clk) begin
    if(!resetn) begin
        rx_bit <= 4'd0;
        rx_cnt <= 16'd0;
        joy    <= 8'h00;
        hold   <= 25'd0;
    end else begin
        if(hold != 25'd0) hold <= hold - 25'd1;
        else              joy  <= 8'h00;

        if(rx_bit == 4'd0) begin
            if(!rx_in) begin                       // start bit
                rx_bit <= 4'd1;
                rx_cnt <= PERIOD[16:1] - 16'd1;    // half a bit
            end
        end else if(rx_cnt != 16'd0) begin
            rx_cnt <= rx_cnt - 16'd1;
        end else begin
            rx_cnt <= PERIOD[15:0] - 16'd1;
            if(rx_bit == 4'd1) begin
                rx_bit <= rx_in ? 4'd0 : 4'd2;     // a glitch, or a real start
            end else if(rx_bit == 4'd10) begin
                rx_bit <= 4'd0;
                if(rx_in) begin                    // a proper stop bit
                    joy  <= rx_shift;
                    hold <= HOLD[24:0];
                end
            end else begin
                rx_shift <= { rx_in, rx_shift[7:1] };
                rx_bit   <= rx_bit + 4'd1;
            end
        end
    end
end

endmodule
