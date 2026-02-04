LATESTARTSERVICE=true

ui_print "------------------------------------"
ui_print "               Zetamin              "
ui_print "------------------------------------"
ui_print "         By: Kanagawa Yamada        "
ui_print "------------------------------------"
ui_print "      DO NOT COMBINE WITH OTHER     "
ui_print "            SCREEN TWEAKS           "
ui_print "------------------------------------"
ui_print " "
sleep 1.5

ui_print "-----------------📱-----------------"
ui_print "            DEVICE INFO             "
ui_print "-----------------📱-----------------"
ui_print "DEVICE : $(getprop ro.build.product) "
ui_print "MODEL : $(getprop ro.product.model) "
ui_print "MANUFACTURE : $(getprop ro.product.system.manufacturer) "
ui_print "PROC : $(getprop ro.product.board) "
ui_print "CPU : $(getprop ro.hardware) "
ui_print "ANDROID VER : $(getprop ro.build.version.release) "
ui_print "KERNEL : $(uname -r) "
ui_print "RAM : $(free | grep Mem |  awk '{print $2}') "
ui_print " "
sleep 1.5

ui_print "------------------------------------"
ui_print "            MODULE INFO             "
ui_print "------------------------------------"
ui_print "Name : Zetamin"
ui_print "Version : 1.0"
ui_print "Support Root : Magisk / KernelSU"
ui_print " "
sleep 1.5

ui_print "        Installing Zetamin          "
ui_print " "

unzip -o "$ZIPFILE" 'Zetamin/*' -d $MODPATH >&2
set_perm_recursive $MODPATH/Zetamin 0 0 0755 0644