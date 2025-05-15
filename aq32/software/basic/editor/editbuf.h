#pragma once

#include "common.h"

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

struct editbuf {
    int      line_count;
    uint8_t *p_buf;
    uint8_t *p_buf_end;
    uint8_t *cached_p;
    int      cached_p_line;
    bool     modified;
};

void editbuf_init(struct editbuf *eb, uint8_t *p, size_t size);
void editbuf_reset(struct editbuf *eb);
int  editbuf_get_line_count(struct editbuf *eb);
int  editbuf_get_line(struct editbuf *eb, int line, const uint8_t **p);
bool editbuf_insert_ch(struct editbuf *eb, int line, int pos, char ch);
bool editbuf_delete_ch(struct editbuf *eb, int line, int pos);
bool editbuf_insert_line(struct editbuf *eb, int line, const char *s, size_t sz);
bool editbuf_split_line(struct editbuf *eb, int line, int pos);
