if {[file exists component_lib]} {
    vdel -lib component_lib -all
}

vlib component_lib
vmap work component_lib

vcom -93 -work work ./src/my_pkg.vhd
vcom -93 -work work ./src/dflipflop.vhd
vcom -93 -work work ./src/general_sized_register.vhd
vcom -93 -work work ./src/counter.vhd
vcom -93 -work work ./src/simple_timer.vhd
vcom -93 -work work ./src/timer.vhd
vcom -93 -work work ./src/shift_register.vhd
vcom -93 -work work ./src/clock_divider.vhd
vcom -93 -work work ./src/ram_block.vhd