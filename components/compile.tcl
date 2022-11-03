if {[file exists component_lib]} {
    vdel -lib component_lib -all
}

vlib component_lib
vmap work component_lib
vmap osvvm $env(QUARTUS_ROOTDIR)/../modelsim_ase/osvvm

vcom -2008 -work work ./src/my_pkg.vhd
vcom -2008 -work work ./src/dflipflop.vhd
vcom -2008 -work work ./src/general_sized_register.vhd
vcom -2008 -work work ./src/counter.vhd
vcom -2008 -work work ./src/simple_timer.vhd
vcom -2008 -work work ./src/timer.vhd
vcom -2008 -work work ./src/shift_register.vhd
vcom -2008 -work work ./src/clock_divider.vhd
vcom -2008 -work work ./src/ram_block.vhd

vcom -2008 -work work ./test/clock_divider_tb.vhd
vcom -2008 -work work ./test/ram_block_tb.vhd
vcom -2008 -work work ./test/timer_tb.vhd