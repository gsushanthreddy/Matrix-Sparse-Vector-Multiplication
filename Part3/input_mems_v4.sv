module input_mems_fsm #(
        parameter INW = 12,
        parameter M = 7,
        parameter N = 9,
        parameter MAXK = 8,
        localparam K_BITS = $clog2(MAXK+1),
        localparam A_ADDR_BITS = $clog2(M*MAXK),
        localparam B_ADDR_BITS = $clog2(MAXK*N)
    )( 
    input clk, reset,
    input AXIS_TVALID,
    input compute_finished,
    input new_A,
    input [K_BITS:0] AXIS_TUSER, 
    input logic [A_ADDR_BITS:0] A_read_addr,
    input logic [B_ADDR_BITS:0] B_read_addr,

    output logic [A_ADDR_BITS:0] A_MEM_ADDRESS,
    output logic [B_ADDR_BITS:0] B_MEM_ADDRESS,
    output logic matrices_loaded,
    output logic wr_en_a,
    output logic wr_en_b,
    output logic AXIS_TREADY,
    output logic [K_BITS-1:0] K
);
    logic [A_ADDR_BITS:0] A_write_addr;
    logic [B_ADDR_BITS:0] B_write_addr;

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
            if (state==start) begin
                if (AXIS_TVALID && AXIS_TREADY) begin
                    if (new_A) begin
                        K <= AXIS_TUSER[$clog2(MAXK+1):1];
                        next_state <= load_a;
                    end
                    else begin
                        next_state = load_b;
                    end
                end
            end
            else if (state==load_a) begin
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
            else if (state==load_b) begin
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
            else if (state==read) begin
                if (compute_finished) begin
                    matrices_loaded <= 0;
                    AXIS_TREADY <= 1;
                    next_state = start;
                end
                else begin
                    AXIS_TREADY <= 0;
                end
            end
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

endmodule
