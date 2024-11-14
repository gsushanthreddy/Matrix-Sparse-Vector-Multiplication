module MMM #(
    parameter INW = 12,
    parameter OUTW = 32,
    parameter M = 7,
    parameter N = 9,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1)
)(
    input clk,
    input reset,
    input [INW-1:0] INPUT_TDATA,
    input INPUT_TVALID,
    input [K_BITS:0] INPUT_TUSER,
    output INPUT_TREADY,
    output [OUTW-1:0] OUTPUT_TDATA,
    output OUTPUT_TVALID,
    input OUTPUT_TREADY
);
    integer A_ADDR_BITS = $clog2(M*MAXK);
    integer B_ADDR_BITS = $clog2(MAXK*N);
    integer m,
    integer n;
    integer k;

    logic [A_ADDR_BITS-1:0] A_read_addr;
    logic [B_ADDR_BITS-1:0] B_read_addr;
    logic matrices_loaded;
    logic clear_acc;
    logic valid_input;
    logic wr_en_fifo;
    logic compute_finished;


    enum {mmm_start, read_from_input_memory, store_in_fifo} state, next_state;
    /* 
        mmm_start => Part4 should wait for Part3 to generate matrices_loaded signal as 1
        read_from_input_memory => After matrices_loaded is set to 1, read addresses should be available from next posedge of clk
        store_in_fifo => wr_en for fifo will be set to 1 here. 
    */ 
     
    always_comb begin
        if(state == mmm_start) begin
        end
    end

    always_ff begin
        if(reset) begin
            state <= mmm_start;
        end
        else begin
            state <= next_state;
        end
    end

endmodule