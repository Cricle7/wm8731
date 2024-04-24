//////////////////////////////////////////////////////////////////////////////
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
// Filename:ipml_multacc.v
//////////////////////////////////////////////////////////////////////////////
module ipml_multacc_v1_1
#(
    parameter               ASIZE               = 36,
    parameter               BSIZE               = 36,
    parameter               PSIZE               = 96,

    parameter               INREG_EN            = 0,        //X_REG Y_REG
    parameter               PIPEREG_EN_1        = 0,        //MULT_REG

    parameter               GRS_EN              = "FALSE",  //"TRUE","FALSE",enable global reset
    parameter               X_SIGNED            = 0,        //signedness of X. X[17:9] and X[8:0] share the same signedness in mult9x9 mode
    parameter               Y_SIGNED            = 0,        //signedness of Y. Y[17:9] and Y[8:0] share the same signedness in mult9x9 mode

    parameter               ASYNC_RST           = 1,        // RST is sync/async
    parameter  [PSIZE-1:0]  ACC_INIT_VALUE      = 0,

    parameter               DYN_ACC_INIT        = 0,
    parameter               ACC_ADDSUB_OP       = 0,
    parameter               DYN_ACC_ADDSUB_OP   = 1
)(
    input                   ce          ,
    input                   rst         ,
    input                   clk         ,
    input      [ASIZE-1:0]  a           ,
    input      [BSIZE-1:0]  b           ,
    input      [PSIZE-1:0]  acc_init    ,
    input                   reload      ,
    input                   acc_addsub  ,                  //0:add 1:sub
    output reg [PSIZE-1:0]  p
);
localparam MAX_DATA_SIZE    = (ASIZE >= BSIZE) ? ASIZE : BSIZE;

localparam MIN_DATA_SIZE    = (ASIZE <  BSIZE) ? ASIZE : BSIZE;

localparam USE_SIMD         = (MAX_DATA_SIZE > 9 ) ? 0 : (PSIZE > 24 )? 0 : 1;   // single addsub18_mult18_add48 / dual addsub9_mult9_add24

localparam INSIZE_9         = (USE_SIMD == 1 ) ? 8 : 17;

localparam USE_POSTADD      = 1'b1 ;         //enable postadder 0/1
localparam P_REG            = 1'b1 ;         //enable P_REG

localparam [95:0]   ACC_INIT_VALUE_REAL = {{(96-PSIZE){1'b0}},ACC_INIT_VALUE};

//data_size error check
localparam N = (MIN_DATA_SIZE < 2  ) ? 0 :
	           (MAX_DATA_SIZE <= 9 ) ? 1 :                               //9x9
	           (MAX_DATA_SIZE <= 18) ? 2 :                               //18x18
               (MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 18) ? 3 :        //36x18
               (MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 36) ? 6 : 0 ;    //36x36


localparam [0:0] M_A_SIGNED    = (ASIZE >= BSIZE)? X_SIGNED : Y_SIGNED ;
localparam [0:0] M_B_SIGNED    = (ASIZE < BSIZE)?  X_SIGNED : Y_SIGNED ;

localparam [3:0] M_A_IN_SIGNED = (MIN_DATA_SIZE < 2)   ?  0 :
                                 (MAX_DATA_SIZE <= 18) ?  M_A_SIGNED :
                                 (MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 18) ? {M_A_SIGNED,1'b0} :          //36x18
                                 (MAX_DATA_SIZE <= 36) ?  {{2{M_A_SIGNED}},2'b0} : 0 ;                       //36x36

localparam [3:0] M_B_IN_SIGNED = (MIN_DATA_SIZE < 2)   ? 0 :
                                 (MAX_DATA_SIZE <= 18) ? M_B_SIGNED :
                                 (MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 18) ? {2{M_B_SIGNED}} :            //36x18
                                 (MAX_DATA_SIZE <= 36) ? {2{M_B_SIGNED,1'b0}} : 0 ;                          //36x36

localparam m_a_sign_ext_bit    = (MAX_DATA_SIZE <=9) ? 18 - MAX_DATA_SIZE :                           //9 ext to 18
                                 (MAX_DATA_SIZE > 9  && MAX_DATA_SIZE < 18)? 18 - MAX_DATA_SIZE :
                                 (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <=36)? 36 - MAX_DATA_SIZE : 0;  //36

localparam m_a_sign_ext_bit_s  = (m_a_sign_ext_bit >= 1)? m_a_sign_ext_bit-1 : 0;

localparam m_a_data_lsb        = (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 )? 18 : 0;
//ext b
localparam m_b_sign_ext_bit    = (MAX_DATA_SIZE <=9) ? 18 - MIN_DATA_SIZE :                                                    //9x9 ext 18x18
                                 (MAX_DATA_SIZE > 9  && MAX_DATA_SIZE <= 18)? 18 - MIN_DATA_SIZE :                             //18x18
                                 (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <=18)? 18 - MIN_DATA_SIZE :       //36x18
                                 (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE > 18)? 36 - MIN_DATA_SIZE : 0;    //36x36

localparam m_b_data_lsb = (MIN_DATA_SIZE > 18 && MIN_DATA_SIZE <= 36 )? 18 : 0;

localparam m_b_sign_ext_bit_s = (m_b_sign_ext_bit >=1) ? m_b_sign_ext_bit-1 :0;

initial
begin
    if (N == 0)
    begin
        $display("apm_mult parameter setting error!!! DATA_SIZE must between 2-72");
    end
end

///////////accsub && reload PIPEREG//////////////
reg [17:0]          m_a_0               ;
reg [17:0]          m_a_1               ;
reg [17:0]          m_b_0               ;
reg [17:0]          m_b_1               ;
reg [17:0]          m_a_sign_ext        ;
reg [17:0]          m_b_sign_ext        ;

reg                 acc_addsub_preg     ;
reg                 reload_preg         ;
reg [PSIZE-1:0]     acc_init_preg       ;

wire                acc_addsub_real     ;
wire                reload_real         ;
wire [PSIZE-1:0]    acc_init_d          ;
wire [95:0]         acc_init_real       ;

wire [35:0]         m_a                 ;
wire [35:0]         m_b                 ;
reg  [17:0]         m_a_in[0:3]         ;
reg  [17:0]         m_b_in[0:3]         ;

wire [47:0]         multout0_p          ;
wire [47:0]         multout0_cpo        ;
wire [47:0]         multout1_p          ;
wire [47:0]         multout1_cpo        ;
wire [47:0]         multout2_p          ;
wire [47:0]         multout2_cpo        ;
wire [47:0]         multout3_p          ;
wire [47:0]         multout3_cpo        ;
wire [47:0]         multout4_p          ;
wire [47:0]         multout4_cpo        ;
wire [47:0]         multout5_p          ;
wire                multout0_cout       ;

wire                rst_async           ;
wire                rst_sync            ;

assign rst_async = (ASYNC_RST == 1'b1) ? rst : 1'b0;
assign rst_sync  = (ASYNC_RST == 1'b0) ? rst : 1'b0;

assign m_a = (ASIZE >= BSIZE) ? a : b;
assign m_b = (ASIZE < BSIZE)  ? a : b;

//**************************************addsub**********************************************
always @ (posedge clk or posedge rst_async)
begin
    if (rst_async)
    begin
        acc_addsub_preg  <= 0;
        reload_preg      <= 0;
        acc_init_preg    <= 0;
    end
    else
    begin
        if (rst_sync)
        begin
            acc_addsub_preg <= 0;
            reload_preg     <= 0;
            acc_init_preg   <= 0;
        end
        else if (ce)
        begin
            acc_addsub_preg <= (DYN_ACC_ADDSUB_OP == 0) ? ACC_ADDSUB_OP : acc_addsub;
            reload_preg     <= reload;
            acc_init_preg   <= acc_init;
        end
    end
end

assign acc_addsub_real  = (PIPEREG_EN_1 == 1) ? acc_addsub_preg:(DYN_ACC_ADDSUB_OP == 0) ? ACC_ADDSUB_OP : acc_addsub;
assign reload_real      = (PIPEREG_EN_1 == 1) ? reload_preg   : reload;
assign acc_init_d       = (PIPEREG_EN_1 == 1) ? acc_init_preg : acc_init;

assign acc_init_real    = {{(96-PSIZE){1'b0}},acc_init_d};
//*******************************************************************************************
always @ (*)
begin
	if (MAX_DATA_SIZE < 9)
        m_a_sign_ext = {{m_a_sign_ext_bit{M_A_SIGNED&&m_a[MAX_DATA_SIZE-1]}},{MAX_DATA_SIZE{1'b0}}};
    else if (MAX_DATA_SIZE < 18)
        m_a_sign_ext = {{m_a_sign_ext_bit{M_A_SIGNED&&m_a[MAX_DATA_SIZE-1]}},{MAX_DATA_SIZE{1'b0}}};
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE < 36)
        m_a_sign_ext = {{m_a_sign_ext_bit{M_A_SIGNED&&m_a[MAX_DATA_SIZE-1]}},{{MAX_DATA_SIZE-m_a_data_lsb}{1'b0}}};
    else
        m_a_sign_ext = 0;
end

always @ (*)
begin
	if (MAX_DATA_SIZE <= 9)
    begin
		m_a_0 = {m_a_sign_ext[MAX_DATA_SIZE+m_a_sign_ext_bit_s:MAX_DATA_SIZE],m_a[MAX_DATA_SIZE-1:0]};
	end
	else if (MAX_DATA_SIZE > 9 && MAX_DATA_SIZE < 18)
    begin
		m_a_0 = {m_a_sign_ext[MAX_DATA_SIZE+m_a_sign_ext_bit_s:MAX_DATA_SIZE],m_a[MAX_DATA_SIZE-1:0]};
	end
	else if (MAX_DATA_SIZE == 18)
    begin
		m_a_0 = m_a[MAX_DATA_SIZE-1:0];
	end
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE < 36)
    begin
        m_a_0 = m_a[17:0];
		m_a_1 = {m_a_sign_ext[MAX_DATA_SIZE+m_a_sign_ext_bit_s-m_a_data_lsb:MAX_DATA_SIZE-m_a_data_lsb],m_a[MAX_DATA_SIZE-1:m_a_data_lsb]};
	end
	else if (MAX_DATA_SIZE == 36)
    begin
        m_a_0 = m_a[17:0];
		m_a_1 = m_a[MAX_DATA_SIZE-1:m_a_data_lsb];
	end
end


always @ (*)
begin
    if (MAX_DATA_SIZE <=9)                                                                                           //9x9
        m_b_sign_ext = {{m_b_sign_ext_bit{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]}},{MIN_DATA_SIZE{1'b0}}};
    else if (MAX_DATA_SIZE <=18 && MIN_DATA_SIZE < 18)                                                               //18x18
        m_b_sign_ext = {{m_b_sign_ext_bit{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]}},{MIN_DATA_SIZE{1'b0}}};
    else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <=36 && MIN_DATA_SIZE <=18)                                         //36x18
        m_b_sign_ext = {{m_b_sign_ext_bit{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]}},{MIN_DATA_SIZE{1'b0}}};
    else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <=36 && MIN_DATA_SIZE > 18)                                         //36x36
        m_b_sign_ext = {{m_b_sign_ext_bit{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]}},{(MIN_DATA_SIZE-m_b_data_lsb){1'b0}}};
    else
        m_b_sign_ext = 0;
end

always @ (*)
begin
	if (MAX_DATA_SIZE <= 9)
    begin       //9x9
		m_b_0 = {m_b_sign_ext[MIN_DATA_SIZE+m_b_sign_ext_bit_s:MIN_DATA_SIZE],m_b[MIN_DATA_SIZE-1:0]};
	end
	else if (MAX_DATA_SIZE > 9 && MAX_DATA_SIZE <= 18 && MIN_DATA_SIZE < 18)
    begin      //18x18
		m_b_0 = {m_b_sign_ext[MIN_DATA_SIZE+m_b_sign_ext_bit_s:MIN_DATA_SIZE],m_b[MIN_DATA_SIZE-1:0]};
	end
	else if (MAX_DATA_SIZE > 9 && MAX_DATA_SIZE <= 18 && MIN_DATA_SIZE == 18)
    begin     //18x18
		m_b_0 = m_b[MIN_DATA_SIZE-1:0];
	end
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <=36 && MIN_DATA_SIZE < 18)
    begin      //36x18
		m_b_0 = {m_b_sign_ext[MIN_DATA_SIZE+m_b_sign_ext_bit_s:MIN_DATA_SIZE],m_b[MIN_DATA_SIZE-1:0]};
	end
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <=36 && MIN_DATA_SIZE == 18)
    begin      //36x18
		m_b_0 = {{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]},m_b[MIN_DATA_SIZE-1:0]};
	end
    else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36&& MIN_DATA_SIZE > 18 && MIN_DATA_SIZE < 36  )
    begin  //36x36
        m_b_0 = m_b[17:0];
		m_b_1 = {m_b_sign_ext[MIN_DATA_SIZE+m_b_sign_ext_bit_s-m_b_data_lsb:MIN_DATA_SIZE-m_b_data_lsb],m_b[MIN_DATA_SIZE-1:m_b_data_lsb]};
	end
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36&&  MIN_DATA_SIZE == 36  )
    begin   //36x36
        m_b_0 = m_b[17:0];
		m_b_1 = {{M_B_SIGNED&&m_b[MIN_DATA_SIZE-1]},m_b[MIN_DATA_SIZE-1:m_b_data_lsb]};
	end
end

////////////////////////////////////////////
always@(*)
begin
    if (MAX_DATA_SIZE <=9)
    begin    //9x9
        m_a_in[0] = m_a_0;
        m_b_in[0] = m_b_0;
    end
    else if (MAX_DATA_SIZE>9 && MAX_DATA_SIZE <=18)
    begin   //18x18
        m_a_in[0] = m_a_0;
        m_b_in[0] = m_b_0;
    end
    else if (MAX_DATA_SIZE >18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <=18)
    begin  //36x18
        m_a_in[0] = m_a_0;
        m_a_in[1] = m_a_1;
        m_b_in[0] = m_b_0;
        m_b_in[1] = m_b_0;
    end
    else if (MAX_DATA_SIZE >18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE >=18)
    begin  //36x36
        m_a_in[0] = m_a_0;
        m_a_in[1] = m_a_0;
        m_a_in[2] = m_a_1;
        m_a_in[3] = m_a_1;
        m_b_in[0] = m_b_0;
        m_b_in[1] = m_b_1;
        m_b_in[2] = m_b_0;
        m_b_in[3] = m_b_1;
    end
end

generate
    if(MAX_DATA_SIZE <= 9)
    begin            //9x9
          GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .X_SIGNED      (  M_A_IN_SIGNED[0]  ),
            .Y_SIGNED      (  M_B_IN_SIGNED[0]  ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  ACC_INIT_VALUE_REAL[47:0])
	       )
        multacc_9(
            .P      (   multout0_p  ),          //Postadder resout
            .CPO    (               ),          //p cascade out
            .COUT   (               ),          //Postadder carry out
            .CXO    (               ),          //X cascade out
            .CXBO   (               ),          //X backward cascade out
            .X      (   m_a_in[0][INSIZE_9:0]   ),
            .CXI    (               ),          //X cascade in
            .CXBI   (               ),          //X backward cascade in
            .Y      (   m_b_in[0][INSIZE_9:0]   ),
            .Z      (   acc_init_real[47:0] ),
            .CPI    (               ),          //p cascade in
            .CIN    (                ),          //Postadder carry in
            .MODEX  (   1'b0        ),          //preadder add/sub(), 0/1
            .MODEY  (   {{reload_real?1'b0:acc_addsub_real},reload_real,1'b0}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?reload_real:1'b0},~reload_real,1'b0} ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );
    end

    else if (MAX_DATA_SIZE > 9 && MAX_DATA_SIZE <= 18)
    begin       //18x18
        reg  mult_sign_d;
        wire mult_sign;

        always @ (posedge clk or posedge rst_async)
        begin
            if (rst_async)
                mult_sign_d <= 0;
            else
            begin
                if (rst_sync)
                    mult_sign_d <= 0;
                else if (ce)
                    mult_sign_d <= ((M_A_IN_SIGNED[0] && m_a_in[0][17]) ^ (M_B_IN_SIGNED[0] && m_b_in[0][17]))&&(|m_a_in[0] && |m_b_in[0]);
            end
        end

        assign mult_sign = (PIPEREG_EN_1 == 1)? mult_sign_d : ((M_A_IN_SIGNED[0] && m_a_in[0][17]) ^ (M_B_IN_SIGNED[0] && m_b_in[0][17]))&&(|m_a_in[0] && |m_b_in[0]);


          GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN              ),
            .X_SIGNED      (  M_A_IN_SIGNED[0]    ),
            .Y_SIGNED      (  M_B_IN_SIGNED[0]    ),
            .USE_POSTADD   (  USE_POSTADD         ),
            .X_REG         (  INREG_EN            ),
            .Y_REG         (  INREG_EN            ),
            .Z_REG         (  INREG_EN            ),
            .MULT_REG      (  PIPEREG_EN_1        ),
            .P_REG         (  P_REG               ),
            .MODEX_REG     (  INREG_EN            ),
            .MODEY_REG     (  INREG_EN            ),
            .MODEZ_REG     (  INREG_EN            ),
            .ASYNC_RST     (  ASYNC_RST           ),
            .USE_SIMD      (  USE_SIMD            ),
            .Z_INIT        (  ACC_INIT_VALUE_REAL[47:0])
	       )
        multacc_18_0(
            .P      (   multout0_p      ),       //Postadder resout
            .CPO    (                   ),       //p cascade out
            .COUT   (   multout0_cout   ),       //Postadder carry out
            .CXO    (                   ),       //X cascade out
            .CXBO   (                   ),       //X backward cascade out
            .X      (   m_a_in[0]       ),
            .CXI    (                   ),       //X cascade in
            .CXBI   (                   ),       //X backward cascade in
            .Y      (   m_b_in[0]       ),
            .Z      (   acc_init_real[47:0] ),
            .CPI    (                   ),       //p cascade in
            .CIN    (                   ),       //Postadder carry in
            .MODEX  (   1'b0            ),       //preadder add/sub(), 0/1
            .MODEY  (   {{reload_real?1'b0:acc_addsub_real},reload_real,1'b0}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?reload_real:1'b0},~reload_real,1'b0}   ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN               ),
            .USE_POSTADD   (  USE_POSTADD          ),
            .Z_REG         (  INREG_EN             ),
            .P_REG         (  P_REG                ),
            .MODEX_REG     (  INREG_EN             ),
            .MODEY_REG     (  INREG_EN             ),
            .MODEZ_REG     (  INREG_EN             ),
            .ASYNC_RST     (  ASYNC_RST            ),
            .USE_SIMD      (  USE_SIMD             ),
            .Z_INIT        (  ACC_INIT_VALUE_REAL[95:48]),
            .CIN_SEL       (  1'b1                 )
	       )
        multacc_18_1(
            .P      (   multout1_p      ),          //Postadder resout
            .CPO    (                   ),          //p cascade out
            .COUT   (                   ),          //Postadder carry out
            .CXO    (                   ),          //X cascade out
            .CXBO   (                   ),          //X backward cascade out
            .X      (   {18{1'b1}}      ),
            .CXI    (                   ),          //X cascade in
            .CXBI   (                   ),          //X backward cascade in
            .Y      (   {18{1'b1}}      ),
            .Z      (   {reload_real? (acc_init_real[95:48]) : {48{mult_sign}}} ),
            .CPI    (                   ),          //p cascade in
            .CIN    (   multout0_cout   ),          //Postadder carry in
            .MODEX  (   1'b0            ),          //preadder add/sub(), 0/1
            .MODEY  (   {2'b01,~reload_real}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {{reload_real?1'b0:acc_addsub_real},{DYN_ACC_INIT?1'b1:~reload_real},2'b0}  ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );
    end
    else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 18)
    begin    //36x18
                GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN              ),
            .X_SIGNED      (  M_A_IN_SIGNED[0]    ),
            .Y_SIGNED      (  M_B_IN_SIGNED[0]    ),
            .USE_POSTADD   (  USE_POSTADD         ),
            .X_REG         (  INREG_EN            ),
            .Y_REG         (  INREG_EN            ),
            .Z_REG         (  INREG_EN            ),
            .MULT_REG      (  PIPEREG_EN_1        ),
            .P_REG         (  P_REG               ),
            .MODEX_REG     (  INREG_EN            ),
            .MODEY_REG     (  INREG_EN            ),
            .MODEZ_REG     (  INREG_EN            ),
            .ASYNC_RST     (  ASYNC_RST           ),
            .USE_SIMD      (  USE_SIMD            ),
            .Z_INIT        (  {30'b0,ACC_INIT_VALUE_REAL[17:0]}),
            .USE_ACCLOW    (  1'b1                )
	       )
        multacc_36x18_0(
            .P      (   multout0_p      ),  //Postadder resout
            .CPO    (   multout0_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   m_a_in[0]       ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   m_b_in[0]       ),
            .Z      (   {30'b0,acc_init_real[17:0]} ),
            .CPI    (                   ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {{reload_real?1'b0:acc_addsub_real},reload_real,1'b0}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?reload_real:1'b0},~reload_real,1'b0}   ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .X_SIGNED      (  M_A_IN_SIGNED[1]  ),
            .Y_SIGNED      (  M_B_IN_SIGNED[1]  ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  48'b0             )
	       )
        multacc_36x18_1(
            .P      (   multout1_p     ),   //Postadder resout
            .CPO    (   multout1_cpo   ),   //p cascade out
            .COUT   (                  ),   //Postadder carry out
            .CXO    (                  ),   //X cascade out
            .CXBO   (                  ),   //X backward cascade out
            .X      (   m_a_in[1]      ),
            .CXI    (                  ),   //X cascade in
            .CXBI   (                  ),   //X backward cascade in
            .Y      (   m_b_in[1]      ),
            .Z      (   {48{1'b1}}     ),
            .CPI    (   multout0_cpo   ),   //p cascade in
            .CIN    (                  ),   //Postadder carry in
            .MODEX  (   1'b0           ),   //preadder add/sub(), 0/1
            .MODEY  (   {acc_addsub_real,2'b00} ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   4'b0111 ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

          GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN               ),
            .USE_POSTADD   (  USE_POSTADD          ),
            .X_REG         (  INREG_EN             ),
            .Y_REG         (  INREG_EN             ),
            .Z_REG         (  INREG_EN             ),
            .MULT_REG      (  PIPEREG_EN_1         ),
            .P_REG         (  P_REG                ),
            .MODEX_REG     (  INREG_EN             ),
            .MODEY_REG     (  INREG_EN             ),
            .MODEZ_REG     (  INREG_EN             ),
            .ASYNC_RST     (  ASYNC_RST            ),
            .USE_SIMD      (  USE_SIMD             ),
            .Z_INIT        (  ACC_INIT_VALUE_REAL[65:18])
	       )
        multacc_36x18_2(
            .P      (   multout2_p      ),  //Postadder resout
            .CPO    (                   ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   {18{1'b1}}      ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   {18{1'b1}}      ),
            .Z      (   acc_init_real[65:18] ),
            .CPI    (   multout1_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {2'b01,~reload_real}   ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?1'b1:~reload_real},~reload_real,1'b0}    ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );
    end
    else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE >= 18)  //36x36
    begin
        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN              ),
            .X_SIGNED      (  M_A_IN_SIGNED[0]    ),
            .Y_SIGNED      (  M_B_IN_SIGNED[0]    ),
            .USE_POSTADD   (  USE_POSTADD         ),
            .X_REG         (  INREG_EN            ),
            .Y_REG         (  INREG_EN            ),
            .Z_REG         (  INREG_EN            ),
            .MULT_REG      (  PIPEREG_EN_1        ),
            .P_REG         (  P_REG               ),
            .MODEX_REG     (  INREG_EN            ),
            .MODEY_REG     (  INREG_EN            ),
            .MODEZ_REG     (  INREG_EN            ),
            .ASYNC_RST     (  ASYNC_RST           ),
            .USE_SIMD      (  USE_SIMD            ),
            .Z_INIT        (  {30'b0,ACC_INIT_VALUE_REAL[17:0]}),
            .USE_ACCLOW    (  1'b1                )
	       )
        multacc_36_0(
            .P      (   multout0_p      ),  //Postadder resout
            .CPO    (   multout0_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   m_a_in[0]       ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   m_b_in[0]       ),
            .Z      (   {30'b0,acc_init_real[17:0]}),
            .CPI    (                   ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {{reload_real?1'b0:acc_addsub_real},reload_real,1'b0}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?reload_real:1'b0},~reload_real,1'b0}   ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .X_SIGNED      (  M_A_IN_SIGNED[1]  ),
            .Y_SIGNED      (  M_B_IN_SIGNED[1]  ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  48'b0             )
	       )
        multacc_36_1(
            .P      (   multout1_p      ),  //Postadder resout
            .CPO    (   multout1_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   m_a_in[1]       ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   m_b_in[1]       ),
            .Z      (   {48{1'b1}}      ),
            .CPI    (   multout0_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {acc_addsub_real,2'b00}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   4'b0111         ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

          GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .X_SIGNED      (  M_A_IN_SIGNED[2]  ),
            .Y_SIGNED      (  M_B_IN_SIGNED[2]  ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  48'b0             )
	       )
        multacc_36_2(
            .P      (   multout2_p      ),  //Postadder resout
            .CPO    (   multout2_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   m_a_in[2]       ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   m_b_in[2]       ),
            .Z      (   {48{1'b1}}      ),
            .CPI    (   multout1_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {acc_addsub_real,2'b00}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   4'b0110         ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  {30'b0,ACC_INIT_VALUE_REAL[35:18]}),
            .USE_ACCLOW    (  1'b1              )
	       )
        multacc_36_3(
            .P      (   multout3_p      ),  //Postadder resout
            .CPO    (   multout3_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   {18{1'b1}}      ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   {18{1'b1}}      ),
            .Z      (   {30'b0,acc_init_real[35:18]}),
            .CPI    (   multout2_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {2'b01,~reload_real}   ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?1'b1:~reload_real},~reload_real,1'b0}    ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

        GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .X_SIGNED      (  M_A_IN_SIGNED[3]  ),
            .Y_SIGNED      (  M_B_IN_SIGNED[3]  ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  48'b0             )
	       )
        multacc_36_4(
            .P      (   multout4_p      ),  //Postadder resout
            .CPO    (   multout4_cpo    ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   m_a_in[3]       ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   m_b_in[3]       ),
            .Z      (   {48{1'b1}}      ),
            .CPI    (   multout3_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {acc_addsub_real,2'b00}    ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   4'b0111         ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );

          GTP_APM_E1 #(
            .GRS_EN        (  GRS_EN            ),
            .USE_POSTADD   (  USE_POSTADD       ),
            .X_REG         (  INREG_EN          ),
            .Y_REG         (  INREG_EN          ),
            .Z_REG         (  INREG_EN          ),
            .MULT_REG      (  PIPEREG_EN_1      ),
            .P_REG         (  P_REG             ),
            .MODEX_REG     (  INREG_EN          ),
            .MODEY_REG     (  INREG_EN          ),
            .MODEZ_REG     (  INREG_EN          ),
            .ASYNC_RST     (  ASYNC_RST         ),
            .USE_SIMD      (  USE_SIMD          ),
            .Z_INIT        (  ACC_INIT_VALUE_REAL[83:36])
	       )
        multacc_36_5(
            .P      (   multout5_p      ),  //Postadder resout
            .CPO    (                   ),  //p cascade out
            .COUT   (                   ),  //Postadder carry out
            .CXO    (                   ),  //X cascade out
            .CXBO   (                   ),  //X backward cascade out
            .X      (   {18{1'b1}}      ),
            .CXI    (                   ),  //X cascade in
            .CXBI   (                   ),  //X backward cascade in
            .Y      (   {18{1'b1}}      ),
            .Z      (   acc_init_real[83:36] ),
            .CPI    (   multout4_cpo    ),  //p cascade in
            .CIN    (                   ),  //Postadder carry in
            .MODEX  (   1'b0            ),  //preadder add/sub(), 0/1
            .MODEY  (   {2'b01,~reload_real} ),
            //ODEY encoding: 0/1
            //[0]     produce all-0 . to post adder / enable p register feedback. MODEY[1] needs to be 1 for MODEY[0] to take effect.
            //[1]     enable/disable mult . for post adder
            //[2]     +/- (mult-mux . polarity)
            .MODEZ  (   {1'b0,{DYN_ACC_INIT?1'b1:~reload_real},~reload_real,1'b0}    ),
            //[ODEZ encoding: 0/1
            //[0]     CPI / (CPI >>> 18) (select shift or non-shift CPI)
            //[2:1]   Z_INIT/p/Z/CPI (zmux . select)
            //[3]     +/- (zmux . polarity)
            .CLK     (   clk  ),
            .RSTX    (   rst  ),
            .RSTY    (   rst  ),
            .RSTZ    (   1'b0 ),
            .RSTM    (   rst  ),
            .RSTP    (   rst  ),
            .RSTPRE  (   rst  ),
            .RSTMODEX(   1'b0 ),
            .RSTMODEY(   1'b0 ),
            .RSTMODEZ(   1'b0 ),
            .CEX     (   ce   ),
            .CEY     (   ce   ),
            .CEZ     (   ce   ),
            .CEM     (   ce   ),
            .CEP     (   ce   ),
            .CEPRE   (   ce   ),
            .CEMODEX (   ce   ),
            .CEMODEY (   ce   ),
            .CEMODEZ (   ce   )
        );
    end
endgenerate


always @ (*)
begin
	if (MAX_DATA_SIZE <=9)                              //9x9
		p = multout0_p;
	else if (MAX_DATA_SIZE > 9 && MAX_DATA_SIZE <= 18)  //18x18
		p = {multout1_p,multout0_p};
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE <= 18)  //36x18
		p = {multout2_p,multout0_p[17:0]};
	else if (MAX_DATA_SIZE > 18 && MAX_DATA_SIZE <= 36 && MIN_DATA_SIZE >= 18)  //36x36
        p = {multout5_p,multout3_p[17:0],multout0_p[17:0]};
end

endmodule