# i3 Rice runs as an Xorg session. Some display managers can leave
# XDG_SESSION_TYPE set to wayland, which makes Qt apps try Wayland.
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORM=xcb
