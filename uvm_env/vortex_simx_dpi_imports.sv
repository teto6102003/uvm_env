// File: vortex_simx_dpi_imports.sv
// All SimX DPI-C imports at compilation-unit scope.
// Compiled as a standalone file BEFORE vortex_env_pkg.
// To add a new DPI function: add one import line here, then call it
// in vortex_scoreboard.sv. To remove: delete the line and all call sites.

`ifndef VORTEX_SIMX_DPI_IMPORTS_SV
`define VORTEX_SIMX_DPI_IMPORTS_SV

import "DPI-C" function int  simx_init    (int cores, int warps, int threads);
import "DPI-C" function void simx_cleanup ();
import "DPI-C" function void simx_write_mem (longint unsigned addr,
                                              int              size,
                                              input byte unsigned data[]);
import "DPI-C" function void simx_read_mem  (longint unsigned addr,
                                              int              size,
                                              inout byte unsigned data[]);
import "DPI-C" function int  simx_load_bin  (string filepath,
                                              longint unsigned load_addr);
import "DPI-C" function int  simx_load_hex  (string filepath);
import "DPI-C" function void simx_dcr_write (int addr, int value);
import "DPI-C" function int  simx_run       ();
import "DPI-C" function int  simx_step      (int cycles);
import "DPI-C" function int  simx_is_done   ();
import "DPI-C" function int  simx_get_exitcode ();
import "DPI-C" function void simx_init_exit_code_register ();

`endif
