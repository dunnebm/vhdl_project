if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

vlib rtl_work
vmap work rtl_work
vmap component_lib ../components/component_lib

vcom -93 -work work src/LT24_touch_cmd_and_data_controller.vhd
vcom -93 -work work src/LT24_touch_cs_fsm.vhd
vcom -93 -work work src/LT24_touch_data_write_enable_fsm.vhd
vcom -93 -work work src/LT24_touch_init_fsm.vhd
vcom -93 -work work src/LT24_touch_penirq_fsm.vhd
vcom -93 -work work src/LT24_touch_spi_controller.vhd
vcom -93 -work work src/LT24_touch_spi_controller.vhd
vcom -93 -work work src/LT24_touch_spi_controller_tb.vhd