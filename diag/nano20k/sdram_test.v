// Diagnosedesign: testet den SDRAM-Datenpfad mit dem Controller des Cores
// LED0 = PLL eingerastet        LED3 = alle Vergleiche korrekt (PASS)
// LED1 = ram_ready              LED4 = mindestens ein Fehler (FAIL)
// LED2 = Test abgeschlossen     LED5 = Herzschlag
module sdram_test (
    input         clk,
    output [5:0]  leds_n,
    // "Magic" Portnamen, die der Gowin-Compiler an das On-Chip-SDRAM bindet
    output        O_sdram_clk,
    output        O_sdram_cke,
    output        O_sdram_cs_n,
    output        O_sdram_cas_n,
    output        O_sdram_ras_n,
    output        O_sdram_wen_n,
    inout  [31:0] IO_sdram_dq,
    output [10:0] O_sdram_addr,
    output [1:0]  O_sdram_ba,
    output [3:0]  O_sdram_dqm
);

wire clk_pixel_x5, clk32, pll_lock;

pll_160m pll_hdmi   (.clkout(clk_pixel_x5), .lock(pll_lock), .clkin(clk));
Gowin_CLKDIV clk_div_5 (.hclkin(clk_pixel_x5), .resetn(pll_lock), .clkout(clk32));

wire [12:0] sdram_addr_full;
assign O_sdram_addr = sdram_addr_full[10:0];

wire        ram_ready;
wire [15:0] dout;
reg  [21:0] addr;
reg  [15:0] din;
reg         cs, we;

sdram sdram_i (
    .clk     ( clk32          ),
    .reset_n ( pll_lock       ),
    .ready   ( ram_ready      ),
    .sd_clk  ( O_sdram_clk    ),
    .sd_cke  ( O_sdram_cke    ),
    .sd_data ( IO_sdram_dq    ),
    .sd_addr ( sdram_addr_full),
    .sd_dqm  ( O_sdram_dqm    ),
    .sd_ba   ( O_sdram_ba     ),
    .sd_cs   ( O_sdram_cs_n   ),
    .sd_we   ( O_sdram_wen_n  ),
    .sd_ras  ( O_sdram_ras_n  ),
    .sd_cas  ( O_sdram_cas_n  ),
    .refresh ( 1'b0           ),
    .din     ( din            ),
    .dout    ( dout           ),
    .addr    ( addr           ),
    .ds      ( 2'b00          ),
    .cs      ( cs             ),
    .we      ( we             )
);

// Testmuster und Adressverteilung ueber alle vier Baenke und beide Bushaelften
wire [4:0]  idx_w;
reg  [4:0]  idx;
wire [15:0] pattern = 16'ha55a ^ { 11'd0, idx };
assign idx_w = idx;

reg [2:0]  fsm;
reg [4:0]  cnt;
reg        phase;   // 0 = schreiben, 1 = lesen
reg        fail, done;

always @(posedge clk32) begin
    if(!ram_ready) begin
        fsm <= 3'd0; cnt <= 5'd0; idx <= 5'd0;
        phase <= 1'b0; fail <= 1'b0; done <= 1'b0;
        cs <= 1'b0; we <= 1'b0;
    end else begin
        case(fsm)
        3'd0: begin
            addr <= { idx, 16'd0, idx[0] };
            din  <= pattern;
            we   <= ~phase;
            cnt  <= 5'd0;
            fsm  <= 3'd1;
        end
        3'd1: begin cs <= 1'b1; fsm <= 3'd2; end
        3'd2: begin
            cnt <= cnt + 5'd1;
            if(cnt == 5'd20) begin cs <= 1'b0; fsm <= 3'd3; end
        end
        3'd3: begin
            if(phase && (dout != pattern)) fail <= 1'b1;
            fsm <= 3'd4;
        end
        3'd4: begin
            if(idx == 5'd31) begin
                idx <= 5'd0;
                if(!phase) begin phase <= 1'b1; fsm <= 3'd0; end
                else       begin done  <= 1'b1; fsm <= 3'd5; end
            end else begin
                idx <= idx + 5'd1;
                fsm <= 3'd0;
            end
        end
        default: ;
        endcase
    end
end

reg [24:0] hb;
always @(posedge clk) hb <= hb + 25'd1;

wire [5:0] leds;
assign leds[0] = pll_lock;
assign leds[1] = ram_ready;
assign leds[2] = done;
assign leds[3] = done && !fail;
assign leds[4] = fail;
assign leds[5] = hb[24];
assign leds_n  = ~leds;

endmodule
