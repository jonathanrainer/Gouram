module if_tracker
#(
    parameter INSTR_ADDR_WIDTH = 16,
    parameter INSTR_DATA_WIDTH = 32,
    parameter TRACE_BUFFER_SIZE = 8,
    parameter type trace_format = int,
    parameter TRACKING_BUFFER_SIZE = 8
)
(
    input logic clk,
    input logic rst_n,
    input integer counter,
    
    // Processor signals for tracing
    input logic jump_done,
    input logic branch_decision,
    input logic pc_set,
    input logic branch_req,
    input logic decode_phase_end,

    // Instruction Memory Ports
    input logic                             instr_req,
    input logic                             instr_rvalid,
    input logic [INSTR_DATA_WIDTH-1:0]      instr_rdata,
    input logic                             instr_gnt,
    input logic [INSTR_ADDR_WIDTH-1:0]      instr_addr,

    // Outputs
    output logic if_data_ready,
    output integer dec_stage_end,
    output integer mem_req_count,
    (* dont_touch = "yes" *) trace_format if_data_o
);

    localparam NUM_CACHED_ADDRS = 16;

    // State Machine to Control Unit
    enum bit [2:0] {
            TRACK_REQ,
            TRACK_GRANT,
            TRACK_RVALID
         } if_state;
         
     // State Machine to Control Unit
    enum bit {
            IDLE,
            CHECK_BRANCH_DEC
         } branch_state;
         
    enum bit {
        FIND_DATA,
        OUTPUT_DATA
    } output_state;
         
    typedef struct packed {
        bit [INSTR_DATA_WIDTH-1:0] instruction;
        bit [INSTR_ADDR_WIDTH-1:0] instr_addr;
        integer instr_req_start;
        integer instr_gnt;
        integer instr_rvalid;
        integer signed dec_end;
        bit branch_dec;
        integer branch_dec_time;
        bit output_ready;
        bit finished;
    } tracking_buffer_format;
    
    (* dont_touch = "yes" *) (* ram_style = "distributed" *) tracking_buffer_format tracking_buffer [0:TRACKING_BUFFER_SIZE-1];
    (* dont_touch = "yes" *) bit signed [$clog2(TRACKING_BUFFER_SIZE):0] if_pointer;
    (* dont_touch = "yes" *) bit [$clog2(TRACKING_BUFFER_SIZE):0] branch_pointer;
    (* dont_touch = "yes" *) bit [$clog2(TRACKING_BUFFER_SIZE):0] jump_pointer;
    (* dont_touch = "yes" *) bit [$clog2(TRACKING_BUFFER_SIZE):0] output_pointer;
    integer pc_set_time;
    integer cut_off_time; 
    bit branching;

    // Initial behaviour

    initial
    begin
        initialise_device();
    end

    task move_to_grant();
        if_state <= TRACK_GRANT;
        tracking_buffer[(if_pointer+1) % TRACKING_BUFFER_SIZE] <= '{default: 0};
        tracking_buffer[(if_pointer+1) % TRACKING_BUFFER_SIZE].instr_req_start <= counter;
        if_pointer <= (if_pointer + 1) % TRACKING_BUFFER_SIZE;
    endtask

    // Data Acquistion

    always_ff @(posedge clk)   
    begin
        if (!rst_n) initialise_device();
        unique case(if_state)
            TRACK_REQ:
            begin
                if (instr_req) move_to_grant();
            end
            TRACK_GRANT:
            begin
                if (instr_gnt) 
                begin
                    tracking_buffer[if_pointer].instr_addr <= instr_addr;
                    tracking_buffer[if_pointer].instr_gnt <= counter;
                    if_state <= TRACK_RVALID;
                end
            end
            TRACK_RVALID:
            begin
                if (instr_rvalid)  
                begin
                    if (instr_req) move_to_grant();
                    else if_state <= TRACK_REQ;
                    tracking_buffer[if_pointer].instruction <= instr_rdata;
                    tracking_buffer[if_pointer].instr_rvalid <= counter;
                    if_pointer <= (if_pointer + 1) % TRACKING_BUFFER_SIZE;
                end
            end
        endcase
        if (decode_phase_end)
        begin
           automatic int signed earliest_index = -1;
           automatic bit present_branching = branching;
           for (int i = 0; i < TRACKING_BUFFER_SIZE; i++)
           begin
                if (
                    (earliest_index == -1 || (tracking_buffer[i].instr_rvalid < tracking_buffer[earliest_index].instr_rvalid))
                    && (tracking_buffer[i].instr_rvalid > 0 && tracking_buffer[i].dec_end == 0 && tracking_buffer[i].instr_gnt >= cut_off_time)
                ) 
                earliest_index = i;
           end
           if (present_branching && tracking_buffer[earliest_index].instr_gnt >= cut_off_time)
           begin
                present_branching = 0;
                branching <= 1'b0;
           end
           if (!present_branching)
           begin
               tracking_buffer[earliest_index].dec_end <= counter;
               tracking_buffer[earliest_index].output_ready <= 1'b1;
               // 3 things could happen here. 
               // 1. If this is neither a jump or a branch then there needs to be a process to output what's current in the tracking buffer.
               // 2. If this is a jump then the calculation is performed in the Decode Phase so we should now immeadiately be able to tell whether to move or not
               // 3. If this is a branch then the calculation is performed in the next cycle so something else needs to decide what to do.
               // Outcome 2
               if (check_jump(tracking_buffer[earliest_index].instruction))
               begin
                   tracking_buffer[earliest_index].branch_dec <= jump_done;
                   tracking_buffer[earliest_index].branch_dec_time <= counter;
                   if (pc_set) cut_off_time <= counter;
                   else cut_off_time <= pc_set_time;
                   branching <= 1'b1;
               end
               // Outcome 3
               else if (check_branch(tracking_buffer[earliest_index].instruction))
               begin
                   tracking_buffer[earliest_index].output_ready <= 1'b0;
                   branch_pointer <= earliest_index;
                   branch_state <= CHECK_BRANCH_DEC;
               end 
           end
           else tracking_buffer[earliest_index].finished <= 1'b1;
        end
	if (pc_set) pc_set_time <= counter;
        unique case (branch_state)
            IDLE:
            begin
            end
            CHECK_BRANCH_DEC:
            begin
                if (branch_decision)
                begin
                    tracking_buffer[branch_pointer].branch_dec_time <= counter;
                    if (pc_set) cut_off_time <= counter;
			        else cut_off_time <= pc_set_time;
                    branching <= 1'b1;
                end
                tracking_buffer[branch_pointer].branch_dec <= branch_decision;
                tracking_buffer[branch_pointer].output_ready <= 1'b1;
                branch_state <= IDLE;
            end
        endcase
        unique case (output_state)
            FIND_DATA:
            begin 
                if_data_ready <= 1'b0;
                dec_stage_end <= 1'b0;
                for (int i = 0; i < TRACKING_BUFFER_SIZE; i++)
                begin
                    if (tracking_buffer[i].output_ready && !tracking_buffer[i].finished && tracking_buffer[i].instr_gnt >= cut_off_time)
                    begin
                        if (check_load_store(tracking_buffer[i].instruction))
                        begin
                            mem_req_count <= mem_req_count + 1;
                            output_pointer <= i;
                            output_state <= OUTPUT_DATA;
                        end
                        else
                        begin
                            tracking_buffer[i].finished <= 1'b1;
                            break;
                        end
                    end
                end 
             end
             OUTPUT_DATA:
             begin
                if_data_o.instruction <= tracking_buffer[output_pointer].instruction;
                if_data_o.instr_addr <= tracking_buffer[output_pointer].instr_addr;
                dec_stage_end <= tracking_buffer[output_pointer].dec_end;
                tracking_buffer[output_pointer].finished <= 1'b1;
                if_data_ready <= 1'b1;
                output_state <= FIND_DATA;
             end
        endcase;

    end

    // Initialise the whole trace unit

    task initialise_device();
        begin
            if_data_ready <= 0;
            if_data_o <= '{default:0};
            tracking_buffer <= '{default:0};
            dec_stage_end <= 0;
            if_pointer <= -1;
            if_state <= TRACK_REQ;
            cut_off_time <= 0;
            pc_set_time <= 0;
            mem_req_count <= 0;
        end
    endtask
    
    function bit check_load_store(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return instruction ==? 32'h??????83 || instruction ==? 32'h??????03 || 
           instruction ==? 32'h??????23 || instruction ==? 32'h??????a3;
    endfunction
    
    function bit check_branch(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return  instruction ==? 32'h??????E3 || instruction ==? 32'h??????63;
    endfunction
    
    function bit check_jump(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return  instruction ==? 32'h??????EF || instruction ==? 32'h??????6F ||
            instruction ==? 32'h??????E7 || instruction ==? 32'h??????67;
    endfunction

endmodule
