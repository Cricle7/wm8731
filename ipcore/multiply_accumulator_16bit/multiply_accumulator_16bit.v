

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
// Filename:multiply_accumulator_16bit.v                 
//////////////////////////////////////////////////////////////////////////////
module multiply_accumulator_16bit
( 
     ce         ,
     rst        ,
     clk        ,
     a          ,
     b          ,

     reload     ,
     p
);



localparam ASIZE = 16 ; //@IPC int 2,36

localparam BSIZE = 16 ; //@IPC int 2,36

localparam PSIZE = 96 ; //@IPC enum 24,48,96,66,84

localparam A_SIGNED = 1 ; //@IPC enum 0,1

localparam B_SIGNED = 1 ; //@IPC enum 0,1

localparam ASYNC_RST = 0 ; //@IPC enum 0,1

localparam INREG_EN = 0 ; //@IPC enum 0,1

localparam PIPEREG_EN = 1 ; //@IPC enum 0,1

localparam ACC_ADDSUB_OP = 0 ; //@IPC bool

localparam DYN_ACC_ADDSUB_OP = 0 ; //@IPC bool

localparam DYN_ACC_INIT = 0 ; //@IPC bool

localparam [PSIZE-1:0] ACC_INIT_VALUE = 96'h0 ; //@IPC string

//tmp variable for ipc purpose

localparam PIPE_STATUS = 1 ; //@IPC enum 0,1,2

localparam ASYNC_RST_BOOL = 0 ; //@IPC bool

//end of tmp variable
 
 localparam  GRS_EN       = "FALSE"        ;


 input                ce                   ;
 input                rst                  ;
 input                clk                  ;
 input  [ASIZE-1:0]   a                    ;
 input  [BSIZE-1:0]   b                    ;

 input                reload               ;
 output [PSIZE-1:0]   p                    ;

ipml_multacc_v1_1
#(  
    .ASIZE              ( ASIZE             ),
    .BSIZE              ( BSIZE             ),
    .PSIZE              ( PSIZE             ),
    .INREG_EN           ( INREG_EN          ),     
    .PIPEREG_EN_1       ( PIPEREG_EN        ),   
    .GRS_EN             ( GRS_EN            ), 
    .X_SIGNED           ( A_SIGNED          ),    
    .Y_SIGNED           ( B_SIGNED          ),    
    .ASYNC_RST          ( ASYNC_RST         ),     
    .ACC_INIT_VALUE     ( ACC_INIT_VALUE    ), 
    .DYN_ACC_INIT       ( DYN_ACC_INIT      ),
    .ACC_ADDSUB_OP      ( ACC_ADDSUB_OP     ),   
    .DYN_ACC_ADDSUB_OP  ( DYN_ACC_ADDSUB_OP ) 
) u_ipml_multacc
(
    .ce         ( ce        ),
    .rst        ( rst       ),
    .clk        ( clk       ),
    .a          ( a         ),
    .b          ( b         ),

    .reload     ( reload    ),
    .p          ( p         )
);

endmodule

