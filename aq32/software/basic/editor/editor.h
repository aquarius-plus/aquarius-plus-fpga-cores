#pragma once

#include "menu.h"
#include "dialog.h"
#include "screen.h"
#include "editbuf.h"

extern const struct menu menubar_menus[];

void editor(struct editbuf *eb);

void editor_set_cursor(int line, int pos);
void editor_redraw_screen(void);

void cmd_file_new(void);
void cmd_file_open(void);
void cmd_file_save(void);
void cmd_file_save_as(void);
void cmd_file_exit(void);
