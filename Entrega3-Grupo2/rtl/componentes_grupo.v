`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Componentes combinacionais criados pelo grupo (Entrega 1).
// -----------------------------------------------------------------------------

// Sign extend: 16 -> 32 bits, replica o bit 15 (imediato/offset das instrucoes I)
module sign_extend_16_32 (
    input  wire [15:0] in,
    output wire [31:0] out
);
    assign out = {{16{in[15]}}, in};
endmodule

// Shift left 2 (32 bits): offset * 4 para os desvios condicionais
module shift_left_2 (
    input  wire [31:0] in,
    output wire [31:0] out
);
    assign out = {in[29:0], 2'b00};
endmodule

// Shift left 2 do jump (26 -> 28 bits) concatenado com PC[31-28]
// Jump address [31-0] = {PC[31-28], Instruction[25-0], 00}
module jump_address (
    input  wire [25:0] instr25_0,
    input  wire [3:0]  pc31_28,
    output wire [31:0] out
);
    wire [27:0] desl = {instr25_0, 2'b00};
    assign out = {pc31_28, desl};
endmodule

// imm << 16 (lui): entrada 6 do mux MemtoReg
module shift_left_16 (
    input  wire [15:0] in,
    output wire [31:0] out
);
    assign out = {in, 16'd0};
endmodule

// Zero extender: byte lido de 253/254/255 (MDR[7-0]) estendido com zeros.
// Saida "address" -> entrada 4 do mux PCSource (endereco da rotina de excecao).
module zero_extender (
    input  wire [7:0]  read_byte,
    output wire [31:0] address
);
    assign address = {24'd0, read_byte};
endmodule

// Exception Address: endereco do byte que guarda a rotina de tratamento
// ExcType: 00 = opcode inexistente (253) | 01 = overflow (254) | 10 = div. por zero (255)
module exception_address (
    input  wire [1:0]  exc_type,
    output reg  [31:0] address
);
    always @(*) begin
        case (exc_type)
            2'b00:   address = 32'd253;
            2'b01:   address = 32'd254;
            2'b10:   address = 32'd255;
            default: address = 32'd253;
        endcase
    end
endmodule

// Load Size (lb): devolve o byte lido estendido com zeros.
//   word_read  = MDR (palavra lida no endereco ALUOut)
//   which_byte = ALUOut[1-0]
// A Memoria fornecida ja rotaciona a palavra de acordo com Address[1-0]
// (enderecamento por byte, little-endian): a palavra lida no endereco X tem
// Mem[X] em [7-0]. Por isso o byte pedido esta sempre em word_read[7-0],
// qualquer que seja which_byte. A porta foi mantida igual ao diagrama.
module load_size (
    input  wire [31:0] word_read,
    input  wire [1:0]  which_byte,
    output wire [31:0] extended_byte
);
    assign extended_byte = {24'd0, word_read[7:0]};
endmodule

// Store Size (sb): monta a palavra a ser escrita trocando so um byte.
//   new_byte     = B[7-0] (byte de rt)
//   current_word = MDR (palavra lida no mesmo endereco ALUOut)
//   where_to_put = ALUOut[1-0]
// Como na Memoria fornecida a palavra lida/escrita no endereco X comeca em
// Mem[X] (bits [7-0]), o byte novo vai em [7-0] e os outros 3 bytes sao
// regravados com o valor que ja estava na memoria (nao sobrescreve a palavra).
module store_size (
    input  wire [7:0]  new_byte,
    input  wire [31:0] current_word,
    input  wire [1:0]  where_to_put,
    output wire [31:0] out
);
    assign out = {current_word[31:8], new_byte};
endmodule

// ALU Control: na FSM da Entrega 2 o ALUOp ja e o codigo da ULA
// (000 = S=A, 001 = ADD, 010 = SUB, 011 = AND, 111 = CMP), entao o bloco
// so repassa o ALUOp para o seletor da Ula32.
module alu_control (
    input  wire [2:0] alu_op,
    input  wire [5:0] funct,
    output wire [2:0] seletor
);
    assign seletor = alu_op;
endmodule
