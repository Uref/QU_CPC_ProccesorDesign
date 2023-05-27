`include "module/mainDecoder.v"
`include "module/ALUDecoder.v"
`include "module/setPrePCSrc.v"
`include "module/setMemSize.v"
`include "module/dffREC.v"
// `include "module/load2Cycle.v"

module controller(
  // from test
  input         clk, reset_x,
  // from datapath
  input [31:0]  Di_inst,
  input         Ei_zero, Ei_neg, Ei_negU,
  // from hazard
  input Ei_flush,

  // to test (dmem)
  output        Mo_memWrite, Mo_memReq,
  output [1:0]  Mo_memSize,
  // to datapath
  output [2:0]  Do_immSrc,
  output        Do_jal,
  output        Do_ecall,
  output [3:0]  Eo_ALUCtrl,
  output        Eo_ALUSrc,
  output        Eo_immPlusSrc,
  output        Eo_ecall,
  output [1:0]  Eo_prePCSrc,    // and to hazard
  output        Mo_isLoadSigned,
  output [1:0]  Wo_resultSrc,
  output        Wo_regWrite, // and to hazard
  // to hazard
  output [1:0]  Eo_resultSrc,
  output [1:0]  Mo_resultSrc,
  output        Mo_regWrite
);

// wire
  // ID stage wire
  wire [6:0]  Dw_opcode   = Di_inst[6:0];
  wire [6:0]  Dw_funct7   = Di_inst[31:25];
  wire [11:0] Dw_funct12  = Di_inst[31:20];
  wire [1:0] Dw_ALUOp;
    // to EX
  wire [3:0]  Dw_ALUCtrl;
  wire        Dw_ALUSrc;
  wire        Dw_immPlusSrc;
  wire [2:0]  Dw_funct3 = Di_inst[14:12];
  wire        Dw_branch, Dw_jalr;
    // to MEM
  wire        Dw_memWrite, Dw_memReq;
  wire [1:0]  Dw_memSize;
  wire        Dw_isLoadSigned;
    // to WB
  wire [1:0]  Dw_resultSrc;
  wire        Dw_regWrite;

  // EX stage wire
  wire [2:0] Ew_funct3;
  wire        Ew_branch, Ew_jalr;
    // to MEM
  wire        Ew_memWrite, Ew_memReq;
  wire [1:0]  Ew_memSize;
  wire        Ew_isLoadSigned;
    // to WB
  wire        Ew_regWrite;

  // MEM stage wire
    // to WB
  wire        Mo_regWrite;
  
  // WB stage wire
// end wire

// ID stage
  mainDecoder main_decoder(
    // .clk(clk), .reset_x(reset_x),
    .i_opcode(Dw_opcode), .i_funct3(Dw_funct3),

    .o_memReq(Dw_memReq), .o_memWrite(Dw_memWrite),
    .o_regWrite(Dw_regWrite),
    .o_ALUSrc(Dw_ALUSrc), .o_immSrc(Do_immSrc),
    .o_immPlusSrc(Dw_immPlusSrc), .o_isLoadSigned(Dw_isLoadSigned),
    .o_resultSrc(Dw_resultSrc),
    .o_ecall(Do_ecall),

    .o_branch(Dw_branch),
    .o_jal(Do_jal), .o_jalr(Dw_jalr),
    .o_ALUOp(Dw_ALUOp)
  );
  ALUDecoder alu_decoder(
    .i_ALUOp(Dw_ALUOp), .i_funct3(Dw_funct3),
    .i_opecodeb5(Dw_opcode[5]), .i_funct7b5(Dw_funct7[5]),

    .o_ALUCtrl(Dw_ALUCtrl)
  );
  setMemSize set_mem_size(
    .i_funct3(Dw_funct3),
    .o_memSize(Dw_memSize)
  );
  // ID/EX reg
  dffREC #(20)
  IDEX_controll_register(
    .i_clock(clk), .i_reset_x(reset_x),
    .i_enable(1'b1), .i_clear(Ei_flush),
    .i_d({
      Dw_ALUCtrl, Dw_ALUSrc, 
      Dw_immPlusSrc, Do_ecall,
      Dw_funct3, Dw_branch, Dw_jalr,

      Dw_memWrite, Dw_memReq, Dw_memSize,
      Dw_isLoadSigned,
      
      Dw_resultSrc,
      Dw_regWrite
    }),
    .o_q({
      Eo_ALUCtrl, Eo_ALUSrc, 
      Eo_immPlusSrc, Eo_ecall,
      Ew_funct3, Ew_branch, Ew_jalr, 

      Ew_memWrite, Ew_memReq, Ew_memSize,
      Ew_isLoadSigned,

      Eo_resultSrc,
      Ew_regWrite
    })
  );
// end ID stage

// EX stage
  setPrePCSrc set_pre_pc_src(
    .i_zero(Ei_zero), .i_neg(Ei_neg), .i_negU(Ei_negU),
    .i_branch(Ew_branch),
    .i_funct3(Ew_funct3), .i_jalr(Ew_jalr), .i_ecall(Eo_ecall),

    .o_prePCSrc(Eo_prePCSrc)
  );
  // EX/MEM reg
  dffREC #(8)
  EXMEM_controll_register(
    .i_clock(clk), .i_reset_x(reset_x),
    .i_enable(1'b1), .i_clear(1'b0),
    .i_d({
      Ew_memWrite, Ew_memReq, Ew_memSize,
      Ew_isLoadSigned,
      
      Eo_resultSrc,
      Ew_regWrite
    }),
    .o_q({
      Mo_memWrite, Mo_memReq, Mo_memSize,
      Mo_isLoadSigned,

      Mo_resultSrc,
      Mo_regWrite
    })
  );
// end EX stage

// MEM stage
  // MEM/WB reg
  dffREC #(3)
  MEMWB_controll_register(
    .i_clock(clk), .i_reset_x(reset_x),
    .i_enable(1'b1), .i_clear(1'b0),
    .i_d({
      Mo_resultSrc,
      Mo_regWrite
    }),
    .o_q({
      Wo_resultSrc,
      Wo_regWrite
    })
  );
// end MEM stage

/* single */
  // assign o_regWDwte = w_regWrite && w_regWriteLoad;
  // load2Cycle load_2cycle(
  //   .i_clk(i_clk), .i_opcode(w_opcode),
  //   .o_PCEnable(o_PCEnable),
  //   .o_regWriteLoad(w_regWriteLoad)
  // );

endmodule