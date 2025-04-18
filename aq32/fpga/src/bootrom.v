`default_nettype none
`timescale 1 ns / 1 ps

module bootrom(
    input  wire        clk,
    input  wire  [8:0] addr,
    output reg  [31:0] rddata
);

    always @(posedge clk) case (addr)
        9'h000:  rddata <= 32'hFF201197;
        9'h001:  rddata <= 32'h00018193;
        9'h002:  rddata <= 32'hFF204117;
        9'h003:  rddata <= 32'h7F810113;
        9'h004:  rddata <= 32'hFF200297;
        9'h005:  rddata <= 32'h7F028293;
        9'h006:  rddata <= 32'hFF200317;
        9'h007:  rddata <= 32'h7E830313;
        9'h008:  rddata <= 32'h00C0006F;
        9'h009:  rddata <= 32'h0002A023;
        9'h00A:  rddata <= 32'h00428293;
        9'h00B:  rddata <= 32'hFE62ECE3;
        9'h00C:  rddata <= 32'hFF200297;
        9'h00D:  rddata <= 32'h7D028293;
        9'h00E:  rddata <= 32'hFF200317;
        9'h00F:  rddata <= 32'h7C830313;
        9'h010:  rddata <= 32'h00000397;
        9'h011:  rddata <= 32'h1B838393;
        9'h012:  rddata <= 32'h0140006F;
        9'h013:  rddata <= 32'h0003AE03;
        9'h014:  rddata <= 32'h00438393;
        9'h015:  rddata <= 32'h01C2A023;
        9'h016:  rddata <= 32'h00428293;
        9'h017:  rddata <= 32'hFE62E8E3;
        9'h018:  rddata <= 32'h00000297;
        9'h019:  rddata <= 32'h07428293;
        9'h01A:  rddata <= 32'h00028067;
        9'h01B:  rddata <= 32'hFF500737;
        9'h01C:  rddata <= 32'h00072783;
        9'h01D:  rddata <= 32'h0027F793;
        9'h01E:  rddata <= 32'hFE079CE3;
        9'h01F:  rddata <= 32'h00A72223;
        9'h020:  rddata <= 32'h00008067;
        9'h021:  rddata <= 32'hFF500737;
        9'h022:  rddata <= 32'h00072783;
        9'h023:  rddata <= 32'h0017F793;
        9'h024:  rddata <= 32'hFE078CE3;
        9'h025:  rddata <= 32'h00472503;
        9'h026:  rddata <= 32'h0FF57513;
        9'h027:  rddata <= 32'h00008067;
        9'h028:  rddata <= 32'hFF500737;
        9'h029:  rddata <= 32'h00072783;
        9'h02A:  rddata <= 32'h0017F793;
        9'h02B:  rddata <= 32'h02079063;
        9'h02C:  rddata <= 32'hFF500737;
        9'h02D:  rddata <= 32'h00072783;
        9'h02E:  rddata <= 32'h0027F793;
        9'h02F:  rddata <= 32'hFE079CE3;
        9'h030:  rddata <= 32'h10000793;
        9'h031:  rddata <= 32'h00F72223;
        9'h032:  rddata <= 32'hFA5FF06F;
        9'h033:  rddata <= 32'h00472783;
        9'h034:  rddata <= 32'hFD5FF06F;
        9'h035:  rddata <= 32'hFE010113;
        9'h036:  rddata <= 32'h00100513;
        9'h037:  rddata <= 32'h00112E23;
        9'h038:  rddata <= 32'h00812C23;
        9'h039:  rddata <= 32'h00912A23;
        9'h03A:  rddata <= 32'h01212823;
        9'h03B:  rddata <= 32'h01312623;
        9'h03C:  rddata <= 32'h01412423;
        9'h03D:  rddata <= 32'hFADFF0EF;
        9'h03E:  rddata <= 32'h01000513;
        9'h03F:  rddata <= 32'hFA5FF0EF;
        9'h040:  rddata <= 32'h00000513;
        9'h041:  rddata <= 32'h00000437;
        9'h042:  rddata <= 32'hF65FF0EF;
        9'h043:  rddata <= 32'h9E840413;
        9'h044:  rddata <= 32'h00044483;
        9'h045:  rddata <= 32'h00140413;
        9'h046:  rddata <= 32'h00048513;
        9'h047:  rddata <= 32'hF51FF0EF;
        9'h048:  rddata <= 32'hFE0498E3;
        9'h049:  rddata <= 32'hF61FF0EF;
        9'h04A:  rddata <= 32'h01851793;
        9'h04B:  rddata <= 32'h4187D793;
        9'h04C:  rddata <= 32'h00050493;
        9'h04D:  rddata <= 32'h0A07C663;
        9'h04E:  rddata <= 32'h80000937;
        9'h04F:  rddata <= 32'h01200513;
        9'h050:  rddata <= 32'hF61FF0EF;
        9'h051:  rddata <= 32'h00048513;
        9'h052:  rddata <= 32'hF25FF0EF;
        9'h053:  rddata <= 32'h00000513;
        9'h054:  rddata <= 32'hF1DFF0EF;
        9'h055:  rddata <= 32'h08000513;
        9'h056:  rddata <= 32'hF15FF0EF;
        9'h057:  rddata <= 32'hF29FF0EF;
        9'h058:  rddata <= 32'h01851513;
        9'h059:  rddata <= 32'h41855513;
        9'h05A:  rddata <= 32'h04054E63;
        9'h05B:  rddata <= 32'hF19FF0EF;
        9'h05C:  rddata <= 32'h01051413;
        9'h05D:  rddata <= 32'hF11FF0EF;
        9'h05E:  rddata <= 32'h41045413;
        9'h05F:  rddata <= 32'h00851513;
        9'h060:  rddata <= 32'h00A467B3;
        9'h061:  rddata <= 32'h01079A13;
        9'h062:  rddata <= 32'h00F907B3;
        9'h063:  rddata <= 32'h01079413;
        9'h064:  rddata <= 32'h410A5A13;
        9'h065:  rddata <= 32'h00090993;
        9'h066:  rddata <= 32'h01045413;
        9'h067:  rddata <= 32'h01099793;
        9'h068:  rddata <= 32'h0107D793;
        9'h069:  rddata <= 32'h00879863;
        9'h06A:  rddata <= 32'h01405E63;
        9'h06B:  rddata <= 32'h01490933;
        9'h06C:  rddata <= 32'hF8DFF06F;
        9'h06D:  rddata <= 32'h00198993;
        9'h06E:  rddata <= 32'hECDFF0EF;
        9'h06F:  rddata <= 32'hFEA98FA3;
        9'h070:  rddata <= 32'hFDDFF06F;
        9'h071:  rddata <= 32'h01100513;
        9'h072:  rddata <= 32'hED9FF0EF;
        9'h073:  rddata <= 32'h00048513;
        9'h074:  rddata <= 32'hE9DFF0EF;
        9'h075:  rddata <= 32'hEB1FF0EF;
        9'h076:  rddata <= 32'h800007B7;
        9'h077:  rddata <= 32'h000780E7;
        9'h078:  rddata <= 32'h0000006F;
        9'h079:  rddata <= 32'h00000000;
        9'h07A:  rddata <= 32'h32337161;
        9'h07B:  rddata <= 32'h6D6F722E;
        9'h07C:  rddata <= 32'h00000000;
        default: rddata <= 32'h00000000;
    endcase

endmodule
