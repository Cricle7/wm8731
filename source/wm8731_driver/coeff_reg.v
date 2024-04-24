module coeff_reg #(
  parameter STAGE = 256
)(
  input      clk,
  input      rst,           // 高电平复位

  input      [8:0]  wr_addr,
  input      [15:0] wr_coeff,
  input      wr_en,
  input      coeff_up,
  
  input      [8:0]  rd_addr,
  output     [15:0] rd_data
);

reg state;//代表写指针
reg [9:0] addr;

always @(posedge clk) begin
  if (rst) begin
    state <= 0;
  end
  else if (coeff_up)
    state <= ~state;
end

always @(*) begin
  if (wr_en) begin
    addr = state ? (wr_addr + STAGE) : wr_addr;
  end
  else begin
    addr = state ? rd_addr  : (rd_addr + STAGE);
  end
end

signle_port_16bit_x_521 coeff_ram (
  .wr_data(wr_coeff),    // input [15:0]
  .addr(addr),          // input [9:0]
  .wr_en(wr_en),        // input
  .clk(clk),            // input
  .rst(rst),            // input
  .rd_data(rd_data)     // output [15:0]
);
endmodule

