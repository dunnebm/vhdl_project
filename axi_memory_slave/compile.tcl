if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

vlib rtl_work
vmap work rtl_work
vmap component_lib ../components/component_lib
vmap osvvm $env(QUARTUS_ROOTDIR)/../modelsim_ase/osvvm

vcom -2008 -work work src/axi_memory_slave_pkg.vhd
vcom -2008 -work work src/ram_block.vhd
vcom -2008 -work work src/axi_write_transfer_controller.vhd
vcom -2008 -work work src/axi_read_transfer_controller.vhd
vcom -2008 -work work src/axi_memory_slave.vhd

vcom -2008 -work work test/ram_block_tb.vhd
vcom -2008 -work work test/axi_write_transfer_controller_tb.vhd
vcom -2008 -work work test/axi_read_transfer_controller_tb.vhd
vcom -2008 -work work test/axi_memory_slave_tb.vhd