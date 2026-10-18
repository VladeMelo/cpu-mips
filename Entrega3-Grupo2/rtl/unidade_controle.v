`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Unidade de Controle - Grupo 2
//
// Maquina de estados (Moore) transcrita da Entrega 2 (FSM-Grupo2-linhas.drawio).
// Cada estado = 1 ciclo de clock. Em cada estado so os sinais listados na FSM
// sao ativados; os demais ficam em 0 (enables) ou no valor padrao (seletores).
// Reset = 1 em qualquer estado leva a S_RESET.
//
// Codificacao dos seletores (igual ao datapath da Entrega 1):
//   IorD: 00=PC 01=ALUOut 10=Exception Address
//   ALUSrcA: 0=PC 1=A   |  ALUSrcB: 00=B 01=4 10=SignExt 11=SignExt<<2
//   ALUOp: 000=S=A 001=ADD 010=SUB 011=AND 111=CMP
//   RegDst: 00=rt 01=rd 10=$31 11=$29
//   MemtoReg: 0=ALUOut 1=MDR 2=HI 3=LO 4=ShiftReg 5=LoadSize 6=imm<<16 7=227 8=LT
//   PCSource: 000=ALU result 001=ALUOut 010=Jump address 011=EPC 100=Zero ext.
//   SrcSP: 0 -> RR1=rs, RR2=rt | 1 -> RR1=$29, RR2=rs
//   ByteWrite: 0=B 1=Store Size | ShiftOp: 000 nada 001 load 010 esq 100 dir arit
//   HISelect: 0=DIV 1=MULT | LOSelect: 0=MULT 1=DIV (guardados na UC)
//   ExcType: 00=opcode inexistente 01=overflow 10=div por zero
// -----------------------------------------------------------------------------
module unidade_controle (
    input  wire       clk,
    input  wire       reset,

    // entradas vindas do datapath
    input  wire [5:0] op,          // IR[31-26]
    input  wire [5:0] funct,       // IR[5-0]
    input  wire       overflow,    // flag O da ULA
    input  wire       mult_end,    // MultEnd
    input  wire       div_end,     // DivEnd
    input  wire       div0,        // DIV0

    // saidas (sinais de controle)
    output reg        PCWrite,
    output reg        PCWriteCond,
    output reg  [1:0] IorD,
    output reg        MemRead,
    output reg        MemWrite,
    output reg  [3:0] MemtoReg,
    output reg        IRWrite,
    output reg  [2:0] PCSource,
    output reg  [2:0] ALUOp,
    output reg  [1:0] ALUSrcB,
    output reg        ALUSrcA,
    output reg        RegWrite,
    output reg  [1:0] RegDst,
    output reg  [2:0] ShiftOp,
    output reg        SrcSP,
    output reg        EPCWrite,
    output reg  [1:0] ExcType,
    output reg        ByteWrite,
    output wire       HISelect,
    output wire       LOSelect,
    output reg        MultStart,
    output reg        DivStart,

    output reg  [6:0] estado        // estado atual (para a simulacao)
);

    // ------------------------------------------------------------- estados
    localparam S_RESET      = 7'd0,
               S_INIT_SP    = 7'd1,
               S_FETCH1     = 7'd2,
               S_FETCH_WAIT = 7'd3,
               S_FETCH2     = 7'd4,
               S_DECODE     = 7'd5,
               // tipo R
               S_ADD        = 7'd6,
               S_ADD_WB     = 7'd7,
               S_SUB        = 7'd8,
               S_SUB_WB     = 7'd9,
               S_AND        = 7'd10,
               S_AND_WB     = 7'd11,
               S_SLT        = 7'd12,
               S_SLL_LD     = 7'd13,
               S_SLL        = 7'd14,
               S_SLL_WB     = 7'd15,
               S_SRA_LD     = 7'd16,
               S_SRA        = 7'd17,
               S_SRA_WB     = 7'd18,
               S_JR         = 7'd19,
               S_RTE        = 7'd20,
               S_MULT_START = 7'd21,
               S_MULT_WAIT  = 7'd22,
               S_MULT_END   = 7'd23,
               S_DIV_START  = 7'd24,
               S_DIV_WAIT   = 7'd25,
               S_DIV_END    = 7'd26,
               S_MFHI       = 7'd27,
               S_MFLO       = 7'd28,
               S_PUSH1      = 7'd29,
               S_PUSH2      = 7'd30,
               S_PUSH3      = 7'd31,
               S_POP1       = 7'd32,
               S_POP2       = 7'd33,
               S_POP_REQ    = 7'd34,
               S_POP_WAIT   = 7'd35,
               S_POP_MDR    = 7'd36,
               S_POP_WB     = 7'd37,
               S_POP_INC    = 7'd38,
               // tipo I
               S_ADDI       = 7'd39,
               S_ADDI_WB    = 7'd40,
               S_LUI        = 7'd41,
               S_LW_ADDR    = 7'd42,
               S_LW_REQ     = 7'd43,
               S_LW_WAIT    = 7'd44,
               S_LW_MDR     = 7'd45,
               S_LW_WB      = 7'd46,
               S_LB_ADDR    = 7'd47,
               S_LB_REQ     = 7'd48,
               S_LB_WAIT    = 7'd49,
               S_LB_MDR     = 7'd50,
               S_LB_WB      = 7'd51,
               S_SW_ADDR    = 7'd52,
               S_SW         = 7'd53,
               S_SB_ADDR    = 7'd54,
               S_SB_REQ     = 7'd55,
               S_SB_WAIT    = 7'd56,
               S_SB_MDR     = 7'd57,
               S_SB_WR      = 7'd58,
               S_BEQ        = 7'd59,
               S_BNE1       = 7'd60,
               S_BNE2       = 7'd61,
               // tipo J
               S_J          = 7'd62,
               S_JAL1       = 7'd63,
               S_JAL2       = 7'd64,
               // excecoes
               S_EXC_OP1    = 7'd65,
               S_EXC_OP2    = 7'd66,
               S_EXC_OP3    = 7'd67,
               S_EXC_OP4    = 7'd68,
               S_EXC_OVF1   = 7'd69,
               S_EXC_OVF2   = 7'd70,
               S_EXC_OVF3   = 7'd71,
               S_EXC_OVF4   = 7'd72,
               S_EXC_DIV1   = 7'd73,
               S_EXC_DIV2   = 7'd74,
               S_EXC_DIV3   = 7'd75,
               S_EXC_DIV4   = 7'd76;

    // ------------------------------------------------------------- opcodes
    localparam OP_R    = 6'h00,
               OP_J    = 6'h02,
               OP_JAL  = 6'h03,
               OP_BEQ  = 6'h04,
               OP_BNE  = 6'h05,
               OP_ADDI = 6'h08,
               OP_LUI  = 6'h0F,
               OP_LB   = 6'h20,
               OP_LW   = 6'h23,
               OP_SB   = 6'h28,
               OP_SW   = 6'h2B;

    localparam F_SLL  = 6'h00,
               F_SRA  = 6'h03,
               F_PUSH = 6'h05,
               F_POP  = 6'h06,
               F_JR   = 6'h08,
               F_MFHI = 6'h10,
               F_MFLO = 6'h12,
               F_RTE  = 6'h13,
               F_MULT = 6'h18,
               F_DIV  = 6'h1A,
               F_ADD  = 6'h20,
               F_SUB  = 6'h22,
               F_AND  = 6'h24,
               F_SLT  = 6'h2A;

    reg [6:0] prox;

    // HISelect / LOSelect guardados na UC: so mudam em S_MULT_END / S_DIV_END
    reg hisel_reg, losel_reg;
    assign HISelect = (estado == S_MULT_END) ? 1'b1 :
                      (estado == S_DIV_END)  ? 1'b0 : hisel_reg;
    assign LOSelect = (estado == S_MULT_END) ? 1'b0 :
                      (estado == S_DIV_END)  ? 1'b1 : losel_reg;

    // ------------------------------------------------------------- registrador de estado
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            estado    <= S_RESET;
            hisel_reg <= 1'b0;
            losel_reg <= 1'b0;
        end else begin
            estado    <= prox;
            hisel_reg <= HISelect;
            losel_reg <= LOSelect;
        end
    end

    // ------------------------------------------------------------- proximo estado
    always @(*) begin
        prox = S_FETCH1;
        case (estado)
            S_RESET:      prox = S_INIT_SP;
            S_INIT_SP:    prox = S_FETCH1;
            S_FETCH1:     prox = S_FETCH_WAIT;
            S_FETCH_WAIT: prox = S_FETCH2;
            S_FETCH2:     prox = S_DECODE;

            S_DECODE: begin
                case (op)
                    OP_R: begin
                        case (funct)
                            F_ADD:   prox = S_ADD;
                            F_SUB:   prox = S_SUB;
                            F_AND:   prox = S_AND;
                            F_SLT:   prox = S_SLT;
                            F_SLL:   prox = S_SLL_LD;
                            F_SRA:   prox = S_SRA_LD;
                            F_JR:    prox = S_JR;
                            F_RTE:   prox = S_RTE;
                            F_MULT:  prox = S_MULT_START;
                            F_DIV:   prox = S_DIV_START;
                            F_MFHI:  prox = S_MFHI;
                            F_MFLO:  prox = S_MFLO;
                            F_PUSH:  prox = S_PUSH1;
                            F_POP:   prox = S_POP1;
                            default: prox = S_EXC_OP1;   // funct inexistente
                        endcase
                    end
                    OP_ADDI: prox = S_ADDI;
                    OP_LUI:  prox = S_LUI;
                    OP_LW:   prox = S_LW_ADDR;
                    OP_LB:   prox = S_LB_ADDR;
                    OP_SW:   prox = S_SW_ADDR;
                    OP_SB:   prox = S_SB_ADDR;
                    OP_BEQ:  prox = S_BEQ;
                    OP_BNE:  prox = S_BNE1;
                    OP_J:    prox = S_J;
                    OP_JAL:  prox = S_JAL1;
                    default: prox = S_EXC_OP1;           // opcode inexistente
                endcase
            end

            // ---- tipo R
            S_ADD:        prox = overflow ? S_EXC_OVF1 : S_ADD_WB;
            S_SUB:        prox = overflow ? S_EXC_OVF1 : S_SUB_WB;
            S_AND:        prox = S_AND_WB;
            S_SLL_LD:     prox = S_SLL;
            S_SLL:        prox = S_SLL_WB;
            S_SRA_LD:     prox = S_SRA;
            S_SRA:        prox = S_SRA_WB;
            S_MULT_START: prox = S_MULT_WAIT;
            S_MULT_WAIT:  prox = mult_end ? S_MULT_END : S_MULT_WAIT;
            S_DIV_START:  prox = S_DIV_WAIT;
            S_DIV_WAIT:   prox = div0    ? S_EXC_DIV1 :
                                 div_end ? S_DIV_END  : S_DIV_WAIT;
            S_PUSH1:      prox = S_PUSH2;
            S_PUSH2:      prox = S_PUSH3;
            S_POP1:       prox = S_POP2;
            S_POP2:       prox = S_POP_REQ;
            S_POP_REQ:    prox = S_POP_WAIT;
            S_POP_WAIT:   prox = S_POP_MDR;
            S_POP_MDR:    prox = S_POP_WB;
            S_POP_WB:     prox = S_POP_INC;

            // ---- tipo I
            S_ADDI:       prox = overflow ? S_EXC_OVF1 : S_ADDI_WB;
            S_LW_ADDR:    prox = S_LW_REQ;
            S_LW_REQ:     prox = S_LW_WAIT;
            S_LW_WAIT:    prox = S_LW_MDR;
            S_LW_MDR:     prox = S_LW_WB;
            S_LB_ADDR:    prox = S_LB_REQ;
            S_LB_REQ:     prox = S_LB_WAIT;
            S_LB_WAIT:    prox = S_LB_MDR;
            S_LB_MDR:     prox = S_LB_WB;
            S_SW_ADDR:    prox = S_SW;
            S_SB_ADDR:    prox = S_SB_REQ;
            S_SB_REQ:     prox = S_SB_WAIT;
            S_SB_WAIT:    prox = S_SB_MDR;
            S_SB_MDR:     prox = S_SB_WR;
            S_BNE1:       prox = S_BNE2;

            // ---- tipo J
            S_JAL1:       prox = S_JAL2;

            // ---- excecoes
            S_EXC_OP1:    prox = S_EXC_OP2;
            S_EXC_OP2:    prox = S_EXC_OP3;
            S_EXC_OP3:    prox = S_EXC_OP4;
            S_EXC_OVF1:   prox = S_EXC_OVF2;
            S_EXC_OVF2:   prox = S_EXC_OVF3;
            S_EXC_OVF3:   prox = S_EXC_OVF4;
            S_EXC_DIV1:   prox = S_EXC_DIV2;
            S_EXC_DIV2:   prox = S_EXC_DIV3;
            S_EXC_DIV3:   prox = S_EXC_DIV4;

            // ultimos estados de cada instrucao: voltam a S_FETCH1
            default:      prox = S_FETCH1;
        endcase
    end

    // ------------------------------------------------------------- saidas
    always @(*) begin
        // valores padrao: enables em 0, seletores em 0
        PCWrite     = 1'b0;
        PCWriteCond = 1'b0;
        IorD        = 2'b00;
        MemRead     = 1'b0;
        MemWrite    = 1'b0;
        MemtoReg    = 4'd0;
        IRWrite     = 1'b0;
        PCSource    = 3'b000;
        ALUOp       = 3'b000;
        ALUSrcB     = 2'b00;
        ALUSrcA     = 1'b0;
        RegWrite    = 1'b0;
        RegDst      = 2'b00;
        ShiftOp     = 3'b000;
        SrcSP       = 1'b0;
        EPCWrite    = 1'b0;
        ExcType     = 2'b00;
        ByteWrite   = 1'b0;
        MultStart   = 1'b0;
        DivStart    = 1'b0;

        case (estado)
            // ======================================== reset, busca, decodificacao
            S_RESET: ; // todas as escritas = 0

            S_INIT_SP: begin                       // $29 <- 227
                RegWrite = 1'b1; RegDst = 2'b11; MemtoReg = 4'd7;
            end

            S_FETCH1, S_FETCH_WAIT: begin
                MemRead = 1'b1; IorD = 2'b00;
            end

            S_FETCH2: begin                        // IR <- Mem[PC]; PC <- PC + 4
                MemRead = 1'b1; IorD = 2'b00; IRWrite = 1'b1;
                ALUSrcA = 1'b0; ALUSrcB = 2'b01; ALUOp = 3'b001;
                PCSource = 3'b000; PCWrite = 1'b1;
            end

            S_DECODE: begin                        // ALUOut <- PC + (SignExt << 2)
                SrcSP = 1'b0;
                ALUSrcA = 1'b0; ALUSrcB = 2'b11; ALUOp = 3'b001;
            end

            // ======================================== tipo R
            S_ADD: begin
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b001;
            end
            S_SUB: begin
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b010;
            end
            S_AND: begin
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b011;
            end
            S_ADD_WB, S_SUB_WB, S_AND_WB: begin    // rd <- ALUOut
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd0;
            end

            S_SLT: begin                           // rd <- (rs < rt)
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b111;
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd8;
            end

            S_SLL_LD, S_SRA_LD: ShiftOp = 3'b001;  // carrega rt no Shift Reg
            S_SLL:              ShiftOp = 3'b010;  // esquerda shamt vezes
            S_SRA:              ShiftOp = 3'b100;  // direita aritmetico shamt vezes
            S_SLL_WB, S_SRA_WB: begin              // rd <- Shift Reg
                ShiftOp = 3'b000;
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd4;
            end

            S_JR: begin                            // PC <- rs
                ALUSrcA = 1'b1; ALUOp = 3'b000;
                PCSource = 3'b000; PCWrite = 1'b1;
            end

            S_RTE: begin                           // PC <- EPC
                PCSource = 3'b011; PCWrite = 1'b1;
            end

            S_MULT_START: MultStart = 1'b1;
            S_DIV_START:  DivStart  = 1'b1;
            S_MULT_WAIT, S_DIV_WAIT, S_MULT_END, S_DIV_END: ; // HISelect/LOSelect acima

            S_MFHI: begin
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd2;
            end
            S_MFLO: begin
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd3;
            end

            S_PUSH1: SrcSP = 1'b1;                 // A <- $29, B <- rs
            S_PUSH2: begin                         // ALUOut <- SP - 4
                SrcSP = 1'b1; ALUSrcA = 1'b1; ALUSrcB = 2'b01; ALUOp = 3'b010;
            end
            S_PUSH3: begin                         // $29 <- SP - 4; Mem[SP - 4] <- rs
                SrcSP = 1'b1; ALUSrcA = 1'b1; ALUSrcB = 2'b01; ALUOp = 3'b010;
                RegWrite = 1'b1; RegDst = 2'b11; MemtoReg = 4'd0;
                MemWrite = 1'b1; IorD = 2'b01; ByteWrite = 1'b0;
            end

            S_POP1: SrcSP = 1'b1;                  // A <- $29
            S_POP2: begin                          // ALUOut <- SP
                SrcSP = 1'b1; ALUSrcA = 1'b1; ALUOp = 3'b000;
            end
            S_POP_REQ, S_POP_WAIT, S_POP_MDR: begin // MDR <- Mem[SP]
                SrcSP = 1'b1; ALUSrcA = 1'b1; ALUOp = 3'b000;
                MemRead = 1'b1; IorD = 2'b01;
            end
            S_POP_WB: begin                        // rd <- MDR; ALUOut <- SP + 4
                ALUSrcA = 1'b1; ALUSrcB = 2'b01; ALUOp = 3'b001;
                RegWrite = 1'b1; RegDst = 2'b01; MemtoReg = 4'd1;
            end
            S_POP_INC: begin                       // $29 <- SP + 4
                RegWrite = 1'b1; RegDst = 2'b11; MemtoReg = 4'd0;
            end

            // ======================================== tipo I
            S_ADDI, S_LW_ADDR, S_LB_ADDR, S_SW_ADDR, S_SB_ADDR: begin
                ALUSrcA = 1'b1; ALUSrcB = 2'b10; ALUOp = 3'b001;   // rs + SignExt
            end
            S_ADDI_WB: begin                       // rt <- ALUOut
                RegWrite = 1'b1; RegDst = 2'b00; MemtoReg = 4'd0;
            end

            S_LUI: begin                           // rt <- imm << 16
                RegWrite = 1'b1; RegDst = 2'b00; MemtoReg = 4'd6;
            end

            S_LW_REQ, S_LW_WAIT, S_LW_MDR,
            S_LB_REQ, S_LB_WAIT, S_LB_MDR,
            S_SB_REQ, S_SB_WAIT, S_SB_MDR: begin   // MDR <- Mem[ALUOut]
                ALUSrcA = 1'b1; ALUSrcB = 2'b10; ALUOp = 3'b001;
                MemRead = 1'b1; IorD = 2'b01;
            end
            S_LW_WB: begin                         // rt <- MDR
                RegWrite = 1'b1; RegDst = 2'b00; MemtoReg = 4'd1;
            end
            S_LB_WB: begin                         // rt <- Load Size
                RegWrite = 1'b1; RegDst = 2'b00; MemtoReg = 4'd5;
            end

            S_SW: begin                            // Mem[ALUOut] <- B
                ALUSrcA = 1'b1; ALUSrcB = 2'b10; ALUOp = 3'b001;
                MemWrite = 1'b1; IorD = 2'b01; ByteWrite = 1'b0;
            end
            S_SB_WR: begin                         // Mem[ALUOut] <- Store Size
                ALUSrcA = 1'b1; ALUSrcB = 2'b10; ALUOp = 3'b001;
                MemWrite = 1'b1; IorD = 2'b01; ByteWrite = 1'b1;
            end

            S_BEQ: begin                           // se Zero: PC <- ALUOut (alvo)
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b010;
                PCWriteCond = 1'b1; PCSource = 3'b001;
            end
            S_BNE1: begin                          // PC <- alvo; ALUOut <- PC + 4
                ALUSrcA = 1'b0; ALUOp = 3'b000;
                PCSource = 3'b001; PCWrite = 1'b1;
            end
            S_BNE2: begin                          // se Zero: PC <- ALUOut (PC + 4)
                ALUSrcA = 1'b1; ALUSrcB = 2'b00; ALUOp = 3'b010;
                PCWriteCond = 1'b1; PCSource = 3'b001;
            end

            // ======================================== tipo J
            S_J: begin
                PCWrite = 1'b1; PCSource = 3'b010;
            end
            S_JAL1: begin                          // ALUOut <- PC (= PC + 4)
                ALUSrcA = 1'b0; ALUOp = 3'b000;
            end
            S_JAL2: begin                          // $31 <- ALUOut; PC <- jump address
                RegWrite = 1'b1; RegDst = 2'b10; MemtoReg = 4'd0;
                PCWrite = 1'b1; PCSource = 3'b010;
            end

            // ======================================== excecoes
            S_EXC_OP1, S_EXC_OVF1, S_EXC_DIV1: begin  // PC <- PC - 4; pede o byte
                ExcType = exc_tipo(estado);
                ALUSrcA = 1'b0; ALUSrcB = 2'b01; ALUOp = 3'b010;
                PCSource = 3'b000; PCWrite = 1'b1;
                MemRead = 1'b1; IorD = 2'b10;
            end
            S_EXC_OP2, S_EXC_OVF2, S_EXC_DIV2: begin  // EPC <- PC
                ExcType = exc_tipo(estado);
                EPCWrite = 1'b1;
                MemRead = 1'b1; IorD = 2'b10;
            end
            S_EXC_OP3, S_EXC_OVF3, S_EXC_DIV3: begin  // MDR captura o byte
                ExcType = exc_tipo(estado);
                MemRead = 1'b1; IorD = 2'b10;
            end
            S_EXC_OP4, S_EXC_OVF4, S_EXC_DIV4: begin  // PC <- ZeroExt(MDR[7-0])
                PCWrite = 1'b1; PCSource = 3'b100;
            end

            default: ;
        endcase
    end

    function [1:0] exc_tipo(input [6:0] s);
        begin
            if (s >= S_EXC_DIV1)      exc_tipo = 2'b10;
            else if (s >= S_EXC_OVF1) exc_tipo = 2'b01;
            else                      exc_tipo = 2'b00;
        end
    endfunction

endmodule
