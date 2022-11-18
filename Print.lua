-----------------------------------------------------
--Print function
-----------------------------------------------------

print = function(msg, color_msg, arrow, ...)
    console.print_color( ' ['.. msg ..'] ', color_msg)

    if ( arrow == true ) then
        console.print_color("> ", color(80, 79, 80, 255))
    end

    console.print(... ..'\n') 
end