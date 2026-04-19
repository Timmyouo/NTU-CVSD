#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Sat Nov 29 20:56:09 2025                
#                                                     
#######################################################

#@(#)CDS: Innovus v17.11-s080_1 (64bit) 08/04/2017 11:13 (Linux 2.6.18-194.el5)
#@(#)CDS: NanoRoute 17.11-s080_1 NR170721-2155/17_11-UB (database version 2.30, 390.7.1) {superthreading v1.44}
#@(#)CDS: AAE 17.11-s034 (64bit) 08/04/2017 (Linux 2.6.18-194.el5)
#@(#)CDS: CTE 17.11-s053_1 () Aug  1 2017 23:31:41 ( )
#@(#)CDS: SYNTECH 17.11-s012_1 () Jul 21 2017 02:29:12 ( )
#@(#)CDS: CPE v17.11-s095
#@(#)CDS: IQRC/TQRC 16.1.1-s215 (64bit) Thu Jul  6 20:18:10 PDT 2017 (Linux 2.6.18-194.el5)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
getDrawView
loadWorkspace -name Physical
win
save_global core.conf
set init_gnd_net VSS
set init_lef_file {library/lef/tsmc13fsg_8lm_cic.lef library/lef/sram_4096x8.vclef library/lef/sram_4096x8_ant.lef library/lef/antenna_8.lef}
set init_verilog design_data/core_syn.v
set init_mmmc_file mmmc.view
set init_io_file core.ioc
set init_top_cell core
set init_pwr_net VDD
init_design
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VDD -type net -net VDD
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VSS -type net -net VSS
setDesignMode -process 130
saveDesign DBS/init
getIoFlowFlag
setIoFlowFlag 0
floorPlan -site TSM13SITE -r 1 0.6 80 80 80 80
uiSetTool select
getIoFlowFlag
fit
setDrawView fplan
::mp::clearAllSeed
setPlanDesignMode -effort high -incremental false -boundaryPlace true -fixPlacedMacros false -noColorize false
planDesign
::mp::clearAllSeed
setPlanDesignMode -effort high -incremental false -boundaryPlace true -fixPlacedMacros false -noColorize false
planDesign
setLayerPreference pinObj -isVisible 1
setLayerPreference pinblock -isVisible 1
setLayerPreference pinstdCell -isVisible 1
setLayerPreference pinio -isVisible 1
setLayerPreference piniopin -isVisible 1
setLayerPreference pinother -isVisible 1
addHaloToBlock {30 30 30 30} -allBlock
saveDesign DBS/floorplan
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top METAL3 bottom METAL3 left METAL2 right METAL2} -width {top 8 bottom 8 left 8 right 8} -spacing {top 0.24 bottom 0.24 left 0.24 right 0.24} -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} -center 1 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None -use_wire_group 1 -use_wire_group_bits 4 -use_interleaving_wire_group 1
setSrouteMode -viaConnectToShape { ring }
sroute -connect { padPin } -layerChangeRange { METAL1(1) METAL8(8) } -blockPinTarget { nearestTarget } -padPinPortConnect { allPort allGeom } -padPinTarget { nearestTarget } -allowJogging 1 -crossoverViaLayerRange { METAL1(1) METAL8(8) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { METAL1(1) METAL8(8) }
saveDesign DBS/powerring
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
set sprCreateIeRingOffset 1.0
set sprCreateIeRingThreshold 1.0
set sprCreateIeRingJogDistance 1.0
set sprCreateIeRingLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeThreshold 1.0
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length 0 -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring }
addStripe -nets {VDD VSS} -layer METAL4 -direction vertical -width 2 -spacing 0.24 -set_to_set_distance 100 -start_from left -start_offset 100 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit METAL8 -padcore_ring_bottom_layer_limit METAL1 -block_ring_top_layer_limit METAL8 -block_ring_bottom_layer_limit METAL1 -use_wire_group 0 -snap_wire_center_to_grid None -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length 0 -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring }
addStripe -nets {VDD VSS} -layer METAL5 -direction horizontal -width 2 -spacing 0.24 -set_to_set_distance 80 -start_from bottom -start_offset 20 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit METAL8 -padcore_ring_bottom_layer_limit METAL1 -block_ring_top_layer_limit METAL8 -block_ring_bottom_layer_limit METAL1 -use_wire_group 0 -snap_wire_center_to_grid None -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
saveDesign DBS/powerstripe
setSrouteMode -viaConnectToShape { ring stripe blockring }
sroute -connect { corePin } -layerChangeRange { METAL1(1) METAL8(8) } -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -allowJogging 1 -crossoverViaLayerRange { METAL1(1) METAL8(8) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { METAL1(1) METAL8(8) }
verify_drc
getMultiCpuUsage -localCpu
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
pan 5.344 -63.645
pan 0.339 -0.667
encMessage warning 0
encMessage debug 0
encMessage info 0
restoreDesign /home/raid7_2/userb11/b11043/CVSD/hw_5/DBS/floorplan.dat core
setDrawView fplan
encMessage warning 1
encMessage debug 0
encMessage info 1
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top METAL3 bottom METAL3 left METAL2 right METAL2} -width {top 8 bottom 8 left 8 right 8} -spacing {top 0.24 bottom 0.24 left 0.24 right 0.24} -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} -center 1 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None -use_wire_group 1 -use_wire_group_bits 4 -use_interleaving_wire_group 1
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top METAL3 bottom METAL3 left METAL2 right METAL2} -width {top 8 bottom 8 left 8 right 8} -spacing {top 0.24 bottom 0.24 left 0.24 right 0.24} -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} -center 1 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None -use_wire_group 1 -use_wire_group_bits 4 -use_interleaving_wire_group 1
setVerifyGeometryMode -area { 0 0 0 0 } -minWidth true -minSpacing true -minArea true -sameNet true -short true -overlap true -offRGrid false -offMGrid true -mergedMGridCheck true -minHole true -implantCheck true -minimumCut true -minStep true -viaEnclosure true -antenna false -insuffMetalOverlap true -pinInBlkg false -diffCellViol true -sameCellViol false -padFillerCellsOverlap true -routingBlkgPinOverlap true -routingCellBlkgOverlap true -regRoutingOnly false -stackedViasOnRegNet false -wireExt true -useNonDefaultSpacing false -maxWidth true -maxNonPrefLength -1 -error 1000
verifyGeometry
setVerifyGeometryMode -area { 0 0 0 0 }
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
encMessage warning 0
encMessage debug 0
encMessage info 0
restoreDesign /home/raid7_2/userb11/b11043/CVSD/hw_5/DBS/floorplan.dat core
setDrawView fplan
encMessage warning 1
encMessage debug 0
encMessage info 1
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top METAL3 bottom METAL3 left METAL2 right METAL2} -width {top 8 bottom 8 left 8 right 8} -spacing {top 0.24 bottom 0.24 left 0.24 right 0.24} -offset {top 3 bottom 3 left 3 right 3} -center 1 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None -use_wire_group 1 -use_wire_group_bits 4 -use_interleaving_wire_group 1
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top METAL3 bottom METAL3 left METAL2 right METAL2} -width {top 8 bottom 8 left 8 right 8} -spacing {top 0.24 bottom 0.24 left 0.24 right 0.24} -offset {top 3 bottom 3 left 3 right 3} -center 1 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None -use_wire_group 1 -use_wire_group_bits 4 -use_interleaving_wire_group 1
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
pan -18.331 6.369
pan -0.113 0.451
selectObject IO_Pin {o_out_addr3[11]}
get_visible_nets
gui_select -rect {695.948 -0.188 695.554 -0.163}
selectObject IO_Pin {o_out_addr3[11]}
get_visible_nets
getPinAssignMode -pinEditInBatch -quiet
get_visible_nets
uiSetTool move
moveGroupPins -loc 694.944 -0.460
pan -3.650 -39.179
pan 12.056 -163.400
pan 9.228 -183.078
pan -30.846 -710.747
deselectAll
selectObject IO_Pin o_exe_finish
moveGroupPins -loc 695.980 691.501
undo
undo
deselectAll
selectMarker 695.9800 691.3600 696.0700 692.0800 2 1 6
editMove 0.011 0.096
selectObject IO_Pin o_exe_finish
moveGroupPins -loc 695.980 691.850
moveGroupPins -loc 695.750 692.080
undo
deselectAll
selectObject IO_Pin {i_in_data[4]}
moveGroupPins -loc 694.993 692.080
pan 1.585 0.084
moveGroupPins -loc 694.933 692.080
moveGroupPins -loc 694.899 692.080
moveGroupPins -loc 694.970 692.080
moveGroupPins -loc 694.808 692.080
uiSetTool move
moveGroupPins -loc 694.874 692.080
deselectAll
selectObject IO_Pin o_exe_finish
moveGroupPins -loc 695.980 691.000
pan 837.505 48.157
deselectAll
selectObject IO_Pin i_clk
moveGroupPins -loc 0.804 692.080
pan -27.348 116.283
pan -18.595 461.142
deselectAll
selectObject IO_Pin {o_out_data4[5]}
moveGroupPins -loc 1.046 0.000
moveGroupPins -loc 1.135 -0.460
pan -303.284 -59.178
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
deselectAll
selectObject IO_Pin {o_out_addr3[10]}
moveGroupPins -loc 695.980 1.490
deselectAll
selectObject IO_Pin {o_out_addr3[11]}
moveGroupPins -loc 694.349 -0.460
pan -64.212 -633.203
deselectAll
selectObject IO_Pin {i_in_data[4]}
moveGroupPins -loc 694.626 692.080
pan 971.067 157.084
pan 2.942 1.062
deselectAll
selectObject IO_Pin {o_out_data4[6]}
moveGroupPins -loc -0.460 690.704
pan -161.191 614.058
deselectAll
selectObject IO_Pin {i_in_data[3]}
moveGroupPins -loc -0.460 0.872
pan -832.008 -537.864
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
deselectAll
selectObject IO_Pin o_exe_finish
moveGroupPins -loc 695.980 686.205
deselectAll
selectObject IO_Pin {i_in_data[4]}
moveGroupPins -loc 690.766 692.080
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
deselectAll
selectMarker 695.9800 691.3600 696.0700 692.0800 2 1 6
editMove 0.0455 -0.219
uiSetTool move
selectPhyPin 695.2600 686.0350 695.9800 686.2350 3 o_exe_finish
editMove 0.1845 0.0
undo
deselectAll
selectObject IO_Pin o_exe_finish
moveGroupPins -loc 695.980 683.649
deselectAll
selectObject IO_Pin {i_in_data[4]}
moveGroupPins -loc 687.310 692.080
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
pan 0.000 342.920
pan 63.181 591.798
uiSetTool move
uiSetTool select
deselectAll
pan 346.889 -49.556
saveDesign DBS/powerring
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length 0 -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring }
addStripe -nets {VDD VSS} -layer METAL5 -direction horizontal -width 2 -spacing 0.24 -set_to_set_distance 80 -start_from bottom -start_offset 20 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit METAL8 -padcore_ring_bottom_layer_limit METAL1 -block_ring_top_layer_limit METAL8 -block_ring_bottom_layer_limit METAL1 -use_wire_group 0 -snap_wire_center_to_grid None -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length 0 -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring }
addStripe -nets {VDD VSS} -layer METAL4 -direction vertical -width 2 -spacing 0.24 -set_to_set_distance 100 -start_from left -start_offset 100 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit METAL8 -padcore_ring_bottom_layer_limit METAL1 -block_ring_top_layer_limit METAL8 -block_ring_bottom_layer_limit METAL1 -use_wire_group 0 -snap_wire_center_to_grid None -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length 0 -stacked_via_top_layer METAL8 -stacked_via_bottom_layer METAL1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring }
addStripe -nets {VDD VSS} -layer METAL4 -direction vertical -width 2 -spacing 0.24 -set_to_set_distance 100 -start_from left -start_offset 100 -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit METAL8 -padcore_ring_bottom_layer_limit METAL1 -block_ring_top_layer_limit METAL8 -block_ring_bottom_layer_limit METAL1 -use_wire_group 0 -snap_wire_center_to_grid None -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
saveDesign DBS/powerstripe
setSrouteMode -viaConnectToShape { ring stripe blockring }
sroute -connect { corePin } -layerChangeRange { METAL1(1) METAL8(8) } -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -allowJogging 1 -crossoverViaLayerRange { METAL1(1) METAL8(8) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { METAL1(1) METAL8(8) }
verify_drc
verifyConnectivity -nets {VDD VSS} -type special -error 1000 -warning 50
saveDesign DBS/powerplan
createBasicPathGroups -expanded
place_opt_design
setDrawView place
saveDesign DBS/place
pan -115.438 29.684
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -preCTS -pathReports -drvReports -slackReports -numPaths 50 -prefix core_preCTS -outDir timingReports
setOptMode -fixCap true -fixTran true -fixFanoutLoad true
optDesign -preCTS
gui_select -rect {680.615 190.216 993.945 -58.248}
saveDesign DBS/place
pan -54.971 4.398
update_constraint_mode -name func_mode -sdc_files core_cts.sdc
create_ccopt_clock_tree_spec -file ./ccopt.spec
ccopt_check_and_flatten_ilms_no_restore
create_ccopt_clock_tree -name i_clk -source i_clk -no_skew_group
set_ccopt_property clock_period -pin i_clk 9
create_ccopt_skew_group -name i_clk/func_mode -sources i_clk -auto_sinks
set_ccopt_property include_source_latency -skew_group i_clk/func_mode true
set_ccopt_property extracted_from_clock_name -skew_group i_clk/func_mode i_clk
set_ccopt_property extracted_from_constraint_mode_name -skew_group i_clk/func_mode func_mode
set_ccopt_property extracted_from_delay_corners -skew_group i_clk/func_mode {Delay_Corner_max Delay_Corner_max}
check_ccopt_clock_tree_convergence
get_ccopt_property auto_design_state_for_ilms
ccopt_design -cts
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
ctd_win -id ctd_window
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postCTS -pathReports -drvReports -slackReports -numPaths 50 -prefix core_postCTS -outDir timingReports
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 50 -prefix core_postCTS -outDir timingReports
saveDesign DBS/cts
addTieHiLo -cell {TIELO TIEHI} -prefix LTIE
setNanoRouteMode -quiet -routeInsertAntennaDiode 1
setNanoRouteMode -quiet -routeAntennaCellName ANTENNA
setNanoRouteMode -quiet -timingEngine {}
setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeWithSiDriven 1
setNanoRouteMode -quiet -routeTdrEffort 10
setNanoRouteMode -quiet -routeWithSiPostRouteFix 0
setNanoRouteMode -quiet -drouteStartIteration default
setNanoRouteMode -quiet -routeTopRoutingLayer default
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration default
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
routeDesign -globalDetail -viaOpt -wireOpt
verify_drc -gui
verify_drc -gui
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
pan -105.077 41.117
ctd_win -id ctd_window
saveDesign DBS/route
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
setAnalysisMode -cppr both -clockGatingCheck true -timeBorrowing true -useOutputPinCap true -sequentialConstProp false -timingSelfLoopsNoSkew false -enableMultipleDriveNet true -clkSrcPath true -warn true -usefulSkew true -analysisType onChipVariation -log true
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postRoute -pathReports -drvReports -slackReports -numPaths 50 -prefix core_postRoute -outDir timingReports
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -prefix core_postRoute -outDir timingReports
saveDesign DBS/route
getFillerMode -quiet
addFiller -cell FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64 -prefix FILLER
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
verifyConnectivity -type all -error 1000 -warning 50
verifyProcessAntenna -reportfile core.antenna.rpt -error 1000
saveNetlist core_pr.v
saveDesign DBS/final
setAnalysisMode -analysisType bcwc
write_sdf -max_view av_func_mode_max \
-min_view av_func_mode_min \
-edges noedge \
-splitsetuphold \
-remashold \
-splitrecrem \
-min_period_edges none \
core_pr.sdf
write_sdf -max_view av_func_mode_max \
-min_view av_func_mode_max \
-edges noedge \
-splitsetuphold \
-remashold \
-splitrecrem \
-min_period_edges none \
core_pr.sdf
setStreamOutMode -specifyViaName default -SEvianames false -
setStreamOutMode -specifyViaName default -SEvianames false -virtualConnection false -uniquifyCellNamesPrefix false -snapToMGrid false -textSize 1 -version 3
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false
violationBrowserClose
streamOut core.gds -mapFile library/streamOut.map -merge {library/gds/tsmc13gfsg_fram.gds  library/gds/sram_4096x8.gds } -stripes 1 -units 1000 -mode ALL
ctd_win -id ctd_window
get_verify_drc_mode -disable_rules -quiet
get_verify_drc_mode -quiet -area
get_verify_drc_mode -quiet -layer_range
get_verify_drc_mode -check_implant -quiet
get_verify_drc_mode -check_implant_across_rows -quiet
get_verify_drc_mode -check_ndr_spacing -quiet
get_verify_drc_mode -check_only -quiet
get_verify_drc_mode -check_same_via_cell -quiet
get_verify_drc_mode -exclude_pg_net -quiet
get_verify_drc_mode -ignore_trial_route -quiet
get_verify_drc_mode -max_wrong_way_halo -quiet
get_verify_drc_mode -use_min_spacing_on_block_obs -quiet
get_verify_drc_mode -limit -quiet
set_verify_drc_mode -disable_rules {} -check_implant true -check_implant_across_rows false -check_ndr_spacing false -check_same_via_cell false -exclude_pg_net false -ignore_trial_route false -report core.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}
verifyConnectivity -type all -error 1000 -warning 50
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postRoute -pathReports -drvReports -slackReports -numPaths 50 -prefix core_postRoute -outDir timingReports
report_timing -max_path 1
get_proto_model -type_match {flex_module flex_instgroup blackbox} -committed -name -tcl
unplaceAllInsts
editDelete -type signal
encMessage warning 0
encMessage debug 0
encMessage info 0
restoreDesign /home/raid7_2/userb11/b11043/CVSD/hw_5/DBS/final.dat core
setDrawView fplan
encMessage warning 1
encMessage debug 0
encMessage info 1
setDrawView place
