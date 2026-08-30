//
// debug_uart.v
//
// Minimal UART transmitter for diagnostic builds. Prints a 128 bit value as
// 32 hex digits followed by CR/LF, repeating about twice per second.
//
// On the Tang Nano 20k the FPGA pin used for the MCU interrupt line is routed
// to the on-board BL616, which exposes it as a serial port on the PC. In a
// diagnostic build without an MCU attached that line is free, so internal
// state can simply be printed to a terminal.
//
module debug_uart #(
    parameter integer CLK_HZ = 32000000,
    parameter integer BAUD   = 115200
) (
    input             clk,
    input             resetn,
    input     [127:0] value,
    output reg        tx
);

localparam integer DIV = CLK_HZ / BAUD;

reg [15:0] baud_cnt;
reg        baud_tick;
always @(posedge clk) begin
    if(!resetn) begin
        baud_cnt  <= 16'd0;
        baud_tick <= 1'b0;
    end else if(baud_cnt == DIV[15:0] - 16'd1) begin
        baud_cnt  <= 16'd0;
        baud_tick <= 1'b1;
    end else begin
        baud_cnt  <= baud_cnt + 16'd1;
        baud_tick <= 1'b0;
    end
end

function [7:0] hexchar(input [3:0] n);
    hexchar = (n < 4'd10) ? (8'h30 + { 4'd0, n }) : (8'h41 + { 4'd0, n } - 8'd10);
endfunction

reg  [5:0] idx;        // 0..31 = hex digits, 32 = CR, 33 = LF
reg  [3:0] bit_idx;
reg  [9:0] shifter;
reg        busy;
reg [15:0] gap;

wire [3:0] nib = value[(31 - idx) * 4 +: 4];
wire [7:0] ch  = (idx < 6'd32) ? hexchar(nib) :
                 (idx == 6'd32) ? 8'h0d : 8'h0a;

always @(posedge clk) begin
    if(!resetn) begin
        tx      <= 1'b1;
        idx     <= 6'd0;
        bit_idx <= 4'd0;
        busy    <= 1'b0;
        gap     <= 16'd0;
        shifter <= 10'h3ff;
    end else if(baud_tick) begin
        if(busy) begin
            tx      <= shifter[0];
            shifter <= { 1'b1, shifter[9:1] };
            if(bit_idx == 4'd9) begin
                busy <= 1'b0;
                if(idx == 6'd33) begin idx <= 6'd0; gap <= 16'd57600; end
                else                   idx <= idx + 6'd1;
            end else
                bit_idx <= bit_idx + 4'd1;
        end else if(gap != 16'd0) begin
            gap <= gap - 16'd1;
            tx  <= 1'b1;
        end else begin
            shifter <= { 1'b1, ch, 1'b0 };
            bit_idx <= 4'd0;
            busy    <= 1'b1;
        end
    end
end

endmodule
