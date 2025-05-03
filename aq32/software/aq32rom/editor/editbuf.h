#pragma once

#include "common.h"

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

struct editbuf {
    uint8_t buf[256 * 1024];
    int     line_count;

    uint8_t *cached_p;
    int      cached_p_line;
};

void editbuf_init(struct editbuf *eb);
int  editbuf_get_line_count(struct editbuf *eb);
int  editbuf_get_line(struct editbuf *eb, int line, const uint8_t **p);
void editbuf_insert_ch(struct editbuf *eb, int line, int pos, char ch);
void editbuf_delete_ch(struct editbuf *eb, int line, int pos);
void editbuf_insert_line(struct editbuf *eb, int line, const char *s, size_t sz);
void editbuf_split_line(struct editbuf *eb, int line, int pos);
