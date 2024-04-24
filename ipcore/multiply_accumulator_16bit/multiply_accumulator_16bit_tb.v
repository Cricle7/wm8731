

/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//               
// Library:
// Filename:TB multiply_accumulator_16bit_tb.v                 
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns

module multiply_accumulator_16bit_tb();

localparam  T_CLK_PERIOD       = 10     ;       //clock a half perid
localparam  T_RST_TIME         = 200    ;       //reset time 
localparam  T_SIM_TIME         = 100000 ;       //simulation time 


localparam ASIZE = 16; //@IPC int 2,36

localparam BSIZE = 16; //@IPC int 2,27

localparam A_SIGNED = 1; //@IPC enum 0,1

localparam B_SIGNED = 1; //@IPC enum 0,1

localparam PSIZE = 96; //@IPC enum 24,48,96,66,84

localparam ASYNC_RST = 0 ; //@IPC enum 0,1

localparam INREG_EN = 0 ; //@IPC enum 0,1

localparam PIPEREG_EN = 1 ; //@IPC enum 0,1

localparam ACC_ADDSUB_OP = 0; //@IPC bool

localparam DYN_ACC_ADDSUB_OP = 0; //@IPC bool

localparam DYN_ACC_INIT = 0; //@IPC bool

localparam [PSIZE-1:0] ACC_INIT_VALUE = 96'h0; //@IPC string

//tmp variable for ipc purpose

localparam PIPE_STATUS = 1 ; //@IPC enum 0,1,2

localparam ASYNC_RST_BOOL = 0 ; //@IPC bool

//end of tmp variable

// variable declaration
reg                 clk;
reg                 rst;
reg                 ce;
reg                 ce_2;
reg  [ASIZE-1:0]    a;
reg  [BSIZE-1:0]    b;
wire [PSIZE-1:0]    p;
wire [PSIZE-1:0]    p_2;
reg  [PSIZE-1:0]    p_comp;

reg  [PSIZE-1:0]    acc_init;		
reg                 acc_addsub;
reg                 reload;

wire [143:0]        a_ext;
wire [143:0]        b_ext;
wire [287:0]        p_ext;
reg  [PSIZE-1:0]    product_p_r;
reg  [PSIZE-1:0]    product_p_rr;

integer             pass;


assign a_ext = A_SIGNED ? {{(144-ASIZE+1){a[ASIZE-1]}},a[ASIZE-2:0]} : {{(144-ASIZE){1'b0}},a};

assign b_ext = B_SIGNED ? {{(144-BSIZE+1){b[BSIZE-1]}},b[BSIZE-2:0]} : {{(144-BSIZE){1'b0}},b};
assign p_ext = ((a == 0) || (b ==0)) ? {288{1'b0}}
                                     : {{(288-ASIZE-BSIZE){(a_ext[ASIZE+BSIZE]&&A_SIGNED)^(b_ext[ASIZE+BSIZE]&&B_SIGNED)}},{a_ext[ASIZE+BSIZE-1:0] * b_ext[ASIZE+BSIZE-1:0]}};

always #T_CLK_PERIOD clk = ~clk;

initial 
begin
    clk = 0;
    ce = 0;
    ce_2 = 0;
	rst = 1;
    #T_RST_TIME
    rst = 0;
end
initial 
begin
    a = 'h00;
	b = 'h00;
	acc_init = 0;
	acc_addsub = 0;
	reload = 0;
    #1000
    ce = 1;
    ce_2 = 1;
    #1000
    ce_2 = 0;
    #1000
    reload = 1;
    #1000
    ce_2 = 1;
    #100 
    reload = 0;
	pass = 1;
end

GTP_GRS   GRS_INST( .GRS_N(1'b1) );

wire [PSIZE-1:0] acc_init_comb = (DYN_ACC_INIT == 1)? acc_init :ACC_INIT_VALUE ;


always @(posedge clk or posedge rst) 
begin
    if (rst) 
    begin
        p_comp   <= 0;
    end
    else 
    begin
        if (reload)
            p_comp <= acc_init_comb;
        else if (DYN_ACC_ADDSUB_OP)
        begin
            if (acc_addsub == 0)
                p_comp <= p_comp + p_ext;
            else 
                p_comp <= p_comp - p_ext;
        end
	    else if (ACC_ADDSUB_OP)
            p_comp <= p_comp - p_ext;
	    else
            p_comp <= p_comp + p_ext;
    end
end

always @(posedge clk or posedge rst) 
begin
    if(rst) 
    begin 
        product_p_r <= 96'b0;
        product_p_rr <= 96'b0;
    end
    else  
    begin 
       product_p_r <= p_comp;
       product_p_rr <= product_p_r;
    end    
end

wire [PSIZE-1:0] p_acc;
assign p_acc = ((INREG_EN ==0)&&(PIPEREG_EN ==0)) ? p_comp :
                      (((INREG_EN ==0)&&(PIPEREG_EN ==1))|((INREG_EN ==1)&&(PIPEREG_EN ==0))) ? product_p_r : product_p_rr ;   



integer  result_fid;
initial 
begin
	$display("Simulation Starts ...\n");
	result_fid = $fopen ("sim_results.log","a");   
	#T_SIM_TIME;
	$display("Simulation is done.\n");
	if (pass == 1)
		$display("Simulation Success!\n");
	else
		$display("Simulation Failed!\n");
	$finish;
end   
   
always  @(posedge clk) 
begin

    a <= $random;

    b <= $random;

    acc_addsub <= $random;

	if ( p_acc != p) 
    begin
        $fdisplay(result_fid, "err_chk=1");
        $display("multacc error! multacc data = %h, product = %h",p_acc,p);
        pass = 0;
    end     
end

//***************************************************************** DUT  INST ********************************************************************************
multiply_accumulator_16bit  U_multiply_accumulator_16bit
(
	.ce         ( ce      ),
	.rst        ( rst       ),
	.clk        ( clk       ),
	.a          ( a         ),
	.b          ( b         ),

	.reload     (reload     ),
	.p          (p          )
 );
multiply_accumulator_16bit  U_U_multiply_accumulator_16bit
(
	.ce         ( ce_2      ),
	.rst        ( rst       ),
	.clk        ( clk       ),
	.a          ( a         ),
	.b          ( b         ),

	.reload     (reload     ),
	.p          (p_2          )
 );
 endmodule

