package gouram_datatypes;

    localparam TDATA_WIDTH = 32;
    localparam INSTR_ADDR_WIDTH = 32;
    localparam INSTR_DATA_WIDTH = 32;
    localparam DATA_ADDR_WIDTH = 32;
    localparam TRACE_BUFFER_SIZE = 64;

    typedef struct packed {
        bit[TDATA_WIDTH-1:0] time_start;
        bit[TDATA_WIDTH-1:0] time_end;
    } mem_access_req;
    
    typedef struct packed {
            bit[TDATA_WIDTH-1:0] time_start;
            bit[TDATA_WIDTH-1:0] time_end;        
    } mem_access_res;

    typedef struct packed {
        bit[TDATA_WIDTH-1:0] time_start;
        bit[TDATA_WIDTH-1:0] time_end;
        mem_access_req mem_access_req;
        mem_access_res mem_access_res;
    } IF_data;
    
    typedef struct packed {
        bit[TDATA_WIDTH-1:0] time_start;
        bit[TDATA_WIDTH-1:0] time_end;
    } ID_data;
    
    typedef struct packed {
        bit[TDATA_WIDTH-1:0] time_start;
        bit[TDATA_WIDTH-1:0] time_end;
        bit[DATA_ADDR_WIDTH-1:0] mem_addr;
        mem_access_req mem_access_req;
    } EX_data;
    
    typedef struct packed {
        bit[TDATA_WIDTH-1:0] time_start;
        bit[TDATA_WIDTH-1:0] time_end;
        mem_access_res mem_access_res;
    } WB_data;
    
    typedef struct packed {
        bit [INSTR_DATA_WIDTH-1:0] instruction;
        bit [INSTR_ADDR_WIDTH-1:0] addr;
        bit pass_through;
        IF_data if_data;
        ID_data id_data;
        EX_data ex_data;
        WB_data wb_data;
     } trace_format;
     

endpackage : gouram_datatypes
