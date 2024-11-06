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

    logic [A_ADDR_BITS-1:0] A_MEM_ADDRESS;
    logic [B_ADDR_BITS-1:0] B_MEM_ADDRESS;
    logic wr_en_a;
    logic wr_en_b;
    logic [A_ADDR_BITS-1:0] A_write_addr;
    logic [B_ADDR_BITS-1:0] B_write_addr;

    logic [$clog2(MAXK+1)-1:0] TUSER_K;
    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1];
    logic new_A;
    assign new_A = AXIS_TUSER[0];

    enum {start, load_a, load_b, read} state, next_state;

    always_ff @(posedge clk) begin
        if(reset) begin
            state <= start;
            A_write_addr <= 0;
            B_write_addr <= 0;
            K <= 0;
            matrices_loaded <= 0;
            AXIS_TREADY <= 1;
        end
        else begin
            state <= next_state;
            case (state) 
                start: begin
                    if (AXIS_TVALID && AXIS_TREADY) begin
                        if (new_A) begin
                            K <= TUSER_K;
                            next_state <= load_a;
                        end
                        else begin
                            next_state <= load_b;
                        end
                    end
                end
                load_a: begin
                    if (AXIS_TVALID) begin
                        if (A_write_addr == M*K-1) begin
                            wr_en_a <= 0;
                            A_write_addr <= 0;
                            next_state <= load_b;
                        end
                        else begin
                            wr_en_a <= 1;
                            A_write_addr <= A_write_addr+1;
                        end
                    end
                end
                load_b: begin
                    if (AXIS_TVALID) begin
                        if (B_write_addr == K*N-1) begin
                            wr_en_b <= 0;
                            B_write_addr <= 0;
                            next_state <= read;
                        end
                        else begin
                            wr_en_b <= 1;
                            B_write_addr <= B_write_addr+1;
                        end
                    end
                end
                read: begin
                    if (compute_finished) begin
                        matrices_loaded <= 0;
                        AXIS_TREADY <= 1;
                        next_state <= start;
                    end
                    else begin
                        AXIS_TREADY <= 0;
                    end
                end
            endcase
        end
    end

    always_comb begin
        if(matrices_loaded) begin
            A_MEM_ADDRESS = A_read_addr;
            B_MEM_ADDRESS = B_read_addr; 
        end
        else begin
            A_MEM_ADDRESS = A_write_addr;
            B_MEM_ADDRESS = B_write_addr;
        end
    end

    memory #(.WIDTH(INW),.SIZE(M*MAXK)) inst_memory_A ( 
        .data_in(AXIS_TDATA),
        .data_out(A_data),
        .addr(A_MEM_ADDRESS),
        .clk(clk),
        .wr_en(wr_en_a)
    );
    
    //instantiating Memory B
    memory #(.WIDTH(INW),.SIZE(MAXK*N)) inst_memory_B ( 
        .data_in(AXIS_TDATA),
        .data_out(B_data),
        .addr(B_MEM_ADDRESS),
        .clk(clk),
        .wr_en(wr_en_b)
    );

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
