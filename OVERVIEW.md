# Printer Port Mapping
## The magic happens in 
 - `/etc/udev/rules.d/050_persistent_printer_mappings.rules` 
 - `/dev/persistent_lp/`

## Fixed ports per model:

    Pi1:
    ETH lp0
    PRT lp1

    Pi3B:
    ETH lp0 lp2
    PRT lp1 lp3

    Pi3B+:
    ETH lp2 lp1
    PRT lp3 lp0

    Pi4B
    lp0 lp2 ETH
    lp1 lp3 PRT
