#pragma once

#include "common.h"

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

struct editbuf {
    uint8_t *p_buf;
    uint8_t *p_buf_end;
    int      line_count;
    uint8_t *cached_p;
    int      cached_p_line;
    bool     modified;
};

void editbuf_init(struct editbuf *eb, uint8_t *p, size_t size);
void editbuf_reset(struct editbuf *eb);
bool editbuf_get_modified(struct editbuf *eb);
int  editbuf_get_line_count(struct editbuf *eb);
int  editbuf_get_line(struct editbuf *eb, int line, const uint8_t **p);
bool editbuf_insert_ch(struct editbuf *eb, int line, int pos, char ch);
bool editbuf_delete_ch(struct editbuf *eb, int line, int pos);
bool editbuf_insert_line(struct editbuf *eb, int line, const char *s, size_t sz);
bool editbuf_split_line(struct editbuf *eb, int line, int pos);

bool editbuf_convert_from_regular(struct editbuf *eb, const uint8_t *ps, const uint8_t *ps_end);
int  editbuf_convert_to_regular(struct editbuf *eb);
