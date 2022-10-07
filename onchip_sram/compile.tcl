if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

vlib rtl_work
vmap work rtl_work
vmap component_lib ../components/component_lib
vmap osvvm $env(QUARTUS_ROOTDIR)/../modelsim_ase/osvvm

vcom -93 -work work src/sram_read_transfer_controller.vhd
vcom -93 -work work src/onchip_sram.vhd
vcom -93 -work work src/onchip_sram_tb.vhd