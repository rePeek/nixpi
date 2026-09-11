# Plugin-specific runtime environment.
# Keep an explicitly supplied value, otherwise let pi-fff override pi's file tools.
: "${PI_FFF_MODE:=override}"
export PI_FFF_MODE
