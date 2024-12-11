module input_mems #(
    parameter INW = 24,
    parameter M = 5,
    parameter N = 4,
    parameter MAXK = 6,
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

    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1]; 
    assign new_A = AXIS_TUSER[0];

    logic wr_en_A;
    logic wr_en_B;
    
    // Status Signals
    logic matrix_A_loaded;
    logic matrix_B_loaded;

    // instantiation of FSM
    input_mems_fsm #(.MAXK(MAXK)) fsm_inst( 
        .clk(clk),
        .reset(reset),
        .AXIS_TVALID(AXIS_TVALID),
        .compute_finished(compute_finished),
        .new_A(new_A),
        .matrix_A_loaded(matrix_A_loaded),
        .matrix_B_loaded(matrix_B_loaded),
        .TUSER_K(TUSER_K),

        .matrices_loaded(matrices_loaded),
        .wr_en_a(wr_en_A),
        .wr_en_b(wr_en_B),
        .AXIS_TREADY(AXIS_TREADY),
        .K(K)
    );

    // instantiation of Datapath
    input_mems_datapath #(.INW(INW), .M(M), .N(N), .MAXK(MAXK)) datapath_inst(
        .clk(clk),
        .reset(reset),
        .AXIS_TDATA(AXIS_TDATA),
        .AXIS_TVALID(AXIS_TVALID),

        .A_read_addr(A_read_addr),
        .A_data(A_data),
        .B_read_addr(B_read_addr),
        .B_data(B_data),
        
        .K(K),

        .wr_en_A(wr_en_A),
        .wr_en_B(wr_en_B),

        .matrices_loaded(matrices_loaded),

        .matrix_A_loaded(matrix_A_loaded),
        .matrix_B_loaded(matrix_B_loaded)
    );
endmodule

module input_mems_fsm #(
        parameter MAXK = 6, 
        localparam K_BITS = $clog2(MAXK+1)
    )( 
    input clk, reset,
    input AXIS_TVALID,
    input compute_finished,
    input new_A,
    input matrix_A_loaded,
    input matrix_B_loaded,
    input [$clog2(MAXK+1)-1:0] TUSER_K,  

    output logic matrices_loaded,
    output logic wr_en_a,
    output logic wr_en_b,
    output logic AXIS_TREADY,
    output logic [K_BITS-1:0] K 
);
    enum logic [1:0] {start, load_a, load_b, read} state, next_state;

    always_comb begin
        if(reset==1) begin
            wr_en_a = 0;
            wr_en_b = 0;
            //matrices_loaded = 0;
            AXIS_TREADY = 1;
            next_state = start;
        end
        else begin
            if(state == start) begin
                AXIS_TREADY = 1;
                if(AXIS_TVALID) begin
                    if(new_A == 1) begin
                        wr_en_a = 1;
                        wr_en_b = 0;
                        //matrices_loaded = 0;
                        next_state = load_a;
                    end
                    else if(new_A == 0) begin
                        wr_en_a = 0;
                        wr_en_b = 1;
                        //matrices_loaded = 0;
                        next_state = load_b;
                    end
                end
                else begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    //matrices_loaded = 0;
                    next_state = start;
                end
            end
            else if(state == load_a) begin
                AXIS_TREADY = 1;
                if(matrix_A_loaded == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    //matrices_loaded = 0;
                    next_state = load_b;
                    AXIS_TREADY = 0;
                end
                else if(matrix_A_loaded == 0) begin
                    if(AXIS_TVALID) begin
                        wr_en_a = 1;
                        wr_en_b = 0;
                        //matrices_loaded = 0;
                        next_state = load_a;
                    end
                    else begin
                        wr_en_a = 0;
                        wr_en_b = 0;
                        //matrices_loaded = 0;
                        next_state = load_a;
                    end
                end
            end
            else if(state == load_b) begin
                AXIS_TREADY = 1;
                if(matrix_B_loaded == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    //matrices_loaded = 1;
                    AXIS_TREADY = 0;
                    next_state = read;
                end
                else if(matrix_B_loaded == 0) begin
                    if(AXIS_TVALID) begin
                        wr_en_a = 0;
                        wr_en_b = 1;
                        //matrices_loaded = 0;
                        next_state = load_b;
                    end
                    else begin
                        wr_en_a = 0;
                        wr_en_b = 0;
                        //matrices_loaded = 0;
                        next_state = load_b;
                    end
                end
            end
            else if(state == read) begin
                AXIS_TREADY = 0;
                if(compute_finished == 0) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    //matrices_loaded = 1;
                    next_state = read;
                end
                else if(compute_finished == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    //matrices_loaded = 0;
                    next_state = start;
                end
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

    always_ff @(posedge clk) begin
        if(AXIS_TVALID && AXIS_TREADY && new_A && state == start) begin
            K <= TUSER_K;
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            matrices_loaded <= 0;
        end
        else if ((state == load_b) && (matrix_B_loaded == 1)) begin
            matrices_loaded <= 1;
        end
        else if (state == read) begin
            if (compute_finished == 0) begin
                matrices_loaded <= 1;
            end 
            else if (compute_finished == 1) begin
                matrices_loaded <= 0;
            end     
        end
    end

endmodule

module input_mems_datapath #(
    parameter INW = 24,
    parameter M = 5,
    parameter N = 4,
    parameter MAXK = 6,
    localparam K_BITS = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
) (
    input clk,
    input reset,
    input [INW-1:0] AXIS_TDATA,
    input AXIS_TVALID,
    
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data,
    
    input [K_BITS-1:0] K,
    
    // Control signals
    input wr_en_A,
    input wr_en_B,
    
    input matrices_loaded,
    
    // Status Signals
    output logic matrix_A_loaded,
    output logic matrix_B_loaded
);

    logic [A_ADDR_BITS-1:0] A_write_address;
    logic [B_ADDR_BITS-1:0] B_write_address;

    logic [A_ADDR_BITS-1:0] A_address;
    logic [B_ADDR_BITS-1:0] B_address;

    // Fix for the issue with part 3 submission
    logic [A_ADDR_BITS:0] A_write_address_check;
    logic [B_ADDR_BITS:0] B_write_address_check;

    logic signed [INW-1:0] A_data_out;
    logic signed [INW-1:0] B_data_out;

    // trying new logic to break down critical path
    logic [A_ADDR_BITS:0] A_matrix_size;
    logic [B_ADDR_BITS:0] B_matrix_size;

    //Computing Matrix sizes
    always_ff @(posedge clk) begin
        A_matrix_size <= M*K;
        B_matrix_size <= K*N;
    end
    //critical path logic ended and made small change in comparator

    
    // Logic for address counter for 'A'
    always_ff @(posedge clk) begin
        if((reset == 1) || (matrix_A_loaded == 1)) begin
            A_write_address <= 0;
            A_write_address_check <= 0;
        end
        else begin
            if (wr_en_A) begin
                A_write_address <= A_write_address + 1;
                A_write_address_check <= A_write_address_check + 1; 
            end 
        end
    end

    always_comb begin
        if (A_write_address_check ==  A_matrix_size/*(M*K)*/) begin 
            matrix_A_loaded = 1;
        end 
        else begin
            matrix_A_loaded = 0;
        end
    end

    // Logic for address counter for 'B'
    always_ff @(posedge clk) begin
        if((reset == 1) || (matrix_B_loaded == 1)) begin
            B_write_address <= 0;
            B_write_address_check <= 0;
        end
        else begin
            if (wr_en_B) begin
                B_write_address <= B_write_address + 1; 
                B_write_address_check <= B_write_address_check + 1;
            end 
        end
    end

    always_comb begin
        if (B_write_address_check == B_matrix_size/*(K*N)*/) begin
            matrix_B_loaded = 1;
        end 
        else begin
            matrix_B_loaded = 0;
        end
    end

    // Determing which address to give to memory A
    always_comb begin
        if (matrices_loaded == 1) begin
            A_address = A_read_addr;
        end
        else begin
            A_address = A_write_address;
        end
    end

    // Determing which address to give to memory B
    always_comb begin
        if (matrices_loaded == 1) begin
            B_address = B_read_addr;
        end
        else begin
            B_address = B_write_address;
        end
    end

    //instantiating Memory A
    memory #(.WIDTH(INW),.SIZE(M*MAXK)) inst_memory_A ( 
        .data_in(AXIS_TDATA),
        .data_out(A_data),
        .addr(A_address),
        .clk(clk),
        .wr_en(wr_en_A)
    );
    
    //instantiating Memory B
    memory #(.WIDTH(INW),.SIZE(MAXK*N)) inst_memory_B ( 
        .data_in(AXIS_TDATA),
        .data_out(B_data),
        .addr(B_address),
        .clk(clk),
        .wr_en(wr_en_B)
    ); 
    
    /*
    // MUX logic for A_data_out
    always_comb begin
        if (matrices_loaded == 1) begin
            A_data = A_data_out;
        end 
        else begin
            A_data = 0;
        end
    end

    // MUX logic for B_data_out
    always_comb begin
        if (matrices_loaded == 1) begin
            B_data = B_data_out;
        end 
        else begin
            B_data = 0;
        end
    end
    */

endmodule

// Memory logic
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