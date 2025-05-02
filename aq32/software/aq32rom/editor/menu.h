#pragma once

#include "common.h"

typedef void (*menu_handler_t)(void);

struct menu_item {
    const char    *title;
    const char    *status;
    uint16_t       shortcut;
    menu_handler_t handler;
};

struct menu {
    const char             *title;
    const struct menu_item *items;
};

void           render_menubar(const struct menu *menus, bool show_accel, const struct menu *active_menu);
void           handle_menu(const struct menu *menus, void (*redraw_screen)(void));
menu_handler_t menu_find_shortcut(const struct menu *menus, uint16_t shortcut);
