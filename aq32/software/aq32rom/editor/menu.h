#pragma once

#include "common.h"

struct menu_item {
    const char *title;
};

struct menu {
    const char             *title;
    const struct menu_item *items;
};

void render_menubar(const struct menu *menus, bool show_accel, const struct menu *active_menu);
void handle_menu(const struct menu *menus, void (*redraw_screen)(void));
