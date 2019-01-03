module if_tracker
#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter type trace_output = int
)
(
    input logic clk,
    input logic rst,

    // IF Register ports
    input logic if_busy,

    // Instruction Memory Ports
    input logic                     instr_req,
    input logic [ADDR_WIDTH-1:0]    instr_addr,
    input logic                     instr_grant,
    input logic                     instr_rvalid,
    input logic [DATA_WIDTH-1:0]    instr_rdata,

    // Tracing Management
    input integer counter,

    // Outputs
    output logic if_data_valid,
    output trace_output if_data_o
);

    // Trace buffer itself
    trace_output trace_element;
    // Space to cache results if further processing needs to happen
    integer cached_counter = -1;
    // Flag to indicate if data is ready to be sent or not
    bit data_ready = 0;
    // IF Pipeline Stage State Machine
    enum logic [1:0] {
        START =             2'b00,
        WAIT_GNT =          2'b01,
        WAIT_RVALID =       2'b10
     } state;


    // Initial behaviour

    initial
    begin
        initialise_device();
    end

    // Reset Behaviour

    always @(posedge rst)
    begin
        if (rst == 1)
        begin
            initialise_device();
        end
    end

    // Creation of record to track instruction's responsibility

    always_ff @(posedge clk)
    begin
    unique case (state)
        START:
        begin
            if (data_ready)
            begin
                if_data_o <= trace_element;
                if_data_valid <= 1;
                data_ready <= 0;
            end
            if (if_busy)
            begin
                trace_element <= '{default:0};
                if (cached_counter != -1)
                begin
                    trace_element.if_data.time_start <= cached_counter;
                    trace_element.if_data.mem_access_req.time_start <= cached_counter;
                    cached_counter <= -1;
                end
                else
                begin
                    trace_element.if_data.time_start <= counter;
                    trace_element.if_data.mem_access_req.time_start <= counter;
                end 
                state <= WAIT_GNT;
            end
        end
        WAIT_GNT:
        begin
            if (instr_grant)
            begin
                trace_element.if_data.mem_access_req.time_end <= counter;
                trace_element.if_data.mem_access_res.time_start <= counter;
                trace_element.addr <= instr_addr;
                state <= WAIT_RVALID;
            end
        end
        WAIT_RVALID:
        begin
            if (instr_rvalid)
            begin
                trace_element.instruction <= instr_rdata;
                trace_element.if_data.time_end <= counter;
                trace_element.if_data.mem_access_res.time_end <= counter;
                data_ready <= 1;
                if (instr_req) 
                begin
                    cached_counter <= counter;
                end
                state <= START;
            end
        end
    endcase
    end
    
    always_ff@(posedge clk)
    begin
        if (if_data_valid) if_data_valid <= 0;
    end

    // Initialise the whole trace unit

    task initialise_device();
        begin
            state <= START;
            if_data_valid <= 0;
        end
    endtask

endmodule
