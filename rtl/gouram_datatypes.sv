`include "../include/ryuki_defines.sv"

package ryuki_datatypes;

    typedef struct packed {
        bit[31:0] time_start;
        bit[31:0] time_end;
    } mem_access_req;
    
    typedef struct packed {
            bit[31:0] time_start;
            bit[31:0] time_end;        
    } mem_access_res;

    typedef struct packed {
        bit[31:0] time_start;
        bit[31:0] time_end;
        mem_access_req mem_access_req;
        mem_access_res mem_access_res;
    } IF_data;
    
    typedef struct packed {
        bit[31:0] time_start;
        bit[31:0] time_end;
    } ID_data;
    
    typedef struct packed {
        bit[31:0] time_start;
        bit[31:0] time_end;
        bit[`ADDR_WIDTH-1:0] mem_addr;
        mem_access_req mem_access_req;
    } EX_data;
    
    typedef struct packed {
        bit[31:0] time_start;
        bit[31:0] time_end;
        mem_access_res mem_access_res;
    } WB_data;
    
    typedef struct packed {
        bit [`DATA_WIDTH-1:0] instruction;
        bit [`ADDR_WIDTH-1:0] addr;
        bit pass_through;
        IF_data if_data;
        ID_data id_data;
        EX_data ex_data;
        WB_data wb_data;
     } trace_output;
     

endpackage : ryuki_datatypes
