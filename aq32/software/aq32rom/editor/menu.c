#include "menu.h"
#include "screen.h"
#include <ctype.h>

static int get_menuitem_count(const struct menu *menu) {
    int                     count = 0;
    const struct menu_item *mi    = menu->items;
    while (mi && mi->title) {
        if (mi->title[0] != '-')
            count++;
        mi++;
    }
    return count;
}

static int get_menu_width(const struct menu *menu) {
    int                     width = 0;
    const struct menu_item *mi    = menu->items;
    while (mi && mi->title) {
        if (mi->title[0] != '-') {
            const char *p = mi->title;
            int         w = 0;
            while (*(p++)) {
                if (p[0] == '&')
                    continue;
                w++;
            }
            if (w > width)
                width = w;
        }
        mi++;
    }
    return width;
}

void render_menubar(const struct menu *menus, bool show_accel, const struct menu *active_menu) {
    scr_locate(0, 0);
    scr_setcolor(COLOR_MENU);

    const struct menu *m = menus;
    scr_putchar(' ');
    scr_putchar(' ');

    while (m->title) {
        uint8_t col = (m == active_menu) ? COLOR_MENU_SEL : COLOR_MENU;
        scr_setcolor(col);
        scr_putchar(' ');

        const char *p = m->title;
        while (*p) {
            if (*p == '&') {
                p++;
                if (show_accel)
                    color = (color & 0x0F00) | (0xF000);
            }
            scr_putchar(*(p++));

            scr_setcolor(col);
        }

        scr_putchar(' ');
        m++;
    }

    scr_setcolor(COLOR_MENU);
    while (p_scr < TRAM + 80) {
        scr_putchar(' ');
    }
}

static int get_menu_offset(const struct menu *menus, const struct menu *active_menu) {
    int                x = 1;
    const struct menu *m = menus;
    while (m != active_menu && m->title) {
        const char *p = m->title;
        x++;
        while (*p) {
            if (*p == '&')
                p++;
            p++;
            x++;
        }
        x++;
        m++;
    }
    return x;
}

static const struct menu_item *get_menu_item_by_idx(const struct menu *menu, int idx) {
    int                     count = 0;
    const struct menu_item *mi    = menu->items;
    while (mi && mi->title) {
        if (mi->title[0] != '-')
            count++;

        if (count == idx)
            return mi;
        mi++;
    }
    return NULL;
}

static const struct menu_item *get_menu_item_by_accel(const struct menu *menu, char ch) {
    const struct menu_item *mi = menu->items;
    while (mi && mi->title) {
        const char *p = mi->title;
        while (*p) {
            if (p[0] == '&') {
                if (toupper(p[1]) == toupper(ch))
                    return mi;
                break;
            }
            p++;
        }
        mi++;
    }
    return NULL;
}

static const struct menu *get_menu_by_accel(const struct menu *menus, char ch) {
    const struct menu *m = menus;
    while (m && m->title) {
        const char *p = m->title;
        while (*p) {
            if (p[0] == '&') {
                if (toupper(p[1]) == toupper(ch))
                    return m;
                break;
            }
            p++;
        }
        m++;
    }
    return NULL;
}

static void render_menu(const struct menu *menus, const struct menu *active_menu, int active_idx) {
    int x   = get_menu_offset(menus, active_menu);
    int y   = 1;
    int w   = 1 + get_menu_width(active_menu);
    int idx = 0;

    // Draw top border
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_putchar(16);
    for (int i = 0; i < w; i++)
        scr_putchar(25);
    scr_putchar(18);
    y++;

    // Draw items
    const struct menu_item *mi = active_menu->items;
    while (mi && mi->title) {
        scr_locate(y, x);
        scr_setcolor(COLOR_MENU);
        int w2 = w;

        if (mi->title[0] == '-') {
            // Separator
            scr_putchar(19);
            for (int i = 0; i < w; i++)
                scr_putchar(25);
            scr_putchar(21);
        } else {
            scr_putchar(26);

            uint8_t col = (idx == active_idx) ? COLOR_MENU_SEL : COLOR_MENU;
            scr_setcolor(col);
            scr_putchar(' ');

            const char *p = mi->title;
            while (*p) {
                scr_setcolor(col);
                if (*p == '&') {
                    p++;
                    scr_setcolor(col | 0xF0);
                }
                scr_putchar(*(p++));
                w2--;
            }
            while (--w2 > 0) {
                scr_putchar(' ');
            }

            scr_setcolor(COLOR_MENU);
            scr_putchar(26);
            idx++;
        }

        mi++;
        y++;
    }

    // Draw bottom border
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_putchar(22);
    for (int i = 0; i < w; i++)
        scr_putchar(25);
    scr_putchar(24);
}

void handle_menu(const struct menu *menus, void (*redraw_screen)(void)) {
    int                key;
    const struct menu *active_menu = menus;
    bool               menu_open   = false;

    // Entering when Alt is being pressed
    render_menubar(menus, true, NULL);

    // Wait for Alt to be released or an accelerator key pressed
    while (1) {
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            if ((key & KEY_KEYDOWN) == 0 && (scancode == 0xE2 || scancode == 0xE6)) {
                break;
            }
        } else {
            uint8_t ch = key & 0xFF;

            // Find menu with matching accelerator key
            while (active_menu->title) {
                const char *p = active_menu->title;
                while (*p) {
                    if (p[0] == '&' && toupper(p[1]) == toupper(ch)) {
                        break;
                    }
                    p++;
                }
                if (*p)
                    break;

                active_menu++;
            }

            // No match found
            if (!active_menu->title)
                return;

            // Match found
            menu_open = true;
            break;
        }
    }

    int  active_idx   = 0;
    bool needs_redraw = true;

    const struct menu_item *selected_mi = NULL;

    // Menu interaction
    while (selected_mi == NULL) {
        if (needs_redraw) {
            active_idx = 0;
            redraw_screen();
            needs_redraw = false;
        }
        render_menubar(menus, !menu_open, active_menu);

        if (menu_open)
            render_menu(menus, active_menu, active_idx);

        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Dismiss menu on pressing and releasing alt again or pressing ESC
            if (((key & KEY_KEYDOWN) && (scancode == 0xE2 || scancode == 0xE6)) ||
                ((key & KEY_KEYDOWN) && scancode == 0x29))
                return;

        } else {
            uint8_t ch = key & 0xFF;
            if (ch == CH_RIGHT) {
                active_menu++;
                if (!active_menu->title)
                    active_menu = menus;
                needs_redraw = true;
            } else if (ch == CH_LEFT) {
                if (active_menu == menus) {
                    while (active_menu[1].title)
                        active_menu++;
                } else {
                    active_menu--;
                }
                needs_redraw = true;
            } else if (ch == CH_DOWN) {
                if (!menu_open) {
                    menu_open = true;
                } else {
                    active_idx++;
                    if (active_idx >= get_menuitem_count(active_menu)) {
                        active_idx = 0;
                    }
                }
            } else if (ch == CH_UP) {
                if (menu_open) {
                    active_idx--;
                    if (active_idx < 0) {
                        active_idx = get_menuitem_count(active_menu) - 1;
                    }
                }
            } else if (ch == '\r') {
                if (!menu_open) {
                    menu_open = true;
                } else {
                    selected_mi = get_menu_item_by_idx(active_menu, active_idx);
                }
            } else {
                if (!menu_open) {
                    const struct menu *m = get_menu_by_accel(menus, ch);
                    if (m) {
                        active_menu = m;
                        menu_open   = true;
                    }
                } else {
                    selected_mi = get_menu_item_by_accel(active_menu, ch);
                }
            }
        }
        if (selected_mi != NULL)
            break;
    }

    redraw_screen();

    if (selected_mi && selected_mi->handler) {
        selected_mi->handler();
    }
}
