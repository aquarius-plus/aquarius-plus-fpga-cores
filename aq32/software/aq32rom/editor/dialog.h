#pragma once

#include "common.h"

bool dialog_open(char *filename, size_t filename_max);
bool dialog_save(char *filename, size_t filename_max);
int  dialog_confirm(const char *text);
