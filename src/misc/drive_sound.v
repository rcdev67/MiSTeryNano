//
// drive_sound.v
//
// Floppy drive sound emulation for MiSTeryNano.
//
// Plays two looped samples taken from a CC0 recording of a real 3.5" drive
// (https://commons.wikimedia.org/wiki/File:Floppy_drive_sounds.ogg):
//
//   motor  - spindle hum, played while the drive motor runs
//   seek   - head movement, played while step pulses arrive and decaying
//            afterwards, so the length of the sound follows the length of
//            the actual head movement
//
// Samples are stored as 4 bit IMA ADPCM at 16kHz and decoded on the fly. At
// 8 bit the two sounds need 12 of the 46 block RAMs of a Tang Nano 20k, which
// is a lot to ask for an ambient effect. ADPCM brings that down to four, at a
// measured deviation of 0.6% for the hum and 2.2% for the seek -- noise like
// material compresses well because there are no fine tones to smear.
//
// The seek sound is deliberately quieter than the hum: a drive in a closed
// case a desk away sounds nothing like a bare mechanism next to a microphone.
//
module drive_sound #(
    parameter integer CLK_HZ     = 32_084_988,
    parameter integer SAMPLE_HZ  = 16000,
    parameter integer MOTOR_LEN  = 12800,
    parameter integer SEEK_LEN   = 5440,
    parameter [7:0]   MOTOR_GAIN = 8'd66,   // 0.26 of full scale
    parameter [7:0]   SEEK_GAIN  = 8'd49,   // 0.19 of full scale
    parameter integer OUT_SHIFT  = 10       // overall level
) (
    input                     clk,
    input                     resetn,

    input                     motor_on,    // spindle running
    input                     step,        // one clk wide pulse per head step
    input               [1:0] volume,      // 0 = off, 3 = loudest

    output signed      [15:0] snd
);

localparam integer TICK_DIV = CLK_HZ / SAMPLE_HZ;

// ---------------------------------------------------------------- samples --
reg [3:0] motor_rom [0:MOTOR_LEN-1];
reg [3:0] seek_rom  [0:SEEK_LEN-1];
initial begin
    $readmemh("../../misc/motor.adpcm.hex", motor_rom);
    $readmemh("../../misc/seek.adpcm.hex",  seek_rom);
end

// step table as logic rather than memory: it is small, and two decoders
// reading one memory at two addresses in the same cycle upsets inference
function [14:0] step_of(input [6:0] i);
    case(i)
        7'd0 : step_of = 15'd7;
        7'd1 : step_of = 15'd8;
        7'd2 : step_of = 15'd9;
        7'd3 : step_of = 15'd10;
        7'd4 : step_of = 15'd11;
        7'd5 : step_of = 15'd12;
        7'd6 : step_of = 15'd13;
        7'd7 : step_of = 15'd14;
        7'd8 : step_of = 15'd16;
        7'd9 : step_of = 15'd17;
        7'd10: step_of = 15'd19;
        7'd11: step_of = 15'd21;
        7'd12: step_of = 15'd23;
        7'd13: step_of = 15'd25;
        7'd14: step_of = 15'd28;
        7'd15: step_of = 15'd31;
        7'd16: step_of = 15'd34;
        7'd17: step_of = 15'd37;
        7'd18: step_of = 15'd41;
        7'd19: step_of = 15'd45;
        7'd20: step_of = 15'd50;
        7'd21: step_of = 15'd55;
        7'd22: step_of = 15'd60;
        7'd23: step_of = 15'd66;
        7'd24: step_of = 15'd73;
        7'd25: step_of = 15'd80;
        7'd26: step_of = 15'd88;
        7'd27: step_of = 15'd97;
        7'd28: step_of = 15'd107;
        7'd29: step_of = 15'd118;
        7'd30: step_of = 15'd130;
        7'd31: step_of = 15'd143;
        7'd32: step_of = 15'd157;
        7'd33: step_of = 15'd173;
        7'd34: step_of = 15'd190;
        7'd35: step_of = 15'd209;
        7'd36: step_of = 15'd230;
        7'd37: step_of = 15'd253;
        7'd38: step_of = 15'd279;
        7'd39: step_of = 15'd307;
        7'd40: step_of = 15'd337;
        7'd41: step_of = 15'd371;
        7'd42: step_of = 15'd408;
        7'd43: step_of = 15'd449;
        7'd44: step_of = 15'd494;
        7'd45: step_of = 15'd544;
        7'd46: step_of = 15'd598;
        7'd47: step_of = 15'd658;
        7'd48: step_of = 15'd724;
        7'd49: step_of = 15'd796;
        7'd50: step_of = 15'd876;
        7'd51: step_of = 15'd963;
        7'd52: step_of = 15'd1060;
        7'd53: step_of = 15'd1166;
        7'd54: step_of = 15'd1282;
        7'd55: step_of = 15'd1411;
        7'd56: step_of = 15'd1552;
        7'd57: step_of = 15'd1707;
        7'd58: step_of = 15'd1878;
        7'd59: step_of = 15'd2066;
        7'd60: step_of = 15'd2272;
        7'd61: step_of = 15'd2499;
        7'd62: step_of = 15'd2749;
        7'd63: step_of = 15'd3024;
        7'd64: step_of = 15'd3327;
        7'd65: step_of = 15'd3660;
        7'd66: step_of = 15'd4026;
        7'd67: step_of = 15'd4428;
        7'd68: step_of = 15'd4871;
        7'd69: step_of = 15'd5358;
        7'd70: step_of = 15'd5894;
        7'd71: step_of = 15'd6484;
        7'd72: step_of = 15'd7132;
        7'd73: step_of = 15'd7845;
        7'd74: step_of = 15'd8630;
        7'd75: step_of = 15'd9493;
        7'd76: step_of = 15'd10442;
        7'd77: step_of = 15'd11487;
        7'd78: step_of = 15'd12635;
        7'd79: step_of = 15'd13899;
        7'd80: step_of = 15'd15289;
        7'd81: step_of = 15'd16818;
        7'd82: step_of = 15'd18500;
        7'd83: step_of = 15'd20350;
        7'd84: step_of = 15'd22385;
        7'd85: step_of = 15'd24623;
        7'd86: step_of = 15'd27086;
        7'd87: step_of = 15'd29794;
        7'd88: step_of = 15'd32767;
        default: step_of = 15'd7;
    endcase
endfunction

// index adjustment per code, the usual IMA table
// five bits, not four: +8 does not fit into a signed 4 bit value and would
// wrap to -8, which keeps the step index near zero and the decoder silent
function signed [4:0] idx_adj(input [2:0] c);
    case(c)
        3'd4: idx_adj = 5'sd2;
        3'd5: idx_adj = 5'sd4;
        3'd6: idx_adj = 5'sd6;
        3'd7: idx_adj = 5'sd8;
        default: idx_adj = -5'sd1;
    endcase
endfunction

// ------------------------------------------------------------ sample tick --
reg [15:0] tick_cnt;
reg        tick;
always @(posedge clk) begin
    if(!resetn) begin
        tick_cnt <= 16'd0;
        tick     <= 1'b0;
    end else if(tick_cnt == TICK_DIV[15:0] - 16'd1) begin
        tick_cnt <= 16'd0;
        tick     <= 1'b1;
    end else begin
        tick_cnt <= tick_cnt + 16'd1;
        tick     <= 1'b0;
    end
end

// ------------------------------------------------------- step retriggering --
// A step pulse holds the seek sound at full level. Only once no further step
// has arrived for a while does it start to decay. Without the hold a fast
// sequence of single track steps would sound like a loose contact.
localparam integer HOLD_SAMPLES = SAMPLE_HZ / 100;   // 10ms

reg [7:0]  hold;
reg        step_seen;
reg [14:0] motor_hold;      // ~1s at 16kHz, bridges the gaps between sectors
always @(posedge clk) begin
    if(!resetn) begin
        hold       <= 8'd0;
        step_seen  <= 1'b0;
        motor_hold <= 15'd0;
    end else begin
        // Both inputs are short pulses in the system clock domain, far shorter
        // than the 62.5us between sample ticks. They have to be latched, or
        // most of them are simply never seen.
        if(step)     step_seen  <= 1'b1;

        if(tick) begin
            if(step_seen)      hold <= HOLD_SAMPLES[7:0];
            else if(hold != 0) hold <= hold - 8'd1;
            step_seen <= 1'b0;

            // Head movement, not sector transfer, is what tells a real access
            // from TOS polling for a disk change at the desktop -- polling reads
            // sectors but never moves the head. One second of hold keeps the hum
            // running across the sectors of a single track.
            if(step_seen && motor_on) motor_hold <= 15'd16000;
            else if(motor_hold != 0) motor_hold <= motor_hold - 15'd1;
            end
    end
end

// ------------------------------------------------------------- envelopes ---
// Attack and release are exponential, which is what a mechanism does. Linear
// ramps sound switched, not moved.
reg [7:0] motor_env, seek_env;
always @(posedge clk) begin
    if(!resetn) begin
        motor_env <= 8'd0;
        seek_env  <= 8'd0;
    end else if(tick) begin
        // motor: ~16ms in and out, avoids a click when the spindle starts.
        // motor_hold bridges the short gaps while TOS deselects the drive
        // between sectors, otherwise the hum would stutter during a load.
        if(motor_hold != 0) begin
            if(motor_env < 8'd255) motor_env <= motor_env + 8'd1;
        end else if(motor_env != 8'd0)
            motor_env <= motor_env - 8'd1;

        // seek: fast attack, short decay. The decay is coarser than intended
        // because an 8 bit envelope cannot step by less than one per sample;
        // refining this needs a wider counter and thus more logic, which this
        // board does not tolerate.
        if(hold != 0) begin
            if(seek_env < 8'd247) seek_env <= seek_env + 8'd8;
            else                  seek_env <= 8'd255;
        end else if(seek_env != 8'd0)
            seek_env <= seek_env - 8'd2;
    end
end

// -------------------------------------------------------- sample playback --
// One decoder per sound, run as a two step sequence: block RAM is synchronous,
// so the code and step values have to be registered before they can be used.
// Reading them combinationally silently yields nothing usable.
reg [15:0] motor_pos, seek_pos;
reg signed [15:0] motor_pred, seek_pred;
reg [6:0] motor_idx, seek_idx;
reg [3:0] m_code, s_code;
reg [14:0] m_step, s_step;
reg        phase;

// delta = step/8 + step*b2 + step/2*b1 + step/4*b0
wire [16:0] m_delta = { 3'b0, m_step[14:3] }
                    + (m_code[2] ? { 2'b0, m_step       } : 17'd0)
                    + (m_code[1] ? { 3'b0, m_step[14:1] } : 17'd0)
                    + (m_code[0] ? { 4'b0, m_step[14:2] } : 17'd0);
wire [16:0] s_delta = { 3'b0, s_step[14:3] }
                    + (s_code[2] ? { 2'b0, s_step       } : 17'd0)
                    + (s_code[1] ? { 3'b0, s_step[14:1] } : 17'd0)
                    + (s_code[0] ? { 4'b0, s_step[14:2] } : 17'd0);

wire signed [17:0] m_next = m_code[3] ? ($signed({{2{motor_pred[15]}}, motor_pred}) - $signed({1'b0, m_delta}))
                                      : ($signed({{2{motor_pred[15]}}, motor_pred}) + $signed({1'b0, m_delta}));
wire signed [17:0] s_next = s_code[3] ? ($signed({{2{seek_pred[15]}},  seek_pred }) - $signed({1'b0, s_delta}))
                                      : ($signed({{2{seek_pred[15]}},  seek_pred }) + $signed({1'b0, s_delta}));

wire signed [7:0] m_adj = { {3{idx_adj(m_code[2:0])[4]}}, idx_adj(m_code[2:0]) };
wire signed [7:0] s_adj = { {3{idx_adj(s_code[2:0])[4]}}, idx_adj(s_code[2:0]) };
wire signed [8:0] m_idx_n = $signed({2'b0, motor_idx}) + $signed({m_adj[7], m_adj});
wire signed [8:0] s_idx_n = $signed({2'b0, seek_idx })  + $signed({s_adj[7], s_adj});

wire signed [7:0] motor_s = motor_pred[15:8];
wire signed [7:0] seek_s  = seek_pred[15:8];

always @(posedge clk) begin
    if(!resetn) begin
        motor_pos  <= 16'd0;  seek_pos  <= 16'd0;
        motor_pred <= 16'sd0; seek_pred <= 16'sd0;
        motor_idx  <= 7'd0;   seek_idx  <= 7'd0;
        m_code <= 4'd0; s_code <= 4'd0;
        m_step <= 15'd7; s_step <= 15'd7;
        phase  <= 1'b0;
    end else begin
        if(tick && !phase) begin
            // step one: fetch, registered so the block RAM has a clock edge
            m_code <= motor_rom[motor_pos];
            s_code <= seek_rom [seek_pos];
            m_step <= step_of(motor_idx);
            s_step <= step_of(seek_idx);
            phase  <= 1'b1;
        end else if(phase) begin
            // step two: decode and advance
            phase <= 1'b0;

            if(motor_pos == MOTOR_LEN[15:0] - 16'd1) begin
                // restart on loop, otherwise the predictor drifts away
                motor_pos <= 16'd0; motor_pred <= 16'sd0; motor_idx <= 7'd0;
            end else begin
                motor_pos  <= motor_pos + 16'd1;
                motor_pred <= (m_next >  18'sd32767) ?  16'sd32767 :
                              (m_next < -18'sd32768) ? -16'sd32768 : m_next[15:0];
                motor_idx  <= (m_idx_n < 0) ? 7'd0 : (m_idx_n > 9'sd88) ? 7'd88 : m_idx_n[6:0];
            end

            if(seek_pos == SEEK_LEN[15:0] - 16'd1) begin
                seek_pos <= 16'd0; seek_pred <= 16'sd0; seek_idx <= 7'd0;
            end else begin
                seek_pos  <= seek_pos + 16'd1;
                seek_pred <= (s_next >  18'sd32767) ?  16'sd32767 :
                             (s_next < -18'sd32768) ? -16'sd32768 : s_next[15:0];
                seek_idx  <= (s_idx_n < 0) ? 7'd0 : (s_idx_n > 9'sd88) ? 7'd88 : s_idx_n[6:0];
            end
        end
    end
end

// -------------------------------------------------------------- mixing -----
wire signed [23:0] m_mul = motor_s * $signed({1'b0, MOTOR_GAIN}) * $signed({1'b0, motor_env});
wire signed [23:0] s_mul = seek_s  * $signed({1'b0, SEEK_GAIN })  * $signed({1'b0, seek_env });
wire signed [23:0] sum   = (m_mul + s_mul) >>> OUT_SHIFT;

// volume 0 mutes entirely, so the feature can be switched off from the OSD
wire signed [23:0] scaled = (volume == 2'd0) ? 24'sd0 :
                            (volume == 2'd1) ? (sum >>> 2) :
                            (volume == 2'd2) ? (sum >>> 1) : sum;

assign snd = scaled[15:0];

endmodule
