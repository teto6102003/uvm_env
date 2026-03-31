////////////////////////////////////////////////////////////////////////////////
// File: vortex_analysis_imp_decls.svh
// Description: Shared uvm_analysis_imp_decl macros for Vortex UVM env
//
// These macros must be declared ONCE at compilation unit scope.
// Both vortex_scoreboard.sv and vortex_coverage_collector.sv include
// this file. The ifndef guard prevents double-declaration when both
// files are compiled together via vortex_env_pkg.sv.
////////////////////////////////////////////////////////////////////////////////

`ifndef VORTEX_ANALYSIS_IMP_DECLS_SVH
`define VORTEX_ANALYSIS_IMP_DECLS_SVH

`uvm_analysis_imp_decl(_mem)
`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_dcr)
`uvm_analysis_imp_decl(_host)
`uvm_analysis_imp_decl(_status)

`endif // VORTEX_ANALYSIS_IMP_DECLS_SVH
