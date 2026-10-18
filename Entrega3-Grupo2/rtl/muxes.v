`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Multiplexadores do datapath (Entrega 1). Mesma codificacao da FSM (Entrega 2).
// -----------------------------------------------------------------------------

// IorD: 00 = PC | 01 = ALUOut | 10 = Exception Address (253/254/255)
module mux_iord (
    input  wire [1:0]  sel,
    input  wire [31:0] in0, in1, in2,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            default: out = in0;
        endcase
    end
endmodule

// ALUSrcA: 0 = PC | 1 = A
module mux_alusrca (
    input  wire        sel,
    input  wire [31:0] in0, in1,
    output wire [31:0] out
);
    assign out = sel ? in1 : in0;
endmodule

// ALUSrcB: 00 = B | 01 = 4 | 10 = SignExt | 11 = SignExt << 2
module mux_alusrcb (
    input  wire [1:0]  sel,
    input  wire [31:0] in0, in2, in3,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            2'b00: out = in0;
            2'b01: out = 32'd4;
            2'b10: out = in2;
            2'b11: out = in3;
        endcase
    end
endmodule

// SrcSP (Read register 1): 0 = rs (IR[25-21]) | 1 = 29
module mux_readreg1 (
    input  wire       sel,
    input  wire [4:0] in0,
    output wire [4:0] out
);
    assign out = sel ? 5'd29 : in0;
endmodule

// SrcSP (Read register 2): 0 = rt (IR[20-16]) | 1 = rs (IR[25-21])
module mux_readreg2 (
    input  wire       sel,
    input  wire [4:0] in0, in1,
    output wire [4:0] out
);
    assign out = sel ? in1 : in0;
endmodule

// RegDst: 00 = rt | 01 = rd | 10 = 31 | 11 = 29
module mux_regdst (
    input  wire [1:0] sel,
    input  wire [4:0] in0, in1,
    output reg  [4:0] out
);
    always @(*) begin
        case (sel)
            2'b00: out = in0;
            2'b01: out = in1;
            2'b10: out = 5'd31;
            2'b11: out = 5'd29;
        endcase
    end
endmodule

// MemtoReg: 0 = ALUOut | 1 = MDR | 2 = HI | 3 = LO | 4 = Shift Reg
//           5 = Load Size | 6 = imm << 16 | 7 = 227 | 8 = LT (flag Menor)
module mux_memtoreg (
    input  wire [3:0]  sel,
    input  wire [31:0] in0, in1, in2, in3, in4, in5, in6,
    input  wire        lt,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            4'd0:    out = in0;
            4'd1:    out = in1;
            4'd2:    out = in2;
            4'd3:    out = in3;
            4'd4:    out = in4;
            4'd5:    out = in5;
            4'd6:    out = in6;
            4'd7:    out = 32'd227;
            4'd8:    out = {31'd0, lt};
            default: out = in0;
        endcase
    end
endmodule

// PCSource: 000 = ALU result | 001 = ALUOut | 010 = Jump address
//           011 = EPC        | 100 = Zero extender
module mux_pcsource (
    input  wire [2:0]  sel,
    input  wire [31:0] in0, in1, in2, in3, in4,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            3'd0:    out = in0;
            3'd1:    out = in1;
            3'd2:    out = in2;
            3'd3:    out = in3;
            3'd4:    out = in4;
            default: out = in0;
        endcase
    end
endmodule

// ByteWrite (Write data da memoria): 0 = B | 1 = Store Size
module mux_bytewrite (
    input  wire        sel,
    input  wire [31:0] in0, in1,
    output wire [31:0] out
);
    assign out = sel ? in1 : in0;
endmodule

// HISelect: 0 = DIV | 1 = MULT  (entrada do registrador HI)
// LOSelect: 0 = MULT | 1 = DIV  (entrada do registrador LO)
module mux_2x32 (
    input  wire        sel,
    input  wire [31:0] in0, in1,
    output wire [31:0] out
);
    assign out = sel ? in1 : in0;
endmodule
