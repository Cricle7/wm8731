module ram_based_shift_register #(//不跨时钟域
    parameter    WR_RD_WIDTH  = 16,
    parameter    RD_ADDR_WIDTH  = 9,
    parameter    STAGE = 256
) (
    input                           rst,//高电平复位
    input                           clk,
    input  [WR_RD_WIDTH - 1 : 0]    wr_data,
    input                           wr_en,//1:wr,0:rd

    input  [RD_ADDR_WIDTH - 1 : 0]  rd_addr,
    output [WR_RD_WIDTH - 1 : 0]    rd_data,
    output  reg                     wr_busy//1:wr,0:rd
);

reg [3:0] state;
reg [RD_ADDR_WIDTH -1 :0] addr;
reg [3:0] next_state;

reg [RD_ADDR_WIDTH - 1:0] wr_pointer;
reg [RD_ADDR_WIDTH - 1:0] rd_pointer;

parameter  INIT	            = 4'h0;	
parameter  WR_IDLE	        = 4'h1;	
parameter  RD_IDLE	        = 4'h2;	
parameter  RD_DONE	        = 4'h3;	
parameter  WR_POINT_SHIFT   = 4'h4;	

always @(posedge clk) begin
    state <= next_state;
end

always @(*) begin
  case (state)
    INIT: next_state = wr_en ? WR_IDLE : RD_IDLE; 
    WR_IDLE: next_state = WR_POINT_SHIFT; 
    RD_IDLE: begin
      if (wr_en) begin
        next_state = WR_IDLE;
      end
      else if (clk) begin
        next_state = wr_en  ? WR_IDLE : RD_IDLE; 
      end
      else 
        next_state = state;
      end
    WR_POINT_SHIFT: next_state = RD_IDLE; 
    default: next_state = INIT;
  endcase
end

always @(posedge clk) begin
  if (rst) begin
    wr_pointer <= 1;
    rd_pointer <= 2;
  end
  if (state == WR_POINT_SHIFT) begin
    wr_pointer <= (wr_pointer == STAGE) ? 1 : (wr_pointer + 1'b1);
    rd_pointer <= (rd_pointer == STAGE) ? 1 : (rd_pointer + 1'b1);
  end
end

always @(*) begin
  if (wr_en)
    addr = wr_pointer ;
  else begin
    if (rd_addr == 0) begin
      addr = 0;
    end
    else if ((rd_addr + wr_pointer - 1) > STAGE) begin
      addr = rd_addr + wr_pointer -1 - STAGE;
    end
    else
      addr = rd_addr + wr_pointer - 1;
  end
end

always @(posedge clk) begin
  if (state == INIT) begin
    wr_busy <= 0;
  end
  else if (state == WR_IDLE) begin
    wr_busy <= 1'b1;
  end
  else if (state == WR_POINT_SHIFT) begin
    wr_busy <= 0;
  end
end

single_port_ram_16bit shift_register (
  .wr_data(wr_data),    // input [15:0]
  .addr(addr),          // input [8:0]
  .wr_en(wr_en),        // input
  .clk(clk),            // input
  .rst(rst),            // input
  .rd_data(rd_data)     // output [15:0]
);

endmodule  // ram_based_shift_register
