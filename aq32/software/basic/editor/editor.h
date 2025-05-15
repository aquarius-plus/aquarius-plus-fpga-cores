#pragma once

#include "menu.h"
#include "dialog.h"
#include "screen.h"
#include "editbuf.h"

extern const struct menu menubar_menus[];

typedef struct {
    int line, pos;
} location_t;

static inline bool loc_lt(location_t l, location_t r) {
    return (l.line == r.line) ? (l.pos < r.pos) : (l.line < r.line);
}

void       editor(struct editbuf *eb);
void       editor_redraw_screen(void);
void       editor_set_cursor(location_t loc);
location_t editor_get_cursor(void);

void cmd_file_new(void);
void cmd_file_open(void);
void cmd_file_save(void);
void cmd_file_save_as(void);
void cmd_file_exit(void);
