package gouram_datatypes;

    localparam INSTR_ADDR_WIDTH = 32;
    localparam INSTR_DATA_WIDTH = 32;
    localparam DATA_ADDR_WIDTH = 32;
    localparam TDATA_WIDTH = 32;
    
    typedef struct packed {
        bit [INSTR_DATA_WIDTH-1:0] instruction;
        bit [INSTR_ADDR_WIDTH-1:0] mem_addr;
        bit [TDATA_WIDTH-1:0] mem_trans_time_start;
        bit [TDATA_WIDTH-1:0] mem_trans_time_end;
     } trace_format;
     

endpackage : gouram_datatypes
