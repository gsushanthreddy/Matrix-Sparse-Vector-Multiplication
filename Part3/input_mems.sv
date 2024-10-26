module input_mems #(
    parameter INW = 12,
    parameter M = 7,
    parameter N = 9,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
    )(
    input clk, reset,
    input [INW-1:0] AXIS_TDATA,
    input AXIS_TVALID,
    input [K_BITS:0] AXIS_TUSER,
    output logic AXIS_TREADY,
    output logic matrices_loaded,
    input compute_finished,
    output logic [K_BITS-1:0] K,
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data
);  
    logic [$clog2(MAXK+1)-1:0] TUSER_K;
    logic new_A;
    logic [A_ADDR_BITS-1:0] A_address; // this shoulb be used for both writing and reading based on the state
    logic [B_ADDR_BITS-1:0] B_address; // this shoulb be used for both writing and reading based on the state
    logic wr_en_a;
    logic wr_en_b;
    // How to instantiate memory modules
    // Instantiation for Memory module "A"
    memory #(.WIDTH(A_ADDR_BITS),.SIZE(M*K)) inst_memory_A ( //need to conform whether the size of the memory is (M*K) or (M*maxK)
        .data_in(AXIS_TDATA),
        .data_out(A_data),
        .addr(A_address), // Given read address then what about write address : TAKEN CARE IN LOGIC DECLARATION
        .clk(clk),
        .wr_en(wr_en_a)
    ); // Done writing intantiation for the memory a
    
    // Instantiation for Memory module "B"
    memory #(.WIDTH(B_ADDR_BITS),.SIZE(K*N)) inst_memory_B ( //need to conform whether the size of the memory is (K*N) or (maxK*N)
        .data_in(AXIS_TDATA),
        .data_out(B_data),
        .addr(B_address), // Given read address then what about write address : TAKEN CARE IN LOGIC DECLARATION
        .clk(clk),
        .wr_en(wr_en_b)
    ); // Done writing intantiation for the memory b
    
    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1]; 
    assign new_A = AXIS_TUSER[0];

    enum [1:0] {start, load_a_and_b, read, load_b} state, next_state; // reset state renamed to start state
    // in the above line i have assigned the bit length for declaring states
    always_comb begin

    // Sushanth, WHY TO WRITE LIKE THIS, CODE SEEMS REDUNDANT??
        if(state==start) begin
            if(AXIS_TREADY==1 && AXIS_TVALID==1) begin
                if(new_A==1) begin
                    next_state = load_a_and_b;
                end 
                else begin
                    next_state = load_b;
                end 
            end
            else begin
                next_state = start;
            end         
        end
        else if(state==load_a_and_b) begin
            if(matrices_loaded==1) begin
                next_state = read;
            end
            else begin
                next_state = load_a_and_b;
            end
        end
        else if(state==load_b) begin
            if(matrices_loaded==1) begin
                next_state = read;
            end
            else begin
                next_state = load_b;
            end
        end
        else if(state==read) begin
            if(compute_finished==1) begin
               next_state = start;
            end
            else begin
               next_state = read;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            state <= start;
        end
        else begin
            state <= next_state;
        end
    end

    /* Next steps :- 
        1. Logic for load_a_and_b, load_b and read states
        2. Handling wr_en_a and wr_en_b signals 
        3. Storing K and new_A values 
        4. Read Addresses computation for mem_a and mem_b  
    */
endmodule

module memory #(
    parameter WIDTH=16, SIZE=64,
    localparam LOGSIZE=$clog2(SIZE)
    )(
        input [WIDTH-1:0] data_in,
        output logic [WIDTH-1:0] data_out,
        input [LOGSIZE-1:0] addr,
        input clk, wr_en
    );
    logic [SIZE-1:0][WIDTH-1:0] mem;
    always_ff @(posedge clk) begin
        data_out <= mem[addr];
        if (wr_en) begin
            mem[addr] <= data_in;
        end
    end
endmodule