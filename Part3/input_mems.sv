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
    logic [A_ADDR_BITS-1:0] A_address; // this should be used for both writing and reading based on the state
    logic [B_ADDR_BITS-1:0] B_address; // this should be used for both writing and reading based on the state
    logic wr_en_a;
    logic wr_en_b;
    logic clear_counter_A;
    logic clear_counter_B;
    logic increment_a;
    logic increment_b;
    logic [A_ADDR_BITS-1:0] address_to_a_memory;
    logic [B_ADDR_BITS-1:0] address_to_b_memory;

    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1]; 
    assign new_A = AXIS_TUSER[0];

    // Counter and Comparator logic for A
    always_ff @(posedge clk) begin
        if(reset || clear_counter_A) begin
            A_address <= 0;
        end 
        else begin
            if(increment_a) begin
                A_address <= A_address+1;
            end
            else if(A_address == M*K) begin
                clear_counter_A <= 1;
            end
        end
    end

    // Instantiation for Memory module "A"
    memory #(.WIDTH(INW),.SIZE(M*MAXK)) inst_memory_A ( 
        .data_in(AXIS_TDATA),
        .data_out(A_data),
        .addr(address_to_a_memory), // Given read address then what about write address : TAKEN CARE IN LOGIC DECLARATION
        .clk(clk),
        .wr_en(wr_en_a)
    );
    
    // Counter and Comparator logic for B
    always_ff @(posedge clk) begin
        if(reset || clear_counter_B) begin
            B_address <= 0;
        end 
        else begin
            if(increment_b) begin
                B_address <= B_address+1;
            end
            else if(B_address == K*N) begin
                clear_counter_B <= 1;
            end
        end
    end

    // Instantiation for Memory module "B"
    memory #(.WIDTH(INW),.SIZE(MAXK*N)) inst_memory_B ( 
        .data_in(AXIS_TDATA),
        .data_out(B_data),
        .addr(address_to_b_memory), // Given read address then what about write address : TAKEN CARE IN LOGIC DECLARATION
        .clk(clk),
        .wr_en(wr_en_b)
    ); 
    
    // Declaring atates for FSM
    enum {start, load_a, load_b, read} state, next_state; 
    
    // combination logic for determing the next state of FSM
    always_comb begin
        wr_en_a = 0;
        wr_en_b = 0;
        matrices_loaded = 0;    
        if(state == start) begin
            if(AXIS_TREADY==1 && AXIS_TVALID==1) begin
                if(new_A==1) begin
                    wr_en_a = 1;
                    K = TUSER_K;
                    next_state = load_a;
                end 
                else begin
                    wr_en_b = 1;
                    next_state = load_b;
                end 
            end
            else begin
                next_state = start;
            end         
        end
        else if(state==load_a) begin
            if(A_address == M*K) begin // Change is required here - A_memory counter reaches DEPTH, that should be written here 
                wr_en_a = 0;
                next_state = load_b;
            end
            else begin
                if(AXIS_TVALID) begin
                    wr_en_a = 1;
                    increment_a = 1;
                end
                next_state = load_a; // Datapath configuration has to be added in this state
            end
        end
        else if(state==load_b) begin
            if(B_address == K*N) begin // Where are we setting matrices loaded? Ans: When both the memory address counters reach M*K and K*N 
                wr_en_b = 0;
                next_state = read;
                matrices_loaded = 1;
            end
            else begin
                if(AXIS_TVALID) begin
                    wr_en_b = 1;
                    increment_b = 1;
                end
                next_state = load_b;
            end
        end
        else if(state==read) begin // No need to handle wr_en signals in this state because only reading operation is done by the MAC Unit 
            if(compute_finished==1) begin
                matrices_loaded = 0;
                next_state = start;

            end
            else begin
                next_state = read;
            end
        end
    end
    
    // Logic for generating AXIS_Tready after compute is finished
    always_comb begin
        if(matrices_loaded == 1) begin
            AXIS_TREADY = 0;
        end
        else begin
            AXIS_TREADY = 1;
        end
    end

    always_comb begin 
        if(matrices_loaded) begin
            address_to_a_memory = A_read_addr;
            address_to_b_memory = B_read_addr;
        end
        else begin
            address_to_a_memory = A_address;
            address_to_b_memory = B_address;
        end
    end
    
    // Output logic for FSM
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= start;
        end
        else begin
            state <= next_state;
        end
    end

    /* Next steps :- 
        1. Logic for load_a_and_b, load_b and read states - Ans: Datapath integration 
        2. Handling wr_en_a and wr_en_b signals - Ans: wr_en signals are to be generated inside FSM. These signals are sent to the datapath for writing into memories.
        3. Storing K and new_A values - Ans: K value can be sent as the output at first clock edge inside "start" state. There is no need to store new_A value since we are using new_A value to check in the "start" state only - Task is done, Need to verify
        4. Read Addresses computation for mem_a and mem_b - Ans: Above memory block instantiation handles this - Task is done, Need to verify 
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