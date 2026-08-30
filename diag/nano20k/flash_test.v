// Diagnosedesign: testet ausschliesslich den Flash-Lesepfad des MiSTeryNano-Cores
// LED0 = Flash-PLL eingerastet     LED3 = Wort @0x100000 == 0x602E (TOS-Magic)
// LED1 = Flash-Controller ready    LED4 = Wort @0x100002 == 0x0104 (TOS-Version)
// LED2 = Lesevorgang abgeschlossen LED5 = Herzschlag (Design laeuft)
module flash_test (
    input        clk,
    output [5:0] leds_n,
    output       mspi_cs,
    output       mspi_clk,
    inout        mspi_di,
    inout        mspi_hold,
    inout        mspi_wp,
    inout        mspi_do
);

wire flash_clk;
wire pll_lock_flash;

flash_pll pll_flash (
    .clkout  ( flash_clk      ),
    .clkoutp ( mspi_clk       ),
    .lock    ( pll_lock_flash ),
    .clkin   ( clk            )
);

wire resetn = pll_lock_flash;

wire        flash_ready;
wire        flash_busy;
wire [15:0] flash_dout;
reg  [21:0] address;
reg         cs;

flash flash_i (
    .clk      ( flash_clk   ),
    .resetn   ( resetn      ),
    .ready    ( flash_ready ),
    .address  ( address     ),
    .cs       ( cs          ),
    .dout     ( flash_dout  ),
    .mspi_cs  ( mspi_cs     ),
    .mspi_di  ( mspi_di     ),
    .mspi_hold( mspi_hold   ),
    .mspi_wp  ( mspi_wp     ),
    .mspi_do  ( mspi_do     ),
    .busy     ( flash_busy  )
);

reg [3:0]  st;
reg [15:0] word0;
reg [15:0] word1;
reg        done;

always @(posedge flash_clk or negedge resetn) begin
    if(!resetn) begin
        st <= 4'd0; cs <= 1'b0; done <= 1'b0;
        address <= 22'h080000; word0 <= 16'h0000; word1 <= 16'h0000;
    end else begin
        case(st)
            4'd0: if(flash_ready) st <= 4'd1;
            4'd1: begin address <= 22'h080000; st <= 4'd2; end
            4'd2: begin cs <= 1'b1; st <= 4'd3; end
            4'd3: if(flash_busy) st <= 4'd4;
            4'd4: if(!flash_busy) begin word0 <= flash_dout; cs <= 1'b0; st <= 4'd5; end
            4'd5: begin address <= 22'h080001; st <= 4'd6; end
            4'd6: begin cs <= 1'b1; st <= 4'd7; end
            4'd7: if(flash_busy) st <= 4'd8;
            4'd8: if(!flash_busy) begin word1 <= flash_dout; cs <= 1'b0; st <= 4'd9; end
            4'd9: done <= 1'b1;
            default: ;
        endcase
    end
end

reg [24:0] hb;
always @(posedge clk) hb <= hb + 25'd1;

wire [5:0] leds;
assign leds[0] = pll_lock_flash;
assign leds[1] = flash_ready;
assign leds[2] = done;
assign leds[3] = done && (word0 == 16'h602e);
assign leds[4] = done && (word1 == 16'h0104);
assign leds[5] = hb[24];
assign leds_n  = ~leds;

endmodule
