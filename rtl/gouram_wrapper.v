include "../include/gouram_config.sv";

module gouram_wrapper
(   
    input clk,
    input rst,

    // IF Register ports

    input if_busy,
    input if_ready,
    input branch_decision,

    // Instruction Memory Ports
    input                      		instr_req,
    input [`INSTR_ADDR_WIDTH-1:0]    	instr_addr,
    input                      		instr_grant,
    input                      		instr_rvalid,
    input [`INSTR_DATA_WIDTH-1:0]    	instr_rdata,

    // ID Register Ports

    input id_ready,
    input jump_done,
    input is_decoding,
    input illegal_instruction,
    input branch_req,

    // EX Register Ports

    input ex_ready,
    input data_mem_req,
    input data_mem_grant,
    input data_mem_rvalid,
    
    // Data Memory Ports
   
    input [`DATA_ADDR_WIDTH-1:0] data_mem_addr,

    // WB Register ports

    input wb_ready,
    
    // Trace output port
    output trace_format trace_data_o
);

gouram gouram
(
	.clk(clk),
	.rst(rst),
	.if_busy(if_busy),
	.if_ready(if_ready),
	.branch_decision(branch_decision),
	.instr_req(instr_req),
	.instr_addr(instr_addr),
	.instr_grant(instr_grant),
	.instr_rvalid(instr_rvalid),
	.instr_rdata(instr_rdata),
	.id_ready(id_ready),
	.jump_done(jump_done),
 	.is_decoding(is_decoding),
	.illegal_instruction(illegal_instruction),
	.branch_req(branch_req),
	.ex_ready(ex_ready),
	.data_mem_req(data_mem_req),
	.data_mem_grant(data_mem_grant),
	.data_mem_rvalid(data_mem_rvalid),
	.data_mem_addr(data_mem_addr),
	.wb_ready(wb_ready),
	.trace_data_o(trace_data_o)
);

endmodule
